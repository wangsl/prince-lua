#!/bin/env lua

local princeQoS = { }

local princeUtils = require "princeUtils"

local two_days = princeUtils.two_days
local seven_days = princeUtils.seven_days

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local qos_all = {
   qos48 = {
      time_min = 0,
      time_max = two_days,
      users = { }
   },
   qos168 = {
      time_min = two_days,
      time_max = seven_days,
      users = { }
   },
   --[[
   qos48plus = {
      time_min = 0,
      time_max = two_days,
      users = { "RES", "sw77", "wang" }
   },
   --]]
   qos168plus = {
      time_min = two_days,
      time_max = seven_days,
      users = { "RES" }
   },
   sysadm = {
      time_min = 0,
      time_max = seven_days,
      users = { "RES" }
   },
   mhealth = {
      time_min = 0,
      time_max = two_days,
      users = { "RES", "ak6179", "apd283", "kz918", "nn1119", "sb6065",
                "wc1144", "xz1364", "yg1053", "yj426" }
   }
}

local time_limit = 0
local user_netid = nil

local function assign_qos()
   local qos = nil
   if time_limit <= princeUtils.two_days then
      qos = "qos48"
   elseif time_limit <= princeUtils.seven_days then
      qos = "qos168"
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
      if #users > 0 and not princeUtils.in_table(users, user_netid) then
	 user_log("No authorized QoS '%s'", qos_name)
	 return false
      end

      if time_limit <= qos.time_min or time_limit > qos.time_max then
	 user_log("Job time limit does not match QoS '%s', it should between %d and %d mins, job wall time is %d mins", qos_name, qos.time_min, qos.time_max, time_limit)
	 return false
      end
      
   end
   return true
end

local function setup_parameters(args)
   time_limit = args.time_limit or 1
   user_netid = args.user_netid or nil
end

-- functions 
princeQoS.setup_parameters = setup_parameters
princeQoS.assign_qos = assign_qos
princeQoS.qos_is_valid = qos_is_valid

return princeQoS
