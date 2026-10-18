# SPDX-FileCopyrightText: 2026 kprof developers
# SPDX-License-Identifier: Apache-2.0
FROM rockylinux/rockylinux:10

# Reuse the same bootstrap logic that desktop and GitHub Actions execute.
# Copy only the stdlib bootstrap and its declarative configuration.
WORKDIR /opt/kprof/bootstrap
COPY dev/etc/toolchains.toml dev/etc/toolchains.toml
COPY dev/src/kprof_dev/toolchains.py dev/src/kprof_dev/toolchains.py
RUN KPROF_BUILD_BOOTSTRAP_IMAGE=1 python3 dev/src/kprof_dev/toolchains.py --backend native bootstrap \
 && touch /opt/kprof/.bootstrap-ready \
 && /opt/kprof/spack-src/bin/spack --version

ENV SPACK_ROOT=/opt/kprof/spack-src \
    SPACK_DISABLE_LOCAL_CONFIG=1 \
    PATH=/opt/kprof/spack-src/bin:${PATH}
WORKDIR /workspace
