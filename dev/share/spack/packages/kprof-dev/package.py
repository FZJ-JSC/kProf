# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

from spack.package import *


class KprofDev(BundlePackage):
    """Development environment for kprof."""

    version("1.0")

    variant("test", default=False, description="Install test dependencies")

    # These are developer tools, not dependencies of a packaged kprof binary.
    # Run dependencies make them available in the Spack environment view.
    depends_on("cmake@4.3:", type=("build", "run"))
    depends_on("ninja", type=("build", "run"))
    depends_on("catch2@3:", when="+test", type=("link", "run"))
