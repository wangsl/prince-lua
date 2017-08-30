#!/bin/env lua

local princeKNL = { }

local princeUtils = require "princeUtils"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local job_desc = nil

local function compute_node_is_OK()
   if job_desc.req_nodes ~= nil and job_desc.req_nodes == "phi-01-02" and
      job_desc.pn_min_memory > 186*1024 then
      user_log("Memory declaration can not be more than 186GB with phi-01-02")
      return false
   end
   return true
end

local function setup_parameters_and_check_is_OK(job_desc_)
   job_desc = job_desc_
   
   if job_desc.req_nodes ~= nil then slurm_log("req_nodes: %s", job_desc.req_nodes) end
   
   if not compute_node_is_OK() then return false end

   --job_desc.shared = 0

   job_desc.qos = "knl"
   slurm_log("QoS is reset to: %s", job_desc.qos)
   
   return true
end

-- functions

princeKNL.setup_parameters_and_check_is_OK = setup_parameters_and_check_is_OK

slurm_log("To load princeKNL")

return princeKNL

