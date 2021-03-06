#!/bin/env lua

local princeJob = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"
local princeCPU = require "princeCPU"
local princeGPU = require "princeGPU"
local princeQoS = require "princeQoS"
local princeKNL = require "princeKNL"
local princeStakeholders = require "princeStakeholders"

local princeReservation = require "princeReservation"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

-- constants

-- local uint16_NO_VAL = slurm.NO_VAL16 
-- local uint32_NO_VAL = slurm.NO_VAL 
-- local uint64_NO_VAL = slurm.NO_VAL64
-- local bigIntNumber = 10240*slurm.NO_VAL

local uint16_NO_VAL = princeUtils.uint16_NO_VAL
local uint32_NO_VAL = princeUtils.uint32_NO_VAL
local uint64_NO_VAL = princeUtils.uint64_NO_VAL

local bigIntNumber = princeUtils.bigIntNumber

local job_desc = nil

local n_cpus_per_node = nil

local gpu_job = false
local n_gpus_per_node = 0

local function memory_is_specified(mem)
   if mem == nil or mem > bigIntNumber then
      return false
   else
      return true
   end
end

local function input_compute_resources_are_valid()

  if not princeReservation.check_reservation_is_OK(job_desc) then return false; end

   if job_desc.time_limit ~= uint32_NO_VAL then
      
      if princeUtils.in_table(princeStakeholders.users_with_unlimited_wall_time, princeUsers.nyu_netid()) then
	 if job_desc.time_limit > princeUtils.unlimited_time then
	    user_log("Maximum wall time is %d days", princeUtils.mins_to_days(princeUtils.unlimited_time))
	    return false
	 end
      else
	 if job_desc.time_limit > princeUtils.seven_days then
	    user_log("Maximum wall time is %d days", princeUtils.mins_to_days(princeUtils.seven_days))
	    return false
	 end
      end
   end
   
   if job_desc.gres ~= nil then
      if not princeGPU.gpu_type_from_gres_is_valid(job_desc.gres) then return false end
   end

   if job_desc.num_tasks ~= uint32_NO_VAL and job_desc.ntasks_per_node == uint16_NO_VAL then
      user_log("Plase do not specify --ntasks on prince cluster, try to use --nodes and --tasks-per-node together")
      return false
   end
   
   return true
end

local function print_job_desc()
   slurm_log("")
   
   slurm_log("time_limit = %d", job_desc.time_limit)
   slurm_log("ntasks_per_node: %d", job_desc.ntasks_per_node)
   slurm_log("num_tasks = %d", job_desc.num_tasks)
   slurm_log("pn_min_cpus: %d", job_desc.pn_min_cpus)
   slurm_log("pn_min_memory: %d", job_desc.pn_min_memory)
   slurm_log("cpus_per_task: %d", job_desc.cpus_per_task)

   slurm_log("min_nodes: %d", job_desc.min_nodes)
   slurm_log("max_nodes: %d", job_desc.max_nodes)
   
   if memory_is_specified(job_desc.min_mem_per_cpu) then
      slurm_log("min_mem_per_cpu: %d", job_desc.min_mem_per_cpu)
   end
   
   if job_desc.qos ~= nil then slurm_log("job_desc.qos: %s", job_desc.qos) end
   
   if job_desc.mail_user ~= nil then slurm_log("mail_user: %s", job_desc.mail_user) end
   
   if job_desc.partition ~= nil then slurm_log("partitions: %s", job_desc.partition) end
   
   if job_desc.gres ~= nil then slurm_log("gres: %s", job_desc.gres) end

   if job_desc.features ~= nil then slurm_log("features: %s", job_desc.features) end
end

local function setup_gpu_job()
   gpu_job = false
   
   local gpu_type = nil
   local gpus = 0
   if job_desc.gres ~= nil then
      gpu_type, gpus = princeGPU.gres_for_gpu(job_desc.gres)
   end

   if gpus > 0 then
      gpu_job = true
      n_gpus_per_node = gpus
      princeGPU.setup_parameters{ gpus = gpus, cpus = n_cpus_per_node,
				  memory = job_desc.pn_min_memory,
				  time_limit = job_desc.time_limit,
				  gpu_type = gpu_type }
      
      if job_desc.bitflags == 0 then job_desc.bitflags = slurm.GRES_ENFORCE_BIND end
   end
end

local function set_default_compute_resources()

   if job_desc.mail_type ~= 0 and job_desc.mail_user == nil then
      local netid = princeUsers.nyu_netid()
      if string.find(netid, "^%a+%d+$") then
	 job_desc.mail_user = netid .. "@nyu.edu"
      end
   end

   if job_desc.time_limit == uint32_NO_VAL then job_desc.time_limit = 60 end

   if job_desc.cpus_per_task == uint16_NO_VAL then job_desc.cpus_per_task = 1 end
   
   if job_desc.pn_min_cpus == uint16_NO_VAL then job_desc.pn_min_cpus = 1 end
   
   if job_desc.ntasks_per_node == uint16_NO_VAL then job_desc.ntasks_per_node = 1 end
   
   n_cpus_per_node = job_desc.ntasks_per_node * job_desc.cpus_per_task
   
   if job_desc.min_nodes == uint32_NO_VAL then job_desc.min_nodes = 1 end

   
   if not memory_is_specified(job_desc.pn_min_memory) then
      if memory_is_specified(job_desc.min_mem_per_cpu) then
	 job_desc.pn_min_memory = job_desc.min_mem_per_cpu
      else
	 job_desc.pn_min_memory = 2048
      end
   end
end

local function assign_cpu_partitions()
   local partitions = princeCPU.assign_partitions()
   if partitions == nil then
      user_log("No proper CPU partitions found")
   end
   return partitions
end

local function assign_gpu_partitions()
   local partitions = princeGPU.assign_partitions()
   if partitions == nil then
      user_log("No proper GPU partitions found")
   end
   return partitions
end

local function assign_partitions()
   local specified_partitions = nil
   local to_append = false

   if job_desc.partition ~= nil then
      local n_match = nil
      specified_partitions, n_match = string.gsub(job_desc.partition, ",%.%.%.$", "")
      if n_match == 1 then to_append = true end
   end
   
   if job_desc.partition == nil or to_append then
      local partitions = nil
      if gpu_job then
	 partitions = assign_gpu_partitions()
      else
	 partitions = assign_cpu_partitions()
      end
      
      if to_append and partitions ~= nil then
	 partitions = specified_partitions .. "," .. partitions
      end

      if partitions ~= nil then
	 job_desc.partition = partitions
      else
	 user_log("No proper partition found")
      end
   end
end

local function assign_qos()
   local netid = princeUsers.nyu_netid()
   princeQoS.setup_parameters{time_limit = job_desc.time_limit, user_netid = netid, gpu_job = gpu_job}
   if job_desc.qos == nil then job_desc.qos = princeQoS.assign_qos() end
end

local function job_with_multiple_gpu_cards_is_ok()

   if princeUtils.in_table(princeStakeholders.special_gpu_users, princeUsers.nyu_netid()) then return true end

   if job_desc.min_nodes > 1 then
      user_log("GPU jobs with multiuple compute nodes are disabled by default, please contact hpc@nyu.edu for help")
      return false
   end

   --[[
   if n_gpus_per_node > 1 then
      user_log("GPU jobs with multiuple GPU cards per node are disabled by default, please contact hpc@nyu.edu for help")
      return false
   end
   --]]

   return true
end

local function compute_resources_are_valid()
   -- check QoS
   if not princeQoS.qos_is_valid(job_desc.qos) then return false end

   -- check request 0 memory

   if job_desc.pn_min_memory ~= nil and job_desc.pn_min_memory == 0 then
      user_log("please request nonzero amount of memory, such as --mem=1GB")
      return false
   end

   -- check partitions
   if gpu_job then
      if not princeGPU.number_of_cpus_is_ge_than_number_of_gpus() then return false end
      if not job_with_multiple_gpu_cards_is_ok() then return false end
      if not princeGPU.partitions_are_valid(job_desc.partition) then return false end
      
      if job_desc.reservation == nil and job_desc.shared ~= uint16_NO_VAL then
	 user_log("exclusive use GPU node is disabled on prince cluster")
	 return false
      end
      
   else
      if not princeCPU.partitions_are_valid(job_desc.partition) then return false end
   end
   
   if job_desc.partition == "knl" then
      if not princeKNL.setup_parameters_and_check_is_OK(job_desc) then return false end
   end
   
   if job_desc.partition ~= "knl" then
      local n_cpu_cores = job_desc.ntasks_per_node*job_desc.cpus_per_task*job_desc.min_nodes
      if n_cpu_cores > 100 and job_desc.qos == "cpu168" then
	 user_log("Single job with wall time longer than 48 hours can not use more than 100 CPU cores")
	 return false
      end
      
      if job_desc.num_tasks ~= uint32_NO_VAL then
	 n_cpu_cores = math.max(job_desc.num_tasks, n_cpu_cores)
      end
      
      if n_cpu_cores > 400 and job_desc.qos == "cpu48" then 
	 user_log("Single job with wall time less than 48 hours can not use more than 400 CPU cores")
	 return false
      end

      if n_cpu_cores > 100 and job_desc.qos == "cpu168" then 
	 user_log("Single job with wall time between 48 and 168 hours can not use more than 100 CPU cores")
	 return false
      end
      
   end

   if job_desc.shared ~= uint16_NO_VAL then slurm_log("shared = %d", job_desc.shared) end
   
   return true
end

local function setup_routings()     
   set_default_compute_resources()
   
   setup_gpu_job()

   if not gpu_job then
      princeCPU.setup_parameters{cpus = n_cpus_per_node,
				 memory = job_desc.pn_min_memory,
				 nodes = job_desc.min_nodes,
				 time_limit = job_desc.time_limit }
      
   end
   
   assign_partitions()
   
   assign_qos()

   -- if princeUsers.nyu_netid() == "wang" then print_job_desc() end
   
   if job_desc.partition ~= nil then slurm_log("partitions: %s", job_desc.partition) end
   if job_desc.qos ~= nil then slurm_log("QoS: %s", job_desc.qos) end
   if job_desc.account ~= nil then slurm_log("account: %s", job_desc.account) end
end

local function setup_parameters(args)
   job_desc = args.job_desc or nil
end

-- functions

princeJob.setup_parameters = setup_parameters
princeJob.input_compute_resources_are_valid = input_compute_resources_are_valid 
princeJob.compute_resources_are_valid = compute_resources_are_valid

princeJob.setup_routings = setup_routings

slurm_log("To load princeJob.lua")

return princeJob


