#pragma once

#include "App.xaml.g.h"
#include "Controller.h"

namespace winrt::DisplaySwitcher::Native::implementation
{
    struct App : AppT<App>
    {
        App();
        void OnLaunched(Microsoft::UI::Xaml::LaunchActivatedEventArgs const&);

    private:
        void ExitApplication();
        // Installer detects running instances without terminating hardware work.
        winrt::handle installationMutex_{ CreateMutexW(nullptr, FALSE, L"Local\\SFlip.Installation") };
        Microsoft::UI::Xaml::Window lifetimeWindow_{ nullptr };
        std::shared_ptr<::DisplaySwitcher::Native::Controller> controller_;
    };
}
