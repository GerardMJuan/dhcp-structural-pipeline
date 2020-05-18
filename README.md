# dHCP Structural Pipeline 

![pipeline image](structural_pipeline.png)

## This Branch

This branch is a modified version of the pipeline for fetal images. It
works reasonably well, but you may need to tune the brain extraction step,
see below.

Mail from Antonis:

```
The pipeline installs DrawEM for the (neonatal) segmentation.
In order to change the DrawEM to do fetal segmentation you need to do the following from inside the dhcp pipeline folder ($pipelinedir):
# go inside the pipeline dir
cd $pipelinedir
# go inside the DrawEM dir
cd build/MIRTK/Packages/DrawEM/
# switch to the fetal branch
git checkout fetal
# download the fetal atlases
wget https://biomedic.doc.ic.ac.uk/brain-development/downloads/dHCP/fetal-atlas-DrawEM.zip
# extract the atlases
unzip fetal-atlas-DrawEM.zip -d atlases/

For the rest of the email I will consider:
DRAWEMDIR=$pipelinedir/build/MIRTK/Packages/DrawEM


Then you can use the fetal segmentation pipeline to segment a subject:
$DRAWEMDIR/pipelines/fetal-pipeline.sh $T2 $age -t $cores -d $output
where:
$T2 the T2 image,
$age the age of the subject in weeks
$cores the number of CPU cores to use
$output the output directory


The brain mask segmentation sometimes fail in the fetal subjects.
This is done with BET, that works well with neonates, but there is not a consistent threshold to use with fetal subjects.
If you want to use your own brain mask you can store it in:
$output/segmentations/${subj}_brain_mask.nii.gz
where $subj is the same as the $T2 filename without the extension  e.g. if T2=subj1.nii.gz then subj=subj1, if T2=/home/subj2.nii.gz then subj=subj2

you can generate different masks with
bet $T2 $brain -R -f $threshold -m
where $brain the output brain (it will also create a mask in the same folder)
and $threshold a threshold in [0, 1] that gives larger brain estimates with smaller values


If you want to do a rigid registration of a subject to e.g. the fetal atlas you can do:
mirtk register $DRAWEMDIR/atlases/fetal/T2/template-$atlasage.nii.gz  $T2 -dofout $dof -model Rigid -threads $cores
where:
$atlasage the age of the atlas to use in weeks (integer in [23, 37])
$dof the estimated transformation

Then you can transform the subject image to the atlas space with:
mirtk transform-image $T2 $T2tranformed -target $DRAWEMDIR/atlases/fetal/T2/template-$atlasage.nii.gz -dofin $dof -interp BSpline
where:
$T2transformed the transformed image
```

## Introduction

The dHCP structural pipeline performs structural analysis of neonatal brain
MRI images (T1 and T2) and consists of:

* cortical and sub-cortical volume segmentation
* cortical surface extraction (white matter and pial surface)
* cortical surface inflation and 
* projection to sphere

It is described in detail in:

A. Makropoulos, E. C. Robinson et al. *"The Developing Human Connectome
Project: a Minimal Processing Pipeline for Neonatal Cortical Surface
Reconstruction"* [link](http://biorxiv.org/content/early/2017/04/07/125526)

### Developers

**Antonios Makropoulos**: main author, developer of the structural pipeline,
and segmentation software. [more](http://antoniosmakropoulos.com)

**Andreas Schuh**: contributor, developer of the cortical surface extraction,
and surface inflation software. [more](http://andreasschuh.com)

**Robert Wright**: contributor, development of the spherical projection
software.

### License

The dHCP structural pipeline is distributed under the terms outlined in
[LICENSE.txt](LICENSE.txt).

## Running the pipeline from dockerhub

You can run the pipeline in a docker container. This will work on any
version of any platform and is simple to set up. First, install docker:

https://docs.docker.com/engine/installation/

Next, you need to make a directory to hold the images you want to analyze and
the results from the pipeline. For example:

```
$ mkdir data
$ cp T1w.nii.gz data
$ cp T2w.nii.gz data
```

The T1 image is optional. You can use any names for the images and the
directory, though you'll obviously have to modify the next command slightly. 

Get the latest version of the pipeline from dockerhub like this:

```
$ docker pull biomedia/dhcp-structural-pipeline:latest 
```

And finally, execute the pipeline like this:

```
$ docker run --rm -t \
    -u $(id -u):$(id -g) \
    -v $PWD/data:/data \
    biomedia/dhcp-structural-pipeline:latest subject1 session1 44 \
            -T1 data/T1w.nii.gz -T2 data/T2w.nii.gz -t 8
```

Substituting subject and session codes, and the post-menstrual age at
scan, see below. 

Once the command completes, you should find the output images in your `data`
folder. 

The `dhcp-pipeline.sh` script has the following arguments:

```
./dhcp-pipeline.sh <subject_ID> <session_ID> <scan_age> -T2 <T2_image> \
    [-T1 <T1_image>] [-t <num_threads>]
```

where:

Argument        | Type      | Description     
------------- | ------------- | ------------- 
`subject_ID` | string | Subject ID
`session_ID` | string | Session ID
`scan_age` | double | Subject post-menstrual age (PMA) in weeks (number between 28 -- 44). If the age is less than 28w or more than 44w, it will be set to 28w or 44w respectively.
`T2_image` | nifti image | The T2 image of the subject
`T1_image` | nifti image | Optional, the T1 image of the subject
`num_threads` | integer | Optional, the number of threads (CPU cores) used (default: 1)

Examples:

```
./dhcp-pipeline.sh subject1 session1 44 -T2 subject1-T2.nii.gz -T1 subject1-T1.nii.gz -t 8
./dhcp-pipeline.sh subject2 session1 36 -T2 subject2-T2.nii.gz -T1 subject2-T1.nii.gz 
./dhcp-pipeline.sh subject3 session4 28 -T2 subject3-T2.nii.gz 
```

The output of the pipeline is the following directories:

* `sourcedata`: folder containing the source images (T1,T2) of the processed subjects
* `derivatives`: folder containing the output of the pipeline processing

Measurements and reporting for the dHCP Structural Pipeline can be computed
using:

https://github.com/amakropoulos/structural-pipeline-measures

### Rebuild the docker image

In the top directory of `dhcp-structural-pipeline`, use git to switch to
the branch you want to build, and enter:

```
$ docker pull ubuntu:xenial
$ docker build -t biomedia/dhcp-structural-pipeline:latest .
$ docker push biomedia/dhcp-structural-pipeline:latest
```

## Install natively

If you want to work on the code of the pipeline, it will be more convenient to
install natively to your machine. Only read on if you need to do a native
install. 

### FSL

The dHCP structural pipeline uses
[FSL](https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FSL). You'll need to read their
install pages. 

### Packages

The dHCP structural requires installation of the following packages.

#### macOS (tested on version 10.9.5)

This is easiest with [homebrew](https://brew.sh/). Install that first, then:

```
$ brew update
$ brew install gcc5 git cmake unzip tbb boost expat cartr/qt4/qt
$ sudo easy_install pip
$ pip install contextlib2
```

#### Ubuntu (tested on version 16.04)

```
$ sudo apt -y update
$ sudo apt -y install g++-5 git cmake unzip bc python python-contextlib2 
$ sudo apt -y install libtbb-dev libboost-dev zlib1g-dev libxt-dev 
$ sudo apt -y install libexpat1-dev libgstreamer1.0-dev libqt4-dev
```

#### Debian GNU (tested on version 8)

```
$ sudo apt -y update
$ sudo apt -y install git cmake unzip bc python python-contextlib2 
$ sudo apt -y install libtbb-dev libboost-dev zlib1g-dev libxt-dev libexpat1-dev 
$ sudo apt -y install libgstreamer1.0-dev libqt4-d
$ # g++-5 is not in the default packages of Debian
$ # install with the following commands:
$ echo "deb http://ftp.us.debian.org/debian unstable main contrib non-free" | sudo tee -a /etc/apt/sources.list
$ sudo apt-get -y update
$ sudo apt-get -y install g++-5
```

#### CENTOS (tested on version 7)

```
$ sudo yum -y update
$ sudo yum -y install git cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel expat-devel gstreamer1-devel 
$ sudo yum -y install epel-release
$ sudo yum -y install python-contextlib2
$ # g++-5 is not in the default packages of CENTOS, install with the following commands:
$ sudo yum -y install centos-release-scl
$ sudo yum -y install "devtoolset-4-gcc*"
$ # then activate it at the terminal before running the installation script
$ scl enable devtoolset-4 bash
```

#### Red Hat Enterprise Linux (tested on version 7.3)

```
$ sudo yum -y update
$ sudo yum -y install it cmake unzip bc python tbb-devel boost-devel qt-devel zlib-devel libXt-devel expat-devel gstreamer1-devel
$ # the epel-release-latest-7.noarch.rpm is for version 7 of RHEL, this needs to be adjusted for the user's OS version
$ curl -o epel.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
$ sudo yum -y install epel.rpm
$ sudo yum -y install python-contextlib2
$ # g++-5 is not in the default packages of RHEL, install with the following commands:
$ sudo yum-config-manager --enable rhel-server-rhscl-7-rpms
$ sudo yum -y install devtoolset-4-gcc*
$ # then activate it at the terminal before running the installation script
$ scl enable devtoolset-4 bash
```

### Installation

```
$ ./setup.sh [-j <num_cores>] 
```

where `num_cores` the number of CPU cores used to compile the pipeline 
software.

The setup script installs the following software packages.
   
Software        | Version           
------------- | ------------- 
[ITK](https://github.com/InsightSoftwareConsortium/ITK) | 4.11.1 
[VTK](https://github.com/Kitware/VTK) | 7.0.0     
[Connectome Workbench](https://github.com/Washington-University/workbench) | 1.2.2  
[MIRTK](https://github.com/BioMedIA/MIRTK) | dhcp-v1.1
[SphericalMesh](https://github.com/amakropoulos/SphericalMesh) | dhcp-v1.1

The '-h' argument can be specified to provide more setup options:

```
$ ./setup.sh -h
```

Once the installation is successfully completed, if desired, the different
commands/tools built (workbench, MIRTK and pipeline commands) can be included
in the shell PATH by running:

```
$ . parameters/path.sh
```
