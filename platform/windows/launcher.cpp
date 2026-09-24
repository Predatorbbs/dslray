#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string>

static int reportError(DWORD code)
{
    const std::wstring message = L"Unable to start DSLRay (Windows error "
        + std::to_wstring(code) + L").\nKeep the complete application folder together.";
    MessageBoxW(nullptr, message.c_str(), L"DSLRay", MB_OK | MB_ICONERROR);
    return static_cast<int>(code ? code : 1);
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR arguments, int)
{
    std::wstring path(32768, L'\0');
    const DWORD length = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
    if (!length || length >= path.size())
        return reportError(GetLastError());
    path.resize(length);
    const auto separator = path.find_last_of(L"\\/");
    if (separator == std::wstring::npos)
        return reportError(ERROR_PATH_NOT_FOUND);
    const std::wstring executable = path.substr(0, separator) + L"\\bin\\appDSLRay.exe";
    // Preserve quoting and Unicode arguments; do not involve a shell or change PATH.
    std::wstring command = L"\"" + executable + L"\"";
    if (arguments && *arguments) {
        command += L" ";
        command += arguments;
    }
    STARTUPINFOW startup {};
    startup.cb = sizeof(startup);
    GetStartupInfoW(&startup); // Preserve redirected output for deployment checks.
    PROCESS_INFORMATION process {};
    if (!CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr,
                        TRUE, 0, nullptr, nullptr, &startup, &process))
        return reportError(GetLastError());
    CloseHandle(process.hThread);
    const DWORD wait = WaitForSingleObject(process.hProcess, INFINITE);
    DWORD result = 1;
    if (wait == WAIT_OBJECT_0)
        GetExitCodeProcess(process.hProcess, &result);
    CloseHandle(process.hProcess);
    return static_cast<int>(result);
}
