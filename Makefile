SHELL := /bin/bash

STACKFS_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WORKSPACE_ROOT ?= $(abspath $(STACKFS_ROOT)/..)
FIG9_LIBFUSE_PREFIX ?= $(STACKFS_ROOT)/.fig9-build/libfuse-prefix
FIG9_FUSE_PC_DIR := $(FIG9_LIBFUSE_PREFIX)/lib/pkgconfig
FIG9_FUSE_PC := $(FIG9_FUSE_PC_DIR)/fuse3.pc
DEFAULT_EXTFUSE_REPO_PATH := $(WORKSPACE_ROOT)/ExtFUSE_Code/extfuse

CC ?= gcc
PKG_CONFIG ?= pkg-config
BUILD_DIR ?= build

# Prefer a non-empty pkg-config path supplied by the caller.  On the Ubuntu
# 16.04 Fig. 9 host, fall back to the original libfuse under .fig9-build.
ifneq ($(strip $(PKG_CONFIG_PATH)),)
STACKFS_PKG_CONFIG_PATH := $(PKG_CONFIG_PATH)
else ifneq ($(wildcard $(FIG9_FUSE_PC)),)
STACKFS_PKG_CONFIG_PATH := $(FIG9_FUSE_PC_DIR)
else
STACKFS_PKG_CONFIG_PATH :=
endif

# The normal workspace layout keeps the original ExtFUSE tree beside StackFS.
# Preserve an explicit (including explicitly empty) caller override.
ifeq ($(origin EXTFUSE_REPO_PATH),undefined)
ifneq ($(wildcard $(DEFAULT_EXTFUSE_REPO_PATH)/include/ebpf.h),)
EXTFUSE_REPO_PATH := $(DEFAULT_EXTFUSE_REPO_PATH)
else
EXTFUSE_REPO_PATH :=
endif
endif

FUSE_CFLAGS ?= $(shell PKG_CONFIG_PATH="$(STACKFS_PKG_CONFIG_PATH)" \
	$(PKG_CONFIG) --cflags fuse3 2>/dev/null)
FUSE_LIBS ?= $(shell PKG_CONFIG_PATH="$(STACKFS_PKG_CONFIG_PATH)" \
	$(PKG_CONFIG) --libs fuse3 2>/dev/null)
FUSE_LIBDIR ?= $(shell PKG_CONFIG_PATH="$(STACKFS_PKG_CONFIG_PATH)" \
	$(PKG_CONFIG) --variable=libdir fuse3 2>/dev/null)
ifneq ($(strip $(FUSE_LIBDIR)),)
FUSE_RPATH := -Wl,-rpath,$(FUSE_LIBDIR)
else
FUSE_RPATH :=
endif
EXTRA_LDFLAGS ?=

CFLAGS ?= -O2 -g
CFLAGS += -D_FILE_OFFSET_BITS=64 -Wall -Wextra

STACKFS_OPT := $(BUILD_DIR)/StackFS_opt
STACKFS_MDOPT := $(BUILD_DIR)/StackFS_mdopt
STACKFS_COMMON_CFLAGS := -DUSE_SPLICE=1 $(FUSE_CFLAGS)
STACKFS_EXTFUSE_CFLAGS := \
	-I$(EXTFUSE_REPO_PATH)/include \
	-I$(EXTFUSE_REPO_PATH)
STACKFS_EXTFUSE_LIBS := -L$(EXTFUSE_REPO_PATH) -lextfuse
STACKFS_EXTFUSE_RPATH := -Wl,-rpath,$(EXTFUSE_REPO_PATH)

.PHONY: all opt mdopt check check-fuse clean

all: opt mdopt

opt: $(STACKFS_OPT)

mdopt: check $(STACKFS_MDOPT)

check-fuse:
	@PKG_CONFIG_PATH="$(STACKFS_PKG_CONFIG_PATH)" \
		$(PKG_CONFIG) --exists fuse3 || { \
		echo "ERROR: pkg-config cannot find fuse3" >&2; \
		echo "Checked PKG_CONFIG_PATH=$(STACKFS_PKG_CONFIG_PATH)" >&2; \
		echo "Build the original Fig. 9 userspace first, or set PKG_CONFIG_PATH to the directory containing fuse3.pc" >&2; \
		exit 1; \
	}

check: check-fuse
	@test -n "$(EXTFUSE_REPO_PATH)" || { \
		echo "ERROR: EXTFUSE_REPO_PATH is not set" >&2; exit 1; }
	@test -r "$(EXTFUSE_REPO_PATH)/include/ebpf.h" || { \
		echo "ERROR: missing $(EXTFUSE_REPO_PATH)/include/ebpf.h" >&2; exit 1; }
	@test -r "$(EXTFUSE_REPO_PATH)/libextfuse.so" || { \
		echo "ERROR: missing $(EXTFUSE_REPO_PATH)/libextfuse.so" >&2; exit 1; }

$(BUILD_DIR):
	mkdir -p "$@"

# Use '-DUSE_SPLICE=0' for default fuse (no optimizations)
# Use '-DUSE_SPLICE=1' for optimized fuse
# Use '-DCACHE_ENTRY_ATTR' FUSE entry/attr caching enabled
# Use '-DENABLE_EXTFUSE' to enable ExtFUSE
# Use '-DENABLE_EXTFUSE_LOOKUP' to cache lookup replies in the kernel with ExtFUSE
# Use '-DENABLE_EXTFUSE_ATTR' to cache attr replies in the kernel with ExtFUSE

# FUSEOpt baseline: the same StackFS implementation without ExtFUSE.
$(STACKFS_OPT): StackFS_LL.c StackFS_LL.h | check-fuse $(BUILD_DIR)
	$(CC) $(CFLAGS) $(STACKFS_COMMON_CFLAGS) \
		$< $(FUSE_LIBS) $(FUSE_RPATH) $(EXTRA_LDFLAGS) -pthread -o $@

# ExtFUSE MDOpt: LOOKUP and GETATTR replies are cached in the kernel.
$(STACKFS_MDOPT): StackFS_LL.c StackFS_LL.h attr.c attr.h lookup.c lookup.h \
		| check $(BUILD_DIR)
	$(CC) $(CFLAGS) \
		-DUSE_SPLICE=1 \
		-DENABLE_EXTFUSE_LOOKUP \
		-DENABLE_EXTFUSE_ATTR \
		-DENABLE_EXTFUSE \
		$(FUSE_CFLAGS) $(STACKFS_EXTFUSE_CFLAGS) \
		StackFS_LL.c attr.c lookup.c \
		$(FUSE_LIBS) $(STACKFS_EXTFUSE_LIBS) \
		$(FUSE_RPATH) $(STACKFS_EXTFUSE_RPATH) $(EXTRA_LDFLAGS) \
		-pthread -o $@

clean:
	$(RM) -- "$(STACKFS_OPT)" "$(STACKFS_MDOPT)"
	@rmdir --ignore-fail-on-non-empty -- "$(BUILD_DIR)" 2>/dev/null || true
