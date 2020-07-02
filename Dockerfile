################################################################################
# Set up environment variables, OS packages, and scripts that are common to the
# build and distribution layers in this Dockerfile
FROM alpine:3.12 AS base

# Must be one of 'gmp' or 'simple'; used to build GHC with support for either
# 'integer-gmp' (with 'libgmp') or 'integer-simple'
ARG GHC_BUILD_TYPE

# Must be a valid GHC version number
ARG GHC_VERSION

# Add ghcup's bin directory to the PATH so that the versions of GHC it builds
# are available in the build layers
ENV GHCUP_INSTALL_BASE_PREFIX=/
ENV PATH=/.ghcup/bin:$PATH

# Install the basic required dependencies to run 'ghcup' and 'stack'
RUN apk upgrade --no-cache &&\
    apk add --no-cache \
        curl \
        gcc \
        git \
        libc-dev \
        xz &&\
    if [ "${GHC_BUILD_TYPE}" = "gmp" ]; then \
        echo "Installing 'libgmp'" &&\
        apk add --no-cache gmp-dev; \
    fi

ENV GHCUP_SHA256="cfdb01dde77121859b5d90b6707238b54e23787fcbb3003e18ab52a5dbfee330  /usr/bin/ghcup"

# Download, verify, and install ghcup
RUN echo "Downloading and installing ghcup" &&\
    cd /tmp &&\
    wget -O /usr/bin/ghcup "https://downloads.haskell.org/~ghcup/x86_64-linux-ghcup" &&\
    if ! echo -n "${GHCUP_SHA256}" | sha256sum -c -; then \
        echo "ghcup checksum failed" >&2 &&\
        exit 1 ;\
    fi ;\
    chmod +x /usr/bin/ghcup

################################################################################
# Intermediate layer that builds GHC
FROM base AS build-ghc

# Carry build args through to this stage
ARG GHC_BUILD_TYPE
ARG GHC_VERSION

RUN echo "Install OS packages necessary to build GHC" &&\
    apk add --no-cache \
        autoconf \
        automake \
        binutils-gold \
        build-base \
        coreutils \
        cpio \
        ghc \
        linux-headers \
        libffi-dev \
        llvm9 \
        musl-dev \
        ncurses-dev \
        perl \
        python3 \
        py3-sphinx \
        zlib-dev

COPY docker/build-gmp.mk /tmp/build-gmp.mk
COPY docker/build-simple.mk /tmp/build-simple.mk
RUN if [ "${GHC_BUILD_TYPE}" = "gmp" ]; then \
        echo "Using 'integer-gmp' build config" &&\
        apk add --no-cache gmp-dev &&\
        mv /tmp/build-gmp.mk /tmp/build.mk && rm /tmp/build-simple.mk; \
    elif [ "${GHC_BUILD_TYPE}" = "simple" ]; then \
        echo "Using 'integer-simple' build config" &&\
        mv /tmp/build-simple.mk /tmp/build.mk && rm tmp/build-gmp.mk; \
    else \
        echo "Invalid argument \[ GHC_BUILD_TYPE=${GHC_BUILD_TYPE} \]" && exit 1; \
fi

RUN echo "Compiling and installing GHC" &&\
    LD=ld.gold \
    SPHINXBUILD=/usr/bin/sphinx-build-3 \
      ghcup -v compile ghc -j $(nproc) -c /tmp/build.mk -v ${GHC_VERSION} -b /usr/bin/ghc &&\
    rm /tmp/build.mk &&\
    echo "Uninstalling GHC bootstrapping compiler" &&\
    apk del ghc &&\
    ghcup set ${GHC_VERSION}

################################################################################
# Intermediate layer that assembles 'stack' tooling
FROM base AS build-tooling

ENV STACK_VERSION=2.3.1
ENV STACK_SHA256="4bae8830b2614dddf3638a6d1a7bbbc3a5a833d05b2128eae37467841ac30e47  stack-${STACK_VERSION}-linux-x86_64-static.tar.gz"

# Download, verify, and install stack
RUN echo "Downloading and installing stack" &&\
    cd /tmp &&\
    wget -P /tmp/ "https://github.com/commercialhaskell/stack/releases/download/v${STACK_VERSION}/stack-${STACK_VERSION}-linux-x86_64-static.tar.gz" &&\
    if ! echo -n "${STACK_SHA256}" | sha256sum -c -; then \
        echo "stack-${STACK_VERSION} checksum failed" >&2 &&\
        exit 1 ;\
    fi ;\
    tar -xvzf /tmp/stack-${STACK_VERSION}-linux-x86_64-static.tar.gz &&\
    cp -L /tmp/stack-${STACK_VERSION}-linux-x86_64-static/stack /usr/bin/stack &&\
    rm /tmp/stack-${STACK_VERSION}-linux-x86_64-static.tar.gz &&\
    rm -rf /tmp/stack-${STACK_VERSION}-linux-x86_64-static

################################################################################
# Build cabal
FROM base AS build-cabal

ENV CABAL_VERSION 3.2.0.0

RUN ghcup install-cabal ${CABAL_VERSION}

################################################################################
# Assemble the final image
FROM base AS image

# Carry build args through to this stage
ARG GHC_BUILD_TYPE
ARG GHC_VERSION

# NOTE: 'stack --docker' needs bash + usermod/groupmod (from shadow)
# cabal needs libffi
RUN apk add --no-cache bash shadow openssh-client tar libffi

COPY --from=build-ghc /.ghcup /.ghcup
COPY --from=build-tooling /usr/bin/stack /usr/bin/stack
COPY --from=build-cabal /.ghcup/bin/cabal /.ghcup/bin/cabal

RUN ghcup set ${GHC_VERSION} &&\
    stack config set system-ghc --global true
