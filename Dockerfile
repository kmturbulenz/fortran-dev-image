FROM oraclelinux:8 AS build-base-image
LABEL maintainer="Håkon Strandenes <h.strandenes@km-turbulenz.no>"
LABEL org.opencontainers.image.source="https://github.com/kmturbulenz/fortran-dev-image"
SHELL ["/bin/bash", "-c"]

# Note: "dnf check-update" return code 100 if there are packages to be updated,
# hence the ";" instead of "&&"
#     vim-common for xxd (not obvious)
#
# oracle-epel-release-el8 provides the EPEL repo information. This repo is
# neccesary for patchelf and the_silver_searcher - therefore these
# are installed in a second call to dnf
RUN dnf check-update ; \
    dnf -y update && \
    dnf -y install bash-completion \
                   bc \
                   bzip2 \
                   file \
                   findutils \
                   gdb \
                   git \
                   git-lfs \
                   libcurl-devel \
                   make \
                   oracle-epel-release-el8 \
                   patch \
                   pinentry \
                   procps-ng \
                   python3.12 \
                   python3.12-devel \
                   python3.12-pip \
                   python3.12-pip-wheel \
                   rsync \
                   time \
                   unzip \
                   vim-common \
                   wget \
                   which \
                   zlib-devel \
                   zstd && \
    dnf -y install patchelf the_silver_searcher && \
    dnf clean all && \
    alternatives --set python3 /usr/bin/python3.12

# Install numpy, scipy, matplotlib, h5py for running MGLET testcases
RUN python3 -m pip install --no-cache-dir numpy scipy matplotlib h5py

# Fetch and install updated CMake in /usr/local
ENV CMAKE_VER="3.31.9"
ARG CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-linux-aarch64.tar.gz"
RUN mkdir /tmp/cmake-install && \
    cd /tmp/cmake-install && \
    wget --no-verbose $CMAKE_URL && \
    tar -xf cmake-${CMAKE_VER}-linux-aarch64.tar.gz -C /usr/local --strip-components=1 && \
    cd / && \
    rm -rf /tmp/cmake-install

# Fetch and install updated Ninja-build in /usr/local
ARG NINJA_URL="https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-linux-aarch64.zip"
RUN mkdir /tmp/ninja-install && \
    cd /tmp/ninja-install && \
    wget --no-verbose $NINJA_URL && \
    unzip ninja-linux-aarch64.zip -d /usr/local/bin && \
    cd / && \
    rm -rf /tmp/ninja-install

COPY build-hdf5.sh /opt/
COPY build-imb.sh /opt/

ENV HDF5_VER="2.0.0"
ENV IMB_VER="2021.10"


# ---------------------------------------------------------------------------- #
# Intel oneAPI compilers, Intel MPI image
FROM build-base-image AS intel-impi-image
LABEL description="Intel compilers with Intel MPI and HDF5 image for building Fortran applications"

# Install Intel oneAPI packages (compiler, MPI)
COPY oneAPI.repo /etc/yum.repos.d/
# Cherry-pick packages to minimize image size
#     instead of:
#     dnf -y install intel-basekit intel-hpckit
# Package ref: https://oneapi-src.github.io/oneapi-ci/#linux-yum-dnf
RUN dnf -y install intel-oneapi-compiler-dpcpp-cpp-2025.3 \
                   intel-oneapi-compiler-fortran-2025.3 \
                   intel-oneapi-mpi-devel-2021.17 \
                   gcc gcc-c++ && \
    dnf clean all

# CPU architecture for optimizations and default compiler flags
ENV CC="icx"
ENV CXX="icpx"
ENV FC="ifx"

ENV CPU_ARCH="x86-64-v2"
ENV CFLAGS="-march=${CPU_ARCH}"
ENV CXXFLAGS="-march=${CPU_ARCH}"
ENV FFLAGS="-march=${CPU_ARCH}"
ENV FCFLAGS=$FFLAGS

# Download and build HDF5
RUN source /opt/intel/oneapi/setvars.sh && /opt/build-hdf5.sh
ENV HDF5_ROOT="/opt/hdf5/${HDF5_VER}/install"
ENV PATH="${HDF5_ROOT}/bin:${PATH}"

# Download and build Intel MPI Benchmarks
RUN source /opt/intel/oneapi/setvars.sh && CC=mpiicx /opt/build-imb.sh

# Update bashrc file
RUN echo "source /opt/intel/oneapi/setvars.sh" >> /opt/bashrc


# ---------------------------------------------------------------------------- #
# GNU compilers, OpenMPI image
FROM build-base-image AS gnu-ompi-image
LABEL description="GNU compilers with OpenMPI and HDF5 image for building Fortran applications"

# Install GNU compilers and development files for compiling OpenMPI
# SLES packages: https://scc.suse.com/packages
# SLES 15 SP3 libraries:
#   - ucx: 1.9.0
#   - libpsm2: 11.2.185
#   - libfabric: 1.11.2
# SLES 15 SP6 libraries:
#   - ucx: 1.15.0
#   - libpsm2: 12.0.1
#   - libfabric: 1.20.0
# Aarch64 does not have libpsm2
RUN dnf -y install gcc-toolset-15 gcc-toolset-15-gcc-gfortran gcc-toolset-15-libubsan-devel ucx-devel-1.15.0-2.el8 && \
    dnf -y --enablerepo=ol8_codeready_builder install torque-devel libfabric-devel-1.18.0-1.el8 && \
    dnf clean all

# CPU architecture for optimizations and default compiler flags
ENV CC="gcc"
ENV CXX="g++"
ENV FC="gfortran"

ENV CPU_ARCH="armv8.2-a"
ENV CFLAGS="-march=${CPU_ARCH}"
ENV CXXFLAGS="-march=${CPU_ARCH}"
ENV FFLAGS="-march=${CPU_ARCH}"
ENV FCFLAGS=$FFLAGS

# Download and build OpenMPI
ENV OMPI_VER="5.0.9"
COPY build-openmpi.sh /opt/
RUN source scl_source enable gcc-toolset-15 && /opt/build-openmpi.sh
ENV MPI_HOME="/opt/openmpi/${OMPI_VER}/install"
ENV PATH="${MPI_HOME}/bin:${PATH}"

# Download and build HDF5
RUN source scl_source enable gcc-toolset-15 && /opt/build-hdf5.sh
ENV HDF5_ROOT="/opt/hdf5/${HDF5_VER}/install"
ENV PATH="${HDF5_ROOT}/bin:${PATH}"

# Download and build Intel MPI Benchmarks
RUN source scl_source enable gcc-toolset-15 && CC=mpicc /opt/build-imb.sh

# Update bashrc file
RUN echo "source scl_source enable gcc-toolset-15" >> /opt/bashrc


# ---------------------------------------------------------------------------- #
# LLVM compilers (clang, clang++, flang), MPICH image
FROM build-base-image AS llvm-mpich-image
LABEL description="LLVM compilers with MPICH and HDF5 image for building Fortran applications"

# We do not install UCX - MPICH builds embedded UCX instead.
RUN dnf -y install gcc gcc-c++ && \
    dnf clean all

# Build LLVM compilers (clang, clang++, flang)
COPY build-llvm.sh /opt/
RUN /opt/build-llvm.sh

# CPU architecture for optimizations and default compiler flags
ENV CC="clang"
ENV CXX="clang++"
ENV FC="flang"

ENV CPU_ARCH="x86-64-v2"
ENV CFLAGS="-march=${CPU_ARCH}"
ENV CXXFLAGS="-march=${CPU_ARCH}"
ENV FFLAGS="-march=${CPU_ARCH}"
ENV FCFLAGS=$FFLAGS

ENV LLVM_ROOT="/opt/llvm/install"
ENV PATH="${LLVM_ROOT}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${LLVM_ROOT}/lib:${LLVM_ROOT}/lib/x86_64-unknown-linux-gnu:${LD_LIBRARY_PATH}"

# Download and build MPICH
ENV MPICH_VER="4.3.2"
COPY build-mpich.sh /opt/
RUN /opt/build-mpich.sh
ENV MPI_HOME="/opt/mpich/${MPICH_VER}/install"
ENV PATH="${MPI_HOME}/bin:${PATH}"

# Download and build HDF5
RUN /opt/build-hdf5.sh
ENV HDF5_ROOT="/opt/hdf5/${HDF5_VER}/install"
ENV PATH="${HDF5_ROOT}/bin:${PATH}"

# Download and build Intel MPI Benchmarks
RUN CC=mpicc /opt/build-imb.sh

# Update bashrc file
RUN echo "" >> /opt/bashrc


# ---------------------------------------------------------------------------- #
# NAG Fortran compiler, GNU gcc and g++ compilers, MPICH image
FROM build-base-image AS nag-mpich-image
LABEL description="NAG fortran compilers with GNU companion C/C++ compilers, MPICH and HDF5 image for building Fortran applications"

# We do not install UCX - MPICH builds embedded UCX instead.
RUN dnf -y install gcc gcc-c++ && \
    dnf clean all

# Install NAG compiler
ENV NAG_VER="7242"
COPY install-nag.sh /opt/
RUN /opt/install-nag.sh

# CPU architecture for optimizations and default compiler flags
ENV CC="gcc"
ENV CXX="g++"
ENV FC="nagfor"

ENV NAG_ROOT="/opt/nag"
ENV PATH="${NAG_ROOT}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${NAG_ROOT}/lib/NAG_Fortran:${LD_LIBRARY_PATH}"

ENV CFLAGS="-I$NAG_ROOT/lib/NAG_Fortran"
ENV CPPFLAGS="-I$NAG_ROOT/lib/NAG_Fortran"
ENV CXXFLAGS="-I$NAG_ROOT/lib/NAG_Fortran"

# Download and build MPICH
ENV MPICH_VER="4.3.2"
COPY build-mpich.sh /opt/
RUN --mount=type=secret,id=nag_license NAG_KUSARI_FILE=/run/secrets/nag_license /opt/build-mpich.sh
ENV MPI_HOME="/opt/mpich/${MPICH_VER}/install"
ENV PATH="${MPI_HOME}/bin:${PATH}"

# Download and build HDF5
COPY HDF5-NAG-Disable-threads.patch /opt/
RUN --mount=type=secret,id=nag_license NAG_KUSARI_FILE=/run/secrets/nag_license /opt/build-hdf5.sh
ENV HDF5_ROOT="/opt/hdf5/${HDF5_VER}/install"
ENV PATH="${HDF5_ROOT}/bin:${PATH}"

# Download and build Intel MPI Benchmarks
RUN CC=mpicc /opt/build-imb.sh

# Update bashrc file
RUN echo "" >> /opt/bashrc
