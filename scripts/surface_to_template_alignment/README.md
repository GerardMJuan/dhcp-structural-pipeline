# dHCP_template_alignment

This repository provides all scripts required for aligning surfaces (derived from the dHCP structural pipeline) to the dHCP surface template space

This needs to be done in three steps:

1) Estimation and application of a rotational transform between MNI space and HCP FS_LR space
2) Estimation of a non-linear transform between each surface's native space and template space using MSM
3) Resampling of native surfaces into template surface topology (the FS_LR32k space) 

# Environment Setup
Before running any scripts please set an environment variable $SURF2TEMPLATE as the path to the top level of this directory

# Pre-processing that has been done for you
For the first step the rotational transformation between MNI space and HCP FS_LR space is given in the folder rotational_transforms. The scripts used to do this can be found (for reference) in the  pre_rotation folder

# Running surface to template alignment

Therefore, to run alignment to template, all that is required is to run the surface_to_template_alignment/align_to_template.sh script. This applies the rotation rotational_transforms/week40_toFS_LR_rot.L.txt (or rotational_transforms/week40_toFS_LR_rot.R.txt ) to the surfaces; then aligns non-linearly using MSM [1][2], before finally resampling all Native surfaces and data onto the template surface topology (creating a new data folder fsaverage_LR32k in the process)

# More info

Emma also posted this email:

```
Hi all


I've generated some scripts to register all subjects directly to the 40 week template:


https://github.com/ecr05/dHCP_template_alignment


I've run them, and tested them. The subject files resampled to template space can be found in


/vol/medic01/users/ecr05/dHCP_processing/reconstructions_june2018/sub-*/ses-*/anat/fsaverage_LR32k/


The output of MSM is here:


/vol/medic01/users/ecr05/dHCP_processing/reconstructions_june2018/surface_transforms/surface_transforms


Some examples of how I called the scripts are


/vol/biomedic/users/ecr05/MSMscripts_clean/examples.txt


They aren't particularly cleanly designed I'm afraid. And there are a few things that we set out to do (registration to local templates) that I haven't done. But I no longer have time to work on this so I'm passing it over to you guys. Please look over them and check your happy with them as soon as possible. I don't have much time left before I go on leave.


***  tips on using the scripts ****


Note, the estimate_pre_rotations.sh does not need to be re-run. I used it to estimated a rotational transform between MNI space and the new template space, without which the MSM registrations wont work. The rotational transforms output from that are in the rotational_transforms folder of the git repository - you just need to use them to call the align_to_template.sh script.


*** NO registration to local templates ****


I have not bothered with intermediate registration to local templates, as I need registrations of all data, including the pre-terms (subjects less than 34 weeks). Personally for surface alignment I don't think the intermediate files are required because the registration is driven only by coarse scale folding patterns (which are present at 30 weeks). If you would like to add registrations to local templates, the scripts should provide you with all the methods you need to use.


*** registration and surface extraction failures ***


Subject CC00605XX11 has big big problems with its surface extraction

Subjects CC00660XX09 (left and right) CC00720XX11 (left) and CC00823XX15 (session 27810 left) failed initial registration using the default config. I thus re-ran these with a modified affine (see config https://github.com/ecr05/dHCP_template_alignment/blob/master/configs/config_subject_to_40_week_template_relaxedaffine. It might be that this config works for all files, but I'd be wary of it as it really relaxes the affine parameters and the affine registration in MSM is quite temperamental.


For Sean specifically:


The regularisation of these registrations to template is relatively weak. For initialising functional alignment you will likely need to re-run to initialise for functional alignment. As a guess I would say use a lambda somewhere between 0.8 and 1.5. You could consider also consider the config that the HCP uses for MSM sulc (https://github.com/ecr05/MSM_HOCR/blob/master/config/HCP_multimodal_alignment/MSMSulcStrainFinalconf) - this seems to be taking it to the other extreme but its worth trying.


Let me know if you have any questions.


Thanks


Emma
```
