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
   
   if not princeJob.input_compute_resources_are_valid() then return slurm.ERROR end
   
   princeJob.setup_routings()

   if not princeJob.compute_resources_are_valid() then return slurm.ERROR end

   return slurm.SUCCESS
end

-- only root is allowed to modify jobs

local function job_modification(job_desc, job_recd, part_list, modify_uid)
   if modify_uid == 0 then return slurm.SUCCESS end
   return slurm.ERROR
end

-- functions

prince.job_submission = job_submission
prince.job_modification = job_modification

return prince
