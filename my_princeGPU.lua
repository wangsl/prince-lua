#!/bin/env lua

local my_princeGPU = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"
local princeStakeholders = require "princeStakeholders"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local requested_gpu_types = {} 

-- data

local job_desc = nil

local gpus = 0
local cpus = 0
local memory = 0
local gres_gpu_types = nil

-- predefined constant data

local available_gpu_types = { "k80", "p40", "p1080", "p100" }

local customized_gpu_types = { fp64 = { "p100" },
			       fp32 = { "p40", "p1080" },
			       all = available_gpu_types
			     }

local valid_gres_gpu_types = { "k80", "p40", "p1080", "p100", "fp64", "fp32", "all" }

local partition_configures = {
   
   k80_4 = { gpu = "k80",
	     { gpus = 1, max_cpus = 7,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 21, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 }
   },
   
   k80_8 = { gpu = "k80",
	     { gpus = 1, max_cpus = 1, max_memory = 20 },
	     { gpus = 2, max_cpus = 2, max_memory = 40 },
	     { gpus = 3, max_cpus = 3, max_memory = 50 },
	     { gpus = 4, max_cpus = 4, max_memory = 60 },
	     { gpus = 5, max_cpus = 5, max_memory = 80 },
	     { gpus = 6, max_cpus = 6, max_memory = 90 },
	     { gpus = 7, max_cpus = 7, max_memory = 105 },
	     { gpus = 8, max_cpus = 8, max_memory = 120 }
   },
   
   p1080_4 = { gpu = "p1080",
	       { gpus = 1, max_cpus = 7,  max_memory = 50 },
	       { gpus = 2, max_cpus = 14, max_memory = 75 },
	       { gpus = 3, max_cpus = 21, max_memory = 100 },
	       { gpus = 4, max_cpus = 28, max_memory = 125 }
   },
   
   p40_4 = { gpu = "p40",
	     { gpus = 1, max_cpus = 7,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 21, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 }
   },

   p100_4 = { gpu = "p100",
	     { gpus = 1, max_cpus = 7,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 21, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 }
   },

   mhealth = { gpu = "p1080",
	       { gpus = 1, max_cpus = 7,  max_memory = 50 },
	       { gpus = 2, max_cpus = 14, max_memory = 75 },
	       { gpus = 3, max_cpus = 21, max_memory = 100 },
	       { gpus = 4, max_cpus = 28, max_memory = 125 },
	       users = princeStakeholders.mhealth_users 
   },

   xwang_gpu = { gpu = "p40",
	     { gpus = 1, max_cpus = 7,  max_memory = 100 },
	     { gpus = 2, max_cpus = 14, max_memory = 150 },
	     { gpus = 3, max_cpus = 21, max_memory = 200 },
	     { gpus = 4, max_cpus = 28, max_memory = 250 },
	     users = princeStakeholders.cns_wang_users 
   },
}

local partitions = { "xwang_gpu", "mhealth",
		     "k80_8", "k80_4", "p40_4", "p1080_4", "p100_4" }

local function gres_for_gpus(gres)
   
   local gpu_types = nil
   local n_gpus = 0
   
   if gres == nil or gres == '' then
      return gpu_types, n_gpus
   end
   
   local tmp = princeUtils.split(gres, ":")
   
   if tmp[1] == "gpu" then
      if #tmp > 3 then
	 gpu_types = nil
	 n_gpus = 0
      elseif #tmp == 3 then
	 gpu_types = tmp[2]
	 n_gpus = tmp[3]
      elseif #tmp == 2 then
	 if tmp[2]:match("^%d+$") then
	    gpu_types = nil
	    n_gpus = tmp[2]
	 else
	    gpu_types = tmp[2]
	    n_gpus = 1
	 end
      elseif #tmp == 1 then
	 gpu_types = nil
	 n_gpus = 1
      end
   else
      gpu_types = nil
      n_gpus = 0
      user_log("GPU gres '%s' error", gres)
   end
   
   if n_gpus == nil then
      n_gpus = 0
   elseif n_gpus == '' then
      n_gpus = 1
   end
   
   n_gpus = tonumber(n_gpus)

   return gpu_types, n_gpus
end

local function gres_gpu_is_valid(gres)
   local gpu_types, n_gpus = gres_for_gpus(gres)
   if n_gpus <= 0 then
      user_log('GPU count is less than 1, it is %d', n_gpus)
      return false
   end

   local val = nil
   for _, val in pairs(princeUtils.split(gpu_types, ",")) do
      if not princeUtils.in_table(valid_gres_gpu_types, val) then
	 user_log("Invalid GPU type, '%s'", val)
	 return false
      end
   end
   
   return true
end

function generate_requested_gpu_types()

   requested_gpu_types = {} 

   if gpus == 0 then return; end
   
   if gres_gpu_types == nil and gpus > 0 then gres_gpu_types = "all" end
   
   local val = nil
   for _, val in pairs(princeUtils.split(gres_gpu_types, ",")) do
      if customized_gpu_types[val] ~= nil then
	 local val_ = nil
	 for _, val_ in pairs(customized_gpu_types[val]) do
	    princeUtils.insert_to_table_if_not_exist(requested_gpu_types, val_)
	 end
      else
	 princeUtils.insert_to_table_if_not_exist(requested_gpu_types, val)
      end
   end
end

--[[
local function gpu_types_are_valid()
   local gpu_type = nil
   for _, gpu_type in pairs(requested_gpu_types) do
      if not princeUtils.in_table(available_gpu_types, gpu_type) then
	 user_log("GPU type '%s' is invalid", gpu_type)
	 return false
      end
   end
   return true
end
--]]

local function fit_into_partition(part_name, gpu_type)
   local partition_conf = partition_configures[part_name]
   if partition_conf ~= nil then
      if gpu_type ~= nil and gpu_type ~= partition_conf.gpu then return false end
      if partition_conf.users ~= nil and
         not princeUtils.in_table(partition_conf.users, princeUsers.nyu_netid()) then
	    return false
      end
      local conf = partition_conf[gpus]
      if conf ~= nil and cpus <= conf.max_cpus and memory <= conf.max_memory then
	 return true
      end
   end
   return false
end

local function partition_is_valid(part_name, gpu_type)
   return fit_into_partition(part_name, gpu_type)
end

local function assign_partitions()
   local partitions_ = nil
   local part_name = nil
   for _, part_name in pairs(partitions) do
      local gpu_type = nil
      for _, gpu_type in pairs(requested_gpu_types) do
	 if fit_into_partition(part_name, gpu_type) then
	    if partitions_ == nil then
	       partitions_ = part_name
	    else
	       partitions_ = partitions_ .. "," .. part_name
	    end
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
      local part_name = nil
      for _, part_name in pairs(princeUtils.split(partitions_, ",")) do
	 if not princeUtils.in_table(partitions, part_name) then
	    user_log("Partition '%s' is not available for GPU jobs", part_name)
	    return false
	 end

	 --[[
	 local gpu_type = nil
	 for _, gpu_type in pairs(requested_gpu_types) do
	    if not partition_is_valid(part_name, gpu_type) then
	       user_log("Partition '%s' is not valid for this GPU job", part_name)
	       return false
	    end
	 end
	 --]]
      end
   end
   return true
end

local function foo()

   if job_desc == nil then return false end

   slurm_log("gres = %s", job_desc.gres)

   slurm_log("gpus = %d", gpus)
   
   local val = nil
   for _, val in pairs(requested_gpu_types) do
      slurm_log(val)
   end

   -- job_desc.gres = "gpu"

   -- job_desc.partition = assign_partitions()

   if job_desc.partition == nil then
      user_log("No GPU partitions assigned")
      return false
   end

   slurm_log("partition: %s", job_desc.partition)

   slurm_log("gres = %s", job_desc.gres)

   return true
   
end

local function setup_parameters(args)
   job_desc = args.job_desc
   gpus = args.gpus --or 1
   cpus = args.cpus or 1
   memory = args.memory/1024 or 2 -- in GB
   gres_gpu_types = args.gres_gpu_types or nil

   if gpus > 0 then generate_requested_gpu_types(); end
end

-- exported functions

my_princeGPU.setup_parameters = setup_parameters
my_princeGPU.gres_for_gpus = gres_for_gpus
my_princeGPU.gres_gpu_is_valid = gres_gpu_is_valid

my_princeGPU.assign_partitions = assign_partitions

my_princeGPU.foo = foo

slurm_log("To load my_princeGPU.lua")

return my_princeGPU
