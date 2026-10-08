# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/internal.cmake")

set(BESA_COVERAGE_OUTDIR "${PROJECT_BINARY_DIR}/coverage" CACHE PATH "Coverage report directory")

add_library(besa.instrumentation.coverage INTERFACE)
add_library(besa::coverage ALIAS besa.instrumentation.coverage)

if(CMAKE_CXX_COMPILER_LOADED AND CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
  set(BESA_COVERAGE_COMPILER clang CACHE INTERNAL "BESA coverage implementation")
  target_compile_options(
    besa.instrumentation.coverage INTERFACE
    $<$<COMPILE_LANGUAGE:C>:-fprofile-instr-generate;-fcoverage-mapping>
    $<$<COMPILE_LANGUAGE:CXX>:-fprofile-instr-generate;-fcoverage-mapping>
  )
  target_link_options(besa.instrumentation.coverage INTERFACE -fprofile-instr-generate -fcoverage-mapping)
  find_program(BESA_LLVM_PROFDATA llvm-profdata REQUIRED)
  find_program(BESA_LLVM_COV llvm-cov REQUIRED)
elseif(
  (CMAKE_CXX_COMPILER_LOADED AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  OR (CMAKE_C_COMPILER_LOADED AND CMAKE_C_COMPILER_ID STREQUAL "GNU")
)
  set(BESA_COVERAGE_COMPILER gcc CACHE INTERNAL "BESA coverage implementation")
  target_compile_options(
    besa.instrumentation.coverage INTERFACE
    $<$<COMPILE_LANGUAGE:C>:--coverage;-fprofile-abs-path>
    $<$<COMPILE_LANGUAGE:CXX>:--coverage;-fprofile-abs-path>
  )
  target_link_options(besa.instrumentation.coverage INTERFACE --coverage)
  find_program(BESA_GCOVR gcovr REQUIRED)
else()
  message(FATAL_ERROR "BESA coverage currently supports GNU and Clang C/C++ compilers")
endif()

function(_besa_coverage_register_test GROUP_NAME TEST_NAME TARGET_NAME)
  if("${GROUP_NAME}" STREQUAL "")
    set(GROUP_NAME default)
  endif()
  _besa_normalize_name("${GROUP_NAME}" _group_key)

  get_property(_groups GLOBAL PROPERTY BESA_COVERAGE_GROUPS)
  if(NOT "${GROUP_NAME}" IN_LIST _groups)
    set_property(GLOBAL APPEND PROPERTY BESA_COVERAGE_GROUPS "${GROUP_NAME}")
  endif()
  set_property(GLOBAL APPEND PROPERTY "BESA_COVERAGE_${_group_key}_TESTS" "${TEST_NAME}")
  set_property(GLOBAL APPEND PROPERTY "BESA_COVERAGE_${_group_key}_TARGETS" "${TARGET_NAME}")

  if(BESA_COVERAGE_COMPILER STREQUAL "clang")
    file(MAKE_DIRECTORY "${BESA_COVERAGE_OUTDIR}/${GROUP_NAME}/prof")
    set_tests_properties(
      "${TEST_NAME}" PROPERTIES
      ENVIRONMENT "LLVM_PROFILE_FILE=${BESA_COVERAGE_OUTDIR}/${GROUP_NAME}/prof/${TEST_NAME}.profraw"
    )
  endif()
endfunction()

function(_besa_coverage_finalize)
  get_property(_groups GLOBAL PROPERTY BESA_COVERAGE_GROUPS)
  if(NOT _groups)
    return()
  endif()

  add_custom_target(besa.coverage)
  set(_report_tests)

  foreach(_group IN LISTS _groups)
    _besa_normalize_name("${_group}" _group_key)
    get_property(_tests GLOBAL PROPERTY "BESA_COVERAGE_${_group_key}_TESTS")
    get_property(_targets GLOBAL PROPERTY "BESA_COVERAGE_${_group_key}_TARGETS")
    list(REMOVE_DUPLICATES _targets)
    set(_outdir "${BESA_COVERAGE_OUTDIR}/${_group}")

    if(BESA_COVERAGE_COMPILER STREQUAL "gcc")
      add_custom_target(
        "besa.coverage.${_group}"
        COMMAND "${CMAKE_COMMAND}" -E make_directory "${_outdir}"
        COMMAND "${BESA_GCOVR}" --root "${PROJECT_SOURCE_DIR}" "${PROJECT_BINARY_DIR}"
          --txt "${_outdir}/summary.txt"
          --json-summary "${_outdir}/summary.json"
          --cobertura-pretty --cobertura "${_outdir}/cobertura.xml"
          --html-details "${_outdir}/index.html"
        WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
        VERBATIM
      )
    else()
      set(_target_files)
      foreach(_target IN LISTS _targets)
        list(APPEND _target_files "$<TARGET_FILE:${_target}>")
      endforeach()
      string(REPLACE ";" "|" _encoded_targets "${_target_files}")
      add_custom_target(
        "besa.coverage.${_group}"
        COMMAND "${CMAKE_COMMAND}"
          "-DPROFDATA=${BESA_LLVM_PROFDATA}"
          "-DLLVM_COV=${BESA_LLVM_COV}"
          "-DPROFILE_DIR=${_outdir}/prof"
          "-DOUTPUT_DIR=${_outdir}"
          "-DTARGET_FILES=${_encoded_targets}"
          -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/coverage/clang-report.cmake"
        DEPENDS ${_targets}
        WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
        VERBATIM
      )
    endif()

    add_dependencies(besa.coverage "besa.coverage.${_group}")
    set(_report_test "instrumentation.coverage.${_group}.t")
    add_test(
      NAME "${_report_test}"
      COMMAND "${CMAKE_COMMAND}" --build "${PROJECT_BINARY_DIR}"
        --target "besa.coverage.${_group}" --config $<CONFIG>
    )
    set_tests_properties(
      "${_report_test}" PROPERTIES DEPENDS "${_tests}" LABELS "instrumentation;coverage"
    )
    list(APPEND _report_tests "${_report_test}")
  endforeach()

  add_test(
    NAME instrumentation.coverage.t
    COMMAND "${CMAKE_COMMAND}" --build "${PROJECT_BINARY_DIR}" --target besa.coverage --config $<CONFIG>
  )
  set_tests_properties(
    instrumentation.coverage.t PROPERTIES
    DEPENDS "${_report_tests}"
    LABELS "instrumentation;coverage"
  )
endfunction()
