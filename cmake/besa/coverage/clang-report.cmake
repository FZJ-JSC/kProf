# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
foreach(_required PROFDATA LLVM_COV PROFILE_DIR OUTPUT_DIR TARGET_FILES)
  if(NOT DEFINED ${_required})
    message(FATAL_ERROR "clang coverage report requires ${_required}")
  endif()
endforeach()
file(MAKE_DIRECTORY "${OUTPUT_DIR}")
file(GLOB _profiles "${PROFILE_DIR}/*.profraw")
if(NOT _profiles)
  message(FATAL_ERROR "No Clang coverage profiles were produced in ${PROFILE_DIR}")
endif()
execute_process(
  COMMAND "${PROFDATA}" merge -sparse ${_profiles} -o "${OUTPUT_DIR}/coverage.profdata"
  COMMAND_ERROR_IS_FATAL ANY
)
string(REPLACE "|" ";" _targets "${TARGET_FILES}")
set(_objects)
foreach(_target IN LISTS _targets)
  list(APPEND _objects -object "${_target}")
endforeach()
execute_process(
  COMMAND "${LLVM_COV}" report ${_objects} -instr-profile "${OUTPUT_DIR}/coverage.profdata"
  OUTPUT_FILE "${OUTPUT_DIR}/summary.txt"
  COMMAND_ERROR_IS_FATAL ANY
)
execute_process(
  COMMAND "${LLVM_COV}" export ${_objects} -instr-profile "${OUTPUT_DIR}/coverage.profdata"
  OUTPUT_FILE "${OUTPUT_DIR}/coverage.json"
  COMMAND_ERROR_IS_FATAL ANY
)
execute_process(
  COMMAND "${LLVM_COV}" show ${_objects} -instr-profile "${OUTPUT_DIR}/coverage.profdata"
    -format=html -output-dir "${OUTPUT_DIR}/html"
  COMMAND_ERROR_IS_FATAL ANY
)
