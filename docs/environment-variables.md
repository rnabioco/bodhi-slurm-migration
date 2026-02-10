# Environment Variables: `$LSB_*` → `$SLURM_*`

LSF and SLURM both set environment variables inside running jobs. You'll need to update any scripts that reference `$LSB_*` variables.

## Variable mapping table

| Purpose | LSF | SLURM |
|---|---|---|
| Job ID | `$LSB_JOBID` | `$SLURM_JOB_ID` (or `$SLURM_JOBID`) |
| Job name | `$LSB_JOBNAME` | `$SLURM_JOB_NAME` |
| Queue / Partition | `$LSB_QUEUE` | `$SLURM_JOB_PARTITION` |
| Submit directory | `$LSB_SUBCWD` | `$SLURM_SUBMIT_DIR` |
| Hostname list | `$LSB_HOSTS` | `$SLURM_JOB_NODELIST` |
| Number of processors | `$LSB_DJOB_NUMPROC` | `$SLURM_NTASKS` |
| Array job index | `$LSB_JOBINDEX` | `$SLURM_ARRAY_TASK_ID` |
| Array job ID (parent) | `$LSB_JOBID` | `$SLURM_ARRAY_JOB_ID` |
| Max array index | `$LSB_JOBINDEX_END` | `$SLURM_ARRAY_TASK_MAX` |
| Allocated GPUs | `$LSB_GPU_ALLOC` | `$SLURM_GPUS_ON_NODE` |
| Temporary directory | `$LSB_TMPDIR` or `$TMPDIR` | `$TMPDIR` |

## SLURM-only variables worth knowing

These variables don't have direct LSF equivalents but are useful in SLURM scripts:

| Variable | Description |
|---|---|
| `$SLURM_CPUS_PER_TASK` | Number of CPUs allocated per task (set by `--cpus-per-task`) |
| `$SLURM_MEM_PER_NODE` | Memory allocated per node in MB |
| `$SLURM_ARRAY_TASK_MIN` | First index in the array |
| `$SLURM_ARRAY_TASK_STEP` | Step size between array indices |
| `$SLURM_ARRAY_TASK_COUNT` | Total number of tasks in the array |
| `$SLURM_JOB_NUM_NODES` | Number of nodes allocated |
| `$SLURM_NODELIST` | List of nodes allocated (compact format) |
| `$SLURM_GPUS` | Total number of GPUs allocated |

## Example: updating a script

=== "LSF"

    ```bash
    #!/bin/bash
    #BSUB -J myjob
    #BSUB -o logs/%J.out

    echo "Job $LSB_JOBID running on $LSB_HOSTS"
    echo "Working from $LSB_SUBCWD"
    echo "Using $LSB_DJOB_NUMPROC processors"

    cd $LSB_SUBCWD
    ./my_program --threads $LSB_DJOB_NUMPROC
    ```

=== "SLURM"

    ```bash
    #!/bin/bash
    #SBATCH --job-name=myjob
    #SBATCH --output=logs/%j.out

    echo "Job $SLURM_JOB_ID running on $SLURM_JOB_NODELIST"
    echo "Working from $SLURM_SUBMIT_DIR"
    echo "Using $SLURM_NTASKS processors"

    cd $SLURM_SUBMIT_DIR
    ./my_program --threads $SLURM_NTASKS
    ```

!!! tip "Search and replace"
    A quick way to catch variable references is to search your scripts for `LSB_`:

    ```bash
    grep -rn 'LSB_' *.sh
    ```

    The [converter script](conversion-script.md) handles the most common variable substitutions automatically.
