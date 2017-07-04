#!/bin/env lua

local prince = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"
local princeJob = require "princeJob"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local function job_submission(job_desc, part_list, submit_uid)
   
   if princeUsers.netid_is_blocked(submit_uid) then return slurm.ERROR end
   
   princeJob.setup_parameters{job_desc = job_desc}
   
   if not princeJob.wall_time_is_valid() then return slurm.ERROR end

   princeJob.setup_routings()

   if not princeJob.compute_resources_are_valid() then return slurm.ERROR end

   return slurm.SUCCESS
end

local function job_modification_test(job_desc, job_recd, part_list, modify_uid)
   slurm.log_info("Lua plugin for Prince job modification")
end

-- functions

prince.job_submission = job_submission
prince.job_modification_test = job_modification_test

return prince
