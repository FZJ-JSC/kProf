# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
add_library(besa.asan INTERFACE)
add_library(besa::asan ALIAS besa.asan)
target_compile_options(
  besa.asan INTERFACE
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang>:-fsanitize=address;-fno-sanitize-recover=address;-fno-omit-frame-pointer;-fno-optimize-sibling-calls;-fsanitize-address-use-after-scope>
  $<$<COMPILE_LANG_AND_ID:CXX,GNU,Clang>:-fsanitize=address;-fno-sanitize-recover=address;-fno-omit-frame-pointer;-fno-optimize-sibling-calls;-fsanitize-address-use-after-scope>
)
target_link_options(
  besa.asan INTERFACE
  $<$<LINK_LANG_AND_ID:C,GNU,Clang>:-fsanitize=address;-fno-sanitize-recover=address>
  $<$<LINK_LANG_AND_ID:CXX,GNU,Clang>:-fsanitize=address;-fno-sanitize-recover=address>
)
