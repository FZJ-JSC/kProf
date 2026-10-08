// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include <kprof/kprof.hpp>

#include <string>

namespace kprof {

std::string greet(std::string const& name)
{
  return "hello " + name;
}

} // namespace kprof
