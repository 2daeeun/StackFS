SHELL := /bin/bash

CC ?= gcc
PKG_CONFIG ?= pkg-config
BUILD_DIR ?= build
EXTFUSE_REPO_PATH ?=
FUSE_CFLAGS ?= $(shell $(PKG_CONFIG) --cflags fuse3)
FUSE_LIBS ?= $(shell $(PKG_CONFIG) --libs fuse3)
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

.PHONY: all opt mdopt check clean

all: opt mdopt

opt: $(STACKFS_OPT)

mdopt: check $(STACKFS_MDOPT)

check:
	@test -n "$(EXTFUSE_REPO_PATH)" || { \
		echo "EXTFUSE_REPO_PATH is not set" >&2; exit 1; }
	@test -r "$(EXTFUSE_REPO_PATH)/include/ebpf.h"
	@test -r "$(EXTFUSE_REPO_PATH)/libextfuse.so"

$(BUILD_DIR):
	mkdir -p "$@"

# Use '-DUSE_SPLICE=0' for default fuse (no optimizations)
# Use '-DUSE_SPLICE=1' for optimized fuse
# Use '-DCACHE_ENTRY_ATTR' FUSE entry/attr caching enabled
# Use '-DENABLE_EXTFUSE' to enable ExtFUSE
# Use '-DENABLE_EXTFUSE_LOOKUP' to cache lookup replies in the kernel with ExtFUSE
# Use '-DENABLE_EXTFUSE_ATTR' to cache attr replies in the kernel with ExtFUSE

# FUSEOpt baseline: the same StackFS implementation without ExtFUSE.
$(STACKFS_OPT): StackFS_LL.c StackFS_LL.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(STACKFS_COMMON_CFLAGS) \
		$< $(FUSE_LIBS) $(EXTRA_LDFLAGS) -pthread -o $@

# ExtFUSE MDOpt: LOOKUP and GETATTR replies are cached in the kernel.
$(STACKFS_MDOPT): StackFS_LL.c StackFS_LL.h attr.c attr.h lookup.c lookup.h \
		| $(BUILD_DIR)
	$(CC) $(CFLAGS) \
		-DUSE_SPLICE=1 \
		-DENABLE_EXTFUSE_LOOKUP \
		-DENABLE_EXTFUSE_ATTR \
		-DENABLE_EXTFUSE \
		$(FUSE_CFLAGS) $(STACKFS_EXTFUSE_CFLAGS) \
		StackFS_LL.c attr.c lookup.c \
		$(FUSE_LIBS) $(STACKFS_EXTFUSE_LIBS) $(EXTRA_LDFLAGS) \
		-pthread -o $@

clean:
	$(RM) -- "$(STACKFS_OPT)" "$(STACKFS_MDOPT)"
	@rmdir --ignore-fail-on-non-empty -- "$(BUILD_DIR)" 2>/dev/null || true
