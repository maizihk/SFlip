import Darwin
import Foundation

struct PeerTransportEndpoint: Equatable {
    let host: String
    let port: Int
}

enum PeerTransportFailureCategory: String, Equatable {
    case invalidPort = "invalid-port"
    case invalidDestination = "invalid-destination"
    case notStarted = "listener-not-started"
    case socketCreate = "socket-create-failed"
    case socketConfigure = "socket-configure-failed"
    case socketBind = "socket-bind-failed"
    case addressResolution = "address-resolution-failed"
    case send = "send-failed"
    case receive = "receive-failed"
    case unknown = "unknown-error"
}

enum PeerTransportSystemErrorDomain: String, Equatable {
    case posix = "errno"
    case addressResolution = "getaddrinfo"
    case unknown = "unknown"
}

struct PeerTransportSystemError: Equatable {
    let domain: PeerTransportSystemErrorDomain
    let code: Int32
}

enum PeerTransportOperationResult: Equatable {
    case success
    case failure(PeerTransportFailureCategory, systemError: PeerTransportSystemError? = nil)
}

extension PeerTransportOperationResult {
    var systemError: PeerTransportSystemError? {
        guard case .failure(_, let systemError) = self else { return nil }
        return systemError
    }

    var userFacingErrorCode: String {
        switch self {
        case .success: return "unknown"
        case .failure(_, let systemError):
            guard let systemError else { return "unknown" }
            return "\(systemError.domain.rawValue) \(systemError.code)"
        }
    }
}

protocol PeerTransportDatagramSocket: AnyObject {
    var onDatagram: ((Data, PeerTransportEndpoint) -> Void)? { get set }
    var onReceiveError: ((Error) -> Void)? { get set }
    func start(port: Int, queue: DispatchQueue) throws
    func send(_ data: Data, to endpoint: PeerTransportEndpoint, completion: @escaping (Error?) -> Void)
    func stop()
}

protocol PeerTransportSocketFactory {
    func makeSocket() -> PeerTransportDatagramSocket
}

protocol PeerHostAddressResolving {
    func numericIPv4Addresses(for host: String) -> Set<String>
}

struct BSDPeerHostAddressResolver: PeerHostAddressResolving {
    func numericIPv4Addresses(for host: String) -> Set<String> {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_UDP
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return [] }
        defer { freeaddrinfo(result) }
        var addresses = Set<String>()
        var current: UnsafeMutablePointer<addrinfo>? = first
        while let item = current {
            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(
                item.pointee.ai_addr, item.pointee.ai_addrlen,
                &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST
            ) == 0 {
                addresses.insert(String(cString: hostBuffer).lowercased())
            }
            current = item.pointee.ai_next
        }
        return addresses
    }
}

enum PeerTransportError: LocalizedError {
    case invalidPort(Int)
    case notStarted
    case socketOperation(String, Int32)
    case addressResolution(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let port): return "通信端口无效：\(port)"
        case .notStarted: return "UDP 发送失败：网络监听尚未启动"
        case .socketOperation(let operation, let code):
            return "UDP \(operation)失败（系统错误 \(code)）"
        case .addressResolution(let code):
            return "UDP 目标地址解析失败（系统错误 \(code)）"
        }
    }

    var diagnosticCategory: PeerTransportFailureCategory {
        switch self {
        case .invalidPort: return .invalidPort
        case .notStarted: return .notStarted
        case .socketOperation(let operation, _):
            switch operation {
            case "创建": return .socketCreate
            case "配置": return .socketConfigure
            case "绑定": return .socketBind
            case "发送": return .send
            case "接收": return .receive
            default: return .unknown
            }
        case .addressResolution: return .addressResolution
        }
    }

    var diagnosticSystemError: PeerTransportSystemError? {
        switch self {
        case .invalidPort, .notStarted: return nil
        case .socketOperation(_, let code):
            return PeerTransportSystemError(domain: .posix, code: code)
        case .addressResolution(let code):
            return PeerTransportSystemError(domain: .addressResolution, code: code)
        }
    }
}

private struct BSDPeerTransportSocketFactory: PeerTransportSocketFactory {
    func makeSocket() -> PeerTransportDatagramSocket { BSDPeerDatagramSocket() }
}

private final class BSDPeerDatagramSocket: PeerTransportDatagramSocket {
    var onDatagram: ((Data, PeerTransportEndpoint) -> Void)?
    var onReceiveError: ((Error) -> Void)?

    private var descriptor: Int32 = -1
    private var readSource: DispatchSourceRead?

    func start(port: Int, queue: DispatchQueue) throws {
        guard (1...65_535).contains(port) else { throw PeerTransportError.invalidPort(port) }
        guard descriptor < 0 else { return }

        let socketDescriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketDescriptor >= 0 else {
            throw PeerTransportError.socketOperation("创建", errno)
        }
        do {
            var reuseAddress: Int32 = 1
            guard setsockopt(
                socketDescriptor, SOL_SOCKET, SO_REUSEADDR,
                &reuseAddress, socklen_t(MemoryLayout<Int32>.size)
            ) == 0 else {
                throw PeerTransportError.socketOperation("配置", errno)
            }
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = in_port_t(UInt16(port).bigEndian)
            address.sin_addr = in_addr(s_addr: INADDR_ANY)
            let bindResult = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.bind(socketDescriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bindResult == 0 else { throw PeerTransportError.socketOperation("绑定", errno) }
            guard fcntl(socketDescriptor, F_SETFL, O_NONBLOCK) == 0 else {
                throw PeerTransportError.socketOperation("配置", errno)
            }

            descriptor = socketDescriptor
            let source = DispatchSource.makeReadSource(fileDescriptor: socketDescriptor, queue: queue)
            source.setEventHandler { [weak self] in self?.drainDatagrams() }
            readSource = source
            source.resume()
        } catch {
            Darwin.close(socketDescriptor)
            throw error
        }
    }

    func send(_ data: Data, to endpoint: PeerTransportEndpoint, completion: @escaping (Error?) -> Void) {
        guard descriptor >= 0 else {
            completion(PeerTransportError.notStarted)
            return
        }
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_UDP
        var result: UnsafeMutablePointer<addrinfo>?
        let resolution = getaddrinfo(endpoint.host, String(endpoint.port), &hints, &result)
        guard resolution == 0, let address = result else {
            completion(PeerTransportError.addressResolution(resolution))
            return
        }
        defer { freeaddrinfo(result) }
        let sendResult = data.withUnsafeBytes { bytes -> (count: Int, errorCode: Int32) in
            let sent = Darwin.sendto(
                descriptor, bytes.baseAddress, bytes.count, 0,
                address.pointee.ai_addr, address.pointee.ai_addrlen
            )
            return (sent, sent == bytes.count ? 0 : errno)
        }
        guard sendResult.count == data.count else {
            completion(PeerTransportError.socketOperation("发送", sendResult.errorCode))
            return
        }
        completion(nil)
    }

    func stop() {
        guard descriptor >= 0 else { return }
        let socketDescriptor = descriptor
        descriptor = -1
        let source = readSource
        readSource = nil
        source?.cancel()
        Darwin.close(socketDescriptor)
    }

    private func drainDatagrams() {
        guard descriptor >= 0 else { return }
        while true {
            var buffer = [UInt8](repeating: 0, count: 65_535)
            var sourceAddress = sockaddr_storage()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_storage>.size)
            let received = buffer.withUnsafeMutableBytes { bytes in
                withUnsafeMutablePointer(to: &sourceAddress) { address in
                    address.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.recvfrom(descriptor, bytes.baseAddress, bytes.count, 0, $0, &sourceLength)
                    }
                }
            }
            if received >= 0 {
                buffer.removeSubrange(Int(received)..<buffer.count)
                if let endpoint = Self.endpoint(from: &sourceAddress, length: sourceLength) {
                    onDatagram?(Data(buffer), endpoint)
                }
                continue
            }
            if errno == EAGAIN || errno == EWOULDBLOCK { return }
            onReceiveError?(PeerTransportError.socketOperation("接收", errno))
            return
        }
    }

    private static func endpoint(
        from address: inout sockaddr_storage,
        length: socklen_t
    ) -> PeerTransportEndpoint? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        var service = [CChar](repeating: 0, count: Int(NI_MAXSERV))
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getnameinfo(
                    $0, length, &host, socklen_t(host.count), &service, socklen_t(service.count),
                    NI_NUMERICHOST | NI_NUMERICSERV
                )
            }
        }
        guard result == 0, let port = Int(String(cString: service)), port > 0 else { return nil }
        return PeerTransportEndpoint(host: String(cString: host), port: port)
    }
}

final class PeerTransport {
    typealias DataReply = (Data) -> Void

    var onDatagram: ((Data, PeerTransportEndpoint, @escaping DataReply) -> Void)?
    var onError: ((String) -> Void)?

    private let queue: DispatchQueue
    private let callbackQueue: DispatchQueue
    private let factory: PeerTransportSocketFactory
    private let hostResolver: PeerHostAddressResolving
    private let queueKey = DispatchSpecificKey<Void>()
    private var socket: PeerTransportDatagramSocket?
    private var generation = 0
    private(set) var listeningPort: Int?

    init(
        factory: PeerTransportSocketFactory = BSDPeerTransportSocketFactory(),
        hostResolver: PeerHostAddressResolving = BSDPeerHostAddressResolver(),
        queue: DispatchQueue = DispatchQueue(label: "DisplaySwitcher.peer-network"),
        callbackQueue: DispatchQueue = .main
    ) {
        self.factory = factory
        self.hostResolver = hostResolver
        self.queue = queue
        self.callbackQueue = callbackQueue
        queue.setSpecific(key: queueKey, value: ())
    }

    func sourceMatches(_ source: PeerTransportEndpoint, configuredHost: String, port: Int) -> Bool {
        guard source.port == port else { return false }
        return hostResolver.numericIPv4Addresses(for: configuredHost).contains(source.host.lowercased())
    }

    deinit { performSync { stopLocked() } }

    @discardableResult
    func start(port: Int) -> PeerTransportOperationResult {
        var result: PeerTransportOperationResult = .failure(.unknown)
        performSync {
            if socket != nil, listeningPort == port {
                result = .success
                return
            }
            stopLocked()
            let candidate = factory.makeSocket()
            generation += 1
            let activeGeneration = generation
            candidate.onDatagram = { [weak self, weak candidate] data, endpoint in
                guard let candidate else { return }
                self?.performAsync {
                    guard let self, self.generation == activeGeneration,
                          self.socket === candidate else { return }
                    self.deliver(data, from: endpoint, on: candidate, generation: activeGeneration)
                }
            }
            candidate.onReceiveError = { [weak self, weak candidate] error in
                guard let candidate else { return }
                self?.performAsync {
                    guard let self, self.generation == activeGeneration,
                          self.socket === candidate else { return }
                    self.reportError(Self.safeErrorMessage(prefix: "UDP 接收失败", error: error))
                    self.stopLocked()
                }
            }
            do {
                try candidate.start(port: port, queue: queue)
                socket = candidate
                listeningPort = port
                result = .success
            } catch {
                candidate.stop()
                reportError(Self.safeErrorMessage(prefix: "UDP 监听失败", error: error))
                result = Self.failureResult(for: error, fallback: .unknown)
            }
        }
        return result
    }

    func stop() { performSync { stopLocked() } }

    func send(
        _ data: Data,
        host: String,
        port: Int,
        completion: ((PeerTransportOperationResult) -> Void)? = nil
    ) {
        guard !host.isEmpty else {
            callbackQueue.async { completion?(.failure(.invalidDestination)) }
            return
        }
        guard (1...65_535).contains(port) else {
            callbackQueue.async { completion?(.failure(.invalidPort)) }
            return
        }
        performAsync { [weak self] in
            guard let self else { return }
            guard let socket = self.socket, self.listeningPort != nil else {
                self.reportError(PeerTransportError.notStarted.localizedDescription)
                self.callbackQueue.async { completion?(.failure(.notStarted)) }
                return
            }
            self.sendLocked(
                data, to: PeerTransportEndpoint(host: host, port: port),
                on: socket, isReply: false, completion: completion
            )
        }
    }

    private func stopLocked() {
        generation += 1
        socket?.onDatagram = nil
        socket?.onReceiveError = nil
        socket?.stop()
        socket = nil
        listeningPort = nil
    }

    private func deliver(
        _ data: Data,
        from endpoint: PeerTransportEndpoint,
        on socket: PeerTransportDatagramSocket,
        generation activeGeneration: Int
    ) {
        guard let onDatagram else { return }
        let reply: DataReply = { [weak self, weak socket] response in
            guard let self, let socket else { return }
            self.performAsync {
                guard self.generation == activeGeneration, self.socket === socket else { return }
                self.sendLocked(response, to: endpoint, on: socket, isReply: true)
            }
        }
        callbackQueue.async { onDatagram(data, endpoint, reply) }
    }

    private func sendLocked(
        _ data: Data,
        to endpoint: PeerTransportEndpoint,
        on socket: PeerTransportDatagramSocket,
        isReply: Bool,
        completion: ((PeerTransportOperationResult) -> Void)? = nil
    ) {
        socket.send(data, to: endpoint) { [weak self] error in
            guard let self else { return }
            guard let error else {
                self.callbackQueue.async { completion?(.success) }
                return
            }
            let operation = isReply ? "UDP 回复失败" : "UDP 发送失败"
            self.reportError(Self.safeErrorMessage(
                prefix: operation, error: error, fallback: .send
            ))
            let result = Self.failureResult(for: error, fallback: .send)
            self.callbackQueue.async { completion?(result) }
        }
    }

    private static func failureResult(
        for error: Error,
        fallback: PeerTransportFailureCategory
    ) -> PeerTransportOperationResult {
        guard let transportError = error as? PeerTransportError else {
            return .failure(fallback, systemError: .init(domain: .unknown, code: 0))
        }
        return .failure(
            transportError.diagnosticCategory,
            systemError: transportError.diagnosticSystemError
        )
    }

    private static func safeErrorMessage(
        prefix: String,
        error: Error,
        fallback: PeerTransportFailureCategory = .unknown
    ) -> String {
        let result = failureResult(for: error, fallback: fallback)
        switch result {
        case .success: return "\(prefix)：unknown-error"
        case .failure(let category, let systemError):
            guard let systemError else { return "\(prefix)：\(category.rawValue)" }
            return "\(prefix)：\(category.rawValue) \(systemError.domain.rawValue)=\(systemError.code)"
        }
    }

    private func reportError(_ message: String) {
        callbackQueue.async { [weak self] in self?.onError?(message) }
    }

    private func performSync(_ action: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil { action() }
        else { queue.sync(execute: action) }
    }

    private func performAsync(_ action: @escaping () -> Void) {
        queue.async(execute: action)
    }
}
