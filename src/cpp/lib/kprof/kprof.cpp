// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include <chrono>
#include <cstddef>
#include <cstring>
#include <fstream>
#include <iostream>
#include <kprof/kprof.hpp>

#include <asm/unistd.h>
#include <linux/perf_event.h>
#include <memory>
#include <string_view>
#include <sys/ioctl.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <unordered_map>
#include <utility>
#include <vector>

#include "config.hpp"
#include "error_handler.hpp"

namespace kprof {

namespace event {
const event_descriptor hw_instrs{.name = "hw_instrs",
                                 .type = event_type::hardware,
                                 .config = PERF_COUNT_HW_INSTRUCTIONS,
                                 .domain = event_domain::user,
                                 .kind = event_kind::perf};

const event_descriptor cpu_cycles{.name = "cpu_cycles",
                                  .type = event_type::hardware,
                                  .config = PERF_COUNT_HW_CPU_CYCLES,
                                  .domain = event_domain::user,
                                  .kind = event_kind::perf};

const event_descriptor l1_read_access{.name = "l1_read_access",
                                      .type = event_type::hw_cache,
                                      .config = PERF_COUNT_HW_CACHE_L1D |
                                                detail::cache_access_r,
                                      .domain = event_domain::user,
                                      .kind = event_kind::perf};

const event_descriptor timer_ns{.name = "timer_ns",
                                .type = event_type::hardware,
                                .config = 0,
                                .domain = event_domain::user,
                                .kind = event_kind::timer};

} // namespace event

struct counter {
    std::string name;
    event_type type = event_type::hardware;
    std::uint64_t config = 0;
    event_domain domain = event_domain::user;
    event_kind kind = event_kind::perf;
    int fd = -1;
    int leader_fd = -1;
    bool is_leader = false;
    std::uint64_t id = 0;
    std::uint64_t value = 0;
    bool valid = false;
};

struct set::impl {
    std::vector<counter> counters;
    std::vector<int> leader_fds;
    std::unordered_map<std::uint64_t, std::size_t> id_to_index;
    std::unordered_map<std::string_view, std::size_t> name_to_index;
    std::vector<measure> measurements;
    std::vector<std::uint64_t> read_buf;
    bool has_timer = false;
    int current_leader_fd = -1;
    std::chrono::steady_clock::time_point t0{};
    std::chrono::steady_clock::time_point t1{};

    ~impl() {
        for (auto const &c : counters) {
            if (c.fd >= 0)
                ::close(c.fd);
        }
    }

    void add(event_descriptor const &d) {
        counter c;
        c.name.assign(d.name);
        c.type = d.type;
        c.config = d.config;
        c.domain = d.domain;
        c.kind = d.kind;
        if (c.kind == event_kind::timer)
            has_timer = true;
        else
            open_perf(c);
        counters.push_back(std::move(c));
    }

    void add_raw(std::string_view name, long type, std::uint64_t config) {
        add(event_descriptor{name, static_cast<event_type>(type), config,
                             event_domain::user, event_kind::perf});
    }

    void open_perf(counter &c) {
        perf_event_attr pe;
        std::memset(&pe, 0, sizeof(pe));
        pe.type = static_cast<std::uint32_t>(c.type);
        pe.size = sizeof(perf_event_attr);
        pe.config = c.config;
        pe.disabled = 1;
        pe.inherit = 1;
        pe.inherit_stat = 0;
        pe.pinned = 0;
        auto const dom = static_cast<std::uint8_t>(c.domain);
        pe.exclude_user =
            !(dom & static_cast<std::uint8_t>(event_domain::user));
        pe.exclude_kernel =
            !(dom & static_cast<std::uint8_t>(event_domain::kernel));
        pe.exclude_hv =
            !(dom & static_cast<std::uint8_t>(event_domain::hypervisor));
        pe.read_format = PERF_FORMAT_ID | PERF_FORMAT_GROUP;

        c.is_leader = (current_leader_fd < 0);
        int fd = static_cast<int>(
            ::syscall(SYS_perf_event_open, &pe, 0, -1,
                      c.is_leader ? -1 : current_leader_fd, 0));
        if (fd < 0 && (errno == EINVAL || errno == ENOSPC)) {
            fd = static_cast<int>(
                ::syscall(SYS_perf_event_open, &pe, 0, -1, -1, 0));
            c.is_leader = true;
        }
        if (fd < 0) {
            std::cerr << "kprof: cannot open counter '" << c.name
                      << "': " << detail::describe_error(errno) << '\n';
            return; // unavailable counter: keep the slot, value stays 0
        }

        if (::ioctl(fd, PERF_EVENT_IOC_ID, &c.id) == -1) {
            std::cerr << "kprof: PERF_EVENT_IOC_ID failed for '" << c.name
                      << "': " << detail::describe_ioctl_error(errno) << '\n';
            ::close(fd);
            return;
        }

        c.fd = fd;
        if (c.is_leader) {
            c.leader_fd = fd;
            current_leader_fd = fd;
            leader_fds.push_back(fd);
        } else {
            c.leader_fd = current_leader_fd;
        }
        c.valid = true;
    }

    void load_file(std::string const &path) {
        std::ifstream file(path);
        if (!file.is_open()) {
            std::cerr << "kprof: cannot open counter file '" << path << "'\n";
            return;
        }
        std::string line;
        while (std::getline(file, line)) {
            std::stringstream ss(line);
            std::string name;
            std::string type;
            std::string spec;
            if (!(std::getline(ss, name, ',') && std::getline(ss, type, ',') &&
                  std::getline(ss, spec)))
                continue;
            long const t = detail::lookup_event(type);
            long const cfg = detail::lookup_event(spec);
            if (t < 0 || cfg < 0) {
                std::cerr << "kprof: invalid counter in '" << line
                          << "', ignoring\n";
                continue;
            }
            add_raw(name, t, static_cast<std::uint64_t>(cfg));
        }
    }

    void load_env(std::string const &spec) {
        std::istringstream ss(spec);
        std::string token;
        while (std::getline(ss, token, ';')) {
            if (token.empty())
                continue;
            auto const comma = token.find(',');
            if (comma == std::string::npos) {
                std::cerr << "kprof: invalid counter spec '" << token
                          << "', ignoring\n";
                continue;
            }
            std::string const name = token.substr(0, comma);
            std::string const rest = token.substr(comma + 1);
            auto const colon = rest.find(':');
            if (colon == std::string::npos) {
                std::cerr << "kprof: invalid counter spec '" << token
                          << "', ignoring\n";
                continue;
            }
            std::string const type = rest.substr(0, colon);
            std::string const value = rest.substr(colon + 1);
            int const t = detail::lookup_perf_type(type);
            long const cfg = detail::lookup_event(value);
            if (t < 0 || cfg < 0) {
                std::cerr << "kprof: invalid counter spec '" << token
                          << "', ignoring\n";
                continue;
            }
            add_raw(name, t, static_cast<std::uint64_t>(cfg));
        }
    }

    void load_default() {
        add_raw("HW-instructions", PERF_TYPE_HARDWARE,
                PERF_COUNT_HW_INSTRUCTIONS);
        add_raw("CPU-cycles", PERF_TYPE_HARDWARE, PERF_COUNT_HW_CPU_CYCLES);
        add_raw("Branch-instructions", PERF_TYPE_HARDWARE,
                PERF_COUNT_HW_BRANCH_INSTRUCTIONS);
        add_raw("Branch-misses", PERF_TYPE_HARDWARE,
                PERF_COUNT_HW_BRANCH_MISSES);
        add_raw("Bus-cycles", PERF_TYPE_HARDWARE, PERF_COUNT_HW_BUS_CYCLES);
        add_raw("Stall-frontend", PERF_TYPE_HARDWARE,
                PERF_COUNT_HW_STALLED_CYCLES_FRONTEND);
        add_raw("Stall-backend", PERF_TYPE_HARDWARE,
                PERF_COUNT_HW_STALLED_CYCLES_BACKEND);
        add_raw("L1d-read-miss", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_L1D | detail::cache_miss_r);
        add_raw("L1d-write-miss", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_L1D | detail::cache_miss_w);
        add_raw("L1d-read-access", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_L1D | detail::cache_access_r);
        add_raw("L1d-write-access", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_L1D | detail::cache_access_w);
        add_raw("L1i-read-miss", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_L1I | detail::cache_miss_r);
        add_raw("L1i-read-access", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_L1I | detail::cache_access_r);
        add_raw("LLC-read-miss", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_LL | detail::cache_miss_r);
        add_raw("LLC-write-miss", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_LL | detail::cache_miss_w);
        add_raw("LLC-read-access", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_LL | detail::cache_access_r);
        add_raw("LLC-write-access", PERF_TYPE_HW_CACHE,
                PERF_COUNT_HW_CACHE_LL | detail::cache_access_w);
        add_raw("Pagefaults-total", PERF_TYPE_SOFTWARE,
                PERF_COUNT_SW_PAGE_FAULTS);
        add_raw("Pagefaults-maj", PERF_TYPE_SOFTWARE,
                PERF_COUNT_SW_PAGE_FAULTS_MAJ);
        add_raw("Pagefaults-min", PERF_TYPE_SOFTWARE,
                PERF_COUNT_SW_PAGE_FAULTS_MIN);
        add_raw("Alignment-faults", PERF_TYPE_SOFTWARE,
                PERF_COUNT_SW_ALIGNMENT_FAULTS);
        add_raw("CPU-migrations", PERF_TYPE_SOFTWARE,
                PERF_COUNT_SW_CPU_MIGRATIONS);
        add(event::timer_ns);
    }

    void absorb(impl &&other) {
        has_timer = has_timer || other.has_timer;
        leader_fds.insert(leader_fds.end(), other.leader_fds.begin(),
                          other.leader_fds.end());
        for (auto &c : other.counters)
            counters.push_back(std::move(c));

        other.counters.clear();
        other.leader_fds.clear();
        other.current_leader_fd = -1;
    }

    void finalize() {
        id_to_index.clear();
        name_to_index.clear();
        std::size_t perf_count = 0;
        for (std::size_t i = 0; i < counters.size(); ++i) {
            auto const &c = counters[i];
            name_to_index.emplace(std::string_view(c.name), i);
            if (c.valid) {
                id_to_index.emplace(c.id, i);
                ++perf_count;
            }
        }
        read_buf.assign(1 + 2 * perf_count, 0);
        measurements.reserve(counters.size());
    }

    void read_groups() {
        if (leader_fds.empty() || read_buf.empty())
            return;
        for (int const lfd : leader_fds) {
            auto const bytes = ::read(lfd, read_buf.data(),
                                      read_buf.size() * sizeof(std::uint64_t));
            if (bytes < static_cast<ssize_t>(sizeof(std::uint64_t)))
                continue;
            std::uint64_t const nr = read_buf[0];
            for (std::uint64_t k = 0; k < nr; ++k) {
                std::uint64_t const value = read_buf[1 + 2 * k];
                std::uint64_t const id = read_buf[2 + 2 * k];
                auto const it = id_to_index.find(id);
                if (it != id_to_index.end())
                    counters[it->second].value = value;
            }
        }
    }

    std::chrono::nanoseconds duration() const {
        return std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0);
    }

    void build_measurements() {
        measurements.clear();
        auto const elapsed = static_cast<std::uint64_t>(duration().count());
        for (auto const &c : counters) {
            std::uint64_t const v =
                (c.kind == event_kind::timer) ? elapsed : c.value;
            measurements.push_back({std::string_view(c.name), v});
        }
    }
};

set::set() : impl_(std::make_unique<impl>()) {
    if (char const *file = std::getenv("KPROF_COUNTER_FILE"))
        impl_->load_file(file);
    else if (char const *conf = std::getenv("KPROF_COUNTER_CONF"))
        impl_->load_env(conf);
    else
        impl_->load_default();
    impl_->finalize();
}

set::set(std::string_view config_file) : impl_(std::make_unique<impl>()) {
    impl_->load_file(std::string(config_file));
    impl_->finalize();
}

set::set(std::initializer_list<event_descriptor> events)
    : impl_(std::make_unique<impl>()) {
    impl_->counters.reserve(events.size());
    for (auto const &e : events)
        impl_->add(e);
    impl_->finalize();
}

set::~set() = default;
set::set(set &&) noexcept = default;
set &set::operator=(set &&) noexcept = default;

set set::operator+(set &&rhs) noexcept {

    impl_->absorb(std::move(*rhs.impl_));
    impl_->finalize();
    return std::move(*this);
}

void set::start() noexcept {
    auto &d = *impl_;
    for (int const lfd : d.leader_fds) {
        ::ioctl(lfd, PERF_EVENT_IOC_RESET, PERF_IOC_FLAG_GROUP);
        ::ioctl(lfd, PERF_EVENT_IOC_ENABLE, PERF_IOC_FLAG_GROUP);
    }
    if (d.has_timer)
        d.t0 = std::chrono::steady_clock::now();
}

void set::end() noexcept {
    auto &d = *impl_;
    if (d.has_timer)
        d.t1 = std::chrono::steady_clock::now();

    for (int const lfd : d.leader_fds)
        ::ioctl(lfd, PERF_EVENT_IOC_DISABLE, PERF_IOC_FLAG_GROUP);
    d.read_groups();
    d.build_measurements();
}

std::span<measure const> set::report() const noexcept {
    return {impl_->measurements.data(), impl_->measurements.size()};
}

std::uint64_t set::get(event_descriptor const &descriptor) const noexcept {
    return get(descriptor.name);
}

std::uint64_t set::get(std::string_view name) const noexcept {
    auto const it = impl_->name_to_index.find(name);
    if (it == impl_->name_to_index.end())
        return 0;
    return impl_->measurements[it->second].value;
}

std::chrono::nanoseconds set::duration() const noexcept {
    return impl_->duration();
}

bool set::empty() const noexcept { return impl_->counters.empty(); }

} // namespace kprof
