# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
if(NOT DEFINED CLANG_FORMAT OR NOT DEFINED SOURCE_DIR)
  message(FATAL_ERROR "clang-format check requires CLANG_FORMAT and SOURCE_DIR")
endif()

set(_extensions .c .h .cc .cpp .cxx .hh .hpp .hxx .cu .cuh .cuhpp .m .mm .proto .json)
file(GLOB_RECURSE _candidates LIST_DIRECTORIES FALSE "${SOURCE_DIR}/*")
set(_failed)
foreach(_file IN LISTS _candidates)
  # Match excluded directories relative to the source tree so that a checkout which itself lives
  # below a directory named build/ is still checked.
  file(RELATIVE_PATH _relative "${SOURCE_DIR}" "${_file}")
  if(_relative MATCHES "(^|/)(build|\\.git|\\.venv)/")
    continue()
  endif()
  get_filename_component(_extension "${_file}" LAST_EXT)
  if(NOT "${_extension}" IN_LIST _extensions)
    continue()
  endif()
  execute_process(
    COMMAND "${CLANG_FORMAT}" --dry-run -Werror --style=file "${_file}"
    RESULT_VARIABLE _result
    OUTPUT_QUIET
    ERROR_QUIET
  )
  if(NOT _result EQUAL 0)
    list(APPEND _failed "${_file}")
  endif()
endforeach()
if(_failed)
  string(REPLACE ";" "\n  " _failed_text "${_failed}")
  message(FATAL_ERROR "clang-format failed for:\n  ${_failed_text}")
endif()
