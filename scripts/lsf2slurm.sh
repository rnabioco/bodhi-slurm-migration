#!/usr/bin/env bash
#
# lsf2slurm.sh — Convert LSF (#BSUB) job scripts to SLURM (#SBATCH)
#
# Usage:
#   bash lsf2slurm.sh input.lsf > output.slurm
#
# This script handles common directive and variable substitutions.
# Complex -R resource strings and dependency expressions require
# manual conversion. Always review the output before submitting.
#

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <lsf_script>" >&2
    exit 1
fi

input="$1"

if [[ ! -f "$input" ]]; then
    echo "Error: file not found: $input" >&2
    exit 1
fi

sed -E \
    -e '
# ── Job arrays: #BSUB -J "name[spec]%limit" → --job-name + --array ──
/^#BSUB +\-J +\"?[^"]*\[/ {
    s/^#BSUB +-J +"?([^[]*)\[([^]]*)\]"?(%[0-9]+)?.*/#SBATCH --job-name=\1\n#SBATCH --array=\2\3/
    s/--job-name=([^ ]*) +\n/--job-name=\1\n/
    p
    d
}

# ── Simple directives ──
s/^#BSUB +-J +"?([^"]*)"?$/#SBATCH --job-name=\1/
s/^#BSUB +-q +(.+)/#SBATCH --partition=\1/
s/^#BSUB +-o +(.+)/#SBATCH --output=\1/
s/^#BSUB +-e +(.+)/#SBATCH --error=\1/
s/^#BSUB +-n +(.+)/#SBATCH --ntasks=\1/
s/^#BSUB +-M +(.+)/#SBATCH --mem=\1MB/
s/^#BSUB +-N/#SBATCH --mail-type=END/
s/^#BSUB +-B/#SBATCH --mail-type=BEGIN/
s/^#BSUB +-u +(.+)/#SBATCH --mail-user=\1/
s/^#BSUB +-P +(.+)/#SBATCH --account=\1/
s/^#BSUB +-H/#SBATCH --hold/
s/^#BSUB +-r/#SBATCH --requeue/
s/^#BSUB +-x/#SBATCH --exclusive/

# ── Wall time: -W H:MM → --time=HH:MM:00 ──
/^#BSUB +-W +[0-9]+:[0-9]+/ {
    s/^#BSUB +-W +([0-9]+):([0-9]+)/#SBATCH --time=\1:\2:00/
    s/--time=([0-9]):/--time=0\1:/
}
' \
    -e '
# ── Output filename tokens ──
s/%J/%j/g
s/%I/%a/g

# ── Environment variables ──
s/\$LSB_JOBID/\$SLURM_JOB_ID/g
s/\$\{LSB_JOBID\}/\$\{SLURM_JOB_ID\}/g
s/\$LSB_JOBINDEX/\$SLURM_ARRAY_TASK_ID/g
s/\$\{LSB_JOBINDEX\}/\$\{SLURM_ARRAY_TASK_ID\}/g
s/\$LSB_JOBNAME/\$SLURM_JOB_NAME/g
s/\$\{LSB_JOBNAME\}/\$\{SLURM_JOB_NAME\}/g
s/\$LSB_QUEUE/\$SLURM_JOB_PARTITION/g
s/\$\{LSB_QUEUE\}/\$\{SLURM_JOB_PARTITION\}/g
s/\$LSB_SUBCWD/\$SLURM_SUBMIT_DIR/g
s/\$\{LSB_SUBCWD\}/\$\{SLURM_SUBMIT_DIR\}/g
s/\$LSB_DJOB_NUMPROC/\$SLURM_NTASKS/g
s/\$\{LSB_DJOB_NUMPROC\}/\$\{SLURM_NTASKS\}/g
s/\$LSB_HOSTS/\$SLURM_JOB_NODELIST/g
s/\$\{LSB_HOSTS\}/\$\{SLURM_JOB_NODELIST\}/g
' "$input"
