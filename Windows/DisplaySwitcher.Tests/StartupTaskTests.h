#pragma once
#include "../DisplaySwitcher.Native/StartupTask.h"
#include <deque>
#include <stdexcept>

namespace DisplaySwitcher::Native::Tests
{
    template<typename Check>
    void RunStartupTaskTests(Check check)
    {
        using Queue = std::deque<std::function<void()>>;
        auto run = [](Queue& queue)
        {
            auto work = std::move(queue.front());
            queue.pop_front();
            work();
        };
        Queue background, foreground;
        auto worker = [&](std::function<void()> action) { background.push_back(std::move(action)); };
        auto dispatch = [&](std::function<void()> action) { foreground.push_back(std::move(action)); };
        int scans{}, publications{};
        bool succeeded{};
        StartupTask task;
        auto start = [&]
        {
            task.Start([&] { ++scans; }, worker, dispatch,
                [&](bool success) { ++publications; succeeded = success; });
        };
        start();
        check(task.Pending() && scans == 0 && publications == 0 && background.size() == 1,
            L"startup returns to the UI before slow device work begins");
        run(background);
        check(task.Pending() && scans == 1 && publications == 0 && foreground.size() == 1,
            L"device results cannot publish from the worker thread");
        task.Invalidate(); task.Invalidate(); task.Invalidate();
        run(foreground);
        check(task.Pending() && publications == 0 && background.size() == 1,
            L"a topology burst discards the queued snapshot and coalesces one new scan");
        run(background); run(foreground);
        check(!task.Pending() && scans == 2 && publications == 1 && succeeded,
            L"only the current topology result completes initialization once");

        start(); task.Cancel(); run(background);
        check(scans == 2 && foreground.empty() && publications == 1,
            L"exit before worker execution performs no scan or publication");
        task.Start([&] { ++scans; task.Cancel(); }, worker, dispatch,
            [&](bool) { ++publications; });
        run(background);
        check(foreground.empty() && publications == 1,
            L"exit during a slow scan does not schedule completion");
        start(); run(background); task.Cancel(); run(foreground);
        check(publications == 1, L"exit after worker completion rejects the queued UI result");

        start(); run(background); start(); run(foreground);
        check(publications == 1 && task.Pending(), L"replaced startup cannot publish a prior queued result");
        run(background); run(foreground);
        check(publications == 2 && !task.Pending(), L"replacement completes through its own dispatcher callback");

        task.Start([] { throw std::runtime_error("simulated enumeration failure"); }, worker, dispatch,
            [&](bool success) { ++publications; succeeded = success; });
        run(background);
        check(task.Pending() && publications == 2, L"enumeration exceptions return through UI completion");
        run(foreground);
        check(!task.Pending() && !succeeded && publications == 3,
            L"enumeration failure is reported without success or endless retries");

        task.Start([] {}, [](std::function<void()>) { throw std::runtime_error("no worker available"); },
            dispatch, [&](bool success) { ++publications; succeeded = success; });
        check(!task.Pending() && !succeeded && publications == 4,
            L"worker creation failure reports failure on the initiating UI thread");

        {
            StartupTask temporary;
            temporary.Start([] {}, worker, dispatch, [&](bool) { ++publications; });
            run(background);
        }
        run(foreground);
        check(publications == 4, L"destroyed startup owner cannot receive a queued completion");
    }
}
