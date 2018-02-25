#!/bin/env lua

local princePkgs = { }

local princeUtils = require "princeUtils"

local slurm_log = princeUtils.slurm_log
local user_log = princeUtils.user_log

local prince_pkgs_last_modification_time = { }

local function unload_new_updated_packages()
   local prefix = "/share/apps/admins/slurm-lua/"
   local pkgs = { "princeUtils.lua",
		  "princeUsers.lua",
		  "princeCPU.lua",
		  "princeGPU.lua",
		  "princeQoS.lua",
		  "princeJob.lua",
		  "princePkgs.lua", 
		  "prince.lua",
		  "princeKNL.lua",
		  "princeStakeholders.lua",
		  "princeReservation.lua",
		  "job_submit.lua"
   }
   
   local has_new_updated = false
   
   for _, pkg in pairs(pkgs) do
      local lua_file = prefix .. pkg
      local f = io.popen("stat -c %Y " .. lua_file)
      local last_modified = f:read()
      f:close()
      
      if prince_pkgs_last_modification_time[pkg] == nil then
	 prince_pkgs_last_modification_time[pkg] = last_modified
      else
	 if prince_pkgs_last_modification_time[pkg] < last_modified then
	    has_new_updated = true
	    prince_pkgs_last_modification_time[pkg] = last_modified
	    slurm.log_info("%s has new update", lua_file)
	 end
      end
   end

   -- to reload all the LUA packages, dependency issue
   if has_new_updated then
      for _, pkg in pairs(pkgs) do
	 local pkg_ = string.gsub(pkg, ".lua$", "")
	 package.loaded[pkg_] = nil
      end
   end
end

princePkgs.unload_new_updated_packages = unload_new_updated_packages

slurm_log("To load princePkgs.lua")

return princePkgs

