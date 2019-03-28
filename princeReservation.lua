#!/bin/env lua

local princeReservation = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local bigIntNumber = 10240*slurm.NO_VAL

local function memory_is_specified(mem)
   if mem == nil or mem > bigIntNumber then
      return false
   else
      return true
   end
end

local job_desc = nil

local function check_reservation_morari_is_OK()
   local res_name = "morari"
   slurm_log("Reservation: %s", res_name)
   
   if job_desc.reservation ~= "morari" then return false end

   if job_desc.min_nodes ~= uint32_NO_VAL then
      if job_desc.min_nodes ~= 1 then
	 user_log("Reservation morari: please specify: --nodes=1")
	 return false
      end
   end
   
   if job_desc.time_limit > 30 then
      user_log("Reservation morari: time limit 30 mins")
      return false
   end
   
   if job_desc.shared ~= 0 then
      user_log("Reservation morari: please specify: --exclusive")
      return false
   end
   
   if job_desc.gres == nil then
      -- CPU only jobs
      
      if memory_is_specified(job_desc.pn_min_memory) and job_desc.pn_min_memory > 62*1024 then
	 user_log("Reservation morari: maximum memory for CPU only job is 62GB")
	 return false
      end
      
      if job_desc.cpus_per_task ~= uint16_NO_VAL then
	 if job_desc.cpus_per_task ~= 20 then
	    user_log("Reservation morari: --cpus-per-task=20")
	    return false
	 end
      end
      
      if job_desc.partition ~= nil then
	 if job_desc.partition ~= "c26" then
	    user_log("Reservation morari: --partition=c26")
	    return false
	 end
      else
	 job_desc.partition = "c26"
      end
   else
      -- GPU jobs

      if job_desc.gres ~= "gpu:k80:4" then
	 user_log("Reservation morari: --gres=gpu:k80:4")
	 return false
      end
      
      if memory_is_specified(job_desc.pn_min_memory) and job_desc.pn_min_memory > 250*1024 then
	 user_log("Reservation morari: maximum memory for GPU only job is 250GB")
	 return false
      end
      
      if job_desc.cpus_per_task ~= uint16_NO_VAL then
	 if job_desc.cpus_per_task ~= 28 then
	    user_log("Reservation morari: --cpus-per-task=28")
	    return false
	 end
      end
      
      if job_desc.partition ~= nil then
	 if job_desc.partition ~= "k80_4" then
	    user_log("Reservation morari: --partition=k80_4")
	    return false
	 end
      else
	 job_desc.partition = "k80_4"
      end
   end
   
   return true
end

local function check_reservation_jupyter_is_OK()
   local res_name = "jupyter"
   slurm_log("Reservation: %s", res_name)
   
   if job_desc.reservation ~= res_name then return false end

   if job_desc.min_nodes ~= uint32_NO_VAL then
      if job_desc.min_nodes ~= 1 then
	 user_log("Reservation jupyter: please specify: --nodes=1")
	 return false
      end
   end
   
   if job_desc.time_limit > 240 then
      user_log("Reservation jupyter: time limit 4 hours")
      return false
   end
   
   if memory_is_specified(job_desc.pn_min_memory) and job_desc.pn_min_memory > 3*1024 then
      user_log("Reservation jupyter: maximum memory for CPU only job is 3GB")
      return false
   end
   
   if job_desc.cpus_per_task ~= uint16_NO_VAL then
      if job_desc.cpus_per_task ~= 1 then
	 user_log("Reservation jupyter: --cpus-per-task=1")
	 return false
      end
   end
      
   if job_desc.partition ~= nil then
      if job_desc.partition ~= "c31" then
	 user_log("Reservation jupyter: --partition=c31")
	 return false
      end
   end

   return true
end

local function check_reservation_chung_is_OK()
   local res_name = "chung"
   slurm_log("Reservation: %s", res_name)

   -- if princeUsers.nyu_netid() ~= "wang" then return true end
   
   if job_desc.reservation ~= res_name then return false end
   
   if job_desc.min_nodes ~= uint32_NO_VAL then
      if job_desc.min_nodes ~= 1 then
	 user_log("Reservation chung: please specify: --nodes=1")
	 return false
      end
   end
   
   if job_desc.time_limit > 60 then
      user_log("Reservation chung: time limit 60 mins")
      return false
   end

   --[[
   if job_desc.shared ~= 0 then
      user_log("Reservation: please specify: --exclusive")
      return false
   end
   --]]
   
   if job_desc.gres == nil then return false end
   
   if job_desc.gres ~= "gpu:k80:4" and job_desc.gres ~= "gpu:p40:4"   then
      user_log("Reservation chung: --gres=gpu:k80:4 or --gres=gpu:p40:4")
      return false
   end
   
   if memory_is_specified(job_desc.pn_min_memory) and job_desc.pn_min_memory > 250*1024 then
      user_log("Reservation chung: maximum memory for GPU only job is 250GB")
      return false
   end
   
   if job_desc.cpus_per_task ~= uint16_NO_VAL then
      if job_desc.cpus_per_task ~= 28 then
	 user_log("Reservation morari: --cpus-per-task=28")
	 return false
      end
   end
   
   return true
end

local function check_reservation_is_OK(job_desc_)
   job_desc = job_desc_

   -- if job_desc.reservation == "morari" then return check_reservation_morari_is_OK() end

   if job_desc.reservation == "jupyter" then return check_reservation_jupyter_is_OK() end

   if job_desc.reservation == "chung" then return check_reservation_chung_is_OK() end
   
   return true
end

-- functions

princeReservation.check_reservation_is_OK = check_reservation_is_OK

slurm_log("To load princeReservation.lua")

return princeReservation


