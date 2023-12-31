#!/bin/bash
#PBS -l walltime=24:00:00
#PBS -N mriqc-all
#PBS -q normal
#PBS -m ae
#PBS -M david.v.smith@temple.edu
#PBS -l nodes=12:ppn=4

# load modules and go to workdir
module load fsl/6.0.2
source $FSLDIR/etc/fslconf/fsl.sh
module load singularity/3.8.5
cd $PBS_O_WORKDIR

# ensure paths are correct
maindir=~/work/rf1-data-hpc #this should be the only line that has to change if the rest of the script is set up correctly
scriptdir=$maindir/code
bidsdir=$maindir/bids
logdir=$maindir/logs
mkdir -p $logdir


rm -f $logdir/cmd_mriqc_${PBS_JOBID}.txt
touch $logdir/cmd_mriqc_${PBS_JOBID}.txt

# make derivatives folder if it doesn't exist.
# let's keep this out of bids for now
if [ ! -d $maindir/derivatives/mriqc ]; then
	mkdir -p $maindir/derivatives/mriqc
fi

scratchdir=~/scratch/mriqc
if [ ! -d $scratchdir ]; then
	mkdir -p $scratchdir
fi

TEMPLATEFLOW_DIR=~/work/tools/templateflow
MPLCONFIGDIR_DIR=~/work/mplconfigdir
export SINGULARITYENV_TEMPLATEFLOW_HOME=/opt/templateflow
export SINGULARITYENV_MPLCONFIGDIR=/opt/mplconfigdir

# need to change this to a more targetted list of subjects
for sub in `ls -1d $bidsdir/sub-*`; do
	sub=${sub:(-5)}
	echo singularity run --cleanenv \
	-B ${TEMPLATEFLOW_DIR}:/opt/templateflow \
	-B $maindir/bids:/data \
	-B $maindir/derivatives/mriqc:/out \
	-B $scratchdir:/scratch \
	~/work/tools/mriqc-23.1.0.simg \
	/data /out \
	participant --participant_label $sub \
	-m T1w T2w bold \
	-w /scratch >> $logdir/cmd_mriqc_${PBS_JOBID}.txt
done

torque-launch -p $logdir/chk_mriqc_${PBS_JOBID}.txt $logdir/cmd_mriqc_${PBS_JOBID}.txt
