// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#ifndef KPROF_CONFIG_HPP
#define KPROF_CONFIG_HPP

#include <cstdint>
#include <linux/perf_event.h>
#include <string>

namespace kprof::detail {

// PERF_COUNT_HW_CACHE_* encoding (op << 8 | result << 16).
inline constexpr std::uint64_t cache_miss_r =
    (PERF_COUNT_HW_CACHE_OP_READ << 8) |
    (PERF_COUNT_HW_CACHE_RESULT_MISS << 16);
inline constexpr std::uint64_t cache_miss_w =
    (PERF_COUNT_HW_CACHE_OP_WRITE << 8) |
    (PERF_COUNT_HW_CACHE_RESULT_MISS << 16);
inline constexpr std::uint64_t cache_access_r =
    (PERF_COUNT_HW_CACHE_OP_READ << 8) |
    (PERF_COUNT_HW_CACHE_RESULT_ACCESS << 16);
inline constexpr std::uint64_t cache_access_w =
    (PERF_COUNT_HW_CACHE_OP_WRITE << 8) |
    (PERF_COUNT_HW_CACHE_RESULT_ACCESS << 16);

// Resolve a symbolic PERF_* name (or a decimal/hex literal) to its value; -1 on
// failure. Used by the CSV/env configuration paths.
long lookup_event(std::string const &query);

// Resolve the short type abbreviation used by KPROF_COUNTER_CONF: H/S/C/R.
int lookup_perf_type(std::string const &abbrev);

} // namespace kprof::detail

#endif // KPROF_CONFIG_HPP
