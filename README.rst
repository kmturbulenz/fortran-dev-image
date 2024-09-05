###############################
Fortran compilation tools image
###############################

This image contains recent versions of compilers, MPI and HDF5 libraries along
with basic build tools (CMake, Ninja). These images can then be used to compile
Fortran applications that depend on MPI and HDF5.

The main purpose is to serve the
`MGLET CFD<https://github.com/kmturbulenz/mglet-base>`_ code with
images it can use in its building and testing framework,
but it can of be used for other Fortran applications as well.

Three images for different workflows are defined:

1. ``intel-impi-image``: Intel Compilers and Intel MPI
2. ``gnu-openmpi-image``: GNU Compilers and OpenMPI
3. ``llvm-mpich-image``: LLVM Compilers (clang, clang++, flang-new) and MPICH
4. ``nag-mpich-image``: NAG Fortran compler (nagfor), GNU C and C++ compilers
   (gcc, g++) and MPICH

The ``gnu-openmpi-image`` and ``llvm-mpich-image`` are build with Github
Actions and are published at the Github container registry. The
``intel-impi-image`` and ``nag-mpich-image`` are should be built locally due
to license restrictions.

If you want to build the images yourself locally, the commands are::

    docker build --target intel-impi-image -t intel-impi-image:latest .
    docker build --target gnu-ompi-image -t gnu-ompi-image:latest .
    docker build --target llvm-mpich-image -t llvm-mpich-image:latest .
    docker build --network host --secret id=nag_license,src=$NAG_KUSARI_FILE --target nag-mpich-image -t nag-mpich-image:latest .

The ``llvm-mpich-image`` build the latest ``main`` branch of the LLVM
compilers ``clang``, ``clang++`` and ``flang-new`` from sources. The build time
of this image is thus very large (hours) compared to the two others. The
reason this builds from source is that the ``flang-new`` receive very frequent
updates and this allows us to have the very latest compilers available.

The ``nag-mpich-image`` image require you to hold a license for the NAG
Fortran compiler for building the image. The path to the license file should be
provided in the environment variable ``NAG_KUSARI_FILE``.
