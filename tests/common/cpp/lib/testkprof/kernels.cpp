// -------------------------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2026 kprof developers
// SPDX-License-Identifier: Apache-2.0
// -------------------------------------------------------------------------------------------------

#include <kprof/do_not_optimize.hpp>
#include <testkprof/kernels.hpp>

namespace testkprof::kernels {
KPROF_DO_NOT_OPTIMIZE
auto accumulate_sequence(std::uint64_t iterations) -> std::uint64_t
{
  std::uint64_t sum = 0;

  for (std::uint64_t i = 0; i < iterations; ++i)
    sum += i;

  return sum;
}
} // namespace testkprof::kernels
