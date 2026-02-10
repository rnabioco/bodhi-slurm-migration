# Resources

External references and guides for SLURM and LSF-to-SLURM migration.

## Official SLURM documentation

- [SLURM Documentation](https://slurm.schedmd.com/documentation.html) — comprehensive reference for all SLURM commands and configuration
- [sbatch Manual](https://slurm.schedmd.com/sbatch.html) — all `#SBATCH` directives and `sbatch` options
- [srun Manual](https://slurm.schedmd.com/srun.html) — interactive and parallel job launch
- [Job Array Support](https://slurm.schedmd.com/job_array.html) — detailed job array documentation
- [sacct Manual](https://slurm.schedmd.com/sacct.html) — job accounting and history

## Migration guides

- [SchedMD Rosetta Stone](https://slurm.schedmd.com/rosetta.pdf) — the official PBS/LSF/SLURM command comparison (PDF)
- [LLNL SLURM Tutorials](https://hpc.llnl.gov/banks-jobs/running-jobs/slurm) — Lawrence Livermore National Laboratory's SLURM guides
- [ETH Zurich LSF to SLURM](https://scicomp.ethz.ch/wiki/LSF_to_Slurm_quick_reference) — concise migration quick reference
- [FIU LSF to SLURM](https://ircc.fiu.edu/lsf-to-slurm/) — Florida International University's migration guide

## Cheat sheets

- [SLURM Quick Reference (PDF)](https://slurm.schedmd.com/pdfs/summary.pdf) — two-page command summary
- [SLURM Command Comparison](https://slurm.schedmd.com/rosetta.html) — web version of the Rosetta Stone

## Tools

- [IBM lsf-slurm-wrappers](https://github.com/IBM/lsf-slurm-wrappers) — drop-in wrapper scripts that translate LSF commands to SLURM equivalents in real time
- [`lsf2slurm.sh`](conversion-script.md) — this project's sed-based directive converter

## SLURM tips for LSF users

!!! tip "Key mindset shifts"

    1. **No input redirection**: Use `sbatch script.sh`, not `sbatch < script.sh`
    2. **Time format**: SLURM prefers `HH:MM:SS` or `D-HH:MM:SS`; bare minutes are not standard
    3. **Memory suffixes**: Use `--mem=4G` instead of bare numbers to be explicit about units
    4. **`seff` for efficiency**: After jobs complete, run `seff <jobid>` to see how well you utilized your allocation
    5. **`squeue` formatting**: Customize with `--format` or set `SQUEUE_FORMAT` in your `.bashrc`
    6. **Default output**: SLURM writes to `slurm-<jobid>.out` by default (LSF uses `LSFJOB_<jobid>/`)
