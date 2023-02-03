#include <cstdio>
#include <filesystem>
#include <string>
#include <string_view>
#include <vector>

#define UNICODE
#include <windows.h>

#ifndef PROG
#define PROG "clang"
#endif

#define REAL_COMPILER "i686-w64-mingw32-" PROG ".exe"

using namespace std;

// See https://stackoverflow.com/questions/31838469/how-do-i-convert-argv-to-lpcommandline-parameter-of-createprocess ,
// and https://learn.microsoft.com/en-gb/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way .
wstring QuoteArg(wstring_view arg)
{
	if (!arg.empty() && arg.find_first_of(L" \t\n\v\"") == arg.npos)
		return wstring{ arg };

	wstring result;
	result.push_back(L'"');
	for (auto it = arg.begin(); ; ++it) {
		unsigned nBackslash = 0;
		while (it != arg.end() && *it == L'\\') {
			++it;
			++nBackslash;
		}
		if (it == arg.end()) {
			// Escape all backslashes, but let the terminating double quotation mark we add below be interpreted as a metacharacter.
			result.append(nBackslash * 2, L'\\');
			break;
		} else if (*it == L'"') {
			// Escape all backslashes and the following double quotation mark.
			result.append(nBackslash * 2 + 1, L'\\');
			result.push_back(*it);
		} else {
			// Backslashes aren't special here.
			result.append(nBackslash, L'\\');
			result.push_back(*it);
		}
	}
	result.push_back(L'"');
	return result;
}

// Win32 API `CreateProcess` is really insane.
wstring BuildWin32CommandLine(wstring_view exec, const vector<wstring_view> &args)
{
	wstring result = QuoteArg(exec);
	for (auto arg : args) {
		result.append(L" ");
		result += QuoteArg(arg);
	}
	// In cross compiler, correct library path is not guaranteed. Use static libc++.
	if constexpr (string_view{PROG} == "clang++" || string_view{PROG} == "g++" || string_view{PROG} == "c++")
		result += L" -Wl,-Bstatic -lc++ -lunwind";
	return result;
}

int main()
{
	// Determine full path of real compiler.
	wchar_t selfExePath[MAX_PATH];
	GetModuleFileNameW(NULL, selfExePath, MAX_PATH);
	auto dp0 = filesystem::path{ selfExePath }.parent_path().wstring();
	auto realCompilerPath = dp0 + L"\\" REAL_COMPILER;
	
	// Compose command line.
	int argc;
	auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
	vector<wstring_view> args(argv + 1, argv + argc);
	auto commandLine = BuildWin32CommandLine(realCompilerPath, args);
	LocalFree(argv);

	// Call real compiler.
	STARTUPINFO si{};
	si.cb = sizeof(si);
	PROCESS_INFORMATION pi{};
	if (!CreateProcessW(nullptr, const_cast<wchar_t*>(commandLine.c_str()), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &pi)) {
		fprintf(stderr, "xross86: error: failed to call real compiler %s\n", REAL_COMPILER);
		return 1;
	}

	// Wait and return.
	WaitForSingleObject(pi.hProcess, INFINITE);
	DWORD exitCode = 0;
	GetExitCodeProcess(pi.hProcess, &exitCode);
	CloseHandle(pi.hProcess);
	CloseHandle(pi.hThread);
	return exitCode;
}
