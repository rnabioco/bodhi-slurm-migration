# Converter Script: `lsf2slurm.sh`

We provide a helper script that automates the most common LSF-to-SLURM conversions. It's located at [`scripts/lsf2slurm.sh`](https://github.com/rnabioco/bodhi-slurm-migration/blob/main/scripts/lsf2slurm.sh) in this repository.

## Usage

```bash
# Convert a script (prints to stdout)
bash scripts/lsf2slurm.sh myjob.lsf

# Save the output to a new file
bash scripts/lsf2slurm.sh myjob.lsf > myjob.slurm

# Or redirect in place (use with caution)
bash scripts/lsf2slurm.sh myjob.sh > myjob_slurm.sh
```

## What it converts

The script handles these substitutions:

### Directives

| LSF | SLURM |
|---|---|
| `#BSUB -J name` | `#SBATCH --job-name=name` |
| `#BSUB -q queue` | `#SBATCH --partition=queue` |
| `#BSUB -W HH:MM` | `#SBATCH --time=HH:MM:00` |
| `#BSUB -n N` | `#SBATCH --ntasks=N` |
| `#BSUB -M mem` | `#SBATCH --mem=memMB` |
| `#BSUB -o file` | `#SBATCH --output=file` |
| `#BSUB -e file` | `#SBATCH --error=file` |
| `#BSUB -N` | `#SBATCH --mail-type=END` |
| `#BSUB -B` | `#SBATCH --mail-type=BEGIN` |
| `#BSUB -u email` | `#SBATCH --mail-user=email` |
| `#BSUB -P project` | `#SBATCH --account=project` |

### Output filename tokens

| LSF | SLURM |
|---|---|
| `%J` | `%j` |
| `%I` | `%a` |

### Environment variables

| LSF | SLURM |
|---|---|
| `$LSB_JOBID` | `$SLURM_JOB_ID` |
| `$LSB_JOBINDEX` | `$SLURM_ARRAY_TASK_ID` |
| `$LSB_JOBNAME` | `$SLURM_JOB_NAME` |
| `$LSB_QUEUE` | `$SLURM_JOB_PARTITION` |
| `$LSB_SUBCWD` | `$SLURM_SUBMIT_DIR` |
| `$LSB_DJOB_NUMPROC` | `$SLURM_NTASKS` |
| `$LSB_HOSTS` | `$SLURM_JOB_NODELIST` |

### Array syntax

Job array specifications in `-J "name[1-100]"` are converted to separate `--job-name=name` and `--array=1-100` directives.

## What it does NOT convert

!!! warning "Manual review required"
    The converter is a starting point, not a complete solution. You **must** review the output before submitting. The following require manual conversion:

- **Complex `-R` resource strings** — e.g., `rusage[mem=X]`, `span[hosts=1]`, GPU resource requests. These need to be translated to `--mem-per-cpu`, `--nodes`, `--gpus`, etc. based on your specific needs.
- **`bsub` command-line invocations** — only `#BSUB` directives inside scripts are converted, not `bsub` commands in wrapper scripts or pipelines.
- **Dependency expressions** — `-w "done(123) && done(456)"` requires manual translation to `--dependency=afterok:123:456`.
- **Time format differences** — LSF accepts `-W 60` (minutes) or `-W 1:00` (H:MM). The script converts `H:MM` to `HH:MM:00` but does not convert bare minute values.
- **Memory unit conversion** — LSF `-M` values are passed through as MB. If your cluster used KB for `-M`, you'll need to adjust.
- **Conditional logic using LSF variables** — if your script has complex logic around `$LSB_*` variables beyond simple references, review carefully.

## Example

Input (`myjob.lsf`):

```bash
#!/bin/bash
#BSUB -J "analysis[1-50]%10"
#BSUB -q normal
#BSUB -W 4:00
#BSUB -n 8
#BSUB -M 16000
#BSUB -o logs/analysis.%J.%I.out
#BSUB -e logs/analysis.%J.%I.err

SAMPLE=$(sed -n "${LSB_JOBINDEX}p" samples.txt)
./process.sh $SAMPLE $LSB_DJOB_NUMPROC
```

Output:

```bash
#!/bin/bash
#SBATCH --job-name=analysis
#SBATCH --array=1-50%10
#SBATCH --partition=normal
#SBATCH --time=04:00:00
#SBATCH --ntasks=8
#SBATCH --mem=16000MB
#SBATCH --output=logs/analysis.%j.%a.out
#SBATCH --error=logs/analysis.%j.%a.err

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samples.txt)
./process.sh $SAMPLE $SLURM_NTASKS
```
