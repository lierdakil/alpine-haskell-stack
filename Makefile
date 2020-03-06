################################################################################
# Variables
# GHC version to build
TARGET_GHC_VERSION ?= 8.8.3
# Must be one of 'gmp' or 'simple'; used to build GHC with support for either
# 'integer-gmp' (with 'libgmp') or 'integer-simple'
TARGET_GHC_BUILD_TYPE ?= gmp

################################################################################
# https://www.gnu.org/software/make/manual/html_node/Special-Variables.html
# https://ftp.gnu.org/old-gnu/Manuals/make-3.80/html_node/make_17.html
ALPINE_HASKELL_MKFILE_PATH := $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
ALPINE_HASKELL_ROOT_DIR    := $(shell cd $(shell dirname $(ALPINE_HASKELL_MKFILE_PATH)); pwd)

################################################################################
# Targets for building GHC
#
# The intermediate layers of the multi-stage Docker build file are cached so
# that changes to the Dockerfile don't force us to rebuild GHC when developing

DOCKER_BUILD = \
	docker build \
	  --build-arg GHC_BUILD_TYPE=$(TARGET_GHC_BUILD_TYPE) \
	  --build-arg GHC_VERSION=$(TARGET_GHC_VERSION) \
	  --target $(TGT) \
	  --tag alpine-haskell-$(TARGET_GHC_BUILD_TYPE):$(LBL) \
	  --cache-from alpine-haskell-$(TARGET_GHC_BUILD_TYPE):$(TARGET_GHC_VERSION) \
	  --cache-from alpine-haskell-$(TARGET_GHC_BUILD_TYPE):build-tooling \
	  --cache-from alpine-haskell-$(TARGET_GHC_BUILD_TYPE):build-cabal\
	  --cache-from alpine-haskell-$(TARGET_GHC_BUILD_TYPE):build-ghc-$(TARGET_GHC_VERSION) \
	  --cache-from alpine-haskell-$(TARGET_GHC_BUILD_TYPE):base \
	  --file $(ALPINE_HASKELL_ROOT_DIR)/Dockerfile \
	  $(ALPINE_HASKELL_ROOT_DIR)

.PHONY: build
build: image

.PHONY: base
base: TGT = base
base: LBL = base
base:
	$(DOCKER_BUILD)

.PHONY: ghc
ghc: TGT = build-ghc
ghc: LBL = build-ghc-$(TARGET_GHC_VERSION)
ghc: base
	$(DOCKER_BUILD)

.PHONY: tooling
tooling: TGT = build-tooling
tooling: LBL = build-tooling
tooling: base
	$(DOCKER_BUILD)

.PHONY: cabal
cabal: TGT = build-cabal
cabal: LBL = build-cabal
cabal: base
	$(DOCKER_BUILD)

.PHONY: image
image: TGT = image
image: LBL = $(TARGET_GHC_VERSION)
image: base ghc tooling cabal
	$(DOCKER_BUILD)
