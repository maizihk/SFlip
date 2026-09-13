#pragma once
#include <atomic>
#include <filesystem>
#include <initializer_list>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace DisplaySwitcher::Native {
    enum class UiLanguagePreference { System, Chinese, English };
    enum class UiLanguage { Chinese, English };
    UiLanguage ResolveUiLanguage(UiLanguagePreference preference, std::wstring_view systemLanguage) noexcept;
    UiLanguagePreference LanguagePreference();
    UiLanguage CurrentUiLanguage();
    bool SaveLanguagePreference(UiLanguagePreference preference);
    bool SaveLanguagePreferenceTo(std::filesystem::path const& path, UiLanguagePreference preference);
    UiLanguagePreference ReadLanguagePreferenceFrom(std::filesystem::path const& path);
    void SetLanguageForTests(UiLanguage language);
    wchar_t const* UiText(wchar_t const* source);
    std::wstring UiFormat(wchar_t const* source,
        std::initializer_list<std::pair<std::wstring_view, std::wstring_view>> arguments);
    struct UiMessage {
        std::wstring source;
        std::vector<std::pair<std::wstring, std::wstring>> arguments;
        UiMessage(wchar_t const* pattern,
            std::initializer_list<std::pair<std::wstring_view, std::wstring_view>> values = {});
        std::wstring Render() const;
    };
    bool ValidateUiCatalog();
    size_t UiCatalogSize();
}
