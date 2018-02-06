#!/bin/env lua

local princeQoS = { }

local princeUtils = require "princeUtils"
local princeStakeholders = require "princeStakeholders"

local two_days = princeUtils.two_days
local seven_days = princeUtils.seven_days
local unlimited_time = princeUtils.unlimited_time

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local qos_all = {

   cpu48 = {
      time_min = 0,
      time_max = two_days
   },
   
   cpu168 = {
      time_min = two_days,
      time_max = seven_days
   },
   
   gpu48 = {
      time_min = 0,
      time_max = two_days
   },
   
   gpu168 = {
      time_min = two_days,
      time_max = seven_days
   },

   gpu48 = {
      time_min = 0,
      time_max = two_days
   },

   -- special QoS with user access control
   
   cpuplus = {
      time_min = 0,
      time_max = seven_days,
      users = { "rg187" }
   },

   cpu365 = {
      time_min = seven_days,
      time_max = unlimited_time,
      users = princeStakeholders.users_with_unlimited_wall_time
   },

   gpuplus = {
      time_min = 0,
      time_max = seven_days,
      users = { "ar2922" }
   },

   knl = {
      time_min = 0,
      time_max = seven_days,
      users = { }
   },

   sysadm = {
      time_min = 0,
      time_max = seven_days,
      users = { "wang" }
   }
}

local time_limit = 0
local user_netid = nil
local gpu_job = false

local function assign_qos()
   local qos = nil
   if time_limit <= princeUtils.two_days then
      if gpu_job then qos = "gpu48" else qos = "cpu48" end
   elseif time_limit <= princeUtils.seven_days then
      if gpu_job then qos = "gpu168" else qos = "cpu168" end
   end
   return qos
end

local function qos_is_valid(qos_name)
   if qos_name == nil then
      user_log("No QoS setup")
      return false
   end

   if user_netid == nil then
      user_log("No user netid available")
      return false
   end

   local qos = qos_all[qos_name]
   if qos == nil then
      user_log("QoS '%s' is not valid", qos_name)
      return false
   else
      local users = qos.users
      if users ~= nil and not princeUtils.in_table(users, user_netid) then
	 user_log("No authorized QoS '%s'", qos_name)
	 return false
      end

      if qos_name == "sysadm" then return true end
      
      if gpu_job then
	 if string.sub(qos_name, 1, 3) ~= "gpu" then
	    user_log("Invalid QoS '%s' for GPU jobs", qos_name)
	    return false
	 end
      else
	 if string.sub(qos_name, 1, 3) ~= "cpu" then
	    user_log("Invalid QoS '%s' for CPU jobs", qos_name)
	    return false
	 end
      end

      if time_limit <= qos.time_min or time_limit > qos.time_max then
	 user_log("Job time limit does not match QoS '%s', it should between %d and %d mins, job wall time is %d mins",
		  qos_name, qos.time_min, qos.time_max, time_limit)
	 return false
      end
      
   end
   return true
end

local function setup_parameters(args)
   time_limit = args.time_limit or 1
   user_netid = args.user_netid or nil
   gpu_job = args.gpu_job or false
end

-- functions 
princeQoS.setup_parameters = setup_parameters
princeQoS.assign_qos = assign_qos
princeQoS.qos_is_valid = qos_is_valid

slurm_log("To load princeQoS.lua")

return princeQoS

