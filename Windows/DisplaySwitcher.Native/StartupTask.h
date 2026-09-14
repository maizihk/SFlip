#pragma once
#include <atomic>
#include <cstdint>
#include <functional>
#include <memory>
#include <utility>

namespace DisplaySwitcher::Native
{
    // UI-owned lifecycle; work runs on the injected background executor. A burst
    // of topology changes requests one fresh scan after the current scan finishes.
    class StartupTask final
    {
    public:
        using Execute = std::function<void(std::function<void()>)>;
        using Work = std::function<void()>;
        using Completion = std::function<void(bool)>;

        ~StartupTask() { Cancel(); }
        bool Pending() const noexcept { return !state_ || state_->pending; }
        void Invalidate() noexcept { if (state_ && state_->pending) ++state_->revision; }
        void Cancel() noexcept { if (state_) state_->canceled = true; }

        void Start(Work work, Execute background, Execute foreground, Completion completion)
        {
            Cancel();
            state_ = std::make_shared<State>();
            state_->work = std::move(work);
            state_->background = std::move(background);
            state_->foreground = std::move(foreground);
            state_->completion = std::move(completion);
            Schedule(state_);
        }

    private:
        struct State
        {
            std::atomic<bool> canceled{};
            bool pending{ true };
            uint64_t revision{};
            Work work;
            Execute background;
            Execute foreground;
            Completion completion;
        };

        static void Schedule(std::shared_ptr<State> const& state)
        {
            auto revision = state->revision;
            auto complete = [state, revision](bool success)
            {
                if (state->canceled) return;
                if (revision != state->revision) { Schedule(state); return; }
                state->pending = false;
                if (state->completion) state->completion(success);
            };
            try
            {
                state->background([state, complete]
                {
                    if (state->canceled) return;
                    bool success{};
                    try { state->work(); success = true; }
                    catch (...) { success = false; }
                    if (!state->canceled)
                    {
                        try { state->foreground([complete, success] { complete(success); }); }
                        catch (...) { state->canceled = true; } // UI shutdown: never publish from the worker.
                    }
                });
            }
            catch (...) { complete(false); }
        }

        std::shared_ptr<State> state_;
    };
}
