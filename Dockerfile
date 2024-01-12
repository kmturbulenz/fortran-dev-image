FROM oraclelinux:8 AS build-base-image
LABEL maintainer="Håkon Strandenes <h.strandenes@km-turbulenz.no>"
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
                   procps-ng \
                   python3.11 \
                   python3.11-devel \
                   python3.11-pip \
                   python3.11-pip-wheel \
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
    alternatives --set python3 /usr/bin/python3.11

# Fetch and install updated CMake in /usr/local
ENV CMAKE_VER="3.28.1"
ARG CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VER}/cmake-${CMAKE_VER}-linux-x86_64.tar.gz"
RUN mkdir /tmp/cmake-install && \
    cd /tmp/cmake-install && \
    wget --no-verbose $CMAKE_URL && \
    tar -xf cmake-${CMAKE_VER}-linux-x86_64.tar.gz -C /usr/local --strip-components=1 && \
    cd / && \
    rm -rf /tmp/cmake-install

# Fetch and install updated Ninja-build in /usr/local
ARG NINJA_URL="https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip"
RUN mkdir /tmp/ninja-install && \
    cd /tmp/ninja-install && \
    wget --no-verbose $NINJA_URL && \
    unzip ninja-linux.zip -d /usr/local/bin && \
    cd / && \
    rm -rf /tmp/ninja-install

ENV HDF5_VER="1.14.0"
COPY build-hdf5.sh /opt/


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
RUN dnf -y install intel-oneapi-compiler-dpcpp-cpp-2024.0 \
                   intel-oneapi-compiler-fortran-2024.0 \
                   intel-oneapi-mpi-devel-2021.11 \
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

# Update bashrc file
RUN echo "source /opt/intel/oneapi/setvars.sh" >> /opt/bashrc


# ---------------------------------------------------------------------------- #
# GNU compilers, OpenMPI image
FROM build-base-image AS gnu-ompi-image
LABEL description="GNU compilers with OpenMPI and HDF5 image for building Fortran applications"

# Install GNU compilers and development files for compiling OpenMPI
# SLES 15 SP3 libraries:
#   - ucx: 1.9.0
#   - libpsm2: 11.2.185
#   - libfabric: 1.11.2
RUN dnf -y install gcc-toolset-13 gcc-toolset-13-gcc-gfortran ucx-devel-1.9.0-1.el8 && \
    dnf -y --enablerepo=ol8_codeready_builder install libpsm2-devel-11.2.185-1.el8 libfabric-devel-1.11.2-1.el8 && \
    dnf clean all

# CPU architecture for optimizations and default compiler flags
ENV CC="gcc"
ENV CXX="g++"
ENV FC="gfortran"

ENV CPU_ARCH="x86-64-v2"
ENV CFLAGS="-march=${CPU_ARCH}"
ENV CXXFLAGS="-march=${CPU_ARCH}"
ENV FFLAGS="-march=${CPU_ARCH}"
ENV FCFLAGS=$FFLAGS

# Download and build OpenMPI
ENV OMPI_VER="4.1.6"
COPY build-openmpi.sh /opt/
RUN source scl_source enable gcc-toolset-13 && /opt/build-openmpi.sh
ENV MPI_HOME="/opt/openmpi/${OMPI_VER}/install"
ENV PATH="${MPI_HOME}/bin:${PATH}"

# Download and build HDF5
RUN source scl_source enable gcc-toolset-13 && /opt/build-hdf5.sh
ENV HDF5_ROOT="/opt/hdf5/${HDF5_VER}/install"
ENV PATH="${HDF5_ROOT}/bin:${PATH}"

# Update bashrc file
RUN echo "source scl_source enable gcc-toolset-13" >> /opt/bashrc
