// -------------------------------------------------------------------------------------------------
// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 kprof developers
// -------------------------------------------------------------------------------------------------


#include <catch2/catch_test_macros.hpp>
#include <lyra/lyra.hpp>

TEST_CASE("Vendored Lyra is available", "[vendored][lyra]")
{
  bool help = false;
  auto cli = lyra::cli() | lyra::help(help);

  char const* argv[] = {"kprof", "--help"};
  auto result = cli.parse({2, argv});

  REQUIRE(static_cast<bool>(result));
  REQUIRE(help);
}
