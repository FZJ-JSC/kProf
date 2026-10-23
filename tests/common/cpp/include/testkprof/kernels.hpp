// -------------------------------------------------------------------------------------------------
// SPDX-FileCopyrightText: 2026 kprof developers
// SPDX-License-Identifier: Apache-2.0
// -------------------------------------------------------------------------------------------------

#ifndef TESTKPROF_KERNELS_HPP
#define TESTKPROF_KERNELS_HPP

#include <cstdint>

namespace testkprof::kernels {
/**
 * @brief Performs a synthetic computational workload.
 *
 * Accumulates consecutive integers from zero to `iterations - 1`.
 * Intended for testing and benchmarking code that requires a
 * predictable amount of computation.
 *
 * @param iterations Number of iterations to perform.
 * @return Sum of the accumulated integers, modulo 2^64.
 */
auto accumulate_sequence(std::uint64_t iterations) -> std::uint64_t;
} // namespace testkprof::kernels

#endif // TESTKPROF_KERNELS_HPP
