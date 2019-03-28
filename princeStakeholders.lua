#!/bin/env lua

local princeStakeholders = { }

local princeUtils = require "princeUtils"

local slurm_log = princeUtils.slurm_log

local cns_wang_users = { "xd432", "jj99", "bm98", "wwp3", "gy441",
			 "mj98", "jl9246", "mejmp20", "vg44", "ssf3",
			 "pz580", "dpb6", " pt49", "upo201" }

local mhealth_users = { "apd283", "kz918", "nn1119", "sb6065",
			"wc1144", "xz1364", "yg1053", "yj426", "asw462",
			"ns3807", "as10656", "pa1303",
			"cm4698", "ic1018",  "jz2575", "gc2300" }

local kussell_users = { "elk2", "ml3365", "tn49", "as8805", "shg325" }

local users_with_unlimited_wall_time = { "sw77" }

local test_users = { "wang", "sw77", "deng", "wd35" }

-- users to request more than 1 GPU node per job
local special_gpu_users = { "wang" }

local blocked_netids = { }

-- data

princeStakeholders.cns_wang_users = cns_wang_users
princeStakeholders.mhealth_users = mhealth_users
princeStakeholders.kussell_users = kussell_users
princeStakeholders.test_users = test_users
princeStakeholders.users_with_unlimited_wall_time = users_with_unlimited_wall_time
princeStakeholders.blocked_netids = blocked_netids
princeStakeholders.special_gpu_users = special_gpu_users

slurm_log("To load princeStakeholders.lua")

return princeStakeholders


