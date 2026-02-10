# Job Arrays

Job arrays are one of the areas where LSF and SLURM differ the most. This page covers the syntax changes, index variable differences, and common pitfalls.

## Syntax comparison

| Feature | LSF | SLURM |
|---|---|---|
| Basic array | `#BSUB -J "myJob[1-100]"` | `#SBATCH --array=1-100` |
| With step | `#BSUB -J "myJob[1-100:2]"` | `#SBATCH --array=1-100:2` |
| Specific indices | `#BSUB -J "myJob[1,3,5,7]"` | `#SBATCH --array=1,3,5,7` |
| Concurrency limit | `#BSUB -J "myJob[1-100]%10"` | `#SBATCH --array=1-100%10` |
| Index variable | `$LSB_JOBINDEX` | `$SLURM_ARRAY_TASK_ID` |

!!! warning "Array index starts"
    Both LSF and SLURM support arbitrary start indices. However, if your LSF arrays start at `0`, double-check that your code handles index `0` correctly — some tools expect 1-based indexing.

## Index variable change

This is the most critical change. Everywhere your script uses `$LSB_JOBINDEX`, replace it with `$SLURM_ARRAY_TASK_ID`.

=== "LSF"

    ```bash
    #!/bin/bash
    #BSUB -J "process[1-50]"
    #BSUB -o logs/process.%J.%I.out

    SAMPLE=$(sed -n "${LSB_JOBINDEX}p" samples.txt)
    echo "Processing sample $SAMPLE (index $LSB_JOBINDEX)"
    ```

=== "SLURM"

    ```bash
    #!/bin/bash
    #SBATCH --job-name=process
    #SBATCH --array=1-50
    #SBATCH --output=logs/process.%A.%a.out

    SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" samples.txt)
    echo "Processing sample $SAMPLE (index $SLURM_ARRAY_TASK_ID)"
    ```

## Array specification options

SLURM's `--array` flag is flexible:

```bash
# Range
#SBATCH --array=1-100

# Range with step
#SBATCH --array=0-20:5          # 0, 5, 10, 15, 20

# Explicit list
#SBATCH --array=1,4,7,22

# Range with concurrency limit (max 10 running at once)
#SBATCH --array=1-1000%10

# Combined range and list (SLURM only)
#SBATCH --array=1-5,10,15-20
```

## Output file naming

For array jobs, use `%A` (array job ID) and `%a` (array task index) in output filenames:

```bash
#SBATCH --output=logs/%x.%A.%a.out    # jobname.jobid.taskindex.out
#SBATCH --error=logs/%x.%A.%a.err
```

| LSF pattern | SLURM pattern | Expands to |
|---|---|---|
| `%J` (in array job) | `%A` | Parent array job ID |
| `%I` | `%a` | Array task index |

## Best practices

1. **Always set a concurrency limit** with `%N` to avoid overwhelming the scheduler or shared resources:
   ```bash
   #SBATCH --array=1-1000%50
   ```

2. **Use meaningful output filenames** that include both the job ID and array index:
   ```bash
   #SBATCH --output=logs/%x_%A_%a.out
   ```

3. **Test with a small range first** before submitting large arrays:
   ```bash
   #SBATCH --array=1-3    # test
   # then change to --array=1-1000%50
   ```

## Common pitfalls

!!! danger "Output file clobbering"
    If you forget to include `%a` in the output filename, all array tasks will write to the same file and overwrite each other. Always include the array index in output filenames for array jobs.

!!! warning "Max array size"
    SLURM clusters have a maximum array size limit (often 1000 or 10000, set by `MaxArraySize` in `slurm.conf`). If you need more tasks than the limit, split into multiple submissions or use a wrapper script. Check the limit with:

    ```bash
    scontrol show config | grep MaxArraySize
    ```

!!! note "Concurrency limit syntax"
    The `%N` concurrency limit goes at the end of the `--array` spec. `--array=1-100%10` means indices 1–100 with at most 10 running simultaneously. This is identical to LSF's syntax — one thing that didn't change!
