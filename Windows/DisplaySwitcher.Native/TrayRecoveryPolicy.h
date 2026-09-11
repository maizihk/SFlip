#pragma once

#include <cstddef>
#include <utility>

namespace DisplaySwitcher::Native
{
    enum class TrayRecoveryAttemptOutcome
    {
        Complete,
        Retry,
        Exhausted,
    };

    struct TrayRecoveryAttemptResult
    {
        TrayRecoveryAttemptOutcome outcome{};
        bool iconPresent{};
    };

    template<typename Modify, typename Add, typename SetVersion>
    TrayRecoveryAttemptResult ExecuteTrayRecoveryAttempt(size_t attempt, size_t maximumAttempts,
        Modify&& modify, Add&& add, SetVersion&& setVersion)
    {
        auto iconPresent = std::forward<Modify>(modify)();
        if (!iconPresent) iconPresent = std::forward<Add>(add)();
        if (iconPresent && std::forward<SetVersion>(setVersion)())
            return { TrayRecoveryAttemptOutcome::Complete, true };
        return { attempt + 1 < maximumAttempts
            ? TrayRecoveryAttemptOutcome::Retry
            : TrayRecoveryAttemptOutcome::Exhausted, iconPresent };
    }
}