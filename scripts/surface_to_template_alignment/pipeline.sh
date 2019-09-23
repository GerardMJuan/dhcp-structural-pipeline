#!/bin/bash

usage()
{
  base=$(basename "$0")
  echo "usage: $base subject [options]
This script runs the surface to template alignment pipeline.

Arguments:
subject                         Subject ID (eg. CC00511XX08-149000)

Options:
  -d / -data-dir  <directory>   The directory used to run the script and output the files.
  -t / -threads  <number>       Number of threads (CPU cores) allowed for the registration to run in parallel (default: 1)
  -h / -help / --help           Print usage.
"
  exit;
}

################ ARGUMENTS ################

if [ $# -le 2 ]; then 
  usage
fi
command=$@
subj=$1

datadir=`pwd`
threads=1

# check whether the different tools are set and load parameters
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. $codedir/../../parameters/configuration.sh

shift
while [ $# -gt 0 ]; do
  case "$1" in
    -d|-data-dir)  shift; datadir=$1; ;;
    -t|-threads)  shift; threads=$1; ;;
    -h|-help|--help) usage; ;;
    -*) echo "$0: Unrecognized option $1" >&2; usage; ;;
     *) break ;;
  esac
  shift
done

echo "dHCP surface to template alignment pipeline
Subject:    $subj
Directory:  $datadir
Threads:    $threads

$BASH_SOURCE $command
----------------------------"

################ PIPELINE ################

if ! [[ $subj =~ (.*)-(.*) ]]; then
  echo "bad subject-session $subj"
  exit 1
fi
subjectID=${BASH_REMATCH[1]}
sessionID=${BASH_REMATCH[2]}

# workdir for emma's script
outdir=$datadir/workdir/$subj/surface_to_template_alignment

# we align to the 40w template
age=40

# appropriate andreas atlas
templatevolume=$codedir/andreas_v1/t2w/t$age.00.nii.gz

# emma surface templates ... sphere, anat and data
templatesphere=$codedir/new_surface_template/week$age.iter30.sphere.%hemi%.dedrift.AVERAGE_removedAffine.surf.gii 
templateanat=$codedir/new_surface_template/week$age.iter30.white.%hemi%.dedrift.AVERAGE_removedAffine.surf.gii
templatedata=$codedir/new_surface_template/week$age.iter30.sulc.%hemi%.AVERAGE.shape.gii 

# align_to_template.sh uses this to find related scripts
export SURF2TEMPLATE=$codedir/..
export WB_BIN=$codedir/../../build/workbench/build/CommandLine/wb_command
export MIRTK_BIN=$codedir/../../build/MIRTK/build/bin/mirtk
export MSM_BIN=$FSLDIR/bin/msm 

run $codedir/align_to_template.sh \
  $datadir \
  $subjectID \
  $sessionID \
  $templatevolume \
  $templatesphere \
  $templateanat \
  $templatedata \
  $codedir/rotational_transforms/week40_toFS_LR_rot.%hemi%.txt \
  $outdir \
  $codedir/configs/config_subject_to_40_week_template 
