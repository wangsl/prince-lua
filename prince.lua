#!/bin/env lua

local prince = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"
local princeJob = require "princeJob"
local time = require "time"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local function job_submission(job_desc, part_list, submit_uid)

   --[[
   -- for HPC maintainance 
   if submit_uid > 1050 then
      if submit_uid ~= 1296493 and submit_uid ~= 2761180 then
	 user_log("Prince is in maintennance today from 9am to 5pm, job submission is disabled")
	 return slurm.ERROR
      end
   end
   --]]

   local time_start = time.getMicroseconds()
   
   if princeUsers.netid_is_blocked(submit_uid) then return slurm.ERROR end
   
   princeJob.setup_parameters{job_desc = job_desc}
   
   if not princeJob.input_compute_resources_are_valid() then return slurm.ERROR end
   
   princeJob.setup_routings()

   if not princeJob.compute_resources_are_valid() then return slurm.ERROR end

   local time_end = time.getMicroseconds()

   slurm_log("Lua job submission plugin time %d usec for %s",
	     (time_end - time_start)*10^6, princeUsers.nyu_netid())

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

slurm_log("To load prince.lua")

return prince



