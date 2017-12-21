#!/bin/env lua

local princeUtils = { }

local two_days = 2880 -- in mins
local seven_days = 10080 -- in mins
local unlimited_time = 525600 -- one year in mins

local function mins_to_days(mins)
   return mins/60/24
end

local function split(s, delimiter)
   local result = {}
   for match in (s..delimiter):gmatch("(.-)"..delimiter) do
      table.insert(result, match)
   end
   return result
end

local function in_table(tbl, item)
   for _, value in pairs(tbl) do
      if value == item then return true end
   end
   return false
end

local function insert_to_table_if_not_exist(tbl, item)
   if not in_table(tbl, item) then table.insert(tbl, item) end
end

local function is_empty(t)
   for _, _ in pairs(t) do return false end
   return true
end

local function slurm_log(s, ...)
   return io.write(s:format(...), "\n")
end 

-- functions

princeUtils.split = split
princeUtils.in_table = in_table
princeUtils.insert_to_table_if_not_exist = insert_to_table_if_not_exist
princeUtils.is_empty = is_empty

princeUtils.mins_to_days = mins_to_days

-- data

princeUtils.two_days = two_days
princeUtils.seven_days = seven_days
princeUtils.unlimited_time = unlimited_time

-- princeUtils.slurm_log = slurm_log
-- princeUtils.user_log = slurm_log

princeUtils.slurm_log = slurm.log_info
princeUtils.user_log = slurm.log_user

princeUtils.slurm_log("To load princeUtils.lua")

return princeUtils

