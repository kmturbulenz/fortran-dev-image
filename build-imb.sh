#!/bin/bash
# Fetch and build Intel MPI benchmarks
# This script require environment variable IMB_VER to be set
set -o errexit
set -o pipefail

IMB_ROOT_DIR="/opt/imb"
IMB_BIN_DIR="/opt/imb/bin"

IMP_URL="https://github.com/intel/mpi-benchmarks/archive/refs/tags/IMB-v${IMB_VER}.tar.gz"

mkdir -p $IMB_ROOT_DIR/licenses
mkdir -p $IMB_BIN_DIR
cd $IMB_ROOT_DIR

wget --no-verbose $IMP_URL
tar -xf IMB-v${IMB_VER}.tar.gz
rm IMB-v${IMB_VER}.tar.gz

cd mpi-benchmarks-IMB-v${IMB_VER}
cp license/license.txt $IMB_ROOT_DIR/licenses/LICENSE-IMB.txt

cd src_c
make
cp IMB-EXT $IMB_BIN_DIR
cp IMB-IO $IMB_BIN_DIR
cp IMB-MPI1 $IMB_BIN_DIR
cp IMB-NBC $IMB_BIN_DIR
cp IMB-RMA $IMB_BIN_DIR

cd P2P
make
cp IMB-P2P $IMB_BIN_DIR
