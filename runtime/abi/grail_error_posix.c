#include <errno.h>

#include "../include/grail/grail_error.h"
#include "../include/grail/grail_abi.h"

/*
 * POSIX mapping shared by Linux and macOS.  Cases are spelled with the
 * canonical name only; EWOULDBLOCK/EAGAIN and ENOTSUP/EOPNOTSUPP may alias on
 * some systems, so those pairs are normalized before the switch.
 */
grail_status grail_os_status_from_errno(int64_t error_number) {
    if (error_number == 0) {
        return GRAIL_OK;
    }
    switch (error_number) {
#ifdef E2BIG
    case E2BIG:
#endif
#ifdef EINVAL
    case EINVAL:
#endif
#ifdef EFAULT
    case EFAULT:
#endif
        return GRAIL_E_INVALID_ARGUMENT;
#ifdef ENOENT
    case ENOENT:
#endif
#ifdef ESRCH
    case ESRCH:
#endif
        return GRAIL_E_NOT_FOUND;
#ifdef EACCES
    case EACCES:
#endif
#ifdef EPERM
    case EPERM:
#endif
        return GRAIL_E_ACCESS_DENIED;
#ifdef EEXIST
    case EEXIST:
#endif
        return GRAIL_E_ALREADY_EXISTS;
#ifdef ENOTDIR
    case ENOTDIR:
#endif
        return GRAIL_E_NOT_A_DIRECTORY;
#ifdef EISDIR
    case EISDIR:
#endif
        return GRAIL_E_IS_A_DIRECTORY;
#ifdef ENOTEMPTY
    case ENOTEMPTY:
#endif
        return GRAIL_E_DIRECTORY_NOT_EMPTY;
#ifdef ENAMETOOLONG
    case ENAMETOOLONG:
#endif
        return GRAIL_E_NAME_TOO_LONG;
#ifdef ENOSPC
    case ENOSPC:
#endif
        return GRAIL_E_NO_SPACE;
#ifdef EDQUOT
    case EDQUOT:
#endif
        return GRAIL_E_QUOTA_EXCEEDED;
#ifdef EROFS
    case EROFS:
#endif
        return GRAIL_E_READ_ONLY;
#ifdef EBUSY
    case EBUSY:
#endif
#ifdef ETXTBSY
    case ETXTBSY:
#endif
        return GRAIL_E_BUSY;
#ifdef ETIMEDOUT
    case ETIMEDOUT:
#endif
        return GRAIL_E_TIMED_OUT;
#ifdef EAGAIN
    case EAGAIN:
#endif
#ifdef EINPROGRESS
    case EINPROGRESS:
#endif
#ifdef EALREADY
    case EALREADY:
#endif
        return GRAIL_E_WOULD_BLOCK;
#ifdef EINTR
    case EINTR:
#endif
        return GRAIL_E_INTERRUPTED;
#ifdef ECONNRESET
    case ECONNRESET:
#endif
        return GRAIL_E_CONNECTION_RESET;
#ifdef ECONNREFUSED
    case ECONNREFUSED:
#endif
        return GRAIL_E_CONNECTION_REFUSED;
#ifdef ECONNABORTED
    case ECONNABORTED:
#endif
        return GRAIL_E_CONNECTION_ABORTED;
#ifdef ENETUNREACH
    case ENETUNREACH:
#endif
#ifdef EHOSTUNREACH
    case EHOSTUNREACH:
#endif
#ifdef ENETDOWN
    case ENETDOWN:
#endif
        return GRAIL_E_NETWORK_UNREACHABLE;
#ifdef EADDRINUSE
    case EADDRINUSE:
#endif
        return GRAIL_E_ADDRESS_IN_USE;
#ifdef EADDRNOTAVAIL
    case EADDRNOTAVAIL:
#endif
#ifdef ENOTSOCK
    case ENOTSOCK:
#endif
        return GRAIL_E_ADDRESS_INVALID;
#ifdef EMSGSIZE
    case EMSGSIZE:
#endif
        return GRAIL_E_MESSAGE_TOO_LARGE;
#ifdef ENOTSUP
    case ENOTSUP:
#endif
#if defined(EOPNOTSUPP) && (!defined(ENOTSUP) || EOPNOTSUPP != ENOTSUP)
    case EOPNOTSUPP:
#endif
#ifdef ENOSYS
    case ENOSYS:
#endif
#ifdef ENOPROTOOPT
    case ENOPROTOOPT:
#endif
#if defined(EPROTONOSUPPORT) && (!defined(ENOPROTOOPT) || EPROTONOSUPPORT != ENOPROTOOPT)
    case EPROTONOSUPPORT:
#endif
        return GRAIL_E_UNSUPPORTED;
#ifdef EAFNOSUPPORT
    case EAFNOSUPPORT:
#endif
        return GRAIL_E_ADDRESS_INVALID;
#ifdef EPIPE
    case EPIPE:
#endif
#ifdef ESHUTDOWN
    case ESHUTDOWN:
#endif
        return GRAIL_E_BROKEN_PIPE;
#ifdef ENOTCONN
    case ENOTCONN:
#endif
        return GRAIL_E_CONNECTION_ABORTED;
#ifdef ECANCELED
    case ECANCELED:
#endif
        return GRAIL_E_CANCELED;
#ifdef EOVERFLOW
    case EOVERFLOW:
#endif
        return GRAIL_E_OVERFLOW;
#ifdef ENOMEM
    case ENOMEM:
#endif
        return GRAIL_E_OUT_OF_MEMORY;
#ifdef EMFILE
    case EMFILE:
#endif
#ifdef ENFILE
    case ENFILE:
#endif
        return GRAIL_E_TOO_MANY_HANDLES;
#ifdef ELOOP
    case ELOOP:
#endif
        return GRAIL_E_SYMLINK_LOOP;
#ifdef EXDEV
    case EXDEV:
#endif
        return GRAIL_E_CROSS_DEVICE;
#ifdef ESPIPE
    case ESPIPE:
#endif
        return GRAIL_E_NOT_SEEKABLE;
    default:
        return GRAIL_E_SYSTEM;
    }
}

