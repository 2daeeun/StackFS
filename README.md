# Simple StackFS FUSE file system to test ExtFUSE functionality

You need modified [libfuse](https://github.com/extfuse/libfuse/tree/ExtFUSE-1.0) and [extfuse](https://github.com/extfuse/extfuse) library to add ExtFUSE support to StackFS.

The Makefile builds two variants from this same source tree. With the default
`BUILD_DIR=build` they are:

```text
build/StackFS_opt    FUSE Opt baseline
build/StackFS_mdopt  ExtFUSE LOOKUP/GETATTR fast path
```

Direct build commands are:

```bash
make opt
make mdopt EXTFUSE_REPO_PATH=/home/leedaeeun/Documents/github/ExtFUSE_Code/extfuse
```

`StackFS_mdopt` requires an absolute BPF object path at runtime:

```bash
export EXTFUSE_BPF_OBJECT=/home/leedaeeun/Documents/github/ExtFUSE_Code/extfuse/bpf/extfuse.o
```

For the reproducible Ubuntu 16.04/original ExtFUSE build, mount profile, local
libfuse prefix, and result paths, use
`/home/leedaeeun/Documents/github/fuse_exp/fig9/Makefile` and its README.
