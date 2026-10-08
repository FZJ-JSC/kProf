# SPDX-FileCopyrightText: 2026 kprof developers
#
# SPDX-License-Identifier: Apache-2.0

from spack.package import *


class KprofDev(BundlePackage):
    """Development environment for kprof."""

    version("1.0")

    variant("test", default=False, description="Install test dependencies")

    depends_on("besa")
    depends_on("catch2", when="+test")
