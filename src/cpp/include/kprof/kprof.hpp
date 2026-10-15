// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#ifndef KPROF_HPP
#define KPROF_HPP

#include <array>
#include <chrono>
#include <concepts>
#include <cstdint>
#include <memory>
#include <span>
#include <string_view>
#include <utility>

#if defined(__clang__)
#define KPROF_DO_NOT_OPTIMIZE __attribute__((optnone))
#elif defined(__GNUC__) || defined(__GNUG__)
#define KPROF_DO_NOT_OPTIMIZE __attribute__((optimize(0)))
#else
#define KPROF_DO_NOT_OPTIMIZE
#endif



namespace kprof {

enum class event_type : std::uint32_t {
  hardware = 0,
  software = 1,
  tracepoint = 2,
  hw_cache = 3,
  raw = 4,
};

enum class event_domain : std::uint8_t {
  user = 0b001,
  kernel = 0b010,
  hypervisor = 0b100,
  all = 0b111,
};

enum class event_kind : std::uint8_t {
  perf,
  timer,
};

struct event_descriptor {
  std::string_view name;
  event_type type;
  std::uint64_t config;
  event_domain domain = event_domain::user;
  event_kind kind = event_kind::perf;
};

namespace event {
extern const event_descriptor hw_instrs;
extern const event_descriptor cpu_cycles;
extern const event_descriptor l1_read_access;
extern const event_descriptor timer_ns;
} // namespace event

struct measure {
  std::string_view name;
  std::uint64_t value;
  // 1 = clean, >1 = corrected, 0 = counter was never scheduled
  double scaling_ratio = 1.0;
};

inline constexpr std::uint64_t invalid_value = ~std::uint64_t(0);
inline constexpr bool is_invalid(std::uint64_t value) noexcept { return value == invalid_value; }

/* A set is a composable collection of counters measured together. `start()` and
 * `end()` ednote a region.  The timer (if present) is read on the calling
 * thread with std::chrono::steady_clock, while perf counters are grouped and
 * read once per leader. The implementation is entirely synchronous and
 * allocation-free on the start()/end() path. */

class set {
public:
  // takes care of KPROF_COUNTER_FILE, then KPROF_COUNTER_CONF, else defaults
  // to the default set
  set();

  // load from CSV file
  explicit set(std::string_view config_file);

  // compose from descriptors
  template <class... E>
    requires((std::convertible_to<E, event_descriptor>) && ...)
  set(E&&... events)
  : set(
      std::array<event_descriptor, sizeof...(E)>{
        static_cast<event_descriptor>(std::forward<E>(events))...})
  {
  }

  ~set();

  set(set&&) noexcept;
  set& operator=(set&&) noexcept;
  set(set const&) = delete;
  set& operator=(set const&) = delete;

  // compose behaviour: steal the RHS' counters and open fds
  set operator+(set&& rhs) noexcept;

  void start() noexcept;
  void end() noexcept;

  // valid until set is destroyed or end() is called again.
  [[nodiscard]] std::span<measure const> report() const noexcept;
  [[nodiscard]] std::uint64_t get(event_descriptor const& descriptor) const noexcept;
  [[nodiscard]] std::uint64_t get(std::string_view name) const noexcept;
  [[nodiscard]] std::chrono::nanoseconds duration() const noexcept;
  [[nodiscard]] bool empty() const noexcept;

private:
  struct impl;
  std::unique_ptr<impl> impl_;
  set(std::span<event_descriptor const> events);
};

} // namespace kprof

#endif // KPROF_HPP
