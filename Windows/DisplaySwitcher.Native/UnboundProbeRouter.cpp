#include "pch.h"
#include "UnboundProbeRouter.h"

namespace
{
    bool EqualId(std::wstring const& left, std::wstring const& right)
    {
        return _wcsicmp(left.c_str(), right.c_str()) == 0;
    }
}

namespace DisplaySwitcher::Native
{
    bool ShouldRouteUnboundStatusProbe(V2Message const& message,
        std::wstring const&, bool)
    {
        return message.type == L"status_probe";
    }

    UnboundProbeMatch MatchUnboundStatusProbe(std::vector<CollaborationProfile> const& candidates,
        std::wstring const& localEndpointId, DatagramSource const& source, V2Message const& message,
        int64_t nowUnixSeconds, int64_t nowMilliseconds, ProbeHostMatcher const& hostMatches,
        V2ReplayCache* replayCache, ProbeKeyProvider const& keyProvider)
    {
        if (message.type != L"status_probe") return {};
        if (!IsValidDisplayId(localEndpointId) || EqualId(message.sourceEndpointId, localEndpointId))
            return { UnboundProbeMatchStatus::EndpointConflict };

        std::vector<size_t> hostCandidates;
        std::vector<size_t> authenticatedCandidates;
        for (size_t index = 0; index < candidates.size(); ++index)
        {
            auto const& profile = candidates[index];
            if ((profile.peerProtocolVersion && *profile.peerProtocolVersion != 2) ||
                !hostMatches(profile, source)) continue;
            hostCandidates.push_back(index);
            try
            {
                auto key = keyProvider ? keyProvider(profile.pairingCode, message.sourceEndpointId) :
                    DeriveV2AuthenticationKey(NormalizeV2PairingSecret(profile.pairingCode), message.sourceEndpointId);
                if (ValidateV2Message(message, localEndpointId, message.sourceEndpointId, key,
                    nowUnixSeconds, nullptr, nowMilliseconds).accepted)
                    authenticatedCandidates.push_back(index);
            }
            catch (...) {}
        }
        if (authenticatedCandidates.empty())
            return { hostCandidates.empty() ? UnboundProbeMatchStatus::NoMatch :
                UnboundProbeMatchStatus::AuthenticationFailed };
        if (authenticatedCandidates.size() != 1) return { UnboundProbeMatchStatus::Ambiguous };

        auto index = authenticatedCandidates.front();
        auto const& profile = candidates[index];
        auto key = keyProvider ? keyProvider(profile.pairingCode, message.sourceEndpointId) :
            DeriveV2AuthenticationKey(NormalizeV2PairingSecret(profile.pairingCode), message.sourceEndpointId);
        auto validation = ValidateV2Message(message, localEndpointId, message.sourceEndpointId, key,
            nowUnixSeconds, replayCache, nowMilliseconds);
        if (!validation.accepted)
            return { validation.reason == L"authentication_failed" ?
                UnboundProbeMatchStatus::AuthenticationFailed : UnboundProbeMatchStatus::NoMatch };
        return { UnboundProbeMatchStatus::Matched, index, validation.duplicate };
    }
    V2Message CreateStatusProbe(std::wstring const& localEndpointId, std::wstring eventId,
        int64_t nowUnixSeconds, std::wstring nonce, std::wstring const& pairingCode,
        ProbeKeyProvider const& keyProvider)
    {
        V2Message probe;
        probe.type = L"status_probe";
        probe.eventId = std::move(eventId);
        probe.sourceEndpointId = localEndpointId;
        probe.targetEndpointId.reset();
        probe.sourcePlatform = L"windows";
        probe.timestamp = nowUnixSeconds;
        probe.nonce = std::move(nonce);
        auto key = keyProvider ? keyProvider(pairingCode, localEndpointId) :
            DeriveV2AuthenticationKey(NormalizeV2PairingSecret(pairingCode), localEndpointId);
        return SignV2Message(std::move(probe), key);
    }
    V2Message CreateUnboundStatusResponse(V2Message const& probe, std::wstring const& localEndpointId,
        int64_t nowUnixSeconds, std::wstring nonce, std::wstring const& pairingCode,
        ProbeKeyProvider const& keyProvider)
    {
        V2Message response;
        response.type = L"status_response";
        response.eventId = probe.eventId;
        response.sourceEndpointId = localEndpointId;
        response.targetEndpointId = probe.sourceEndpointId;
        response.sourcePlatform = L"windows";
        response.timestamp = nowUnixSeconds;
        response.nonce = std::move(nonce);
        auto key = keyProvider ? keyProvider(pairingCode, localEndpointId) :
            DeriveV2AuthenticationKey(NormalizeV2PairingSecret(pairingCode), localEndpointId);
        return SignV2Message(std::move(response), key);
    }
    V2Message GetOrCreateStatusResponse(std::map<std::wstring, V2Message>& cache,
        V2Message const& probe, std::wstring const& localEndpointId, int64_t nowUnixSeconds,
        std::wstring nonce, std::wstring const& pairingCode, ProbeKeyProvider const& keyProvider)
    {
        auto key = L"status_response|" + probe.eventId + L"|" + probe.sourceEndpointId;
        auto cached = cache.find(key);
        if (cached != cache.end()) return cached->second;
        auto response = CreateUnboundStatusResponse(probe, localEndpointId, nowUnixSeconds,
            std::move(nonce), pairingCode, keyProvider);
        cache.emplace(std::move(key), response);
        return response;
    }
}
