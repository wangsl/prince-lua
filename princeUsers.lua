#!/bin/env lua

local princeUsers = { }

local princeUtils = require "princeUtils"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local users = { }
users["1015"] = "wang"
users["1032"] = "stratos"
users["1041"] = "deng"
users["1042"] = "peskin"
users["1044"] = "teague"
users["1045"] = "polunina"

local blocked_netids = { }

local netid = nil

local function create_users_from_etc_passwd()
   slurm_log("setup users from /etc/passwd")
   local passwd_file = "/etc/passwd"
   local fin = io.open(passwd_file, "r")
   if fin == nil then return end
   local netid, uid
   local n = 0
   while true do
      local line = fin:read("*l")
      if line == nil then break end
      _, _, netid, uid = string.find(line, "^(%a+%d+):x:(%d+):")
      if netid ~= nil and uid ~= nil then
	 users[uid] = netid
	 n = n + 1
      end
   end
   fin:close()
   slurm_log("%d netids in users", n)
end

local function uid_to_netid(uid)
   local uid = string.format("%d", uid)
   netid = users[uid]
   if netid == nil then
      create_users_from_etc_passwd()
      netid = users[uid]
   end
end

local function uid_is_valid(uid)
   uid_to_netid(uid)
   if netid == nil then
      user_log("uid %d is not valid to run jobs", uid)
      return false
   end
   return true
end

local function netid_is_blocked(uid)
   if not uid_is_valid(uid) then return true end
   if #blocked_netids > 0 and princeUtils.in_table(blocked_netids, netid) then
      slurm_log("user %s is blocked to submit jobs", netid)
      user_log("Sorry, you are not allowed to submit jobs now, please contact hpc@nyu.edu for help")
      return true
   end
   return false
end

local function nyu_netid()
   return netid
end

-- functions

princeUsers.nyu_netid = nyu_netid
princeUsers.netid_is_blocked = netid_is_blocked

slurm_log("To load princeUsers.lua")

return princeUsers

