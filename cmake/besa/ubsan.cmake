# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
add_library(besa.ubsan INTERFACE)
add_library(besa::ubsan ALIAS besa.ubsan)
target_compile_options(
  besa.ubsan INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-fsanitize=undefined;-fno-sanitize-recover=undefined;-fno-omit-frame-pointer>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-fsanitize=undefined;-fno-sanitize-recover=undefined;-fno-omit-frame-pointer>
)
target_link_options(
  besa.ubsan INTERFACE
  $<$<LINK_LANG_AND_ID:C,GNU,Clang>:-fsanitize=undefined;-fno-sanitize-recover=undefined>
  $<$<LINK_LANG_AND_ID:CXX,GNU,Clang>:-fsanitize=undefined;-fno-sanitize-recover=undefined>
)
