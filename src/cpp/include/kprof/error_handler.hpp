// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#ifndef KPROF_ERROR_HANDLER_HPP
#define KPROF_ERROR_HANDLER_HPP

#include <string>

namespace kprof::detail {
// Human-readable description of a perf_event_open errno.
std::string describe_error(int errnum);
// Human-readable description of a ioctl errno.
std::string describe_ioctl_error(int errnum);
} // namespace kprof::detail

#endif // KPROF_ERROR_HANDLER_HPP