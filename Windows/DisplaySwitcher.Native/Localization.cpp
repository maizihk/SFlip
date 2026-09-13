#include <windows.h>
#include <shlobj.h>
#include <algorithm>
#include <fstream>
#include <mutex>
#include <set>
#include <vector>
#include "Localization.h"
#include <stdexcept>

namespace DisplaySwitcher::Native {
namespace {
    struct Entry { wchar_t const* chinese; wchar_t const* english; };
    Entry const catalog[]{
#include "LocalizationCatalog.inc"
    };
    std::atomic<UiLanguagePreference> preference{UiLanguagePreference::System};
    std::atomic<int> testLanguage{-1};
    std::once_flag initialized;
    std::filesystem::path PreferencePath() {
        PWSTR folder{};
        if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &folder))) return {};
        auto path = std::filesystem::path(folder) / L"DisplaySwitcher" / L"ui-language.txt";
        CoTaskMemFree(folder); return path;
    }
    std::wstring SystemLanguage() {
        wchar_t name[LOCALE_NAME_MAX_LENGTH]{};
        LCIDToLocaleName(MAKELCID(GetUserDefaultUILanguage(), SORT_DEFAULT), name, LOCALE_NAME_MAX_LENGTH, 0);
        return name;
    }
    void Initialize() { std::call_once(initialized, [] { preference.store(ReadLanguagePreferenceFrom(PreferencePath())); }); }
    std::vector<std::wstring> Placeholders(std::wstring_view text) {
        std::vector<std::wstring> result;
        for(size_t index=0; index<text.size(); ++index) if(text[index]==L'{') {
            auto end=text.find(L'}', index+1); if(end==std::wstring_view::npos) throw std::invalid_argument("unclosed placeholder");
            result.emplace_back(text.substr(index+1, end-index-1)); index=end;
        }
        std::sort(result.begin(),result.end()); return result;
    }
}
UiLanguage ResolveUiLanguage(UiLanguagePreference choice, std::wstring_view system) noexcept {
    if(choice==UiLanguagePreference::Chinese) return UiLanguage::Chinese;
    if(choice==UiLanguagePreference::English) return UiLanguage::English;
    return system.size()>=2 && (system[0]==L'z'||system[0]==L'Z') && (system[1]==L'h'||system[1]==L'H')
        && (system.size()==2 || system[2]==L'-' || system[2]==L'_') ? UiLanguage::Chinese : UiLanguage::English;
}
UiLanguagePreference ReadLanguagePreferenceFrom(std::filesystem::path const& path) {
    std::error_code error;
    auto size = std::filesystem::file_size(path, error);
    if (error || size > 16) return UiLanguagePreference::System;
    std::ifstream input(path, std::ios::binary); std::string value;
    if(!input || !std::getline(input,value)) return UiLanguagePreference::System;
    if (!input.eof()) return UiLanguagePreference::System;
    if(value=="zh-CN") return UiLanguagePreference::Chinese;
    if(value=="en") return UiLanguagePreference::English;
    return UiLanguagePreference::System;
}
bool SaveLanguagePreferenceTo(std::filesystem::path const& path, UiLanguagePreference choice) {
    if(path.empty()) return false;
    auto temporary=path; temporary+=L".tmp";
    try {
        std::filesystem::create_directories(path.parent_path());
        { std::ofstream output(temporary,std::ios::binary|std::ios::trunc);
          output << (choice==UiLanguagePreference::Chinese ? "zh-CN" : choice==UiLanguagePreference::English ? "en" : "system");
          output.flush(); if(!output) { output.close(); std::filesystem::remove(temporary); return false; } }
        if(!MoveFileExW(temporary.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)) {
            std::filesystem::remove(temporary); return false;
        } return true;
    } catch(...) { std::error_code error; std::filesystem::remove(temporary,error); return false; }
}
UiLanguagePreference LanguagePreference() { Initialize(); return preference.load(); }
UiLanguage CurrentUiLanguage() {
    auto test=testLanguage.load(); if(test>=0) return static_cast<UiLanguage>(test);
    return ResolveUiLanguage(LanguagePreference(),SystemLanguage());
}
bool SaveLanguagePreference(UiLanguagePreference choice) {
    Initialize(); if(!SaveLanguagePreferenceTo(PreferencePath(),choice)) return false;
    preference.store(choice); return true;
}
void SetLanguageForTests(UiLanguage language) { testLanguage.store(static_cast<int>(language)); }
wchar_t const* UiText(wchar_t const* source) {
    if(CurrentUiLanguage()==UiLanguage::Chinese) return source;
    for(auto const& entry:catalog) if(std::wstring_view(source)==entry.chinese) return entry.english;
    return source;
}
std::wstring UiFormat(wchar_t const* source,
    std::initializer_list<std::pair<std::wstring_view,std::wstring_view>> arguments) {
    std::wstring_view pattern=UiText(source); std::wstring result;
    for(size_t index=0;index<pattern.size();) {
        if(pattern[index]!=L'{') { result+=pattern[index++]; continue; }
        auto end=pattern.find(L'}',index+1); if(end==std::wstring_view::npos) throw std::invalid_argument("unclosed placeholder");
        auto key=pattern.substr(index+1,end-index-1);
        auto argument=std::find_if(arguments.begin(),arguments.end(),[&](auto const& value){return value.first==key;});
        if(argument==arguments.end()) throw std::invalid_argument("missing placeholder");
        result.append(argument->second); index=end+1;
    } return result;
}
UiMessage::UiMessage(wchar_t const* pattern,
    std::initializer_list<std::pair<std::wstring_view, std::wstring_view>> values) : source(pattern) {
    for (auto const& value : values) arguments.emplace_back(value.first, value.second);
}
std::wstring UiMessage::Render() const {
    if (verbatim) return source;
    std::wstring_view pattern = UiText(source.c_str()); std::wstring result;
    for (size_t index=0; index<pattern.size();) {
        if(pattern[index]!=L'{') { result+=pattern[index++]; continue; }
        auto end=pattern.find(L'}', index+1); if(end==std::wstring_view::npos) throw std::invalid_argument("unclosed placeholder");
        auto key=pattern.substr(index+1,end-index-1);
        auto argument=std::find_if(arguments.begin(),arguments.end(),[&](auto const& value){return value.first==key;});
        if(argument==arguments.end()) throw std::invalid_argument("missing placeholder");
        result.append(argument->second); index=end+1;
    } return result;
}
bool ValidateUiCatalog() {
    std::set<std::wstring> keys;
    for(auto const& entry:catalog) if(!*entry.english || !keys.insert(entry.chinese).second ||
        Placeholders(entry.chinese)!=Placeholders(entry.english)) return false;
    return true;
}
size_t UiCatalogSize(){return std::size(catalog);}
}
