// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#include <kprof/kprof.hpp>

#include <string>

int main()
{
  return kprof::greet("world") == "hello world" ? 0 : 1;
}
