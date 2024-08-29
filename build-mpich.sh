#!/bin/bash
# This script require environment variable MPICH_VER to be set

set -o errexit
set -o pipefail

MPICH_URL="https://github.com/pmodels/mpich/releases/download/v${MPICH_VER}/mpich-${MPICH_VER}.tar.gz"
MPICH_ROOT_DIR="/opt/mpich/${MPICH_VER}"

mkdir -p $MPICH_ROOT_DIR
cd $MPICH_ROOT_DIR

wget --no-verbose $MPICH_URL
tar -xf mpich-${MPICH_VER}.tar.gz
rm mpich-${MPICH_VER}.tar.gz

mv mpich-${MPICH_VER} source
mkdir install
cd source

./configure \
    --prefix=$MPICH_ROOT_DIR/install \
    --with-pic \
    --with-device=ch4:ucx \
    2>&1 | tee configure.log
make -j install 2>&1 | tee make.log

# To reduce the size of the image, only the installed files are kept, the
# checked out and compiled sources are deleted.
cd $MPICH_ROOT_DIR
rm -rf source
