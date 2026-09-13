import Foundation
import XCTest

final class LocalizationTests: XCTestCase {
    private var previousPreference: Any?

    override func setUp() {
        super.setUp()
        previousPreference = UserDefaults.standard.object(forKey: L10n.preferenceKey)
    }

    override func tearDown() {
        if let previousPreference {
            UserDefaults.standard.set(previousPreference, forKey: L10n.preferenceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: L10n.preferenceKey)
        }
        super.tearDown()
    }

    func testLanguageResolutionUsesPrimarySystemLanguageAndExplicitChoice() {
        XCTAssertEqual(AppLanguage.resolve(.system, preferredLanguages: ["zh-Hans-CN", "en"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(.system, preferredLanguages: ["zh-Hant-TW"]), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.resolve(.system, preferredLanguages: ["en-US", "zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.resolve(.system, preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.resolve(.system, preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.resolve(.english, preferredLanguages: ["zh-Hans"]), .english)
        XCTAssertEqual(AppLanguage.resolve(.simplifiedChinese, preferredLanguages: ["en"]), .simplifiedChinese)
    }

    func testMissingOrUnknownPreferenceSafelyUsesSystem() {
        UserDefaults.standard.removeObject(forKey: L10n.preferenceKey)
        XCTAssertEqual(L10n.preference, .system)
        UserDefaults.standard.set("future-language", forKey: L10n.preferenceKey)
        XCTAssertEqual(L10n.preference, .system)
        L10n.preference = .english
        XCTAssertEqual(UserDefaults.standard.string(forKey: L10n.preferenceKey), "en")
    }

    func testEveryCatalogEntryHasEnglishAndMatchingPlaceholders() {
        let pattern = try! NSRegularExpression(pattern: #"\{[0-9]+\}"#)
        let han = try! NSRegularExpression(pattern: #"\p{Han}"#)
        func placeholders(_ value: String) -> [String] {
            pattern.matches(in: value, range: NSRange(value.startIndex..<value.endIndex, in: value))
                .map { String(value[Range($0.range, in: value)!]) }.sorted()
        }
        XCTAssertGreaterThan(L10n.english.count, 300)
        for (source, english) in L10n.english {
            XCTAssertFalse(english.isEmpty, source)
            XCTAssertNil(han.firstMatch(in: english, range: NSRange(english.startIndex..<english.endIndex, in: english)), source)
            XCTAssertEqual(placeholders(source), placeholders(english), source)
            XCTAssertEqual(L10n.text(source, language: .simplifiedChinese), source)
            XCTAssertEqual(L10n.text(source, language: .english), english)
        }
    }

    func testTemplateFormattingPreservesUserDataWithoutRecursiveReplacement() {
        let name = "显示器 {1} % @ HDMI 中文"
        XCTAssertEqual(L10n.render("Connected to {0}; {1}", arguments: [name, "Ready"]), "Connected to \(name); Ready")
        L10n.preference = .english
        XCTAssertEqual(CollaborationConnectionStatusPresentation.text(for: .connected, profileName: name), "Connected to \(name)")
        L10n.preference = .simplifiedChinese
        XCTAssertEqual(CollaborationConnectionStatusPresentation.text(for: .connected, profileName: name), "已和对端（\(name)）建立连接")
    }

    func testLanguageChangeUpdatesComputedPresentationWithoutChangingConfiguration() throws {
        var document = DisplayConfigurationStoreV5Document(
            schemaVersion: 5, localEndpointID: "11111111-1111-1111-1111-111111111111",
            localDeviceName: "本机 {0}", listenPort: 49731, linkAllDisplays: false,
            displays: [], collaborationProfiles: [], usbSwitch: .disabled
        )
        document.collaborationProfiles = [CollaborationProfile(
            id: "22222222-2222-2222-2222-222222222222", name: "自定义配置 {1}",
            peerHost: "peer.example", peerPort: 49731, pairingCode: "example-code",
            peerEndpointID: nil, peerProtocolVersion: nil, coordinationEnabled: false,
            displayInputs: [], triggerDevices: []
        )]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let before = try encoder.encode(document)
        L10n.preference = .english
        XCTAssertEqual(SettingsPageLayoutProjection.tabLabels, ["General", "USB Switching", "Collaboration", "Displays", "Diagnostics", "About"])
        XCTAssertEqual(DDCCommand.luminance.userFacingName, "Brightness")
        XCTAssertEqual(DisplayDDCStatusPresentation.read(values: [:], skipReason: nil), "Read Failed")
        XCTAssertEqual(try encoder.encode(document), before)
        XCTAssertFalse(String(data: before, encoding: .utf8)!.contains(L10n.preferenceKey))
        XCTAssertEqual(document.collaborationProfiles[0].name, "自定义配置 {1}")
        L10n.preference = .simplifiedChinese
        XCTAssertEqual(SettingsPageLayoutProjection.tabLabels[0], "常规")
        XCTAssertEqual(DDCCommand.luminance.userFacingName, "亮度")
    }

    func testSocketOperationDiagnosticCategoriesAreStableAcrossLanguageChanges() {
        let error = PeerTransportError.socketOperation("绑定", 1)
        L10n.preference = .simplifiedChinese
        XCTAssertEqual(error.diagnosticCategory, .socketBind)
        L10n.preference = .english
        XCTAssertEqual(error.diagnosticCategory, .socketBind)
        XCTAssertTrue(error.localizedDescription.contains("binding"))
    }
}
