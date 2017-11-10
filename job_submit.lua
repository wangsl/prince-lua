#!/bin/env lua

--[[
   
   Example lua script demonstrating the SLURM job_submit/lua interface.
   This is only an example, not meant for use in its current form.
   
   Leave the function names, arguments, local variables and setmetatable
   set up logic in each function unchanged. Change only the logic after
   the line containing "*** YOUR LOGIC GOES BELOW ***".
   
   For use, this script should be copied into a file name "job_submit.lua"
   in the same directory as the SLURM configuration file, slurm.conf.
   
--]]

function slurm_job_submit(job_desc, part_list, submit_uid)

   package.path = ';/share/apps/admins/slurm-lua/?.lua;' .. package.path
   package.cpath = ';/share/apps/admins/slurm-lua/?.so;' .. package.cpath
   
   -- local princePkgs = require "princePkgs"
   -- princePkgs.unload_new_updated_packages()
   
   local prince = require "prince"
   return prince.job_submission(job_desc, part_list, submit_uid)
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
   if modify_uid == 0 then
      return slurm.SUCCESS
   else
      return slurm.ERROR
   end
end

slurm.log_info("**** SLURM Lua plugin initialized with Lua version %s ****", _VERSION)

return slurm.SUCCESS


