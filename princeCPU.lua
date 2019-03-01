#!/bin/env lua

local princeCPU = { }

local princeUtils = require "princeUtils"
local princeUsers = require "princeUsers"
local princeStakeholders = require "princeStakeholders"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local cpus = 0
local memory = 0
local nodes = 0

local ave_memory = nil

local partition_to_partition_group = { }

local partition_groups = {
   
   group_20_62_16 = { partitions = "c26,c27,c28,c29,c30,c31",
		      min_cpus = 1, max_cpus = 20, max_nodes = 16,
		      min_memory = 0, max_memory = 62,
		      min_ave_memory = 0, max_ave_memory = 6
   },
   
   group_28_125 = { partitions = "c01_17",
		    min_cpus = 1, max_cpus = 28, max_nodes = 68,
		    min_memory = 0, max_memory = 125,
		    min_ave_memory = 0, max_ave_memory = 20
   },
   
   group_28_250 = { partitions = "c18_25",
		    min_cpus = 1, max_cpus = 28, max_nodes = 32,
		    min_memory = 0, max_memory = 250,
		    min_ave_memory = 0, max_ave_memory = 100
   },	       
   
   group_28 = { partitions = "c01_25",
		min_cpus = 1, max_cpus = 28, max_nodes = 100,
		min_memory = 0, max_memory = 125,
		min_ave_memory = 0, max_ave_memory = 20
   },

   group_bigmem = { partitions = "bigmem",
		    min_cpus = 1, max_cpus = 48, max_nodes = 1,
		    min_memory = 50, max_memory = 1500,
		    min_ave_memory = 10, max_ave_memory = 1500
   },

   group_knl = { partitions = "knl",
		 min_cpus = 1, max_cpus = 64, max_nodes = 1,
		 min_memory = 0, max_memory = 186,
		 min_ave_memory = 0, max_ave_memory = 186
   },

   group_c32_38 = { partitions = "c32_38",
		    min_cpus = 1, max_cpus = 20, max_nodes = 112,
		    min_memory = 0, max_memory = 62,
		    min_ave_memory = 0, max_ave_memory = 6
   },

   group_c39_41 = { partitions = "c39_41",
		    min_cpus = 1, max_cpus = 20, max_nodes = 40,
		    min_memory = 0, max_memory = 188,
		    min_ave_memory = 0, max_ave_memory = 60,
   },

   group_c32_41 = { partitions = "c32_41",
		    min_cpus = 1, max_cpus = 20, max_nodes = 150,
		    min_memory = 0, max_memory = 62,
		    min_ave_memory = 0, max_ave_memory = 6
   },

   group_c42 = { partitions = "c42",
		 min_cpus = 1, max_cpus = 40, max_nodes = 4,
		 min_memory = 0, max_memory = 187.5,
		 min_ave_memory = 0, max_ave_memory = 20
   },
   
   xwang =  { partitions = "xwang_cpu",
	      min_cpus = 1, max_cpus = 28, max_nodes = 4,
	      min_memory = 0, max_memory = 250,
	      min_ave_memory = 0, max_ave_memory = 250,
	      users = princeStakeholders.cns_wang_users 
   },
   
   kussell =  { partitions = "kussell_cpu",
	       min_cpus = 1, max_cpus = 40, max_nodes = 4,
	       min_memory = 0, max_memory = 187.5,
	       min_ave_memory = 0, max_ave_memory = 187.5,
	       users = princeStakeholders.kussell_users
   }
}

local partition_group_names = { "xwang", "kussell",
				"group_c32_38",
				"group_c32_41",
				"group_c39_41",
				"group_20_62_16",
				"group_28_125",
				"group_28",
				"group_28_250",
				"group_c42",
				"group_bigmem"
}

local function setup_partition_to_partition_group()
   if not princeUtils.is_empty(partition_to_partition_group) then return end
   slurm_log("Setup partition to partition group")
   for key, val in pairs(partition_groups) do
      local tmp = princeUtils.split(val.partitions, ",")
      for i = 1, #tmp do
	 partition_to_partition_group[tmp[i]] = key
      end
   end
end

local function fit_into_partition_group(group_name)
   local group = partition_groups[group_name]
   if group ~= nil then
      if group.users ~= nil and not princeUtils.in_table(group.users, princeUsers.nyu_netid()) then
	 return false
      end
      if nodes <= group.max_nodes and
	 group.min_cpus <= cpus and cpus <= group.max_cpus and
	 group.min_memory <= memory and memory <= group.max_memory and
         group.min_ave_memory <= ave_memory and ave_memory <= group.max_ave_memory then
	    return true
      end
   end
   return false
end

local function partition_is_valid(part_name)
   setup_partition_to_partition_group()
   local group_name = partition_to_partition_group[part_name]
   if group_name ~= nil then
      return fit_into_partition_group(group_name)
   end
   return false
end

local function assign_partitions()
   if cpus == 28 and memory <= 125 then return "c01_17" end
   local partitions = nil
   for _, group_name in pairs(partition_group_names) do
      if fit_into_partition_group(group_name) then
	 if partitions == nil then
	    partitions = partition_groups[group_name].partitions
	 else
	    partitions = partitions .. "," .. partition_groups[group_name].partitions
	 end
      end
   end
   return partitions
end

local function extra_checks_are_valid()
   if 250 < memory and memory <= 500 and cpus > 20 then
      user_log("For job with memory between 250GB and 500GB per node, please request no more than 20 CPU cores per node")
      return false
   end

   return true
end

local function partitions_are_valid(partitions)
   if partitions == nil then
      user_log("No CPU partitions set")
      return false
   else
      for _, part_name in pairs(princeUtils.split(partitions, ",")) do
	 if not partition_is_valid(part_name) then
	    user_log("partition '%s' is not valid for this job", part_name)
	    return false
	 end
      end
   end
   if not extra_checks_are_valid() then return false end

   if cpus == 28 and memory <= 125 and partitions ~= "c01_17" then
      user_log("For jobs with 28 CPU cores and <= 125GB memory, please use c01_17 partition only")
      return false
   end
   
   return true
end

local function setup_parameters(args)
   cpus = args.cpus or 1
   memory = args.memory/1024 or 2 -- in GB only
   nodes = args.nodes or 1
   
   ave_memory = memory/cpus
end

-- functions

princeCPU.setup_parameters = setup_parameters
princeCPU.assign_partitions = assign_partitions
princeCPU.partitions_are_valid = partitions_are_valid

slurm_log("To load princeCPU.lua")

return princeCPU

