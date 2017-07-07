#!/bin/env lua

local princeJob = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"
local princeCPU = require "princeCPU"
local princeGPU = require "princeGPU"
local princeQoS = require "princeQoS"
 
local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

-- constants

local uint16_NO_VAL = slurm.NO_VAL16 
local uint32_NO_VAL = slurm.NO_VAL 
local uint64_NO_VAL = slurm.NO_VAL64

local bigIntNumber = 10240*slurm.NO_VAL

local job_desc = nil

local n_cpus_per_node = nil

local gpu_job = false

local function memory_is_specified(mem)
   if mem == nil or mem > bigIntNumber then
      return false
   end
   return true
end

local function input_compute_resources_are_valid()
   if job_desc.time_limit ~= uint32_NO_VAL and job_desc.time_limit > princeUtils.seven_days then
      user_log("Maximum wall time is %d days", princeUtils.seven_days/60/24)
      return false
   end

   if job_desc.gres ~= nil then
      if not princeGPU.gpu_type_from_gres_is_valid(job_desc.gres) then return false end
   end

   if job_desc.num_tasks ~= uint32_NO_VAL then
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
end

local function setup_gpu_job()
   local gpu_type = nil
   local gpus = 0
   if job_desc.gres ~= nil then
      gpu_type, gpus = princeGPU.gres_for_gpu(job_desc.gres)
   end

   if gpus > 0 then
      gpu_job = true
      princeGPU.setup_parameters{ gpus = gpus, cpus = n_cpus_per_node,
				  memory = job_desc.pn_min_memory,
				  gpu_type = gpu_type }
   else
      gpu_job = false
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
      specified_partitions, n_match = string.gsub(job_desc.partition, ",...$", "")
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
   princeQoS.setup_parameters{time_limit = job_desc.time_limit, user_netid = netid}
   if job_desc.qos == nil then job_desc.qos = princeQoS.assign_qos() end
end

local function compute_resources_are_valid()
   -- check QoS
   if not princeQoS.qos_is_valid(job_desc.qos) then return false end

   -- check partitions
   if gpu_job then
      if not princeGPU.partitions_are_valid(job_desc.partition) then return false end
   else
      if not princeCPU.partitions_are_valid(job_desc.partition) then return false end
   end

   return true
end
				   
local function setup_routings()     
   --print_job_desc()
   
   set_default_compute_resources()
   
   setup_gpu_job()

   if not gpu_job then
      princeCPU.setup_parameters{cpus = n_cpus_per_node, memory = job_desc.pn_min_memory,
				 nodes = job_desc.min_nodes }
   end

   assign_partitions()

   assign_qos()

   --print_job_desc()
end

local function setup_parameters(args)
   job_desc = args.job_desc or nil
end

-- functions

princeJob.setup_parameters = setup_parameters
princeJob.input_compute_resources_are_valid = input_compute_resources_are_valid 
princeJob.compute_resources_are_valid = compute_resources_are_valid

princeJob.setup_routings = setup_routings

return princeJob

