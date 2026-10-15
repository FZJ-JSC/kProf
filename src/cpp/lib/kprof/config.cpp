// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include <kprof/config.hpp>
#include <cstddef>
#include <cstdlib>
#include <linux/perf_event.h>
#include <string>
#include <unordered_map>

namespace kprof::detail {

namespace {

std::unordered_map<std::string, long> const &name_table() {
    static std::unordered_map<std::string, long> const table = {
        {"PERF_TYPE_HARDWARE", PERF_TYPE_HARDWARE},
        {"PERF_TYPE_SOFTWARE", PERF_TYPE_SOFTWARE},
        {"PERF_TYPE_HW_CACHE", PERF_TYPE_HW_CACHE},
        {"PERF_TYPE_RAW", PERF_TYPE_RAW},

        {"PERF_COUNT_HW_CPU_CYCLES", PERF_COUNT_HW_CPU_CYCLES},
        {"PERF_COUNT_HW_INSTRUCTIONS", PERF_COUNT_HW_INSTRUCTIONS},
        {"PERF_COUNT_HW_CACHE_REFERENCES", PERF_COUNT_HW_CACHE_REFERENCES},
        {"PERF_COUNT_HW_CACHE_MISSES", PERF_COUNT_HW_CACHE_MISSES},
        {"PERF_COUNT_HW_BRANCH_INSTRUCTIONS",
         PERF_COUNT_HW_BRANCH_INSTRUCTIONS},
        {"PERF_COUNT_HW_BRANCH_MISSES", PERF_COUNT_HW_BRANCH_MISSES},
        {"PERF_COUNT_HW_BUS_CYCLES", PERF_COUNT_HW_BUS_CYCLES},
        {"PERF_COUNT_HW_STALLED_CYCLES_FRONTEND",
         PERF_COUNT_HW_STALLED_CYCLES_FRONTEND},
        {"PERF_COUNT_HW_STALLED_CYCLES_BACKEND",
         PERF_COUNT_HW_STALLED_CYCLES_BACKEND},

        {"PERF_COUNT_SW_CPU_CLOCK", PERF_COUNT_SW_CPU_CLOCK},
        {"PERF_COUNT_SW_TASK_CLOCK", PERF_COUNT_SW_TASK_CLOCK},
        {"PERF_COUNT_SW_PAGE_FAULTS", PERF_COUNT_SW_PAGE_FAULTS},
        {"PERF_COUNT_SW_PAGE_FAULTS_MIN", PERF_COUNT_SW_PAGE_FAULTS_MIN},
        {"PERF_COUNT_SW_PAGE_FAULTS_MAJ", PERF_COUNT_SW_PAGE_FAULTS_MAJ},
        {"PERF_COUNT_SW_ALIGNMENT_FAULTS", PERF_COUNT_SW_ALIGNMENT_FAULTS},
        {"PERF_COUNT_SW_CPU_MIGRATIONS", PERF_COUNT_SW_CPU_MIGRATIONS},

        {"PERF_COUNT_HW_CACHE_L1D_READ_ACCESS",
         PERF_COUNT_HW_CACHE_L1D | cache_access_r},
        {"PERF_COUNT_HW_CACHE_L1D_READ_MISS",
         PERF_COUNT_HW_CACHE_L1D | cache_miss_r},
        {"PERF_COUNT_HW_CACHE_L1D_WRITE_ACCESS",
         PERF_COUNT_HW_CACHE_L1D | cache_access_w},
        {"PERF_COUNT_HW_CACHE_L1D_WRITE_MISS",
         PERF_COUNT_HW_CACHE_L1D | cache_miss_w},
        {"PERF_COUNT_HW_CACHE_L1I_READ_ACCESS",
         PERF_COUNT_HW_CACHE_L1I | cache_access_r},
        {"PERF_COUNT_HW_CACHE_L1I_READ_MISS",
         PERF_COUNT_HW_CACHE_L1I | cache_miss_r},
        {"PERF_COUNT_HW_CACHE_LL_READ_ACCESS",
         PERF_COUNT_HW_CACHE_LL | cache_access_r},
        {"PERF_COUNT_HW_CACHE_LL_READ_MISS",
         PERF_COUNT_HW_CACHE_LL | cache_miss_r},
        {"PERF_COUNT_HW_CACHE_LL_WRITE_ACCESS",
         PERF_COUNT_HW_CACHE_LL | cache_access_w},
        {"PERF_COUNT_HW_CACHE_LL_WRITE_MISS",
         PERF_COUNT_HW_CACHE_LL | cache_miss_w},
        {"PERF_COUNT_HW_CACHE_DTLB_READ_ACCESS",
         PERF_COUNT_HW_CACHE_DTLB | cache_access_r},
        {"PERF_COUNT_HW_CACHE_DTLB_READ_MISS",
         PERF_COUNT_HW_CACHE_DTLB | cache_miss_r},
        {"PERF_COUNT_HW_CACHE_ITLB_READ_ACCESS",
         PERF_COUNT_HW_CACHE_ITLB | cache_access_r},
        {"PERF_COUNT_HW_CACHE_ITLB_READ_MISS",
         PERF_COUNT_HW_CACHE_ITLB | cache_miss_r},
        {"PERF_COUNT_HW_CACHE_BPU_READ_ACCESS",
         PERF_COUNT_HW_CACHE_BPU | cache_access_r},
        {"PERF_COUNT_HW_CACHE_BPU_READ_MISS",
         PERF_COUNT_HW_CACHE_BPU | cache_miss_r},

    };
    return table;
}
} // namespace



long lookup_event(const std::string &query){
    auto const it = name_table().find(query);
    if (it != name_table().end())
        return it->second;
    try{
        if (query.size() > 2 && query[0] == '0' && (query[1] == 'x' || query[1] == 'X'))
            return  std::stol(query.substr(2), nullptr, 16);
    return std::stol(query, nullptr, 10);
    } catch(...){
        return -1;
    }
}

int lookup_perf_type(const std::string &abbrev){
    if (abbrev == "H")
        return PERF_TYPE_HARDWARE;
    if (abbrev == "S")
        return PERF_TYPE_SOFTWARE;
    if (abbrev == "C")
        return PERF_TYPE_HW_CACHE;
    if (abbrev == "R")
        return PERF_TYPE_RAW;
    return -1;
}



} // namespace kprof::detail