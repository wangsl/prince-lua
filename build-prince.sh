#!/bin/bash

# $Id: build-nyu.sh 38 2013-06-19 19:12:11Z wangsl2001@gmail.com $

#export BUILD_WRAPPER_SCRIPT=
#export SPECIAL_RULES_FUNCTION=

#export SOURCE_CODE_LIST_WITH_INTEL_COMPILERS=
#export SOURCE_CODE_LIST_WITH_GNU_COMPILERS=
#export REGULAR_EXPRESSION_LIST_FOR_SOURCE_CODE_WITH_INTEL_COMPILERS=
#export REGULAR_EXPRESSION_LIST_FOR_SOURCE_CODE_WITH_GNU_COMPILERS=
#export INVALID_FLAGS_FOR_INTEL_COMPILERS=
#export INVALID_FLAGS_FOR_GNU_COMPILERS=
#export OPTIMIZATION_FLAGS=
#export OPTIMIZATION_FLAGS_FOR_INTEL_COMPILERS=
#export OPTIMIZATION_FLAGS_FOR_INTEL_FORTRAN_COMPILERS=
#export OPTIMIZATION_FLAGS_FOR_GNU_COMPILERS=
#export OPTIMIZATION_FLAGS_FOR_GNU_FORTRAN_COMPILERS=
#export INCLUDE_FLAGS=
#export INCLUDE_FLAGS_FOR_INTEL_COMPILERS=
#export INCLUDE_FLAGS_FOR_INTEL_FORTRAN_COMPILERS=
#export INCLUDE_FLAGS_FOR_GNU_COMPILERS=
#export INCLUDE_FLAGS_FOR_GNU_FORTRAN_COMPILERS=
#export LINK_FLAGS=
#export LINK_FLAGS_FOR_INTEL_COMPILERS="
#export LINK_FLAGS_FOR_GNU_COMPILERS="-fopenmp"
#export EXTRA_OBJECT_FILE_AND_LIBRARY_LIST=
#export STRING_MACROS=
#export FUNCTION_MACROS=
#export INTEL_MPI_BIN_PATH=
#export GNU_MPI_BIN_PATH=
#export DEFAULT_COMPILER="INTEL"
#export NO_ECHO_FLAGS=
#export REGULAR_EXPRESSIONS_FOR_NO_ECHO=
#export STRING_PREPEND_TO_ECHO=
#export DEBUG_LOG_FILE=tmp.log

#export CC=icc
#export CFLAGS=
#export LDFLAGS="-shared-intel $CFLAGS"
#export LIBS=
#export CPPFLAGS=
#export CPP="icc -E"
#export CCAS=
#export CCASFLAGS=
#export CXX=icpc
#export CXXFLAGS=
#export CXXCPP="icpc -E"
#export F77=ifort
#export FFLAGS="$CFLAGS"

#grep "module load" build-caffe.sh | grep -v "#grep" | awk '{printf "%s(\"%s\")\n", $2, $3}'

set -e

alias die='_error_exit_ "Error in file $0 at line $LINENO\n"'

function special_rules()
{
    return
    
    if [ "$COMPILER_NAME" == "nvcc" ]; then
	export EXTRA_LINK_FLAGS=
        export DEFAULT_COMPILER="GNU"
    fi

    local arg=
    for arg in $*; do
	echo $arg
    done
}

function main() 
{
    export LMOD_DISABLE_SAME_NAME_AUTOSWAP=yes
    module use /share/apps/modulefiles
    module purge
    export CPATH=
    export LD_LIBRARY_PATH=
    #module load intel/17.0.1

    export SLURM_INC=/opt/slurm/include
    export SLURM_LIB=/opt/slurm/lib64

    export LD_LIBRARY_PATH=$SLURM_LIB

    export MY_INTEL_PATH=~wang/bin/intel

    #export NVCC_PATH=$MY_INTEL_PATH/cuda/bin
    
    local util=$MY_INTEL_PATH/util.sh
    if [ -e $util ]; then
	source $util
    fi
    
    export SPECIAL_RULES_FUNCTION=special_rules
    if [ "$SPECIAL_RULES_FUNCTION" != "" ]; then
	export BUILD_WRAPPER_SCRIPT=$(readlink -e $0)
    fi
    
    export GNU_BIN_PATH=$(dirname $(which gcc))
    #export INTEL_BIN_PATH=$(dirname $(which icc))
    #export INTEL_MPI_BIN_PATH=$(dirname $(which mpicc))
    #export NVCC_BIN_PATH=$(dirname $(which nvcc))
    
    export INVALID_FLAGS_FOR_GNU_COMPILERS="-O -O0 -O1 -O2 -O3 -g -g0"
    export OPTIMIZATION_FLAGS_FOR_GNU_COMPILERS="-fPIC -fopenmp -mavx -mno-avx2"
    
    export INVALID_FLAGS_FOR_INTEL_COMPILERS="-O -O0 -O1 -O2 -O3 -g -g0 -lm -xhost -fast"

    export OPTIMIZATION_FLAGS_FOR_INTEL_COMPILERS="-fPIC -unroll -ip -axCORE-AVX2 -qopenmp -qopt-report-stdout -qopt-report-phase=openmp"
    
    export OPTIMIZATION_FLAGS_FOR_INTEL_FORTRAN_COMPILERS="-fPIC -unroll -ip -axCORE-AVX2 -qopenmp -qopt-report-phase=openmp"

    #export INVALID_FLAGS_FOR_NVCC_COMPILERS="-O0 -O1 -O2 -O3 -O"
    #export OPTIMIZATION_FLAGS_FOR_NVCC_COMPILERS="-Wno-deprecated-gpu-targets"
    
    export OPTIMIZATION_FLAGS="-O3"
    
    export CPPFLAGS=$(for inc in $(env -u INTEL_INC -u MKL_INC | grep _INC= | cut -d= -f2); do echo '-I'$inc; done | xargs)
    export LDFLAGS=$(for lib in $(env | grep _LIB= | cut -d= -f2); do echo '-L'$lib; done | xargs)

    prepend_to_env_variable INCLUDE_FLAGS "$CPPFLAGS"
    prepend_to_env_variable LINK_FLAGS "$LDFLAGS"
    
    export INCLUDE_FLAGS_FOR_INTEL_COMPILERS="-I$INTEL_INC -I$MKL_INC"
    
    export LINK_FLAGS_FOR_INTEL_COMPILERS="-shared-intel"
    export EXTRA_LINK_FLAGS="$(LD_LIBRARY_PATH_to_rpath)"
    
    if [ "$DEBUG_LOG_FILE" != "" ]; then
	rm -rf $DEBUG_LOG_FILE
    fi
    
    export LD_RUN_PATH=$LD_LIBRARY_PATH
    
    local prefix=$(pwd)
    if [ "$prefix" == "" ]; then
	local dir=$(readlink -e $(dirname $0))
	dir="$dir/local"
	if [ -d $dir ]; then prefix=$dir; fi
    fi
    if [ "$prefix" == "" ]; then
        die "$0: no prefix defined"
    fi

    export PATH=.:$MY_INTEL_PATH:$PATH

    export DEFAULT_COMPILER="GNU"

    icc -shared -o time.so time.c -llua #-lrt
    
    exit
    
    local args=$*
    local arg=
    for arg in $args; do
	
	case $arg in
	    
	    configure|conf)
		echo " Run configuration ..."
		export PATH=.:$MY_INTEL_PATH:$PATH
		
		if [ "$DEFAULT_COMPILER" != "GNU" ]; then
		    export CC=icc
                    export CXX=icpc
                    export FC=ifort
		    export F77=ifort
		fi
		
		./configure --build=x86_64-centos-linux \
			    --prefix=$prefix
		;;
	    
	    cmake)
		module load cmake/intel/3.7.1
		export PATH=.:$MY_INTEL_PATH:$PATH

		export CMAKE_INCLUDE_PATH=$(env | grep _INC= | cut -d= -f2 | xargs | sed -e 's/ /:/g')
		export CMAKE_LIBRARY_PATH=$(env | grep _LIB= | cut -d= -f2 | xargs | sed -e 's/ /:/g')
		
                export CC=icc
                export CXX=icpc
		cmake \
		    -DCMAKE_BUILD_TYPE=release \
                    -DBUILD_SHARED_LIBS::BOOL=ON \
                    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
                    -DCMAKE_SKIP_RPATH:BOOL=ON \
		    -DCMAKE_INSTALL_PREFIX:PATH=$prefix \
		    ../breakdancer
                ;;
	    
	    make)
		export PATH=.:$MY_INTEL_PATH:$PATH
		echo " Run make"
		eval "$args" 
		exit
		;;

	    a2so)
		export PATH=.:$HOME/bin/intel:$PATH
		cd $SUITESPARSE_LIB
		icc -shared -o libsuitesparse.so  \
		    -Wl,--whole-archive \
		    libamd.a \
		    -Wl,--no-whole-archive \
		    -L$MKL_ROOT/lib/intel64 -lmkl_intel_lp64 -lmkl_core -lmkl_intel_thread -lpthread -lrt
		exit
		;;
	    
	    *)
		die " Usage: $0 <argument>: configure make"
		;;
	esac

	args=$(eval "echo $args | sed -e 's/$arg //'")
    done
}

## do the main work here
## do not modify the follwoing part, we just need to modify the main function

if [ "$TO_SOURCE_BUILD_WRAPPER_SCRIPT" == "" ]; then
    main "$*"
    exit
else
    unset -f main
fi

## do not add anything after this line
