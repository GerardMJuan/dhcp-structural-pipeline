## Build Docker image for execution of dhcp pipelines within a Docker
## container with all modules and applications available in the image

FROM ubuntu:xenial
MAINTAINER John Cupitt <jcupitt@gmail.com>
LABEL Description="dHCP structural-pipeline" Vendor="BioMedIA"

# Git repository and commit SHA from which this Docker image was built
# (see https://microbadger.com/#/labels)
ARG VCS_REF
LABEL org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-url="https://github.com/biomedia/dhcp-structural-pipeline"

# No. of threads to use for build (--build-arg THREADS=8)
# By default, all available CPUs are used. 
ARG THREADS

# install prerequisites
# - build tools
# - FSL 6.0.1 
#	- needs dc 
#	- needs gcc-4.8 
#		MSM must be compiled against the FSL binary oxon ship, and
#		that is built with g++-4.8. We must build MS with that
#		compiler as well to avoid link errors.
# - VTK etc. need gcc 5
RUN apt-get update --fix-missing
RUN apt-get install -y \
    g++-5 gcc-4.8 g++-4.8 \
    wget git cmake unzip bc python python-contextlib2 \
    libtbb-dev libboost-dev zlib1g-dev libxt-dev libexpat1-dev \
    libgstreamer1.0-dev libqt4-dev dc 

# install FSL to this prefix ... don't set FSLDIR as an ENV, it'll appear in
# the image we make and break the pipeline script
ENV fsl_prefix=/usr/local/fsl 

# -E is not suported on ubuntu (rhel only), so we make a quick n dirty
# /etc/fsl/fsl.sh 
COPY . /usr/src/structural-pipeline
RUN cd /usr/src/structural-pipeline \
    && python fslinstaller.py -V 6.0.2 -q -d $fsl_prefix \
    && mkdir -p /etc/fsl \
    && echo "FSLDIR=$fsl_prefix; . \${FSLDIR}/etc/fslconf/fsl.sh; PATH=\${FSLDIR}/bin:\${PATH}; export FSLDIR PATH" > /etc/fsl/fsl.sh 

# set FSL up for build:
# 	- ${FSLDIR}/etc/fslconf/fsl.sh needs to be patched to enable 
# 	  FSLCONFDIR, FSLMACHTYPE, and the associated export
RUN cd $fsl_prefix/etc/fslconf \
    && patch < /usr/src/structural-pipeline/fsl.sh.patch 

# FSLMACHTYPE will be reported as gnu_64-gcc4.8 with gcc-4.8 enabled ... this 
# is not a supported configuration for FSL (see the set of configs in 
# /usr/local/fsl/config) so we take a copy of the closest one (linux_64-gcc4.8)
RUN cp -r $fsl_prefix/config/linux_64-gcc4.8 $fsl_prefix/config/gnu_64-gcc4.8

# FSL6 openblas needs libgfortran.so.3, but this is not linked as
# libgfortran.so ... fix this
RUN cd $fsl_prefix/lib \
    && ln -s libgfortran.so.3 libgfortran.so

# we'll need to be able to flip between compilers
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 50 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.8 50 \
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 50 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 50 

RUN cd /usr/src/structural-pipeline \
    && NUM_CPUS=${THREADS:-`cat /proc/cpuinfo | grep processor | wc -l`} \
    && echo "Maximum number of build threads = $NUM_CPUS" \
    && ./setup.sh -j $NUM_CPUS

WORKDIR /data
ENTRYPOINT ["/usr/src/structural-pipeline/dhcp-pipeline.sh"]
CMD ["-help"]

