#!/bin/bash

set -x

srun hostname
srun --nodes=2 --tasks-per-node=2 hostname
srun --tasks-per-node=2 hostname
srun --nodes=2 hostname

srun --ntasks=4 hostname
srun --ntasks=4 --tasks-per-node=3 hostname
srun --ntasks=4 --tasks-per-node=2  hostname
srun --ntasks=4 --nodes=2 hostname

srun --gres=gpu hostname

srun --gres=gpu sh -c "env | grep SLURM_JOB_PARTITION; hostname"
srun --gres=gpu --partition=p1080_4  sh -c "env | grep SLURM_JOB_PARTITION; hostname"
srun --gres=gpu --partition=p1080_4,...  sh -c "env | grep SLURM_JOB_PARTITION; hostname"

srun --gres=gpu:2 --cpus-per-task=4 sh -c "env | grep SLURM_JOB_PARTITION; hostname"

srun --gres=gpu:2 --partition=k80_4,... --cpus-per-task=4 sh -c "env | grep SLURM_JOB_PARTITION; hostname"

srun --gres=gpu:2 --partition=k80_8,... --cpus-per-task=4 sh -c "env | grep SLURM_JOB_PARTITION; hostname"

