// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include "error_handler.hpp"

#include <cerrno>
#include <cstring>
#include <string>

namespace kprof::detail {

std::string describe_error(int errnum) {
    switch (errnum) {
    case E2BIG:
        return "perf_event_attr size is invalid.";
    case EACCES:
        return "requires CAP_PERFMON/CAP_SYS_ADMIN or a more permissive "
               "perf_event_paranoid setting.";
    case EBADF:
        return "the group_fd file descriptor is not valid.";
    case EBUSY:
        return "another event already has exclusive access to the PMU.";
    case EFAULT:
        return "the attr pointer points at an invalid memory address.";
    case EINVAL:
        return "the specified event is invalid.";
    case EMFILE:
        return "per-process open-file-descriptor limit reached.";
    case ENODEV:
        return "the event involves a feature not supported by this CPU.";
    case ENOENT:
        return "the perf event type is not valid.";
    case ENOSPC:
        return "not enough hardware counters available.";
    case ENOSYS:
        return "a requested sample feature is not supported by the hardware.";
    case EOPNOTSUPP:
        return "the requested event is not supported by the hardware.";
    case EOVERFLOW:
        return "sample_max_stack exceeds perf_event_max_stack.";
    case EPERM:
        return "unsupported exclude setting or insufficient permission.";
    case ESRCH:
        return "attempted to attach to a process that does not exist.";
    default:
        return std::strerror(errnum);
    }
}

std::string describe_ioctl_error(int errnum) {
    switch (errnum) {
    case EBADF:
        return "fd is not a valid file descriptor.";
    case EFAULT:
        return "argp references an inaccessible memory area.";
    case EINVAL:
        return "op or argp is not valid.";
    case ENOTTY:
        return "fd is not associated with a character special device, or the "
               "operation does not apply to this descriptor.";
    default:
        return std::strerror(errnum);
    }
}

} // namespace kprof::detail