#!/bin/bash
#PBS -l walltime=12:00:00
#PBS -N L1stats-trust-all
#PBS -q normal
#PBS -m ae
#PBS -M david.v.smith@temple.edu
#PBS -l nodes=4:ppn=15

# load modules and go to workdir
module load fsl/6.0.2
source $FSLDIR/etc/fslconf/fsl.sh
cd $PBS_O_WORKDIR

# ensure paths are correct
maindir=~/work/rf1-data-hpc #this should be the only line that has to change if the rest of the script is set up correctly
scriptdir=$maindir/code
bidsdir=$maindir/bids
logdir=$maindir/logs
mkdir -p $logdir

rm -f $logdir/cmd_feat_${PBS_JOBID}.txt
touch $logdir/cmd_feat_${PBS_JOBID}.txt

TASK=trust
ppi=0
sm=6

# need to change this to a more targetted list of subjects
# also should only run this if the inputs exist. add if statements.
for sub in `ls -1d $bidsdir/sub-*`; do
	sub=${sub:(-5)}
	for run in 1 2; do

		# set inputs and general outputs (should not need to chage across studies in Smith Lab)
		MAINOUTPUT=${maindir}/derivatives/fsl/sub-${sub}
		mkdir -p $MAINOUTPUT
		DATA=${maindir}/derivatives/fmriprep/sub-${sub}/func/sub-${sub}_task-${TASK}_run-${run}_space-MNI152NLin2009cAsym_desc-preproc_bold.nii.gz
		CONFOUNDEVS=${maindir}/derivatives/fsl/confounds/sub-${sub}/sub-${sub}_task-${TASK}_run-${run}_desc-fslConfounds.tsv
		if [ ! -e $CONFOUNDEVS ]; then
			echo "missing: $CONFOUNDEVS " >> ${maindir}/re-runL1.log
			continue # exiting/continuing to ensure nothing gets run without confounds
		fi
		EVDIR=${maindir}/derivatives/fsl/EVfiles/sub-${sub}/${TASK}/run-0${run} # don't zeropad here since only 2 runs at most
		if [ ! -d ${EVDIR} ]; then
			echo "missing EVfiles: $EVDIR " >> ${maindir}/re-runL1.log
			continue # skip these since some won't exist yet
		fi

		# check for empty EVs (extendable to other studies)
		MISSED_TRIAL=${EVDIR}_missed_trial.txt
		if [ -e $MISSED_TRIAL ]; then
			EV_SHAPE=3
		else
			EV_SHAPE=10
		fi

		# if network (ecn or dmn), do nppi; otherwise, do activation or seed-based ppi
		if [ "$ppi" == "ecn" -o  "$ppi" == "dmn" ]; then

			# check for output and skip existing
			OUTPUT=${MAINOUTPUT}/L1_task-${TASK}_model-01_type-melodic-nppi-${ppi}_run-0${run}_sm-${sm}
			if [ -e ${OUTPUT}.feat/cluster_mask_zstat1.nii.gz ]; then
				continue
			else
				echo "missing: $OUTPUT " >> ${maindir}/re-runL1.log
				rm -rf ${OUTPUT}.feat
			fi

			# network extraction. need to ensure you have run Level 1 activation
			MASK=${MAINOUTPUT}/L1_task-${TASK}_model-01_type-act_run-0${run}_sm-${sm}.feat/mask
			if [ ! -e ${MASK}.nii.gz ]; then
				echo "cannot run nPPI because you're missing $MASK"
				continue
			fi
			for net in `seq 0 9`; do
				NET=${maindir}/masks/melodic-114_smith09_net${net}.nii.gz
				TSFILE=${MAINOUTPUT}/ts_task-${TASK}_melodic-114_net${net}_nppi-${ppi}_run-0${run}.txt
				fsl_glm -i $DATA -d $NET -o $TSFILE --demean -m $MASK
				eval INPUT${net}=$TSFILE
			done

			# set names for network ppi (we generally only care about ECN and DMN)
			DMN=$INPUT3
			ECN=$INPUT7
			if [ "$ppi" == "dmn" ]; then
				MAINNET=$DMN
				OTHERNET=$ECN
			else
				MAINNET=$ECN
				OTHERNET=$DMN
			fi

			# create template and run analyses
			ITEMPLATE=${maindir}/templates/L1_task-${TASK}_model-01_type-nppi.fsf
			OTEMPLATE=${MAINOUTPUT}/L1_task-${TASK}_model-01_seed-${ppi}_run-0${run}.fsf
			sed -e 's@OUTPUT@'$OUTPUT'@g' \
			-e 's@DATA@'$DATA'@g' \
			-e 's@EVDIR@'$EVDIR'@g' \
			-e 's@MISSED_TRIAL@'$MISSED_TRIAL'@g' \
			-e 's@EV_SHAPE@'$EV_SHAPE'@g' \
			-e 's@CONFOUNDEVS@'$CONFOUNDEVS'@g' \
			-e 's@MAINNET@'$MAINNET'@g' \
			-e 's@OTHERNET@'$OTHERNET'@g' \
			-e 's@INPUT0@'$INPUT0'@g' \
			-e 's@INPUT1@'$INPUT1'@g' \
			-e 's@INPUT2@'$INPUT2'@g' \
			-e 's@INPUT4@'$INPUT4'@g' \
			-e 's@INPUT5@'$INPUT5'@g' \
			-e 's@INPUT6@'$INPUT6'@g' \
			-e 's@INPUT8@'$INPUT8'@g' \
			-e 's@INPUT9@'$INPUT9'@g' \
			<$ITEMPLATE> $OTEMPLATE

		else # otherwise, do activation and seed-based ppi

			# set output based in whether it is activation or ppi
			if [ "$ppi" == "0" ]; then
				TYPE=act
				OUTPUT=${MAINOUTPUT}/L1_task-${TASK}_model-01_type-${TYPE}_run-0${run}_sm-${sm}
			else
				TYPE=ppi
				OUTPUT=${MAINOUTPUT}/L1_task-${TASK}_model-01_type-${TYPE}_seed-${ppi}_run-0${run}_sm-${sm}
			fi

			# check for output and skip existing
			if [ -e ${OUTPUT}.feat/cluster_mask_zstat1.nii.gz ]; then
				continue
			else
				echo "missing: $OUTPUT " >> ${maindir}/re-runL1.log
				rm -rf ${OUTPUT}.feat
			fi

			# create template and run analyses
			ITEMPLATE=${maindir}/templates/L1_task-${TASK}_model-01_type-${TYPE}.fsf
			OTEMPLATE=${MAINOUTPUT}/L1_sub-${sub}_task-${TASK}_model-01_seed-${ppi}_run-0${run}.fsf
			if [ "$ppi" == "0" ]; then
				sed -e 's@OUTPUT@'$OUTPUT'@g' \
				-e 's@DATA@'$DATA'@g' \
				-e 's@EVDIR@'$EVDIR'@g' \
				-e 's@MISSED_TRIAL@'$MISSED_TRIAL'@g' \
				-e 's@EV_SHAPE@'$EV_SHAPE'@g' \
				-e 's@SMOOTH@'$sm'@g' \
				-e 's@CONFOUNDEVS@'$CONFOUNDEVS'@g' \
				<$ITEMPLATE> $OTEMPLATE
			else
				PHYS=${MAINOUTPUT}/ts_task-${TASK}_mask-${ppi}_run-0${run}.txt
				MASK=${maindir}/masks/seed-${ppi}.nii.gz
				fslmeants -i $DATA -o $PHYS -m $MASK
				sed -e 's@OUTPUT@'$OUTPUT'@g' \
				-e 's@DATA@'$DATA'@g' \
				-e 's@EVDIR@'$EVDIR'@g' \
				-e 's@MISSED_TRIAL@'$MISSED_TRIAL'@g' \
				-e 's@EV_SHAPE@'$EV_SHAPE'@g' \
				-e 's@PHYS@'$PHYS'@g' \
				-e 's@SMOOTH@'$sm'@g' \
				-e 's@CONFOUNDEVS@'$CONFOUNDEVS'@g' \
				<$ITEMPLATE> $OTEMPLATE
			fi
		fi

		# add feat cmd to submission script
		echo feat $OTEMPLATE >> $logdir/cmd_feat_${PBS_JOBID}.txt

	done
done

torque-launch -p $logdir/chk_feat_${PBS_JOBID}.txt $logdir/cmd_feat_${PBS_JOBID}.txt
