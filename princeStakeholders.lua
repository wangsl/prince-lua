#!/bin/env lua

local princeStakeholders = { }

local princeUtils = require "princeUtils"

local slurm_log = princeUtils.slurm_log

local cns_wang_users = { "xd432", "jj99", "bm98", "wwp3", "gy441",
			 "mj98", "jl9246", "mejmp20", "vg44", "ssf3",
			 "pz580", "dpb6" }

local mhealth_users = { "apd283", "kz918", "nn1119", "sb6065",
			"wc1144", "xz1364", "yg1053", "yj426", "asw462",
			"ns3807" }

local users_with_unlimited_wall_time = { "qhv200" }

local test_users = { "wang", "sw77", "deng", "wd35" }

-- data

princeStakeholders.cns_wang_users = cns_wang_users
princeStakeholders.mhealth_users = mhealth_users
princeStakeholders.test_users = test_users
princeStakeholders.users_with_unlimited_wall_time = users_with_unlimited_wall_time

slurm_log("To load princeStakeholders.lua")

return princeStakeholders

