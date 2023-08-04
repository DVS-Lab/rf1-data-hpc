#/usr/bin/env bash

sub=$1

except_subs=(1001 3003)
for i in "${except_subs[@]}" ; do
    if [ "$i" -eq "$sub" ] ; then
        echo "Exception ${sub}"
	      exit 1
    fi
done


# ensure paths are correct irrespective from where user runs the script
codedir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
dsroot="$(dirname "$scriptdir")"


## Run MRIQC on subject
# To-do: run through datalad with YODA principles

## make derivatives folder if it doesn't exist.
## let's keep this out of bids for now
echo "running MRIQC for subject $sub remember to clear your scratch"
if [ ! -d $dsroot/derivatives/mriqc ]; then
	mkdir -p $dsroot/derivatives/mriqc
fi


# make scratch
scratch=/ZPOOL/data/scratch/`whoami`
if [ ! -d $scratch ]; then
	mkdir -p $scratch
fi

# no space left on device error for v0.15.2 and higher
# https://neurostars.org/t/mriqc-no-space-left-on-device-error/16187/1
# https://github.com/poldracklab/mriqc/issues/850
TEMPLATEFLOW_DIR=/ZPOOL/data/tools/templateflow
export SINGULARITYENV_TEMPLATEFLOW_HOME=/opt/templateflow
singularity run --cleanenv \
-B ${TEMPLATEFLOW_DIR}:/opt/templateflow \
-B $dsroot/bids:/data \
-B $dsroot/derivatives/mriqc:/out \
-B $scratch:/scratch \
/ZPOOL/data/tools/mriqc-23.1.0.simg \
/data /out \
participant --participant_label $sub \
-m T1w T2w bold \
-w /scratch
