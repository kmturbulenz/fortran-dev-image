#!/bin/bash
# This script require environment variable HDF5_VER to be set

set -o errexit
set -o pipefail

HDF5_URL="https://github.com/HDFGroup/hdf5/releases/download/hdf5_${HDF5_VER//-/.}/hdf5-${HDF5_VER}.tar.gz"
HDF5_ROOT_DIR="/opt/hdf5/${HDF5_VER}"

mkdir -p $HDF5_ROOT_DIR
cd $HDF5_ROOT_DIR

wget --no-verbose $HDF5_URL
tar -xf hdf5-$HDF5_VER.tar.gz
rm hdf5-$HDF5_VER.tar.gz

mv hdf5-$HDF5_VER source

if [ -z "$NAG_ROOT" ]; then
    # For all Fortran compilers except NAG
    mkdir build
    cd build
    cmake \
        -GNinja \
        -DCMAKE_INSTALL_PREFIX=$HDF5_ROOT_DIR/install \
        -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DBUILD_TESTING=OFF \
        -DONLY_SHARED_LIBS=ON \
        -DHDF5_BUILD_FORTRAN=ON \
        -DHDF5_ENABLE_Z_LIB_SUPPORT=OFF \
        -DHDF5_ENABLE_SZIP_SUPPORT=OFF \
        -DHDF5_ENABLE_PARALLEL=ON \
        -DHDF5_ENABLE_TRACE=ON \
        -DHDF5_BUILD_EXAMPLES=OFF \
        -DHDF5_BUILD_HL_LIB=OFF \
        ../source 2>&1 | tee cmake.log
    ninja install 2>&1 | tee ninja.log
else
    # For NAG Fortran compiler
    cd source
    FC="mpifort" CC="mpicc" ./configure \
        --enable-fortran \
        --enable-parallel \
        --disable-tests \
        --disable-shared \
        --enable-static \
        --with-pic \
        --prefix=$HDF5_ROOT_DIR/install 2>&1 | tee configure.log
    make -j install 2>&1 | tee make.log
fi

