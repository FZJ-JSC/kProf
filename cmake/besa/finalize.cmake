# SPDX-FileCopyrightText: 2026 BESA developers
# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0
include_guard(GLOBAL)

function(_besa_project_finalize)
  _besa_codegen_finalize()
  _besa_manifest_finalize()
  if(COMMAND _besa_cpdocs_finalize)
    _besa_cpdocs_finalize()
  endif()
  _besa_devtools_finalize()
  _besa_package_finalize()
endfunction()
