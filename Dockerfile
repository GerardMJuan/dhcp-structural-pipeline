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

# install prerequsites
# - build tools
# - FSL 6.0.0 needs "dc"
# - FSL latest
#
#	  * -E is not suported on ubuntu (rhel only), so we make a quick n dirty
#	    /etc/fsl/fsl.sh 

RUN apt-get update 
RUN apt-get install -y \
	wget g++-5 git cmake unzip bc python python-contextlib2 \
	libtbb-dev libboost-dev zlib1g-dev libxt-dev libexpat1-dev \
	libgstreamer1.0-dev libqt4-dev dc

# install FSL to this prefix ... don't set FSLDIR as an ENV, it'll appear in
# the image we make and break the pipeline script
ENV fsl_prefix=/usr/local/fsl 

COPY . /usr/src/structural-pipeline
RUN cd /usr/src/structural-pipeline \
	&& python fslinstaller.py -V 6.0.1 -q -d $fsl_prefix \
	&& mkdir -p /etc/fsl \
	&& echo "FSLDIR=$fsl_prefix; . \${FSLDIR}/etc/fslconf/fsl.sh; PATH=\${FSLDIR}/bin:\${PATH}; export FSLDIR PATH" > /etc/fsl/fsl.sh 

RUN cd /usr/src/structural-pipeline \
  && NUM_CPUS=${THREADS:-`cat /proc/cpuinfo | grep processor | wc -l`} \
  && echo "Maximum number of build threads = $NUM_CPUS" \
  && ./setup.sh -j $NUM_CPUS

WORKDIR /data
ENTRYPOINT ["/usr/src/structural-pipeline/dhcp-pipeline.sh"]
CMD ["-help"]

