# --------------------------------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 besa developers
# --------------------------------------------------------------------------------------------------
# Orchestrate project finalization after all targets have been declared.
#
# besa_finalize_options() schedules this internal entry point with CMake DEFER.
# Order matters: integrate generated headers, write the semantic manifest,
# finalize documentation and devtools, then export/install package targets.

include_guard(GLOBAL)

# --------------------------------------------------------------------------------------------------
# Internal implementation
# --------------------------------------------------------------------------------------------------

# Run deferred per-project finalizers in dependency order.
# Must execute after directory/target declarations have completed.
function(_besa_project_finalize)
  _besa_codegen_finalize()
  _besa_manifest_finalize()
  if(COMMAND _besa_cpdocs_finalize)
    _besa_cpdocs_finalize()
  endif()
  _besa_devtools_finalize()
  _besa_package_finalize()
endfunction()
