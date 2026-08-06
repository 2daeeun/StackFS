# Simple StackFS FUSE file system to test ExtFUSE functionality

You need modified [libfuse](https://github.com/extfuse/libfuse/tree/ExtFUSE-1.0) and [extfuse](https://github.com/extfuse/extfuse) library to add ExtFUSE support to StackFS.

The Makefile builds two variants from this same source tree. With the default
`BUILD_DIR=build` they are:

```text
build/StackFS_opt    FUSE Opt baseline
build/StackFS_mdopt  ExtFUSE LOOKUP/GETATTR fast path
```

In the standard workspace layout, the direct build automatically uses
`.fig9-build/libfuse-prefix/lib/pkgconfig/fuse3.pc` when it exists and finds
the sibling `ExtFUSE_Code/extfuse` tree:

```bash
make
```

If that local libfuse prefix has not been prepared yet, build the original
Fig. 9 userspace first on Ubuntu 16.04:

```bash
make -C ../fuse_exp/fig9 TARGET=original all
```

An explicit `PKG_CONFIG_PATH` or `EXTFUSE_REPO_PATH` overrides that automatic
selection. Outside the standard layout, for example:

```bash
PKG_CONFIG_PATH=/path/to/lib/pkgconfig \
make EXTFUSE_REPO_PATH=/path/to/extfuse
```

`StackFS_mdopt` requires an absolute BPF object path at runtime:

```bash
export EXTFUSE_BPF_OBJECT=/home/leedaeeun/Documents/github/ExtFUSE_Code/extfuse/bpf/extfuse.o
```

Both variants record whether `FUSE_CAP_WRITEBACK_CACHE` was negotiated.  In
writeback mode, StackFS opens write-only backing files as `O_RDWR` and removes
`O_APPEND`: the kernel may issue reads to fill partially dirty pages and sends
explicit offsets for append writes.  This is required by workloads such as the
Linux `tinyconfig` merge step.

For the reproducible Ubuntu 16.04/original ExtFUSE build, mount profile, local
libfuse prefix, and result paths, use
`/home/leedaeeun/Documents/github/fuse_exp/fig9/Makefile` and its README.
