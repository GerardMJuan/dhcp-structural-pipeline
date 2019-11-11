#!/bin/bash

# script to align native surfaces with template space & resample native surfaces with template topology 
# output: native giftis resampled with template topology


Usage() {
    echo "align_to_template.sh <topdir> <subjid> <session> <template volume> <template sphere> <template data> <pre_rotation> <outdir> <config> <MSM bin> <wb bin>"
    echo " script to align native surfaces with template space & resample native surfaces with template topology "
    echo " input args: "
    echo " topdir: top directory where subject directories are located "
    echo " subjid : subject id "
    echo " session: subject scan session "
    echo " template volume: template T2 volume "
    echo " template sphere: template sphere.surf.gii (with wildcard %hemi% in place of hemisphere) "
    echo " template anat: template anatomy file i.e. white or midthickness.surf.gii (with wildcard %hemi% in place of hemisphere) "
    echo " template data : template sulc.shape.gii (with wildcard %hemi% in place of hemisphere) "
    echo " pre_rotation : txt file containing rotational transform between MNI and FS_LR space (i.e. file rotational_transforms/week40_toFS_LR_rot.%hemi%.txt  ) "
    echo " outdir : base directory where output will be sent "
    echo " config : base config file "
    echo "output: 1) surface registrations; 2)  native giftis resampled with template topology "
    echo ""
    echo "set SURF2TEMPLATE, WB_BIN, MSM_BIN, MIRTK_BIN to this parent dir, "
    echo "the workbench executable, the MSM executable and the MIRTK exe"
}

if [ "$#" -lt 9  ]; then
   echo "$#" 
   Usage
   exit
fi

topdir=$1;shift
subjid=$1;shift
session=$1;shift
templatevolume=$1;shift
templatesphere=$1;shift
templateanat=$1;shift
templatedata=$1;shift
pre_rotation=$1;shift
outdir=$1; shift
config=$1; shift

mkdir -p $outdir $outdir/volume_dofs $outdir/surface_transforms

# define paths to variables

# read generated files from here
anat=${topdir}/derivatives/sub-${subjid}/ses-${session}/anat

native_volume=${anat}/sub-${subjid}_ses-${session}_T2w_restore_brain.nii.gz

# native spheres
native_sphereL=${anat}/Native/sub-${subjid}_ses-${session}_left_sphere.surf.gii
native_sphereR=${anat}/Native/sub-${subjid}_ses-${session}_right_sphere.surf.gii

# native spheres rotated into FS_LR space
native_rot_sphereL=${anat}/Native/sub-${subjid}_ses-${session}_left_sphere.rot.surf.gii
native_rot_sphereR=${anat}/Native/sub-${subjid}_ses-${session}_right_sphere.rot.surf.gii

# native data
native_dataL=${anat}/Native/sub-${subjid}_ses-${session}_left_sulc.shape.gii
native_dataR=${anat}/Native/sub-${subjid}_ses-${session}_right_sulc.shape.gii

# pre-rotations
pre_rotationL=$(echo ${pre_rotation} |  sed "s/%hemi%/L/g")
pre_rotationR=$(echo ${pre_rotation} |  sed "s/%hemi%/R/g")


# rotate left and right hemispheres into approximate alignment with MNI space
echo ${SURF2TEMPLATE}/surface_to_template_alignment/pre_rotation.sh $native_volume $native_sphereL $templatevolume $pre_rotationL $outdir/volume_dofs/${subjid}-${session}.dof ${native_rot_sphereL}
${SURF2TEMPLATE}/surface_to_template_alignment/pre_rotation.sh $native_volume $native_sphereL $templatevolume $pre_rotationL $outdir/volume_dofs/${subjid}-${session}.dof ${native_rot_sphereL} 
${SURF2TEMPLATE}/surface_to_template_alignment/pre_rotation.sh $native_volume $native_sphereR $templatevolume $pre_rotationR $outdir/volume_dofs/${subjid}-${session}.dof ${native_rot_sphereR}


# run msm non linear alignment to template for left and right hemispheres

for hemi in L R; do
  refmesh=$(echo $templatesphere | sed "s/%hemi%/$hemi/g")
  refdata=$(echo $templatedata | sed "s/%hemi%/$hemi/g")

  if [ "$hemi" == "L" ]; then
    inmesh=$native_rot_sphereL
    indata=$native_dataL
    outname=$outdir/surface_transforms/sub-${subjid}_ses-${session}_left_

  else
    inmesh=$native_rot_sphereR
    indata=$native_dataR
    outname=$outdir/surface_transforms/sub-${subjid}_ses-${session}_right_
  fi

  if [ ! -f ${outname}sphere.reg.surf.gii ]; then
	  echo  ${MSM_BIN}  --conf=${config}  --inmesh=${inmesh}  --refmesh=${refmesh} --indata=${indata} --refdata=${refdata} --out=${outname} --verbose
	  ${MSM_BIN}  --conf=${config}  --inmesh=${inmesh}  --refmesh=${refmesh} --indata=${indata} --refdata=${refdata} --out=${outname} --verbose
  fi

done

# now resample template topology on native surfaces - output in 
# anat directory, but we tag as "space-dHCPavg32k"

nativedir=${anat}/Native
space32k=dHCPavg32k

for in_hemi in left right; do
  # BIDS uses L and R
  if [ $in_hemi == "left" ]; then
    out_hemi=L
  else
    out_hemi=R
  fi

  transformed_sphere=$outdir/surface_transforms/sub-${subjid}_ses-${session}_${in_hemi}_sphere.reg.surf.gii

  template=$(echo $templatesphere | sed "s/%hemi%/$out_hemi/g")
  template_areal=$(echo $templateanat | sed "s/%hemi%/$out_hemi/g")

  # template sphere needed for HCP compat ... this is the same for all
  # subjects, so it goes higher up in the tree
  cp $template ${topdir}/derivatives/hemi-${out_hemi}_space-template40w_sphere.surf.gii

  # native transformed to template
  cp $transformed_sphere $anat/sub-${subjid}_ses-${session}_hemi-${out_hemi}_space-template40w_sphere.surf.gii 
  
  # resample surfaces
  for surf in pial white midthickness sphere inflated very_inflated; do	
    # no underscores in BIDS names
    if [ $surf == "very_inflated" ]; then
      new_surf="veryinflated"
    else
      new_surf=$surf
    fi

    ${WB_BIN} -surface-resample \
      $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_${surf}.surf.gii \
      $transformed_sphere \
      $template \
      ADAP_BARY_AREA \
      $anat/sub-${subjid}_ses-${session}_hemi-${out_hemi}_space-${space32k}_${new_surf}.surf.gii \
      -area-surfs \
        $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_white.surf.gii \
        $template_areal
  done

  # resample .func metrics ... again, no underscores in BIDS names, so we must
  # rename myelin_map and smoothed_myelin_map
  ${WB_BIN} -metric-resample \
    $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_myelin_map.func.gii \
    $transformed_sphere \
    $template \
    ADAP_BARY_AREA \
    $anat/sub-${subjid}_ses-${session}_hemi-${out_hemi}_space-${space32k}_myelinmap.func.gii \
    -area-surfs \
      $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_white.surf.gii \
      $template_areal

  ${WB_BIN} -metric-resample \
    $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_smoothed_myelin_map.func.gii \
    $transformed_sphere \
    $template \
    ADAP_BARY_AREA \
    $anat/sub-${subjid}_ses-${session}_hemi-${out_hemi}_desc-smoothed_space-${space32k}_myelinmap.func.gii \
    -area-surfs \
      $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_white.surf.gii \
      $template_areal

  # resample .shape metrics
  for metric in sulc curvature thickness; do
    ${WB_BIN} -metric-resample \
      $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_${metric}.shape.gii \
      $transformed_sphere \
      $template \
      ADAP_BARY_AREA \
      $anat/sub-${subjid}_ses-${session}_hemi-${out_hemi}_space-${space32k}_${metric}.shape.gii \
      -area-surfs \
        $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_white.surf.gii \
        $template_areal
  done

  # again, no _ in BIDS names
  ${WB_BIN} -metric-resample \
    $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_corr_thickness.shape.gii \
    $transformed_sphere \
    $template \
    ADAP_BARY_AREA \
    $anat/sub-${subjid}_ses-${session}_hemi-${out_hemi}_desc-corr_space-${space32k}_thickness.shape.gii \
    -area-surfs \
      $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_white.surf.gii \
      $template_areal

  ${WB_BIN} -label-resample \
    $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_space-${space32k}_drawem.label.gii \
    $transformed_sphere \
    $template \
    ADAP_BARY_AREA \
    $anat/sub-${subjid}_ses-${session}_hemi-${out_hemi}_space-${space32k}_drawem.label.gii \
    -area-surfs \
      $nativedir/sub-${subjid}_ses-${session}_${in_hemi}_white.surf.gii \
      $template_areal
done
