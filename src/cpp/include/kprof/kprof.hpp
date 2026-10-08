// SPDX-FileCopyrightText: 2026 kprof developers
//
// SPDX-License-Identifier: Apache-2.0

#ifndef kprof_HPP
#define kprof_HPP

#include <string>

namespace kprof {

/** Return a greeting for name. */
[[nodiscard]] std::string greet(std::string const& name);

} // namespace kprof

#endif // kprof_HPP
