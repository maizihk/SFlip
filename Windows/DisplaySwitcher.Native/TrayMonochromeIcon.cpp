#include "pch.h"
#include "TrayMonochromeIcon.h"

namespace
{
    struct Point
    {
        double x{};
        double y{};
    };

    double DistanceToSegment(Point point, Point start, Point end) noexcept
    {
        auto dx = end.x - start.x;
        auto dy = end.y - start.y;
        auto lengthSquared = dx * dx + dy * dy;
        if (lengthSquared <= 0.0) return std::hypot(point.x - start.x, point.y - start.y);
        auto position = (std::clamp)(((point.x - start.x) * dx + (point.y - start.y) * dy) /
            lengthSquared, 0.0, 1.0);
        auto closest = Point{ start.x + position * dx, start.y + position * dy };
        return std::hypot(point.x - closest.x, point.y - closest.y);
    }

    bool HitsIconStroke(Point point, double stroke) noexcept
    {
        auto half = stroke / 2.0;
        auto segment = [&](Point start, Point end)
        {
            return DistanceToSegment(point, start, end) <= half;
        };
        // Rounded monitor outline and connected stand, with transparent interior.
        constexpr auto left = 0.04, right = 0.96, top = 0.05, bottom = 0.72, radius = 0.10;
        auto closestX = (std::clamp)(point.x, left + radius, right - radius);
        auto closestY = (std::clamp)(point.y, top + radius, bottom - radius);
        auto outlineDistance = std::hypot(point.x - closestX, point.y - closestY) - radius;
        if (std::abs(outlineDistance) <= half ||
            segment({ 0.50, bottom }, { 0.50, 0.94 }) ||
            segment({ 0.28, 0.94 }, { 0.72, 0.94 })) return true;

        // Opposing arrows replace the old percent symbol. Slightly lighter inner
        // strokes preserve the gap between arrows in the 16-pixel notification slot.
        auto arrowSegment = [&](Point start, Point end)
        {
            return DistanceToSegment(point, start, end) <= half * (5.0 / 6.0);
        };
        return arrowSegment({ 0.26, 0.28 }, { 0.74, 0.28 }) ||
            arrowSegment({ 0.65, 0.19 }, { 0.74, 0.28 }) ||
            arrowSegment({ 0.74, 0.28 }, { 0.65, 0.37 }) ||
            arrowSegment({ 0.74, 0.49 }, { 0.26, 0.49 }) ||
            arrowSegment({ 0.35, 0.40 }, { 0.26, 0.49 }) ||
            arrowSegment({ 0.26, 0.49 }, { 0.35, 0.58 });
    }

    int ColorLuminance(COLORREF color) noexcept
    {
        return (GetRValue(color) * 299 + GetGValue(color) * 587 + GetBValue(color) * 114) / 1000;
    }

    int TaskbarBackgroundLuminance(bool highContrastEnabled) noexcept
    {
        if (highContrastEnabled) return ColorLuminance(GetSysColor(COLOR_WINDOW));
        auto taskbar = FindWindowW(L"Shell_TrayWnd", nullptr);
        RECT bounds{};
        if (taskbar && GetWindowRect(taskbar, &bounds))
        {
            auto screen = GetDC(nullptr);
            if (screen)
            {
                std::vector<int> samples;
                constexpr int positions[]{ 10, 25, 50, 75, 90 };
                auto horizontal = bounds.right - bounds.left >= bounds.bottom - bounds.top;
                for (auto position : positions)
                {
                    auto x = horizontal
                        ? bounds.left + MulDiv(bounds.right - bounds.left - 1, position, 100)
                        : (bounds.left + bounds.right) / 2;
                    auto y = horizontal
                        ? (bounds.top + bounds.bottom) / 2
                        : bounds.top + MulDiv(bounds.bottom - bounds.top - 1, position, 100);
                    auto color = GetPixel(screen, x, y);
                    if (color != CLR_INVALID) samples.push_back(ColorLuminance(color));
                }
                ReleaseDC(nullptr, screen);
                if (!samples.empty())
                {
                    std::sort(samples.begin(), samples.end());
                    return samples[samples.size() / 2];
                }
            }
        }
        return ColorLuminance(GetSysColor(COLOR_3DFACE));
    }
}

namespace DisplaySwitcher::Native
{
    std::vector<uint32_t> RenderMonochromeTrayIconPixels(
        TrayIconGeometry const& geometry, TrayIconTone tone)
    {
        if (geometry.pixelSize <= 0 || geometry.bodySize <= 0 || geometry.bodyLeft < 0 ||
            geometry.bodyTop < 0 || geometry.bodyLeft + geometry.bodySize > geometry.pixelSize ||
            geometry.bodyTop + geometry.bodySize > geometry.pixelSize) return {};
        constexpr int samplesPerAxis = 4;
        constexpr int sampleCount = samplesPerAxis * samplesPerAxis;
        constexpr auto stroke = TrayIconStrokeRatio;
        std::vector<uint32_t> pixels(static_cast<size_t>(geometry.pixelSize) * geometry.pixelSize);
        for (int y = 0; y < geometry.pixelSize; ++y)
        {
            for (int x = 0; x < geometry.pixelSize; ++x)
            {
                int hits{};
                for (int sampleY = 0; sampleY < samplesPerAxis; ++sampleY)
                {
                    for (int sampleX = 0; sampleX < samplesPerAxis; ++sampleX)
                    {
                        auto localX = (x + (sampleX + 0.5) / samplesPerAxis - geometry.bodyLeft) /
                            geometry.bodySize;
                        auto localY = (y + (sampleY + 0.5) / samplesPerAxis - geometry.bodyTop) /
                            geometry.bodySize;
                        if (localX >= 0 && localX <= 1 && localY >= 0 && localY <= 1 &&
                            HitsIconStroke({ localX, localY }, stroke)) ++hits;
                    }
                }
                if (!hits) continue;
                auto alpha = static_cast<uint32_t>((hits * 255 + sampleCount / 2) / sampleCount);
                auto channel = tone == TrayIconTone::White ? alpha : 0u;
                pixels[static_cast<size_t>(y) * geometry.pixelSize + x] =
                    (alpha << 24) | (channel << 16) | (channel << 8) | channel;
            }
        }
        return pixels;
    }

    HICON CreateMonochromeTrayIcon(TrayIconGeometry const& geometry, TrayIconTone tone)
    {
        auto pixels = RenderMonochromeTrayIconPixels(geometry, tone);
        if (pixels.empty()) return nullptr;
        BITMAPV5HEADER header{};
        header.bV5Size = sizeof(header);
        header.bV5Width = geometry.pixelSize;
        header.bV5Height = -geometry.pixelSize;
        header.bV5Planes = 1;
        header.bV5BitCount = 32;
        header.bV5Compression = BI_BITFIELDS;
        header.bV5RedMask = 0x00FF0000;
        header.bV5GreenMask = 0x0000FF00;
        header.bV5BlueMask = 0x000000FF;
        header.bV5AlphaMask = 0xFF000000;
        void* bits{};
        auto screen = GetDC(nullptr);
        auto color = CreateDIBSection(screen, reinterpret_cast<BITMAPINFO*>(&header),
            DIB_RGB_COLORS, &bits, nullptr, 0);
        if (screen) ReleaseDC(nullptr, screen);
        if (!color || !bits)
        {
            if (color) DeleteObject(color);
            return nullptr;
        }
        CopyMemory(bits, pixels.data(), pixels.size() * sizeof(uint32_t));
        auto maskBytesPerRow = static_cast<size_t>((geometry.pixelSize + 15) / 16) * 2;
        std::vector<uint8_t> maskBits(maskBytesPerRow * geometry.pixelSize);
        auto mask = CreateBitmap(geometry.pixelSize, geometry.pixelSize, 1, 1, maskBits.data());
        if (!mask)
        {
            DeleteObject(color);
            return nullptr;
        }
        ICONINFO info{};
        info.fIcon = TRUE;
        info.hbmColor = color;
        info.hbmMask = mask;
        auto icon = CreateIconIndirect(&info);
        DeleteObject(mask);
        DeleteObject(color);
        return icon;
    }

    TrayIconTone ReadSystemTrayIconTone() noexcept
    {
        HIGHCONTRASTW highContrast{ sizeof(highContrast) };
        auto highContrastEnabled = SystemParametersInfoW(SPI_GETHIGHCONTRAST,
            sizeof(highContrast), &highContrast, 0) && (highContrast.dwFlags & HCF_HIGHCONTRASTON);
        std::optional<DWORD> systemUsesLightTheme;
        if (!highContrastEnabled)
        {
            DWORD value{};
            DWORD size = sizeof(value);
            if (RegGetValueW(HKEY_CURRENT_USER,
                L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
                L"SystemUsesLightTheme", RRF_RT_REG_DWORD, nullptr, &value, &size) == ERROR_SUCCESS)
                systemUsesLightTheme = value;
        }
        return SelectTrayIconTone(ClassifyTaskbarTheme(systemUsesLightTheme),
            TaskbarBackgroundLuminance(highContrastEnabled));
    }
}
