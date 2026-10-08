# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
add_library(besa.lsan INTERFACE)
add_library(besa::lsan ALIAS besa.lsan)
target_compile_options(
  besa.lsan INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-fsanitize=leak;-fno-omit-frame-pointer>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-fsanitize=leak;-fno-omit-frame-pointer>
)
target_link_options(
  besa.lsan INTERFACE
  $<$<LINK_LANG_AND_ID:C,GNU,Clang>:-fsanitize=leak>
  $<$<LINK_LANG_AND_ID:CXX,GNU,Clang>:-fsanitize=leak>
)
