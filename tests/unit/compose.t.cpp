// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include <kprof/kprof.hpp>

#include <cstdint>
#include <utility>
#include <vector>

#include <catch2/catch_test_macros.hpp>

namespace {

void busy()
{
  volatile std::uint64_t sink = 0;
  for (int i = 0; i < 1000000; ++i)
    sink += static_cast<std::uint64_t>(i);
  (void)sink;
}

} // namespace

TEST_CASE("append merges two sets", "[compose]")
{
  kprof::set a{std::vector{kprof::event::hw_instrs}};
  kprof::set b{std::vector{kprof::event::timer_ns}};

  a.append(std::move(b));
  REQUIRE_FALSE(a.empty());

  a.start();
  busy();
  a.end();

  auto r = a.report();
  REQUIRE(r.size() == 2);
  CHECK(r[0].name == "hw_instrs");
  CHECK(r[1].name == "timer_ns");
  CHECK(r[1].value > 0);
}

TEST_CASE("move construction and assignment preserve measurements", "[compose]")
{
  kprof::set a{std::vector{kprof::event::timer_ns}};
  a.start();
  busy();
  a.end();

  kprof::set b = std::move(a);
  REQUIRE(b.report().size() == 1);
  CHECK(b.report()[0].name == "timer_ns");

  kprof::set c{std::vector{kprof::event::cpu_cycles}};
  c = std::move(b);
  c.start();
  busy();
  c.end();
  REQUIRE(c.report().size() == 1);
  CHECK(c.report()[0].value > 0);
}

TEST_CASE("duplicate names resolve to the first registration", "[compose]")
{
  kprof::set a{std::vector{kprof::event::timer_ns}};
  kprof::set b{std::vector{kprof::event::timer_ns}};

  a.append(std::move(b));
  a.start();
  busy();
  a.end();

  auto r = a.report();
  REQUIRE(r.size() == 2);
  CHECK(r[0].name == "timer_ns");
  CHECK(r[1].name == "timer_ns");
  CHECK(a.get("timer_ns") == r[0].value);
}

TEST_CASE("merge order is left then right", "[compose]")
{
  kprof::set a{std::vector{kprof::event::hw_instrs, kprof::event::cpu_cycles}};
  kprof::set b{std::vector{kprof::event::l1_read_access}};
  kprof::set c{std::vector{kprof::event::timer_ns}};

  a.append(std::move(b)).append(std::move(c));
  a.start();
  busy();
  a.end();

  auto r = a.report();
  REQUIRE(r.size() == 4);
  CHECK(r[0].name == "hw_instrs");
  CHECK(r[1].name == "cpu_cycles");
  CHECK(r[2].name == "l1_read_access");
  CHECK(r[3].name == "timer_ns");
}

TEST_CASE("self-append is a no-op", "[compose]")
{
  kprof::set a{std::vector{kprof::event::hw_instrs, kprof::event::cpu_cycles}};

  a.append(std::move(a));
  a.start();
  busy();
  a.end();

  auto r = a.report();
  REQUIRE(r.size() == 2);
  CHECK(r[0].name == "hw_instrs");
  CHECK(r[1].name == "cpu_cycles");
}