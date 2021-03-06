#!/bin/env lua

local princeGPU = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"
local princeStakeholders = require "princeStakeholders"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

-- data

local gpus = 0
local cpus = 0
local memory = 0
local gpu_type = nil
local time_limit = 0

local available_gpu_types = { "k80", "p1080", "p100", "p40", "v100" }

local partition_configures = {
   
   k80_4 = { gpu = "k80",
	     { gpus = 1, max_cpus = 12,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 24, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 }
   },
   
   k80_8 = { gpu = "k80",
	     { gpus = 1, max_cpus = 2, max_memory = 30 },
	     { gpus = 2, max_cpus = 4, max_memory = 40 },
	     { gpus = 3, max_cpus = 5, max_memory = 50 },
	     { gpus = 4, max_cpus = 6, max_memory = 60 },
	     { gpus = 5, max_cpus = 7, max_memory = 70 },
	     { gpus = 6, max_cpus = 8, max_memory = 90 },
	     { gpus = 7, max_cpus = 9, max_memory = 105 },
	     { gpus = 8, max_cpus = 10, max_memory = 120 }
   },
   
   p1080_4 = { gpu = "p1080",
	       { gpus = 1, max_cpus = 12,  max_memory = 50 },
	       { gpus = 2, max_cpus = 14, max_memory = 75 },
	       { gpus = 3, max_cpus = 24, max_memory = 100 },
	       { gpus = 4, max_cpus = 28, max_memory = 125 }
   },
   
   p40_4 = { gpu = "p40",
	     { gpus = 1, max_cpus = 12,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 24, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 }
   },

   p100_4 = { gpu = "p100",
	      { gpus = 1, max_cpus = 12,  max_memory = 100 },
	      { gpus = 2, max_cpus = 14, max_memory = 150 },
	      { gpus = 3, max_cpus = 24, max_memory = 200 },
	      { gpus = 4, max_cpus = 28, max_memory = 250 }
   },
   
   v100_sxm2_4 = { gpu = "v100",
		   { gpus = 1, max_cpus = 12,  max_memory = 256 },
		   { gpus = 2, max_cpus = 14, max_memory = 325 },
		   { gpus = 3, max_cpus = 18, max_memory = 350 },
		   { gpus = 4, max_cpus = 20, max_memory = 375 }
   },

   v100_pci_2 = { gpu = "v100",
	     { gpus = 1, max_cpus = 20,  max_memory = 150 },
	     --{ gpus = 2, max_cpus = 40, max_memory = 185 }
   },

   dgx1 = { gpu = "v100",
	    { gpus = 1, max_cpus = 10,  max_memory = 250 },
	    { gpus = 2, max_cpus = 15,  max_memory = 300 },
	    { gpus = 3, max_cpus = 18,  max_memory = 350 },
	    { gpus = 4, max_cpus = 20,  max_memory = 400 },
	    { gpus = 5, max_cpus = 30,  max_memory = 425 },
	    { gpus = 6, max_cpus = 35,  max_memory = 450 },
	    { gpus = 7, max_cpus = 38,  max_memory = 475 },
	    { gpus = 8, max_cpus = 40,  max_memory = 500 },
   },

   v100_sxm2_4_2 = { gpu = "v100",
		     { gpus = 1, max_cpus = 16,  max_memory = 256 },
		     { gpus = 2, max_cpus = 20, max_memory = 325 },
		     { gpus = 3, max_cpus = 36, max_memory = 350 },
		     { gpus = 4, max_cpus = 40, max_memory = 375 },
		     time_limit = princeUtils.hours_to_mins(12)
   },

   mhealth = { gpu = "p1080",
	       { gpus = 1, max_cpus = 12,  max_memory = 50 },
	       { gpus = 2, max_cpus = 14, max_memory = 75 },
	       { gpus = 3, max_cpus = 21, max_memory = 100 },
	       { gpus = 4, max_cpus = 28, max_memory = 125 },
	       users = princeStakeholders.mhealth_users 
   },

   xwang_gpu = { gpu = "p40",
	     { gpus = 1, max_cpus = 12,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 24, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 },
	     users = princeStakeholders.cns_wang_users 
   },
   
   simoncelli_gpu = { gpu = "v100",
		      { gpus = 1, max_cpus = 16,  max_memory = 256 },
		      { gpus = 2, max_cpus = 20, max_memory = 325 },
		      { gpus = 3, max_cpus = 36, max_memory = 350 },
		      { gpus = 4, max_cpus = 40, max_memory = 375 },
		      users = princeStakeholders.simoncelli_users
   },
}

local partitions = { "xwang_gpu", "simoncelli_gpu", "mhealth",
		     "p40_4", "p1080_4", "p100_4",
		     "v100_pci_2", "v100_sxm2_4", "dgx1", 
		     "k80_8", "k80_4", "v100_sxm2_4_2" }

local function gpu_type_is_valid(gpu_type)
   if gpu_type == nil then return true end

   --[[
   if gpu_type == "k80" then
      user_log("k80 cards are not available now")
      return false
   end
   --]]
   
   if princeUtils.in_table(available_gpu_types, gpu_type) then
      return true
   else
      user_log("GPU type '%s' is invalid", gpu_type)
      return false
   end
end

local function gres_for_gpu(gres)
   local gpu_type = nil
   local gpus = 0
   
   local tmp = princeUtils.split(gres, ":")
   
   if tmp[1] == "gpu" then
      if #tmp > 3 then
	 gpus = 0
	 gpu_type = nil
      elseif #tmp == 3 then
	 gpu_type = tmp[2]
	 gpus = tmp[3]
      elseif #tmp == 2 then
	 if tmp[2]:match("^%d+$") then
	    gpus = tmp[2]
	    gpu_type = nil
	 else
	   gpus = 1
	   gpu_type = tmp[2]
	 end
      elseif #tmp == 1 then
	 gpus = 1
	 gpu_type = nil
      end
   else
      gpus = nil
      gpu_type = nil
      user_log("GPU gres '%s' error", gres)
   end

   if gpus ~= nil then gpus = tonumber(gpus) end

   return gpu_type, gpus
end

local function gpu_type_from_gres_is_valid(gres)
   local gpu_type, _ = gres_for_gpu(gres)
   return gpu_type_is_valid(gpu_type)
end

local function number_of_cpus_is_ge_than_number_of_gpus()
   if cpus >= gpus then
      return true
   else
      user_log("GPU number %d is bigger than CPU number %d", gpus, cpus)
      return false
   end
end

local function fit_into_partition(part_name)
   local partition_conf = partition_configures[part_name]
   if partition_conf ~= nil then
      if gpu_type ~= nil and gpu_type ~= partition_conf.gpu then return false end
      if partition_conf.users ~= nil and
         not princeUtils.in_table(partition_conf.users, princeUsers.nyu_netid()) then
	    return false
      end

      if partition_conf.time_limit ~= nil and time_limit > partition_conf.time_limit then
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
      user_log("No GPU partitions set")
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

local function setup_parameters(args)
   gpus = args.gpus -- or 1
   cpus = args.cpus or 1
   memory = args.memory/1024 or 2 -- in GB
   gpu_type = args.gpu_type or nil
   time_limit = args.time_limit
   -- slurm_log("**** time_limit: %d", time_limit)
end

-- exported functions

princeGPU.gres_for_gpu = gres_for_gpu
princeGPU.gpu_type_from_gres_is_valid = gpu_type_from_gres_is_valid
princeGPU.number_of_cpus_is_ge_than_number_of_gpus = number_of_cpus_is_ge_than_number_of_gpus

princeGPU.setup_parameters = setup_parameters
princeGPU.assign_partitions = assign_partitions
princeGPU.partitions_are_valid = partitions_are_valid

slurm_log("To load princeGPU.lua")

return princeGPU


