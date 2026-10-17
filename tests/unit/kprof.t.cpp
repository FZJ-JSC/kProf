// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include <catch2/catch_test_macros.hpp>
#include <cstddef>
#include <cstdint>
#include <kprof/do_not_optimize.hpp>
#include <kprof/kprof.hpp>
#include <linux/perf_event.h>

namespace {

KPROF_DO_NOT_OPTIMIZE void busy()
{
  volatile std::uint64_t sink = 0;
  for (int i = 0; i < 1000000; ++i)
    sink += static_cast<std::uint64_t>(i);
  (void)sink;
}

} // namespace

TEST_CASE("event descriptors expose expected metadata", "[event]")
{
  constexpr std::uint64_t cache_access_r
    = (PERF_COUNT_HW_CACHE_OP_READ << 8) | (PERF_COUNT_HW_CACHE_RESULT_ACCESS << 16);

  CHECK(kprof::event::hw_instrs.name == "hw_instrs");
  CHECK(kprof::event::hw_instrs.kind == kprof::event_kind::perf);
  CHECK(kprof::event::hw_instrs.type == kprof::event_type::hardware);
  CHECK(kprof::event::hw_instrs.config == PERF_COUNT_HW_INSTRUCTIONS);

  CHECK(kprof::event::cpu_cycles.name == "cpu_cycles");
  CHECK(kprof::event::cpu_cycles.config == PERF_COUNT_HW_CPU_CYCLES);

  CHECK(kprof::event::l1_read_access.name == "l1_read_access");
  CHECK(kprof::event::l1_read_access.type == kprof::event_type::hw_cache);
  CHECK(kprof::event::l1_read_access.config == (PERF_COUNT_HW_CACHE_L1D | cache_access_r));

  CHECK(kprof::event::timer_ns.name == "timer_ns");
  CHECK(kprof::event::timer_ns.kind == kprof::event_kind::timer);
}

TEST_CASE("timer-only set measures a duration", "[set][timer]")
{
  kprof::set s{std::vector{kprof::event::timer_ns}};
  REQUIRE_FALSE(s.empty());
  CHECK(s.report().empty()); // nothing measured until end()

  s.start();
  busy();
  s.end();

  auto r = s.report();
  REQUIRE(r.size() == 1);
  CHECK(r[0].name == "timer_ns");
  CHECK(r[0].value > 0);
  CHECK(s.duration().count() > 0);
}

TEST_CASE("full set preserves construction order", "[set]")
{
  kprof::set s{std::vector{
    kprof::event::hw_instrs,
    kprof::event::cpu_cycles,
    kprof::event::l1_read_access,
    kprof::event::timer_ns}};
  REQUIRE_FALSE(s.empty());

  s.start();
  busy();
  s.end();

  auto r = s.report();
  REQUIRE(r.size() == 4);
  CHECK(r[0].name == "hw_instrs");
  CHECK(r[1].name == "cpu_cycles");
  CHECK(r[2].name == "l1_read_access");
  CHECK(r[3].name == "timer_ns");
  CHECK(r[3].value > 0);
  CHECK(r[3].value == static_cast<std::uint64_t>(s.duration().count()));
  for (std::size_t i = 0; i < r.size() - 1; ++i)
    CHECK((r[i].scaling_ratio >= 1.0 || r[i].scaling_ratio == 0.0));
}

TEST_CASE("a set without a timer reports zero duration", "[set]")
{
  kprof::set s{std::vector{kprof::event::hw_instrs}};
  s.start();
  busy();
  s.end();
  CHECK(s.duration().count() == 0);
}

TEST_CASE("get() agrees with report()", "[set]")
{
  kprof::set s{std::vector{kprof::event::timer_ns}};
  s.start();
  busy();
  s.end();

  CHECK(s.get(kprof::event::timer_ns) == s.get("timer_ns"));
  CHECK(s.get("timer_ns") == s.report()[0].value);
  CHECK(s.get("does_not_exist") == 0);
}

TEST_CASE("repeated start/end cycles rebuild measurements", "[set]")
{
  kprof::set s{std::vector{kprof::event::timer_ns}};
  for (int round = 0; round < 2; ++round) {
    s.start();
    busy();
    s.end();
    CHECK(s.report().size() == 1);
    CHECK(s.duration().count() > 0);
  }
}

TEST_CASE("custom descriptors are measured without crashing", "[set]")
{
  kprof::event_descriptor raw{
    "raw", kprof::event_type::raw, 0xdeadbeef, kprof::event_domain::user, kprof::event_kind::perf};
  kprof::set s{std::vector{raw}};
  REQUIRE_FALSE(s.empty());
  CHECK(s.report().empty());

  s.start();
  busy();
  s.end();
  REQUIRE(s.report().size() == 1);
  CHECK(s.report()[0].name == "raw");
}
