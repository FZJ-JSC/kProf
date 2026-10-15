// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <kprof/kprof.hpp>

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <sched.h>
#include <string>
#include <utility>
#include <vector>

#include <catch2/catch_test_macros.hpp>

namespace {

int pin_to_certain_cpu()
{
  cpu_set_t allowed;
  CPU_ZERO(&allowed);
  if (::sched_getaffinity(0, sizeof(allowed), &allowed) != 0)
    return -1;

  // pin to selected core - cpu0 may be used by kernel interrupts
  // int selected = -1;
  // for (int i = CPU_SETSIZE - 1; i >= 0; --i) {
  //   if (CPU_ISSET(i, &allowed)) {
  //     selected = i;
  //     break;
  //   }
  // }
  // if (selected < 0)
  //   return -1;
  int const selected = 2;
  if (!CPU_ISSET(selected, &allowed)){
     return -1;
  }


  cpu_set_t single;
  CPU_ZERO(&single);
  CPU_SET(selected, &single);
  if (::sched_setaffinity(0, sizeof(single), &single) != 0)
    return -1;
  return selected;
}

// Sample function under benchmark.
KPROF_DO_NOT_OPTIMIZE void busy()
{
  [[maybe_unused]] volatile std::uint64_t sink = 0;
  for (int i = 0; i < 1000000; ++i)
    sink += static_cast<std::uint64_t>(i);
  (void)sink;
}

struct counter_stats {
  std::string name;
  std::uint64_t min;
  double q1;
  double median;
  double q3;
  std::uint64_t max;
  double mean;
  double std_dev;
  double min_ratio;
  bool invalid;
};

double percentile(std::vector<std::uint64_t> const& sorted, double p)
{
  if (sorted.empty())
    return 0.0;
  double const pos = p * static_cast<double>(sorted.size() - 1);
  auto const lo = static_cast<std::size_t>(pos);
  auto const hi = static_cast<std::size_t>(std::ceil(pos));
  double const frac = pos - static_cast<double>(lo);
  return static_cast<double>(sorted[lo]) * (1.0 - frac) + static_cast<double>(sorted[hi]) * frac;
}

counter_stats summarize(
  std::string name, std::vector<std::uint64_t> samples, std::vector<double> ratios)
{
  std::sort(samples.begin(), samples.end());

  double sum = 0.0;
  for (auto v : samples)
    sum += static_cast<double>(v);
  double const mean = samples.empty() ? 0.0 : sum / static_cast<double>(samples.size());

  double variance = 0.0;
  for (auto v : samples) {
    double const d = static_cast<double>(v) - mean;
    variance += d * d;
  }
  double const std_dev
    = samples.size() > 1 ? std::sqrt(variance / static_cast<double>(samples.size() - 1)) : 0.0;

  bool const invalid = !samples.empty() && samples.front() == kprof::invalid_value;
  return counter_stats{
    std::move(name),
    samples.front(),
    percentile(samples, 0.25),
    percentile(samples, 0.50),
    percentile(samples, 0.75),
    samples.back(),
    mean,
    std_dev,
    ratios.empty() ? 0.0 : *std::min_element(ratios.begin(), ratios.end()),
    invalid};
}

std::vector<counter_stats> profile_busy(std::size_t warmup, std::size_t runs)
{
  kprof::set monitor;

  std::vector<std::string> names;
  std::vector<std::vector<std::uint64_t>> samples;
  std::vector<std::vector<double>> ratios;

  auto measure = [&](bool record) {
    monitor.start();
    busy();
    monitor.end();

    auto report = monitor.report();
    if (names.empty()) {
      names.reserve(report.size());
      samples.resize(report.size());
      ratios.resize(report.size());
      for (auto const& m : report)
        names.emplace_back(m.name);
    }
    if (record)
      for (std::size_t k = 0; k < report.size(); ++k) {
        samples[k].push_back(report[k].value);
        ratios[k].push_back(report[k].scaling_ratio);
      }
  };

  for (std::size_t i = 0; i < warmup; ++i)
    measure(false);
  for (std::size_t i = 0; i < runs; ++i)
    measure(true);

  std::vector<counter_stats> result;
  result.reserve(names.size());
  for (std::size_t k = 0; k < names.size(); ++k) {
    result.push_back(summarize(names[k], std::move(samples[k]), std::move(ratios[k])));
  }
  return result;
}

} // namespace

TEST_CASE("profile busy() with the default counter set", "[benchmark]")
{
  ::unsetenv("KPROF_COUNTER_FILE");
  ::unsetenv("KPROF_COUNTER_CONF");

  int const cpu = pin_to_certain_cpu();
  if (cpu >= 0)
    std::printf("pinned benchmark to CPU %d\n", cpu);
  else
    std::fprintf(stderr, "kprof: could not pin benchmark to lowest CPU\n");

  constexpr std::size_t warmup = 10;
  constexpr std::size_t runs = 100;
  std::vector<counter_stats> const stats = profile_busy(warmup, runs);

  REQUIRE_FALSE(stats.empty());

  std::printf(
    "%-20s %12s %12s %12s %12s %12s %14s %14s %14s (%14s)\n",
    "counter",
    "min",
    "q1",
    "median",
    "q3",
    "max",
    "mean",
    "std_dev",
    "min_ratio",
    "percent(std_dev / mean)");
  for (auto const& s : stats) {
    if (s.invalid) {
      std::printf(
        "%-20s %2llu %2llu %2llu %2llu %2llu %2llu %2llu %2llu (%s %%)\n",
        s.name.c_str(),
        -1LL,
        -1LL,
        -1LL,
        -1LL,
        -1LL,
        -1LL,
        -1LL,
        -1LL,
        "could not open counter");
      continue;
    }
    std::printf(
      "%-20s %12llu %12.2f %12.2f %12.2f %12llu %14.2f %14.2f %14.2f (%3.2f %%)\n",
      s.name.c_str(),
      static_cast<unsigned long long>(s.min),
      s.q1,
      s.median,
      s.q3,
      static_cast<unsigned long long>(s.max),
      s.mean,
      s.std_dev,
      s.min_ratio,
      (s.std_dev / s.mean * 100));

    CHECK(s.min <= s.q1);
    CHECK(s.q1 <= s.median);
    CHECK(s.median <= s.q3);
    CHECK(s.q3 <= s.max);
    CHECK(s.min <= s.mean);
    CHECK(s.mean <= s.max);
    CHECK(s.std_dev >= 0.0);
    CHECK(s.min_ratio >= 1.0);
  }

  CHECK(stats.back().name == "timer_ns");
  CHECK(stats.back().median > 0);
}
