#include "../include/grail/grail_error.h"
#include "../include/grail/grail_unicode.h"
#include "grail_internal.h"

typedef struct grail_error_entry {
    grail_status status;
    const char *text;
} grail_error_entry;

static const grail_error_entry grail_error_table[] = {
    {GRAIL_OK, "success"},
    {GRAIL_E_INVALID_ARGUMENT, "invalid argument"},
    {GRAIL_E_INVALID_HANDLE, "invalid handle"},
    {GRAIL_E_INVALID_UTF8, "invalid UTF-8"},
    {GRAIL_E_NOT_FOUND, "not found"},
    {GRAIL_E_ACCESS_DENIED, "access denied"},
    {GRAIL_E_ALREADY_EXISTS, "already exists"},
    {GRAIL_E_NOT_A_DIRECTORY, "not a directory"},
    {GRAIL_E_IS_A_DIRECTORY, "is a directory"},
    {GRAIL_E_DIRECTORY_NOT_EMPTY, "directory not empty"},
    {GRAIL_E_NAME_TOO_LONG, "name too long"},
    {GRAIL_E_NO_SPACE, "no space left"},
    {GRAIL_E_QUOTA_EXCEEDED, "quota exceeded"},
    {GRAIL_E_READ_ONLY, "read-only file system"},
    {GRAIL_E_BUSY, "resource busy"},
    {GRAIL_E_TIMED_OUT, "timed out"},
    {GRAIL_E_WOULD_BLOCK, "operation would block"},
    {GRAIL_E_INTERRUPTED, "interrupted"},
    {GRAIL_E_CONNECTION_RESET, "connection reset"},
    {GRAIL_E_CONNECTION_REFUSED, "connection refused"},
    {GRAIL_E_CONNECTION_ABORTED, "connection aborted"},
    {GRAIL_E_NETWORK_UNREACHABLE, "network unreachable"},
    {GRAIL_E_ADDRESS_IN_USE, "address in use"},
    {GRAIL_E_ADDRESS_INVALID, "address invalid"},
    {GRAIL_E_MESSAGE_TOO_LARGE, "message too large"},
    {GRAIL_E_UNSUPPORTED, "operation not supported"},
    {GRAIL_E_NOT_INITIALIZED, "runtime not initialized"},
    {GRAIL_E_SYSTEM, "system error"},
    {GRAIL_E_BROKEN_PIPE, "broken pipe"},
    {GRAIL_E_CANCELED, "operation canceled"},
    {GRAIL_E_OVERFLOW, "value overflow"},
    {GRAIL_E_OUT_OF_MEMORY, "out of memory"},
    {GRAIL_E_TOO_MANY_HANDLES, "too many open handles"},
    {GRAIL_E_SYMLINK_LOOP, "too many symbolic links"},
    {GRAIL_E_CROSS_DEVICE, "cross-device operation"},
    {GRAIL_E_NOT_SEEKABLE, "handle is not seekable"},
};

static const char *grail_error_lookup(grail_status status) {
    const uint64_t count = sizeof(grail_error_table) / sizeof(grail_error_table[0]);
    for (uint64_t i = 0; i < count; i++) {
        if (grail_error_table[i].status == status) {
            return grail_error_table[i].text;
        }
    }
    return "unknown error";
}

grail_result grail_error_text(grail_status status, uint8_t *out, uint64_t capacity) {
    const char *text = grail_error_lookup(status);
    const uint64_t length = grail_abi_bounded_length(text, 1024);
    return grail_abi_copy_out((const uint8_t *)text, length, out, capacity);
}

uint64_t grail_error_is_transient(grail_status status) {
    return status == GRAIL_E_WOULD_BLOCK || status == GRAIL_E_INTERRUPTED ||
           status == GRAIL_E_TIMED_OUT || status == GRAIL_E_BUSY;
}

grail_status grail_os_status_from_win32(int64_t error_number) {
    switch (error_number) {
    case 0:
        return GRAIL_OK;
    case 1:   /* ERROR_INVALID_FUNCTION, e.g. seeking a pipe */
        return GRAIL_E_NOT_SEEKABLE;
    case 2:   /* ERROR_FILE_NOT_FOUND */
    case 3:   /* ERROR_PATH_NOT_FOUND */
    case 18:  /* ERROR_NO_MORE_FILES */
    case 1168: /* ERROR_NOT_FOUND */
        return GRAIL_E_NOT_FOUND;
    case 5:   /* ERROR_ACCESS_DENIED */
        return GRAIL_E_ACCESS_DENIED;
    case 32:  /* ERROR_SHARING_VIOLATION */
    case 33:  /* ERROR_LOCK_VIOLATION */
        return GRAIL_E_BUSY;
    case 80:  /* ERROR_FILE_EXISTS */
    case 183: /* ERROR_ALREADY_EXISTS */
        return GRAIL_E_ALREADY_EXISTS;
    case 267: /* ERROR_DIRECTORY */
        return GRAIL_E_NOT_A_DIRECTORY;
    case 145: /* ERROR_DIR_NOT_EMPTY */
        return GRAIL_E_DIRECTORY_NOT_EMPTY;
    case 206: /* ERROR_FILENAME_EXCED_RANGE */
        return GRAIL_E_NAME_TOO_LONG;
    case 39:  /* ERROR_HANDLE_DISK_FULL */
    case 112: /* ERROR_DISK_FULL */
        return GRAIL_E_NO_SPACE;
    case 19:  /* ERROR_WRITE_PROTECT */
        return GRAIL_E_READ_ONLY;
    case 121: /* ERROR_SEM_TIMEOUT */
    case 258: /* WAIT_TIMEOUT */
    case 10060: /* WSAETIMEDOUT */
        return GRAIL_E_TIMED_OUT;
    case 997: /* ERROR_IO_PENDING */
    case 10035: /* WSAEWOULDBLOCK */
    case 10036: /* WSAEINPROGRESS */
    case 10037: /* WSAEALREADY */
        return GRAIL_E_WOULD_BLOCK;
    case 995: /* ERROR_OPERATION_ABORTED */
        return GRAIL_E_CANCELED;
    case 10054: /* WSAECONNRESET */
        return GRAIL_E_CONNECTION_RESET;
    case 10061: /* WSAECONNREFUSED */
        return GRAIL_E_CONNECTION_REFUSED;
    case 10053: /* WSAECONNABORTED */
        return GRAIL_E_CONNECTION_ABORTED;
    case 10050: /* WSAENETDOWN */
    case 10051: /* WSAENETUNREACH */
    case 10065: /* WSAEHOSTUNREACH */
        return GRAIL_E_NETWORK_UNREACHABLE;
    case 10048: /* WSAEADDRINUSE */
        return GRAIL_E_ADDRESS_IN_USE;
    case 10049: /* WSAEADDRNOTAVAIL */
    case 10038: /* WSAENOTSOCK */
        return GRAIL_E_ADDRESS_INVALID;
    case 10040: /* WSAEMSGSIZE */
        return GRAIL_E_MESSAGE_TOO_LARGE;
    case 50:  /* ERROR_NOT_SUPPORTED */
    case 120: /* ERROR_CALL_NOT_IMPLEMENTED */
        return GRAIL_E_UNSUPPORTED;
    case 109: /* ERROR_BROKEN_PIPE */
    case 232: /* ERROR_NO_DATA */
    case 233: /* ERROR_PIPE_NOT_CONNECTED */
    case 10058: /* WSAESHUTDOWN */
        return GRAIL_E_BROKEN_PIPE;
    case 10057: /* WSAENOTCONN */
        return GRAIL_E_CONNECTION_ABORTED;
    case 8:   /* ERROR_NOT_ENOUGH_MEMORY */
    case 14:  /* ERROR_OUTOFMEMORY */
    case 10055: /* WSAENOBUFS */
        return GRAIL_E_OUT_OF_MEMORY;
    case 10024: /* WSAEMFILE */
        return GRAIL_E_TOO_MANY_HANDLES;
    case 10013: /* WSAEACCES */
        return GRAIL_E_ACCESS_DENIED;
    case 10014: /* WSAEFAULT */
    case 10022: /* WSAEINVAL */
        return GRAIL_E_INVALID_ARGUMENT;
    case 6:   /* ERROR_INVALID_HANDLE */
        return GRAIL_E_INVALID_HANDLE;
    case 87:  /* ERROR_INVALID_PARAMETER */
    case 123: /* ERROR_INVALID_NAME */
        return GRAIL_E_INVALID_ARGUMENT;
    default:
        return GRAIL_E_SYSTEM;
    }
}

grail_status grail_os_status_from_mach(int64_t error_number) {
    switch (error_number) {
    case 0: /* KERN_SUCCESS */
        return GRAIL_OK;
    case 2: /* KERN_INVALID_ADDRESS */
    case 3: /* KERN_PROTECTION_FAILURE */
        return GRAIL_E_ACCESS_DENIED;
    case 4: /* KERN_NO_SPACE */
    case 5: /* KERN_INVALID_ARGUMENT */
        return GRAIL_E_INVALID_ARGUMENT;
    case 6: /* KERN_FAILURE */
        return GRAIL_E_SYSTEM;
    case 7: /* KERN_RESOURCE_SHORTAGE */
        return GRAIL_E_OUT_OF_MEMORY;
    case 8: /* KERN_NOT_RECEIVER */
    case 9: /* KERN_NO_ACCESS */
        return GRAIL_E_ACCESS_DENIED;
    case 10: /* KERN_MEMORY_FAILURE */
        return GRAIL_E_SYSTEM;
    case 11: /* KERN_MEMORY_ERROR */
        return GRAIL_E_SYSTEM;
    case 12: /* KERN_ALREADY_IN_SET */
    case 13: /* KERN_NOT_IN_SET */
        return GRAIL_E_INVALID_ARGUMENT;
    case 14: /* KERN_NAME_EXISTS */
        return GRAIL_E_ALREADY_EXISTS;
    case 15: /* KERN_ABORTED */
        return GRAIL_E_INTERRUPTED;
    case 16: /* KERN_INVALID_NAME */
    case 17: /* KERN_INVALID_TASK */
    case 18: /* KERN_INVALID_RIGHT */
        return GRAIL_E_INVALID_HANDLE;
    case 19: /* KERN_INVALID_VALUE */
        return GRAIL_E_INVALID_ARGUMENT;
    case 20: /* KERN_UREFCNT_OVERFLOW */
        return GRAIL_E_OVERFLOW;
    case 21: /* KERN_RIGHT_EXISTS */
        return GRAIL_E_ALREADY_EXISTS;
    case 22: /* KERN_INVALID_HOST */
        return GRAIL_E_INVALID_ARGUMENT;
    case 23: /* KERN_MEMORY_PRESENT */
        return GRAIL_E_ALREADY_EXISTS;
    case 24: /* KERN_MEMORY_DATA_MOVED */
        return GRAIL_E_BUSY;
    case 25: /* KERN_MEMORY_RESTART_COPY */
        return GRAIL_E_BUSY;
    case 26: /* KERN_INVALID_PROCESSOR_SET */
        return GRAIL_E_INVALID_ARGUMENT;
    case 27: /* KERN_POLICY_LIMIT */
        return GRAIL_E_QUOTA_EXCEEDED;
    case 28: /* KERN_INVALID_POLICY */
        return GRAIL_E_INVALID_ARGUMENT;
    case 29: /* KERN_INVALID_OBJECT */
        return GRAIL_E_INVALID_HANDLE;
    case 30: /* KERN_ALREADY_WAITING */
        return GRAIL_E_BUSY;
    case 31: /* KERN_DEFAULT_SET */
        return GRAIL_E_ALREADY_EXISTS;
    case 32: /* KERN_EXCEPTION_PROTECTED */
        return GRAIL_E_ACCESS_DENIED;
    case 33: /* KERN_INVALID_LEDGER */
        return GRAIL_E_INVALID_ARGUMENT;
    case 34: /* KERN_INVALID_MEMORY_CONTROL */
        return GRAIL_E_INVALID_ARGUMENT;
    case 35: /* KERN_INVALID_SECURITY */
        return GRAIL_E_ACCESS_DENIED;
    default:
        return GRAIL_E_SYSTEM;
    }
}
