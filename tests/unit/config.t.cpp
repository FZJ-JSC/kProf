// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include <kprof/kprof.hpp>

#include <cstring>
#include <string>

#include <unistd.h>

#include <catch2/catch_test_macros.hpp>

namespace {

void clear_env() {
  ::unsetenv("KPROF_COUNTER_FILE");
  ::unsetenv("KPROF_COUNTER_CONF");
}

std::string write_temp_csv(char const* content) {
  char path[] = "/tmp/kprof_test_XXXXXX";
  int const fd = ::mkstemp(path);
  if (fd < 0)
    return {};
  auto const len = std::strlen(content);
  auto const written = ::write(fd, content, len);
  ::close(fd);
  if (written != static_cast<ssize_t>(len)) {
    ::unlink(path);
    return {};
  }
  return std::string(path);
}

void measure(kprof::set& s) {
  s.start();
  s.end();
}

} // namespace


TEST_CASE("KPROF_COUNTER_CONF spec is parsed in order", "[config][env]") {
  clear_env();
  ::setenv("KPROF_COUNTER_CONF",
           "a,H:PERF_COUNT_HW_INSTRUCTIONS;b,S:PERF_COUNT_SW_PAGE_FAULTS", 1);
  kprof::set s;
  measure(s);
  auto r = s.report();
  REQUIRE(r.size() == 2);
  CHECK(r[0].name == "a");
  CHECK(r[1].name == "b");
  clear_env();
}

TEST_CASE("malformed env entries are skipped", "[config][env]") {
  clear_env();
  ::setenv("KPROF_COUNTER_CONF",
           "garbage,H:BOGUS;good,H:PERF_COUNT_HW_INSTRUCTIONS", 1);
  kprof::set s;
  measure(s);
  auto r = s.report();
  REQUIRE(r.size() == 1);
  CHECK(r[0].name == "good");
  clear_env();
}

TEST_CASE("CSV file spec is parsed in order", "[config][file]") {
  clear_env();
  std::string const path = write_temp_csv(
      "hw,PERF_TYPE_HARDWARE,PERF_COUNT_HW_INSTRUCTIONS\n"
      "sw,PERF_TYPE_SOFTWARE,PERF_COUNT_SW_PAGE_FAULTS\n");
  REQUIRE_FALSE(path.empty());

  kprof::set s(path);
  measure(s);
  auto r = s.report();
  REQUIRE(r.size() == 2);
  CHECK(r[0].name == "hw");
  CHECK(r[1].name == "sw");

  ::unlink(path.c_str());
}

TEST_CASE("missing config file yields an empty set", "[config][file]") {
  clear_env();
  kprof::set s("definitely_not_here.csv");
  CHECK(s.empty());
}

TEST_CASE("KPROF_COUNTER_FILE takes precedence over the env spec",
          "[config]") {
  clear_env();
  std::string const path =
      write_temp_csv("fromfile,PERF_TYPE_HARDWARE,PERF_COUNT_HW_INSTRUCTIONS\n");
  REQUIRE_FALSE(path.empty());

  ::setenv("KPROF_COUNTER_FILE", path.c_str(), 1);
  ::setenv("KPROF_COUNTER_CONF", "fromenv,H,PERF_COUNT_HW_INSTRUCTIONS", 1);

  kprof::set s;
  measure(s);
  auto r = s.report();
  REQUIRE(r.size() == 1);
  CHECK(r[0].name == "fromfile");

  ::unlink(path.c_str());
  clear_env();
}
