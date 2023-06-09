#! /bin/bash
# ============================================================================
# Developing brain Region Annotation With Expectation-Maximization (Draw-EM)
#
# Copyright 2013-2016 Imperial College London
# Copyright 2013-2016 Andreas Schuh
# Copyright 2013-2016 Antonios Makropoulos
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================

# if FSLDIR is not defined, assume we need to read the FSL startup
if [ -z ${FSLDIR+x} ]; then
  if [ -f /etc/fsl/fsl.sh ]; then
    . /etc/fsl/fsl.sh
  else
    echo FSLDIR is not set and there is no system-wide FSL startup
    exit 1
  fi
fi

# we need the paths set for N4, drawem etc.
export BASEDIR="$(cd "$(dirname "$BASH_SOURCE")" && pwd)"
source $BASEDIR/parameters/path.sh 

# double-check drawem
if [ -n "$DRAWEMDIR" ]; then
  [ -d "$DRAWEMDIR" ] || { echo "DRAWEMDIR environment variable invalid!" 1>&2; exit 1; }
else
  export DRAWEMDIR="$BASEDIR/build/MIRTK/Packages/DrawEM"
fi

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject_T2.nii.gz scan_age [options]
This script runs the fetal segmentation pipeline of Draw-EM.

Arguments:
  subject_T2.nii.gz             Nifti Image: The T2 image of the subject to be segmented.
  scan_age                      Number: Subject age in weeks. This is used to select the appropriate template for the initial registration. 
			        If the age is <23w or >37w, it will be set to 23w or 37w respectively.
Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files. 
  -c / -cleanup  <0/1>          Whether cleanup of temporary files is required (default: 1)
  -p / -save-posteriors  <0/1>  Whether the structures' posteriors are required (default: 0)
  -atlas  <atlasname>           Atlas used for the tissue priors (default: non-rigid-v2)
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -v / -verbose  <0/1>          Whether the script progress is reported (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}

# log function for completion
runpipeline()
{
  pipeline=$1
  shift
  log=$logdir/$subj.$pipeline.log
  err=$logdir/$subj.$pipeline.err
  echo "running $pipeline pipeline"
  echo "$@"
  "$@" >$log 2>$err
  if [ ! $? -eq 0 ]; then
    echo "Pipeline failed: see log files $log $err for details"
    exit 1
  fi
  echo "-----------------------"
}

[ $# -ge 2 ] || { usage; }
T2=$1
age=$2

[ -f "$T2" ] || { echo "$T2 does not exist!" >&2; exit 1; }
subj=`basename $T2  |sed -e 's:.nii.gz::g' |sed -e 's:.nii::g'`
age=`printf "%.*f\n" 0 $age` #round
[ $age -lt 37 ] || { age=37; }
[ $age -gt 23 ] || { age=23; }



cleanup=1 # whether to delete temporary files once done
datadir=`pwd`
posteriors=0   # whether to output posterior probability maps
threads=1
verbose=1
command="$@"

atlasname=fetal

while [ $# -gt 0 ]; do
  case "$3" in
    -c|-cleanup)  shift; cleanup=$3; ;;
    -d|-data-dir)  shift; datadir=$3; ;;
    -p|-save-posteriors) shift; posteriors=$3; ;;
    -atlas)  shift; atlasname=$3; ;; 
    -t|-threads)  shift; threads=$3; ;; 
    -v|-verbose)  shift; verbose=$3; ;; 
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

mkdir -p $datadir/T2 
if [[ "$T2" == *nii ]];then 
  mirtk convert-image $T2 $datadir/T2/$subj.nii.gz
else
  cp $T2 $datadir/T2/$subj.nii.gz
fi
cd $datadir

version=`git -C "$DRAWEMDIR" branch | grep \* | cut -d ' ' -f2`
gitversion=`git -C "$DRAWEMDIR" rev-parse HEAD`

[ $verbose -le 0 ] || { echo "DrawEM multi atlas  $version (branch version: $gitversion)
Subject:    $subj 
Age:        $age
Directory:  $datadir 
Posteriors: $posteriors 
Cleanup:    $cleanup 
Threads:    $threads

$BASH_SOURCE $command
----------------------------"; }

mkdir -p logs || exit 1

# log function
run()
{
  echo "$@"
  "$@"
  if [ ! $? -eq 0 ]; then
    echo "$@ : failed"
    exit 1
  fi
}

# infodir=$datadir/info 
logdir=$datadir/logs
workdir=$datadir/workdir/$subj
# mkdir -p $infodir
mkdir -p $workdir $logdir

# make run function global
typeset -fx run

run_script()
{
  echo "$@"
  "$DRAWEMDIR/scripts/$@"
  if [ ! $? -eq 0 ]; then
    echo "$DRAWEMDIR/scripts/$@ : failed"
    exit 1
  fi
}

if [ ! -f segmentations/${subj}_all_labels.nii.gz ];then

  rm -f logs/$subj logs/$subj-err
  run_script preprocess.sh        $subj
  # phase 1 tissue segmentation
  run_script fetal-tissue-priors.sh     $subj $age $atlasname $threads
  # registration using gm posterior + image
  run_script register-multi-atlas-using-gm-posteriors.sh $subj $age $threads
  # structural segmentation
  run_script labels-multi-atlas.sh   $subj
  run_script segmentation.sh      $subj
  # post-processing
  run_script separate-hemispheres.sh  $subj
  run_script correct-segmentation.sh  $subj
  run_script postprocess.sh       $subj
fi

# if probability maps are required
[ "$posteriors" == "0" -o "$posteriors" == "no" -o "$posteriors" == "false" ] || run_script postprocess-pmaps.sh $subj

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $codedir/parameters/configuration.sh

scriptdir=$codedir/scripts

# segmentation
runpipeline segmentation $scriptdir/segmentation/pipeline.sh $T2 $subj $age -d $workdir -t $threads

# generate some additional files
runpipeline additional $scriptdir/misc/pipeline.sh $subj $age -d $workdir -t $threads

# surface extraction
runpipeline surface $scriptdir/surface/pipeline.sh $subj -d $workdir -t $threads


# cleanup
if [ "$cleanup" == "1" -o "$cleanup" == "yes" -o "$cleanup" == "true" ] && [ -f "segmentations/${subj}_labels.nii.gz" ];then
  run_script clear-data.sh $subj
  rm -f logs/$subj logs/$subj-err
  rmdir logs 2> /dev/null # may fail if other log files exist
fi

exit 0
