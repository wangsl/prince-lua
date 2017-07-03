#!/bin/env lua

local prince = { }

--local princeUtils = require "princeUtils"
--local princeJob = require "princeJob"
--local princeUsers = require "princeUsers"

--local slurm_log = princeUtils.slurm_log
--local user_log = princeUtils.user_log

--[[
-- package.path = ';/opt/slurm/etc/?.lua;' .. package.path

-- variables

local uint16_NO_VAL = slurm.NO_VAL16 
local uint32_NO_VAL = slurm.NO_VAL 
local uint64_NO_VAL = slurm.NO_VAL64

local bigIntNumber = 10240*slurm.NO_VAL

--

local two_days = 2880 -- in mins
local seven_days = 10080 -- in mins

local users = {}
users["1015"] = "wang"
users["1032"] = "stratos"
users["1041"] = "deng"
users["1042"] = "peskin"
users["1044"] = "teague"
users["1045"] = "polunina"

local blocked_netids = { }

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
   qos48plus = {
      time_min = 0,
      time_max = two_days,
      users = { "RES" }
   },
   qos168plus = {
      time_min = two_days,
      time_max = seven_days,
      users = { "RES" }
   },
   sysadm = {
      time_min = 0,
      time_max = seven_days,
      users = { "RES", "wang" }
   },
   mhealth = {
      time_min = 0,
      time_max = two_days,
      users = { "RES", "ak6179", "apd283", "kz918", "nn1119", "sb6065",
		"wc1144", "xz1364", "yg1053", "yj426" }
   }
}

local gpu_restraints = {
   k80 = {
      { gpus = 1, cpus = 7, memory = 100 },
      { gpus = 2, cpus = 14, memory = 150 },
      { gpus = 3, cpus = 21, memory = 200 },
      { gpus = 4, cpus = 28, memory = 250 },
      { gpus = 5, cpus = 5, memory = 75 },
      { gpus = 6, cpus = 6, memory = 90 },
      { gpus = 7, cpus = 7, memory = 105 },
      { gpus = 8, cpus = 8, memory = 120 },
   },
   
   p1080 = { 
      { gpus = 1, cpus = 7, memory = 50 },
      { gpus = 2, cpus = 14, memory = 75 },
      { gpus = 3, cpus = 21, memory = 100 },
      { gpus = 4, cpus = 28, memory = 125 },
   }
}

local gpu_partitions = {
   p1080_4 = { gpu = "p1080" },
   k80_4 = { },
   k80_8 = { }
}

local function check_gpus()
   -- local key, value

   if prince.gpu_type == nil then return true end
   
   local gpus = gpu_restraints[prince.gpu_type]

   if gpus == nil then
      slurm.log_user("GPUs wrong")
      return false
   end
   
   if prince.n_gpus > #gpus then
      slurm.log_user("GPU number is bigger than %d", #gpus)
      return false
   end
   
   local gpu = gpus[prince.n_gpus]

   if gpu == nil then
      slurm.log_user("GPU wrong")
      return false
   end
   
   if prince.job_desc.pn_min_memory > gpu.memory*1024 then
      slurm.log_user("GPU job with %d %s cards host memory <= %d only",
		     prince.n_gpus, prince.gpu_type, gpu.memory)
      return false
   end

   if prince.n_cpus_per_node > gpu.cpus then
      slurm.log_user("GPU job with %d %s cards with CPU cores <= %d only",
		     prince.n_gpus, prince.gpu_type, gpu.cpus)
      return false
   end
   
   return true
end

local function in_table(tbl, item)
   for key, value in pairs(tbl) do
      if value == item then return true end
   end
   return false
end

local function memory_is_specified(mem)
   if mem == nil or mem > bigIntNumber then
      return false
   else
      return true
   end
end

local function whether_to_reload_prince_lua()
   local f = io.popen("stat -c %Y /opt/slurm/etc/prince.lua")
   local last_modified = f:read()
   f:close()

   if prince_last_modification_time ~= nil and prince_last_modification_time == last_modified then
      return false
   else
      prince_last_modification_time = last_modified
      slurm.log_info("prince.lua last modification time: %s, will be reload", prince_last_modification_time)
      return true
   end
end

local function create_users_from_etc_passwd()
   slurm.log_info("setup users from /etc/passwd")
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
   slurm.log_info("%d netids in users", n)
end

local function gres_with_gpus(gres)
   local gpu_type = nil
   local n_gpus = 0
   
   if gres == "gpu" then
      n_gpus = 1
   elseif gres == "gpu:k80" then
      gpu_type = "k80"
      n_gpus = 1
   elseif gres == "gpu:p1080" then
      gpu_type = "p1080"
      n_gpus = 1
   elseif gres:match("^gpu:(%d+)$") then
      n_gpus = gres:match("^gpu:(%d+)$")
   elseif gres:match("^gpu:(%S+):(%d+)$") then
      gpu_type, n_gpus = gres:match("^gpu:(%S+):(%d+)$")
   end

   if type(n_gpus) == "string" then n_gpus = tonumber(n_gpus) end

   return gpu_type, n_gpus
end

local function uid_to_netid(uid)
   local uid_ = string.format("%d", uid)
   local netid = users[uid_]
   if netid == nil then
      create_users_from_etc_passwd()
      netid = users[uid_]
   end
   return netid
end

local function netid_is_blocked(uid)
   prince.netid = uid_to_netid(uid)
   if #blocked_netids > 0 and in_table(blocked_netids, prince.netid) then
      slurm.log_info("user %s is blocked to submit jobs", prince.netid)
      slurm.log_user("Sorry, you are not allowed to submit jobs now, please contact hpc@nyu.edu for help")
      return true
   end
   return false
end

local function wall_time_is_ok()
   if prince.job_desc.time_limit > seven_days then
      slurm.log_user("Maximum wall time is 168 hours")
      return false
   end
   return true
end

local function test_partition_list(part_list)
   local name, partition
   for name, partition in pairs(part_list) do
      slurm.log_info("Partition: %s %s", name, partition.nodes)
   end
end

local function set_default_compute_resources()
   if prince.job_desc.time_limit == uint32_NO_VAL then prince.job_desc.time_limit = 60 end
   if prince.job_desc.pn_min_cpus == uint16_NO_VAL then prince.job_desc.pn_min_cpus = 1 end
   if prince.job_desc.cpus_per_task == uint16_NO_VAL then prince.job_desc.cpus_per_task = 1 end
   if prince.job_desc.ntasks_per_node == uint16_NO_VAL then prince.job_desc.ntasks_per_node = 1 end

   if not memory_is_specified(prince.job_desc.pn_min_memory) then
      if memory_is_specified(prince.job_desc.min_mem_per_cpu) then
	 prince.job_desc.pn_min_memory = prince.job_desc.min_mem_per_cpu
      else
	 prince.job_desc.pn_min_memory = 2048
      end
   end

   if prince.job_desc.mail_type ~= 0 and prince.job_desc.mail_user == nil then
      if string.find(prince.netid, "^%a+%d+$") then
	 prince.job_desc.mail_user = prince.netid .. "@nyu.edu"
      end
   end
   
   prince.n_cpus_per_node = prince.job_desc.ntasks_per_node * prince.job_desc.cpus_per_task
end

local function parse_gres()
   prince.gpu_type = nil
   prince.n_gpus = 0
   if prince.job_desc.gres ~= nil then
      prince.gpu_type, prince.n_gpus = gres_with_gpus(prince.job_desc.gres)
   end

   slurm.log_info("n_gpus = %d\n", prince.n_gpus)

   prince.cpu_job = true
   prince.gpu_job = false

   if prince.n_gpus > 0 then
      prince.cpu_job = false
      prince.gpu_job = true
   end
end

local function assign_qos()
   if prince.job_desc.qos == nil then
      if prince.job_desc.time_limit <= two_days then
	 prince.job_desc.qos = "qos48"
      elseif prince.job_desc.time_limit <= seven_days then
	 prince.job_desc.qos = "qos168"
      end
   end
end

local function qos_is_valid()
   local qos_key = prince.job_desc.qos
   if qos_key == nil then
      slurm.log_user("No valid QoS set")
      return false
   else
      local qos_val = qos_all[qos_key]
      if qos_val == nil then
	 slurm.log_user("No valid QoS found, %s", qos_key)
	 return false
      end
      local qos_users = qos_val.users
      if #qos_users > 0 and not in_table(qos_users, prince.netid) then
	 slurm.log_user("No authorized Qos: %s", qos_key)
	 return false
      end

      if prince.job_desc.time_limit <= qos_val.time_min or prince.job_desc.time_limit > qos_val.time_max then
	 slurm.log_user("Job time limt and QoS time limit do not match: TimeLimit=%dmins, QoS %s TimeLimitMin=%d, TimeLimitMax=%d",
			prince.job_desc.time_limit, qos_key, qos_val.time_min, qos_val.time_max)
	 return false
      end
   end
   return true
end

local function gpu_gres_is_ok()
   return check_gpus()
end

local function assign_gpu_partion_p1080_4(part)
end

local function assign_gpu_partition_k80_4(part)
end

local function assign_gpu_partition_k80_8()
   if prince.n_cpus_per_node > prince.n_gpus then
      return nil
   end
   
   local part = nil
   if 4 < prince.n_gpus and prince.n_gpus <= 8 and prince.job_desc.pn_min_memory/prince.n_gpus <= 20*1024 then
      part = "k80_8"
   end

   return part
end

local function assign_gpu_partitions()
   if prince.job_desc.partition == "gpu" then
      slurm.log_user("Plese don't specify to use partition gpu")
      return false
   end

   local partition = ""
   
   local part = assign_gpu_partition_k80_8()
   if part ~= nil then partition = part end

   --if local ~= nil then prince.job_desc.partition = prince.job_desc.partition .. part

   prince.job_desc.partition = partition
end

local function assign_cpu_partitions()
    prince.job_desc.partition = "c01_25"
end

local function assign_partitions()
   if prince.cpu_job then assign_cpu_partitions() end
   if prince.gpu_job then assign_gpu_partitions() end
end
--]]

local function job_submission(job_desc, part_list, submit_uid)
   
   local princeUtils = require "princeUtils"
   local princeUsers = require "princeUsers"
   local princeJob = require "princeJob"
   
   local slurm_log = princeUtils.slurm_log
   local user_log = princeUtils.user_log
   
   -- slurm_log("Lua plugin for Prince job submission with Lua verison %s", _VERSION)

   -- if not princeUsers.uid_is_valid(submit_uid) then return slurm.ERROR end
   
   if princeUsers.netid_is_blocked(submit_uid) then return slurm.ERROR end
   
   princeJob.setup_parameters{job_desc = job_desc}
   
   if not princeJob.wall_time_is_valid() then return slurm.ERROR end
   princeJob.setup_routings()
   if not princeJob.compute_resources_are_valid() then return slurm.ERROR end

   --slurm.log_info("-- NetID: %s", princeUsers.uid_to_netid(submit_uid))
   --slurm.log_info("-- NetID: %s", princeUsers.uid_to_netid(1296493))

   -- prince.job_desc = job_desc

   --if netid_is_blocked(submit_uid) then return slurm.ERROR end

   --[[

   set_default_compute_resources()

   assign_qos()
   if not qos_is_valid() then return slurm.ERROR end

   parse_gres()
   if not gpu_gres_is_ok() then return slurm.ERROR end
   
   assign_partitions()

   slurm.log_info("NetID: %s", prince.netid)

   princeJob.my_test()

   slurm.log_info("job_desc.time_limit = %d", job_desc.time_limit)
   slurm.log_info("job_desc.ntasks_per_node: %d", job_desc.ntasks_per_node)
   slurm.log_info("job_desc.pn_min_cpus: %d", job_desc.pn_min_cpus)
   slurm.log_info("job_desc.pn_min_memory: %d", job_desc.pn_min_memory)
   slurm.log_info("job_desc.cpus_per_task: %d", job_desc.cpus_per_task)
   if memory_is_specified(job_desc.min_mem_per_cpu) then
      slurm.log_info("job_desc.min_mem_per_cpu: %d", job_desc.min_mem_per_cpu)
   end

   slurm.log_info("job_desc.qos: %s", job_desc.qos)

   if not wall_time_is_ok() then return slurm.ERROR end
   
   slurm.log_info("prince.n_cpus_per_node: %d", prince.n_cpus_per_node)

   slurm.log_info("job_desc.min_nodes: %d", prince.job_desc.min_nodes)

   if prince.job_desc.partition ~= nil then
      slurm.log_info("job_desc.partition: %s", prince.job_desc.partition)
   end

   if prince.job_desc.mail_user ~= nil then
      slurm.log_info("prince.job_desc.mail_user: %s", prince.job_desc.mail_user)
   end
   --]]
   return slurm.SUCCESS
end

local function job_modification_test(job_desc, job_recd, part_list, modify_uid)
   slurm.log_info("Lua plugin for Prince job modification")
   
end

-- functions

--prince.whether_to_reload_prince_lua = whether_to_reload_prince_lua
--prince.netid_is_blocked = netid_is_blocked

prince.job_submission = job_submission
prince.job_modification_test = job_modification_test

return prince
