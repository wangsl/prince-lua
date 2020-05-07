#!/bin/env lua

local princeReservation = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

-- local bigIntNumber = 10240*slurm.NO_VAL
local bigIntNumber = princeUtils.bigIntNumber

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

local function check_reservation_jupyter_cpu_is_OK()
   local res_name = "jupyter_cpu"
   slurm_log("Reservation: %s", res_name)
   
   if job_desc.reservation ~= res_name then return false end
   
   if job_desc.min_nodes ~= princeUtils.uint32_NO_VAL and job_desc.min_nodes ~= 1 then
      user_log("Reservation jupyter_cpu: please specify: --nodes=1")
      return false
   end
   
   if job_desc.time_limit ~= princeUtils.uint32_NO_VAL and job_desc.time_limit > 240 then
      user_log("Reservation jupyter_cpu: time limit 4 hours")
      return false
   end
   
   if memory_is_specified(job_desc.pn_min_memory) and job_desc.pn_min_memory > 4*1024 then
      user_log("Reservation jupyter_cpu: maximum memory for CPU only job is 4GB")
      return false
   end
   
   if job_desc.cpus_per_task ~= princeUtils.uint16_NO_VAL and job_desc.cpus_per_task > 4 then
      user_log("Reservation jupyter_cpu: --cpus-per-task=4")
      return false
   end
      
   if job_desc.partition ~= nil and job_desc.partition ~= "jupyterhub_cpu" then
      user_log("Reservation jupyter_cpu: --partition=jupyterhub_cpu")
      return false
   end

   return true
end

local function check_reservation_chung_is_OK()
   local res_name = "chung"
   slurm_log("Reservation: %s", res_name)

   if job_desc.reservation ~= res_name then return false end
   
   if job_desc.min_nodes ~= uint32_NO_VAL then
      if job_desc.min_nodes ~= 1 then
	 user_log("Reservation chung: please specify: --nodes=1")
	 return false
      end
   end
   
   if job_desc.time_limit > 240 then
      user_log("Reservation chung: time limit 240 mins")
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
	 user_log("Reservation chung: --cpus-per-task=28")
	 return false
      end
   end
   
   return true
end

local function check_reservation_zhang_is_OK()
   local res_name = "zhang"
   slurm_log("Reservation: %s", res_name)

   if job_desc.reservation ~= res_name then return false end
   
   if job_desc.min_nodes ~= uint32_NO_VAL then
      if job_desc.min_nodes ~= 1 then
	 user_log("Reservation zhang: please specify: --nodes=1")
	 return false
      end
   end

   --[[
   if job_desc.time_limit > 240 then
      user_log("Reservation zhang: time limit 240 mins")
      return false
   end
   --]]
   --[[
   if job_desc.shared ~= 0 then
      user_log("Reservation: please specify: --exclusive")
      return false
   end
   --]]
   
   if job_desc.gres == nil then return false end
   
   if job_desc.gres ~= "gpu:k80:8" then
      user_log("Reservation zhang: --gres=gpu:k80:8")
      return false
   end
   
   if memory_is_specified(job_desc.pn_min_memory) and job_desc.pn_min_memory ~= 120*1024 then
      user_log("Reservation zhang: --mem=120GB")
      return false
   end
   
   if job_desc.cpus_per_task ~= uint16_NO_VAL then
      if job_desc.cpus_per_task ~= 10 then
	 user_log("Reservation zhang: --cpus-per-task=10")
	 return false
      end
   end
   
   if job_desc.partition ~= nil and job_desc.partition ~= "k80_8" then
      user_log("Reservation zhang: --partition=k80_8")
      return false
   end

   return true
end

local function check_reservation_cds_courses_is_OK()
   local res_name = "cds-courses"
   slurm_log("Reservation: %s", res_name)

   if job_desc.reservation ~= res_name then return false end
   
   if job_desc.min_nodes ~= uint32_NO_VAL then
      if job_desc.min_nodes ~= 1 then
	 user_log("Reservation cds-courses: please specify: --nodes=1")
	 return false
      end
   end
   
   if job_desc.time_limit > 240 then
      user_log("Reservation cds-courses: time limit 240 mins")
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
      user_log("Reservation cds-courses: --gres=gpu:k80:4 or --gres=gpu:p40:4")
      return false
   end
   
   if memory_is_specified(job_desc.pn_min_memory) and job_desc.pn_min_memory > 250*1024 then
      user_log("Reservation cds-courses: maximum memory for GPU only job is 250GB")
      return false
   end
   
   if job_desc.cpus_per_task ~= uint16_NO_VAL then
      if job_desc.cpus_per_task ~= 28 then
	 user_log("Reservation cds-courses: --cpus-per-task=28")
	 return false
      end
   end
   
   return true
end

local function check_reservation_is_OK(job_desc_)
   job_desc = job_desc_

   -- if job_desc.reservation == "morari" then return check_reservation_morari_is_OK() end

   if job_desc.reservation == "jupyter_cpu" then return check_reservation_jupyter_cpu_is_OK() end

   if job_desc.reservation == "chung" then return check_reservation_chung_is_OK() end

   if job_desc.reservation == "zhang" then return check_reservation_zhang_is_OK() end

   if job_desc.reservation == "cds-courses" then return check_reservation_cds_courses_is_OK() end
   
   return true
end

-- functions

princeReservation.check_reservation_is_OK = check_reservation_is_OK

slurm_log("To load princeReservation.lua")

return princeReservation


