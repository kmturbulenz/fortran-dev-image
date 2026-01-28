#!/bin/bash
# Fetch and build LLVM from Github
set -o errexit
set -o pipefail

LLVM_ROOT_DIR="/opt/llvm"

mkdir -p $LLVM_ROOT_DIR/install
cd $LLVM_ROOT_DIR

TARGETS_TO_BUILD=""
if [[ "${BUILD_ARCH}" == "x86_64" ]]; then
    TARGETS_TO_BUILD="X86"
elif [[ "${BUILD_ARCH}" == "aarch64" ]]; then
    TARGETS_TO_BUILD="AArch64"
else
    echo "Unsupported BUILD_ARCH: ${BUILD_ARCH}"
    exit 1
fi

git clone --depth 1 https://github.com/llvm/llvm-project.git
cd llvm-project
mkdir build
cd build
cmake -GNinja \
    -DCMAKE_BUILD_TYPE="Release" \
    -DCMAKE_INSTALL_PREFIX="$LLVM_ROOT_DIR/install" \
    -DLLVM_ENABLE_PROJECTS="clang;lld;flang" \
    -DLLVM_ENABLE_RUNTIMES="compiler-rt;openmp;flang-rt" \
    -DLLVM_TARGETS_TO_BUILD="${TARGETS_TO_BUILD}" \
    -DLLVM_ENABLE_RTTI="ON" \
    ../llvm 2>&1 | tee cmake.log
ninja -j 2 install 2>&1 | tee ninja.log

# To reduce the size of the image, only the installed files are kept, the
# checked out and compiled sources are deleted.
cd $LLVM_ROOT_DIR
rm -rf llvm-project
