#!/bin/env lua

local princeGPU = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

-- data

local gpus = 0
local cpus = 0
local memory = 0
local gpu_type = nil

local available_gpu_types = { "k80", "p1080"  }

local partition_configures = {
   
   k80_4 = { gpu = "k80",
	     users = { },
	     { gpus = 1, max_cpus = 7,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 21, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 }
   },
   
   k80_8 = { gpu = "k80",
	     users = { },
	     { gpus = 1, max_cpus = 1, max_memory = 15 },
	     { gpus = 2, max_cpus = 2, max_memory = 30 },
	     { gpus = 3, max_cpus = 3, max_memory = 45 },
	     { gpus = 4, max_cpus = 4, max_memory = 60 },
	     { gpus = 5, max_cpus = 5, max_memory = 75 },
	     { gpus = 6, max_cpus = 6, max_memory = 90 },
	     { gpus = 7, max_cpus = 7, max_memory = 105 },
	     { gpus = 8, max_cpus = 8, max_memory = 120 }
   },
   
   p1080_4 = { gpu = "p1080",
	       users = { },
	       { gpus = 1, max_cpus = 7,  max_memory = 50 },
	       { gpus = 2, max_cpus = 14, max_memory = 75 },
	       { gpus = 3, max_cpus = 21, max_memory = 100 },
	       { gpus = 4, max_cpus = 28, max_memory = 125 }
   }
}

local partitions = { "k80_8", "k80_4", "p1080_4" }

local function gpu_type_is_valid(gpu_type_)
   if gpu_type_ == nil then return true end
   if not princeUtils.in_table(available_gpu_types, gpu_type_) then
      user_log("GPU type '%s' is not valid", gpu_type_)
      return false
   else
      return true
   end
end

local function gres_for_gpu(gres)
   local gpu_type = nil
   local gpus = 1
   
   local tmp = princeUtils.split(gres, ":")
   
   if tmp[1] == "gpu" then
      if #tmp > 3 then
	 gpus = nil
      elseif #tmp == 3 then
	 gpu_type = tmp[2]
	 gpus = tmp[3]
      elseif #tmp == 2 then
	 if tmp[2]:match("^%d+$") then
	    gpus = tmp[2]
	 else
	    gpu_type = tmp[2]
	 end
      end
   else
      gpus = nil
      user_log("GPU gres '%s' error", gres)
   end

   if not gpu_type_is_valid(gpu_type) then
      user_log("Invalid GPU type: %s", gpu_type)
   end
   
   if gpus ~= nil then gpus = tonumber(gpus) end
   
   return gpu_type, gpus
end

local function fit_into_partition(part_name)
   local partition_conf = partition_configures[part_name]
   if partition_conf ~= nil then
      if gpu_type ~= nil and gpu_type ~= partition_conf.gpu then return false end
      if #partition_conf.users > 0 and not princeUtils.in_table(partition_conf.users, princeUsers.nyu_netid()) then
	 return false
      end

      local conf = partition_conf[gpus]
      if conf ~= nil and cpus <= conf.max_cpus and memory <= conf.max_memory then
	 return true
      end
   end
   return false
end

local function partition_is_valid(part_name)
   return fit_into_partition(part_name)
end

local function assign_partitions()
   local partitions_ = nil
   for _, part_name in pairs(partitions) do
      if fit_into_partition(part_name) then
	 if partitions_ == nil then
	    partitions_ = part_name
	 else
	    partitions_ = partitions_ .. "," .. part_name
	 end
      end
   end
   return partitions_
end

local function partitions_are_valid(partitions_)
   if partitions_ == nil then
      user_log("No GPU partitions defined")
      return false
   else
      for _, part_name in pairs(princeUtils.split(partitions_, ",")) do
	 if not princeUtils.in_table(partitions, part_name) then
	    user_log("Partition '%s' is not available for GPU jobs", part_name)
	    return false
	 end
	 if not partition_is_valid(part_name) then
	    user_log("Partition '%s' is not valid for this GPU job", part_name)
	    return false
	 end
      end
   end
   return true
end

local function setup_compute_resources(args)
   gpus = args.gpus or 1
   cpus = args.cpus or 1
   memory = args.memory/1024 or 2 -- in GB
   gpu_type = args.gpu_type or nil
   gpu_type_is_valid(gpu_type)
end

local function setup_parameters(args)
   setup_compute_resources(args)
end

-- exported functions

princeGPU.setup_parameters = setup_parameters
princeGPU.setup_compute_resources = setup_compute_resources
princeGPU.assign_partitions = assign_partitions
princeGPU.partitions_are_valid = partitions_are_valid
princeGPU.gpu_type_is_valid = gpu_type_is_valid
princeGPU.gres_for_gpu = gres_for_gpu

return princeGPU

