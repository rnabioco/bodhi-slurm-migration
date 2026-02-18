# Common Pain Points

This page covers recurring issues that Bodhi users encounter when migrating from LSF to SLURM. These aren't simple directive swaps — they're behavioral differences that catch people off guard.

---

## Debugging OOM (Out-of-Memory) errors

### How OOM kills look in SLURM

When a job exceeds its memory allocation, SLURM kills it immediately. The job state is set to `OUT_OF_MEMORY`:

```bash
$ sacct -j 12345 --format=JobID,JobName,State,ExitCode,MaxRSS
JobID           JobName      State ExitCode     MaxRSS
------------ ---------- ---------- -------- ----------
12345          analysis OUT_OF_ME+      0:125
12345.batch       batch OUT_OF_ME+      0:125    15.8G
```

You can also see this with `seff`:

```bash
$ seff 12345
Job ID: 12345
State: OUT_OF_MEMORY (exit code 0)
Memory Utilized: 15.80 GB
Memory Efficiency: 98.75% of 16.00 GB
```

!!! warning "This is different from LSF"
    On Bodhi's LSF, memory limits were often **soft limits** — jobs could exceed their requested memory without being killed (as long as the node had memory available). In SLURM, `--mem` is a **hard limit** enforced by cgroups. If your job exceeds it, even briefly, it will be killed.

### Diagnosing memory usage

**For completed jobs**, use `sacct`:

```bash
# Check peak memory usage
sacct -j <jobid> --format=JobID,JobName,MaxRSS,MaxVMSize,State

# For array jobs, check all tasks
sacct -j <jobid> --format=JobID%20,JobName,MaxRSS,State
```

**For running jobs**, use `sstat`:

```bash
# Monitor memory of a running job
sstat -j <jobid> --format=JobID,MaxRSS,MaxVMSize
```

!!! tip "Use `seff` for quick checks"
    `seff <jobid>` gives a one-line summary of memory efficiency for completed jobs. It's the fastest way to check if your job was close to its memory limit.

### Fixing OOM errors

1. **Check what your job actually used** — run `seff <jobid>` on a similar completed job to see actual peak memory.

2. **Request more memory with headroom** — add 20–30% buffer above the observed peak:

    ```bash
    #SBATCH --mem=20G   # if your job peaked at ~15 GB
    ```

3. **Use `--mem-per-cpu` for multi-threaded jobs** — if your job scales memory with cores:

    ```bash
    #SBATCH --cpus-per-task=8
    #SBATCH --mem-per-cpu=4G   # 32 GB total
    ```

<!-- TODO: verify default --mem value on Bodhi if no --mem is specified -->

!!! note "Don't just request the maximum"
    Requesting far more memory than you need reduces scheduling priority and wastes cluster resources. Right-size your requests based on actual usage from `seff`.

---

## Understanding SLURM accounts

### What is `--account`?

In SLURM, the `--account` flag associates your job with a resource allocation account. This is used for:

- **Fair-share scheduling** — accounts that have used fewer resources recently get higher priority
- **Resource tracking** — PIs and admins can see how allocations are consumed
- **Access control** — some partitions may be restricted to certain accounts

!!! warning "Why this matters on Bodhi"
    On LSF, the `-P` project flag was often optional or had a simple default. On SLURM, submitting with the wrong account (or no account) can result in job rejection or lower scheduling priority.

### Finding your account(s)

```bash
# List your SLURM associations (accounts and partitions you can use)
sacctmgr show associations user=$USER format=Account,Partition,QOS

# Shorter version — just account names
sacctmgr show associations user=$USER format=Account --noheader | sort -u
```

<!-- TODO: verify what Bodhi accounts look like — are they PI-based (e.g., "hesselj"), lab-based (e.g., "rbi"), or project-based? -->

### Setting a default account

Rather than adding `--account` to every script, set a default:

```bash
# Set your default account (persists across sessions)
sacctmgr modify user $USER set DefaultAccount=<your_account>
```

You can also add it to your `~/.bashrc` or a SLURM defaults file:

```bash
# In ~/.bashrc
export SBATCH_ACCOUNT=<your_account>
export SRUN_ACCOUNT=<your_account>
```

!!! tip "Check your default"
    ```bash
    sacctmgr show user $USER format=DefaultAccount
    ```

### In your job scripts

```bash
#SBATCH --account=<your_account>
```

<!-- TODO: verify if --account is required on Bodhi or if there's a cluster-wide default -->

---

## Paying attention to wall time

### SLURM enforces `--time` strictly

In SLURM, the `--time` (wall time) limit is a **hard cutoff**. When your job hits the limit:

1. SLURM sends `SIGTERM` to your job (giving it a chance to clean up)
2. After a short grace period<!-- TODO: verify grace period on Bodhi — typically 30-60 seconds -->, SLURM sends `SIGKILL`
3. The job state is set to `TIMEOUT`

```bash
$ sacct -j 12345 --format=JobID,JobName,Elapsed,Timelimit,State
JobID           JobName    Elapsed  Timelimit      State
------------ ---------- ---------- ---------- ----------
12345          longrun   02:00:00   02:00:00    TIMEOUT
```

!!! warning "This is different from LSF"
    On Bodhi's LSF, wall-time limits were often loosely enforced — jobs could sometimes run past their `-W` limit. In SLURM, when your time is up, your job is killed. Period.

### Checking remaining time

**From outside the job:**

```bash
# See time limit and elapsed time
squeue -u $USER -o "%.10i %.20j %.10M %.10l %.6D %R"
#                              Elapsed ^  ^ Limit

# Detailed view
scontrol show job <jobid> | grep -E "RunTime|TimeLimit"
```

**From inside the job** (in your script):

```bash
# Remaining time in seconds — useful for checkpointing
squeue -j $SLURM_JOB_ID -h -o "%L"
```

### Consequences of TIMEOUT

- Your job output may be incomplete or corrupted
- Any files being written at kill time may be truncated
- Temporary files won't be cleaned up

!!! tip "Add cleanup traps"
    If your job writes large intermediate files, add a trap to handle `SIGTERM`:

    ```bash
    cleanup() {
        echo "Job hit time limit — cleaning up"
        # save checkpoint, remove temp files, etc.
    }
    trap cleanup SIGTERM
    ```

### Bodhi partition time limits

<!-- TODO: verify these partition limits — values below are placeholders -->

| Partition | Max wall time | Default wall time | Notes |
|---|---|---|---|
| `short` | 4 hours | 1 hour | Quick jobs, higher priority |
| `normal` | 7 days | 1 hour | General-purpose |
| `long` | 30 days | 1 hour | Extended runs |
| `gpu` | 7 days | 1 hour | GPU jobs |
| `interactive` | 12 hours | 1 hour | Interactive sessions |

!!! note "Check current limits"
    Partition limits can change. Verify the current limits with:

    ```bash
    sinfo -o "%12P %10l %10L %6D %8c %10m"
    #            Name  TimeLimit  DefTime  Nodes  CPUs  Memory
    ```

### Tips for setting wall time

1. **Start with a generous estimate**, then refine based on actual runtimes using `seff` or `sacct`.

2. **Shorter jobs schedule faster** — SLURM's backfill scheduler can fit shorter jobs into gaps. Requesting 2 hours instead of 7 days can dramatically reduce queue wait time.

3. **Use `sacct` to check past runtimes:**

    ```bash
    sacct -u $USER --format=JobID,JobName,Elapsed,State -S 2024-01-01 | grep COMPLETED
    ```

4. **SLURM format for `--time`:**

    | Format | Meaning |
    |---|---|
    | `MM` | Minutes |
    | `HH:MM:SS` | Hours, minutes, seconds |
    | `D-HH:MM:SS` | Days, hours, minutes, seconds |
    | `D-HH` | Days and hours |

    ```bash
    #SBATCH --time=04:00:00      # 4 hours
    #SBATCH --time=1-00:00:00    # 1 day
    #SBATCH --time=7-00:00:00    # 7 days
    ```
