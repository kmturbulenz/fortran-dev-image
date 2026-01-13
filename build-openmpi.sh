#!/bin/bash
# This script require environment variable OMPI_VER to be set

set -o errexit
set -o pipefail

OMPI_URL="https://download.open-mpi.org/release/open-mpi/v${OMPI_VER%.*}/openmpi-${OMPI_VER}.tar.bz2"
OMPI_ROOT_DIR="/opt/openmpi/${OMPI_VER}"

mkdir -p $OMPI_ROOT_DIR
cd $OMPI_ROOT_DIR

wget --no-verbose $OMPI_URL
tar -xf openmpi-${OMPI_VER}.tar.bz2
rm openmpi-${OMPI_VER}.tar.bz2

mv openmpi-$OMPI_VER source
mkdir install
cd source
./configure \
    --prefix=$OMPI_ROOT_DIR/install \
    --enable-mca-dso \
    --with-hwloc=internal \
    --with-libevent=internal \
    --with-pmix=internal \
    --disable-oshmem \
    --with-ucx \
    --with-psm2 \
    --with-libfabric \
    --with-tm \
    2>&1 | tee configure.log
make -j install 2>&1 | tee make.log
