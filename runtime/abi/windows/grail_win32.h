/*
 * Minimal, pinned Win32 declarations for the Grail OS ABI backend.
 *
 * This host has no Windows SDK, so the backend declares exactly the kernel32
 * surface it uses instead of including <windows.h>.  Types and signatures match
 * the 64-bit Windows ABI; `GRAIL_WINAPI` is empty on x64/ARM64 because there is
 * a single calling convention there.  A real Windows build may replace this
 * header with the SDK's declarations without changing the backend, but the
 * pinned form is what the cross-target compile check exercises.
 */
#ifndef GRAIL_WIN32_H
#define GRAIL_WIN32_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void *HANDLE;
typedef void *LPVOID;
typedef const void *LPCVOID;
typedef const void *LPSECURITY_ATTRIBUTES;
typedef int32_t BOOL;
typedef uint32_t DWORD;
typedef uint16_t WCHAR;
typedef WCHAR *LPWSTR;
typedef const WCHAR *LPCWSTR;

#if defined(_M_IX86)
#define GRAIL_WINAPI __stdcall
#else
#define GRAIL_WINAPI
#endif
#define GRAIL_WINIMPORT __declspec(dllimport)

#define GRAIL_INVALID_HANDLE_VALUE ((HANDLE)(intptr_t)-1)
#define GRAIL_INVALID_FILE_ATTRIBUTES ((DWORD)0xFFFFFFFFu)

typedef union grail_large_integer {
    struct {
        DWORD LowPart;
        int32_t HighPart;
    } parts;
    int64_t QuadPart;
} LARGE_INTEGER;

typedef struct grail_filetime {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
} FILETIME;

typedef struct grail_by_handle_file_information {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD dwVolumeSerialNumber;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD nNumberOfLinks;
    DWORD nFileIndexHigh;
    DWORD nFileIndexLow;
} BY_HANDLE_FILE_INFORMATION;

typedef struct grail_win32_file_attribute_data {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD dwFileSizeHigh;
    DWORD dwFileSizeLow;
} WIN32_FILE_ATTRIBUTE_DATA;

typedef struct grail_srwlock {
    void *Ptr;
} SRWLOCK;

/* Access masks and file creation flags. */
#define GRAIL_GENERIC_READ 0x80000000u
#define GRAIL_GENERIC_WRITE 0x40000000u
#define GRAIL_FILE_APPEND_DATA 0x00000004u
#define GRAIL_FILE_SHARE_READ 0x00000001u
#define GRAIL_FILE_SHARE_WRITE 0x00000002u
#define GRAIL_FILE_SHARE_DELETE 0x00000004u
#define GRAIL_CREATE_NEW 1u
#define GRAIL_CREATE_ALWAYS 2u
#define GRAIL_OPEN_EXISTING 3u
#define GRAIL_OPEN_ALWAYS 4u
#define GRAIL_TRUNCATE_EXISTING 5u
#define GRAIL_FILE_ATTRIBUTE_READONLY 0x00000001u
#define GRAIL_FILE_ATTRIBUTE_HIDDEN 0x00000002u
#define GRAIL_FILE_ATTRIBUTE_DIRECTORY 0x00000010u
#define GRAIL_FILE_ATTRIBUTE_NORMAL 0x00000080u
#define GRAIL_FILE_ATTRIBUTE_REPARSE_POINT 0x00000400u
#define GRAIL_FILE_FLAG_OPEN_REPARSE_POINT 0x00200000u
#define GRAIL_FILE_FLAG_BACKUP_SEMANTICS 0x02000000u
#define GRAIL_FILE_FLAG_WRITE_THROUGH 0x80000000u
#define GRAIL_FILE_BEGIN 0u
#define GRAIL_FILE_CURRENT 1u
#define GRAIL_FILE_END 2u
#define GRAIL_MOVEFILE_REPLACE_EXISTING 0x00000001u
#define GRAIL_CP_UTF8 65001u
#define GRAIL_MB_ERR_INVALID_CHARS 0x00000008u
#define GRAIL_WC_ERR_INVALID_CHARS 0x00000080u
#define GRAIL_ERROR_SUCCESS 0u
#define GRAIL_ERROR_FILE_NOT_FOUND 2u
#define GRAIL_ERROR_PATH_NOT_FOUND 3u
#define GRAIL_ERROR_ACCESS_DENIED 5u
#define GRAIL_ERROR_GEN_FAILURE 31u
#define GRAIL_ERROR_INSUFFICIENT_BUFFER 122u
#define GRAIL_ERROR_ALREADY_EXISTS 183u
#define GRAIL_ERROR_NO_UNICODE_TRANSLATION 1113u
#define GRAIL_WIN32_INFINITE 0xFFFFFFFFu

typedef int32_t GRAIL_GET_FILEEX_INFO_LEVELS;
#define GRAIL_GET_FILE_EX_INFO_STANDARD 0

GRAIL_WINIMPORT HANDLE GRAIL_WINAPI CreateFileW(LPCWSTR name, DWORD access, DWORD share,
                                                LPSECURITY_ATTRIBUTES security, DWORD creation,
                                                DWORD attributes, HANDLE template_file);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI ReadFile(HANDLE file, LPVOID buffer, DWORD length,
                                           DWORD *read, LPVOID overlapped);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI WriteFile(HANDLE file, LPCVOID buffer, DWORD length,
                                            DWORD *written, LPVOID overlapped);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI SetFilePointerEx(HANDLE file, LARGE_INTEGER distance,
                                                   LARGE_INTEGER *position, DWORD method);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI SetEndOfFile(HANDLE file);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI FlushFileBuffers(HANDLE file);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI CloseHandle(HANDLE handle);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI GetFileInformationByHandle(HANDLE file,
                                                             BY_HANDLE_FILE_INFORMATION *info);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI GetFileAttributesExW(LPCWSTR name,
                                                       GRAIL_GET_FILEEX_INFO_LEVELS level,
                                                       LPVOID info);
GRAIL_WINIMPORT DWORD GRAIL_WINAPI GetFileAttributesW(LPCWSTR name);
GRAIL_WINIMPORT DWORD GRAIL_WINAPI GetCurrentDirectoryW(DWORD length, LPWSTR buffer);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI SetCurrentDirectoryW(LPCWSTR path);
GRAIL_WINIMPORT DWORD GRAIL_WINAPI GetModuleFileNameW(HANDLE module, LPWSTR buffer, DWORD length);
GRAIL_WINIMPORT int32_t GRAIL_WINAPI MultiByteToWideChar(uint32_t code_page, DWORD flags,
                                                         const char *text, int32_t length,
                                                         LPWSTR wide, int32_t wide_length);
GRAIL_WINIMPORT int32_t GRAIL_WINAPI WideCharToMultiByte(uint32_t code_page, DWORD flags,
                                                         LPCWSTR wide, int32_t wide_length,
                                                         char *text, int32_t text_length,
                                                         const char *default_char,
                                                         BOOL *used_default);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI SetEnvironmentVariableW(LPCWSTR name, LPCWSTR value);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI CreateDirectoryW(LPCWSTR path, LPSECURITY_ATTRIBUTES security);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI RemoveDirectoryW(LPCWSTR path);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI DeleteFileW(LPCWSTR path);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI MoveFileExW(LPCWSTR from, LPCWSTR to, DWORD flags);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI CreatePipe(HANDLE *read, HANDLE *write,
                                             LPSECURITY_ATTRIBUTES security, DWORD size);
GRAIL_WINIMPORT DWORD GRAIL_WINAPI GetLastError(void);
GRAIL_WINIMPORT void GRAIL_WINAPI Sleep(DWORD milliseconds);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI QueryPerformanceCounter(LARGE_INTEGER *value);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI QueryPerformanceFrequency(LARGE_INTEGER *value);
GRAIL_WINIMPORT void GRAIL_WINAPI GetSystemTimePreciseAsFileTime(FILETIME *value);
GRAIL_WINIMPORT void GRAIL_WINAPI GetSystemTimeAsFileTime(FILETIME *value);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI GetProcessTimes(HANDLE process, FILETIME *creation,
                                                  FILETIME *exit, FILETIME *kernel,
                                                  FILETIME *user);
GRAIL_WINIMPORT BOOL GRAIL_WINAPI GetThreadTimes(HANDLE thread, FILETIME *creation,
                                                 FILETIME *exit, FILETIME *kernel,
                                                 FILETIME *user);
GRAIL_WINIMPORT HANDLE GRAIL_WINAPI GetCurrentProcess(void);
GRAIL_WINIMPORT HANDLE GRAIL_WINAPI GetCurrentThread(void);
GRAIL_WINIMPORT void GRAIL_WINAPI InitializeSRWLock(SRWLOCK *lock);
GRAIL_WINIMPORT void GRAIL_WINAPI AcquireSRWLockExclusive(SRWLOCK *lock);
GRAIL_WINIMPORT void GRAIL_WINAPI ReleaseSRWLockExclusive(SRWLOCK *lock);

#ifdef __cplusplus
}
#endif

#endif /* GRAIL_WIN32_H */
