// -------------------------------------------------------------------------------------------------
// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: 2026 kprof developers
// -------------------------------------------------------------------------------------------------

#ifndef KPROF_DO_NOT_OPTIMIZE_HPP
#define KPROF_DO_NOT_OPTIMIZE_HPP

#if defined(__clang__)
#define KPROF_DO_NOT_OPTIMIZE __attribute__((optnone))
#elif defined(__GNUC__) || defined(__GNUG__)
#define KPROF_DO_NOT_OPTIMIZE __attribute__((optimize(0)))
#else
#define KPROF_DO_NOT_OPTIMIZE
#warning "KPROF_DO_NOT_OPTIMIZE is unsupported by this compiler."
#endif

#endif // KPROF_DO_NOT_OPTIMIZE_HPP
