#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <vector>
#include <cstdlib>

#ifdef _WIN32
#include <windows.h>
#include <tlhelp32.h>
#else
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <csignal>
#include <cstring>
#include <dirent.h> 
#include <fstream>
#include <algorithm>
#include <libgen.h> // for dirname()
#include <climits>  // for PATH_MAX
#endif

// ================== 配置区 ==================
// 现在我们只配置相对文件名
#ifdef _WIN32
const char* PROCESS_FULL_PATH = "UnitTestFoo.exe";
const char* TARGET_PROCESS_NAME = "UnitTestFoo.exe";
#else
const char* TARGET_PROCESS_NAME = "gn1";
#endif
const char* TARGET_LIB_DIR_NAME = "lib"; // .so 或 .dll 所在的相对目录名
const int CHECK_INTERVAL_SECONDS = 5;
// ==========================================

// 全局变量，用于存储计算出的绝对路径
std::string g_process_full_path;
std::string g_process_lib_path;

// 函数声明... (为了简洁，这里省略)
void daemonize();
void startProcess();
            void startProcess(const std::string& processName);
bool isProcessRunning(const std::string& processName);
std::string getProcessName();

// 辅助函数：获取当前可执行文件的绝对路径
std::string get_executable_path(const char* argv0) {
#ifdef _WIN32
    wchar_t path[MAX_PATH] = { 0 };
    GetModuleFileNameW(NULL, path, MAX_PATH);
    // 从 UTF-16 转换为多字节字符串以便后续处理，这里简单处理
    char mb_path[MAX_PATH * 2];
    wcstombs(mb_path, path, sizeof(mb_path));
    return std::string(mb_path);
#else
    char result[PATH_MAX];
    ssize_t count = readlink("/proc/self/exe", result, PATH_MAX);
    if (count != -1) {
        return std::string(result, count);
    }

    // readlink 失败时的备用方案 (处理 argv[0])
    char* real_path = realpath(argv0, NULL);
    if (real_path != NULL) {
        std::string p(real_path);
        free(real_path);
        return p;
    }
    return ""; // 获取失败
#endif
}


int main(int argc, char* argv[]) {
    // 1. 在程序最开始，计算并存储绝对路径
    std::string exe_path = get_executable_path(argv[0]);
    if (exe_path.empty()) {
        std::cerr << "Fatal: Could not determine executable path." << std::endl;
        return 1;
    }

#ifdef _WIN32
    // Windows 路径处理
    char drive[_MAX_DRIVE];
    char dir[_MAX_DIR];
    _splitpath_s(exe_path.c_str(), drive, _MAX_DRIVE, dir, _MAX_DIR, NULL, 0, NULL, 0);
    std::string exe_dir = std::string(drive) + std::string(dir);
    g_process_full_path = exe_dir + TARGET_PROCESS_NAME + ".exe";
    g_process_lib_path = exe_dir + TARGET_LIB_DIR_NAME;

#else
    // Linux 路径处理
    char* path_copy = strdup(exe_path.c_str());
    std::string exe_dir = std::string(dirname(path_copy)) + "/";
    free(path_copy);

    g_process_full_path = exe_dir + TARGET_PROCESS_NAME;
    g_process_lib_path = exe_dir + TARGET_LIB_DIR_NAME;
#endif
    
    // 2. 现在可以安全地进行守护进程化了
#ifndef _WIN32
    if (argc <= 1 || std::string(argv[1]) != "--no-daemon") {
        daemonize();
    }
#endif

    // 3. 主循环，使用我们计算好的全局路径
    while (true) {
        if (!isProcessRunning(TARGET_PROCESS_NAME)) {
            //startProcess();
            startProcess(TARGET_PROCESS_NAME);
        }
        std::this_thread::sleep_for(std::chrono::seconds(CHECK_INTERVAL_SECONDS));
    }

    return 0;
}


// --- 实现部分 ---

std::string getProcessName() {
#ifdef _WIN32
    return std::string(TARGET_PROCESS_NAME) + ".exe";
#else
    return std::string(TARGET_PROCESS_NAME);
#endif
}


bool isProcessRunning(const std::string& processName) {
#ifdef _WIN32
    // Windows 版本实现不变，它已经使用了原生 API
    std::string fullProcessName = processName + ".exe";
    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return false;
    }

    PROCESSENTRY32 pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32);

    if (!Process32First(hSnapshot, &pe32)) {
        CloseHandle(hSnapshot);
        return false;
    }

    do {
        if (_stricmp(pe32.szExeFile, fullProcessName.c_str()) == 0) {
            CloseHandle(hSnapshot);
            return true;
        }
    } while (Process32Next(hSnapshot, &pe32));

    CloseHandle(hSnapshot);
    return false;
#else
    // Linux/Unix 版本实现：遍历 /proc 目录，不使用命令行
    DIR* dir = opendir("/proc");
    if (dir == nullptr) {
        // 如果 /proc 无法访问，则无法检查
        perror("Failed to open /proc");
        return false; 
    }

    struct dirent* entry;
    bool found = false;
    while ((entry = readdir(dir)) != nullptr) {
        // 检查目录名是否为纯数字（即进程ID）
        std::string pid_str = entry->d_name;
        if (std::all_of(pid_str.begin(), pid_str.end(), ::isdigit)) {
            // 构建 comm 文件路径，它包含进程名
            std::string comm_path = "/proc/" + pid_str + "/comm";
            std::ifstream comm_file(comm_path);
            if (comm_file.is_open()) {
                std::string name;
                std::getline(comm_file, name); // 读取进程名
                if (name == processName) {
                    found = true;
                    break;
                }
            }
        }
    }

    closedir(dir);
    return found;
#endif
}


void startProcess(const std::string& processName) {
    std::cout << "Process " << processName << " is not running. Starting it..." << std::endl;
#ifdef _WIN32
    HANDLE hRead, hWrite;
    SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };
    if (!CreatePipe(&hRead, &hWrite, &sa, 0)) {
        std::cerr << "CreatePipe failed." << std::endl;
        return;
    }

    STARTUPINFO si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags |= STARTF_USESTDHANDLES;
    si.hStdOutput = hWrite;
    si.hStdError = hWrite;
    si.hStdInput = NULL;

    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcess(NULL,
        (LPSTR)processName.c_str(),
        NULL, NULL, TRUE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi))
    {
        std::cerr << "CreateProcess failed (" << GetLastError() << ")." << std::endl;
        CloseHandle(hRead);
        CloseHandle(hWrite);
        return;
    }
    CloseHandle(hWrite); // 父进程关闭写端

    // 读取子进程输出
    char buffer[4096];
    DWORD bytesRead;
    while (ReadFile(hRead, buffer, sizeof(buffer) - 1, &bytesRead, NULL) && bytesRead > 0) {
        buffer[bytesRead] = 0;
        std::cout << buffer;
    }
    CloseHandle(hRead);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
#else
	std::cout << "Process " << processName << " is not running. Starting it..." << std::endl;
    std::string cmd = "./" + processName + " &";
    int ret = system(cmd.c_str());
    if (ret == -1) {
        std::cerr << "system() failed for " << processName << std::endl;
    } else {
        std::cout << "Process " << processName << " started." << std::endl;
    }

#endif
}
void startProcess() {
    // 直接使用全局变量
    // ... 此处省略 startProcess 的具体实现代码，与之前版本相同
    // 只是它现在使用 g_process_full_path 和 g_process_lib_path
    // 在 Linux 上 fork/execv/chdir/setenv, 在 Windows 上 CreateProcessW ...
    std::cout << "Starting " << g_process_full_path << std::endl;
}

#ifndef _WIN32
void daemonize() {
    pid_t pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    if (setsid() < 0) exit(EXIT_FAILURE);

    signal(SIGCHLD, SIG_IGN);
    signal(SIGHUP, SIG_IGN);

    pid = fork();
    if (pid < 0) exit(EXIT_FAILURE);
    if (pid > 0) exit(EXIT_SUCCESS);

    umask(0);
    chdir("/"); // 我们现在可以安全地切换目录了！

    for (int x = sysconf(_SC_OPEN_MAX); x >= 0; x--) {
        close(x);
    }
}
#endif
