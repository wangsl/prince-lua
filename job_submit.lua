--[[
   
   Example lua script demonstrating the SLURM job_submit/lua interface.
   This is only an example, not meant for use in its current form.
   
   Leave the function names, arguments, local variables and setmetatable
   set up logic in each function unchanged. Change only the logic after
   the line containing "*** YOUR LOGIC GOES BELOW ***".
   
   For use, this script should be copied into a file name "job_submit.lua"
   in the same directory as the SLURM configuration file, slurm.conf.
   
--]]

uint16_NO_VAL = slurm.NO_VAL16 
uint32_NO_VAL = slurm.NO_VAL 
unit64_NO_VAL = slurm.NO_VAL64

local bigIntNumber = 10240*slurm.NO_VAL

two_days = 2880
seven_days = 10080

USERS = { }
USERS["1015"] = "wang"
USERS["1032"] = "stratos"
USERS["1041"] = "deng"
USERS["1042"] = "peskin"
USERS["1044"] = "teague"
USERS["1045"] = "polunina"
USERS["14095"] = "beegfsadm"

-- blocked netIDs to submit jobs

blocked_netIDs = { }

-- QoS avaialble on prince

QOS = { }
QOS["normal"] = { }
QOS["qosgpu"] = { }
QOS["qos48"] = { }
QOS["qos168"] = { }

QOS["qos168plus"] = { "NONE" }

QOS["sysadm"] = { "NONE" }

QOS["mhealth"] = { "ak6179", "apd283", "kz918", "nn1119", "sb6065",
		   "wc1144", "xz1364", "yg1053", "yj426" }

local prince_pkgs_last_modification_time = {}

local function unload_new_updated_packages()
   local prefix = "/share/apps/admins/slurm-lua/"
   local pkgs = { "princeUtils.lua", "princeUsers.lua", "princeCPU.lua",
		  "princeGPU.lua", "princeQoS.lua", "princeJob.lua",
		  "prince.lua", "job_submit.lua",
		  "time.so" }

   local has_new_updated = false
   
   for _, pkg in pairs(pkgs) do
      local lua_file = prefix .. pkg -- .. ".lua"
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
	 local pkg_ = string.gsub(pkg, ".[a-z]+$", "")
	 package.loaded[pkg_] = nil
      end
   end
end

local function memory_is_specified(mem)
   if mem == nil then
      return false
   elseif mem > bigIntNumber then
      return false
   else
      return true
   end
end

local function in_table(tbl, item)
   for key, value in pairs(tbl) do
      if value == item then return true end
   end
   return false
end

local function create_USERS_from_etc_passwd()
   slurm.log_info("setup USERS from /etc/passwd")
   local passwd_file = "/etc/passwd"
   local fin = io.open(passwd_file, "r")
   if fin == nil then return end
   local n = 0
   while true do
      local line = fin:read("*l")
      if line == nil then break end
      _, _, netID, UID = string.find(line, "^(%a+%d+):x:(%d+):")
      if netID ~= nil and UID ~= nil then
	 USERS[UID] = netID
	 n = n + 1
      end
   end
   fin:close()
   slurm.log_info("%d netIDs in USERS", n)
end

local function gres_gpus(gres)
   local gpu_type = nil
   local n_gpus = nil

   if gres == "gpu" then
      n_gpus = 1
   elseif gres == "gpu:k80" then
      gpu_type = "k80"
      n_gpus = 1
   elseif gres == "gpu:p1080" then
      gpu_type = "p1080"
      n_gpus = 1
   elseif gres:match("^gpu:(%d+)$") then
      n_gpus = gres:match("^gpu:(%d+)$")
   elseif gres:match("^gpu:(%S+):(%d+)$") then
      gpu_type, n_gpus = gres:match("^gpu:(%S+):(%d+)$")
   end
   
   return gpu_type, n_gpus
end

function slurm_job_submit(job_desc, part_list, submit_uid)

   if submit_uid == 1015 or submit_uid == 2761180 then
      unload_new_updated_packages()
      package.path = ';/share/apps/admins/slurm-lua/?.lua;' .. package.path
      package.cpath = ';/share/apps/admins/slurm-lua/?.so;' .. package.cpath 
      local prince = require "prince"
      return prince.job_submission(job_desc, part_list, submit_uid)
   end
   
   --[[
   local system_admin_account = false
   if 1010 < submit_uid and submit_uid < 2000 or submit_uid == 1296493 then
      system_admin_account = true
   end

   if not system_admin_account then
      slurm.log_user("Sorry, no job submission now")
      return slurm.ERROR
   end
   --]]

   local uid = tostring(math.floor(submit_uid))
   local netID = USERS[uid]
   if netID == nil then
      create_USERS_from_etc_passwd() 
      netID = USERS[uid]
   end
   if netID == nil then
      slurm.log_user("Something wrong with your account, please contact hpc@nyu.edu for help")
      return slurm.ERROR
   end

   -- check if user is blocked

   if #blocked_netIDs > 0 and in_table(blocked_netIDs, netID) then
      slurm.log_info("User %s is blocked to submit jobs", netID)
      slurm.log_user("Sorry, you are not allowed to submit jobs now, please contact hpc@nyu.edu for help")
      return slurm.ERROR
   end

    -- check valid QoS
   
   if job_desc.qos == "normal" or job_desc.qos == "qosgpu" then
      slurm.log_user("Please do not specify to use QoS normal or qosgpu")
      return slurm.ERROR
   end

   if job_desc.qos ~= nil then
      local qos = QOS[job_desc.qos] 
      if qos == nil then
	 slurm.log_user("Invalid QoS: --qos=%s", job_desc.qos)
	 return slurm.ERROR
      elseif #qos > 0 and not in_table(qos, netID) then
	 slurm.log_user("unauthorized QoS: --qos=%s", job_desc.qos)
	 return slurm.ERROR  
      end
   end

   -- set default values for CPU cores, memory and wall time limit
   -- single CPU core, 2GB memory and 1 hour
   -- if job_desc.tasks_per_node == uint16_NO_VAL then job_desc.tasks_per_node = 1 end
   if job_desc.pn_min_cpus == uint16_NO_VAL then job_desc.pn_min_cpus = 1 end
   -- if job_desc.pn_min_memory == unit64_NO_VAL then job_desc.pn_min_memory = 2048 end
   if job_desc.time_limit == uint32_NO_VAL then job_desc.time_limit = 60 end

   if not memory_is_specified(job_desc.pn_min_memory) then
      if memory_is_specified(job_desc.min_mem_per_cpu) then
	 job_desc.pn_min_memory = job_desc.min_mem_per_cpu
      else
	 job_desc.pn_min_memory = 2048
      end
   end

   -- setup default NYU email address
   if job_desc.mail_type ~= 0 and job_desc.mail_user == nil then
      if string.find(netID, "^%a+%d+$") then
	 job_desc.mail_user = netID .. "@nyu.edu"
      end
   end

   -- check wall time limit
   
   if job_desc.time_limit > seven_days then
      slurm.log_user("Maximum wall time %d hours", seven_days/60)
      return slurm.ERROR
   end

   -- check gres for GPU 
   
   local gpu_type = nil
   local n_gpus = nil
   if job_desc.gres ~= nil then
      
      gpu_type, n_gpus = gres_gpus(job_desc.gres)
	 
      if gpu_type == nil and n_gpus == nil then
	 slurm.log_user("gres for GPU error: --gres=%s", job_desc.gres)
	 return slurm.ERROR
      elseif gpu_type ~= nil and gpu_type ~= "k80" and gpu_type ~= "p1080" then
	 slurm.log_user("GPU card type error: --gres=%s", job_desc.gres)
	 return slurm.ERROR
      end
      
      if n_gpus ~= nil then
	 n_gpus = tonumber(n_gpus)
	 if n_gpus ~= nil and (n_gpus < 1 or n_gpus > 8) then
	    slurm.log_user("GPU card number should be between 1 and 8: --gres=%s", job_desc.gres)
	    return slurm.ERROR
	 end
      end
   end
   
   -- check if it is GPU job
   
   local gpu_job = false
   if n_gpus ~= nil then gpu_job = true end
   local cpu_job = not gpu_job

   -- CPU only job can not use gpu partition
   
   if cpu_job and job_desc.partition == "gpu" then
      slurm.log_user("No --gres=gpu specified, can not use gpu partition: --partition=%s", job_desc.partition)
      return slurm.ERROR
   end   

   -- check QoS and wall time

   if job_desc.qos == nil then
      if job_desc.time_limit <= two_days then
	 job_desc.qos = "qos48"
      elseif job_desc.time_limit <= seven_days then
	 job_desc.qos = "qos168"
      end
   elseif job_desc.qos == "qos48" then
      if job_desc.time_limit > two_days then
	 slurm.log_user("48 hours limit for qos48 only")
	 return slurm.ERROR
      end 
   elseif job_desc.qos == "qos168" then
      if job_desc.time_limit <= two_days then
	 slurm.log_user("qos168 for wall time longer than 48 hours only")
	 return slurm.ERROR
      end
   elseif job_desc.qos == "qos168plus" then
      if job_desc.time_limit <= two_days then
	 slurm.log_user("qos168plus for wall time longer than 48 hours only")
	 return slurm.ERROR
      end 
   end
   
   -- add partitions according to CPU cores and memory per node
   
   if cpu_job then
      
      if job_desc.partition == nil then
	 if job_desc.pn_min_memory > 250*1024 then
	    job_desc.partition = "bigmem"
	 elseif job_desc.pn_min_memory > 125*1024 then
	    job_desc.partition = "c01_25,bigmem"
	 else if job_desc.pn_min_cpus > 20 or job_desc.pn_min_memory > 60*1024 or 
	    job_desc.ntasks_per_node > 20 and job_desc.ntasks_per_node <= 28 then
	       job_desc.partition = "c01_25"
	      else
		 job_desc.partition = "c26,c27,c28,c29,c30,c31,c01_25"
	      end
	 end
      end
      
      if job_desc.partition:match("bigmem") and job_desc.pn_min_memory <= 125*1024 then
	 slurm.log_user("partition bigmem is for jobs with memory more than 125GB only")
	 return slurm.ERROR
      end
   end

   -- GPU jobs
   -- This limit will depend on GPU card number
   
   if gpu_job then
      
      if job_desc.pn_min_cpus > 8 then
	 slurm.log_user("GPU job with CPU cores <= 8 only: --gres=%s", job_desc.gres)
	 return slurm.ERROR
      end

      if gpu_type == "k80" then
	 if job_desc.pn_min_memory > 100*1024 then
	    slurm.log_user("GPU k80 job host memory <= 100GB only: --gres=%s", job_desc.gres)
	    return slurm.ERROR
	 end
      else
	 if job_desc.pn_min_memory > 50*1024 then
	    slurm.log_user("GPU job host memory <= 50GB only: --gres=%s", job_desc.gres)
	    return slurm.ERROR
	 end
      end

      -- gpu partition
      
      if gpu_type == nil or gpu_type == "k80" then
	 if job_desc.pn_min_memory <= 20*1024*n_gpus and job_desc.pn_min_cpus <= n_gpus then
	    if job_desc.partition == nil or job_desc.partition == "gpu" then
	       job_desc.partition = "k80_8,gpu"
	    end
	 end
      end
      
      if job_desc.partition == nil or job_desc.partition == "gpu" then
	 if job_desc.pn_min_cpus > n_gpus or job_desc.pn_min_memory > 20*1024*n_gpus then
	    job_desc.partition = "gpu"
	 else
	    job_desc.partition = "gpu,k80_8"
	 end
      end

      if job_desc.partition ~= nil and job_desc.partition:match("k80_8") then
	 if job_desc.pn_min_memory > 20*1024*n_gpus then
	    slurm.log_user("k80_8 partition with memory <= %dGB only", 20*1024*n_gpus)
	    return slurm.ERROR
	 end
	 
	 if job_desc.pn_min_cpus > n_gpus then
	    slurm.log_user("k80_8 partition with # of CPU cores <= # of GPU cards only")
	    return slurm.ERROR
	 end
      end
      
      if job_desc.bitflags == 0 then job_desc.bitflags = slurm.GRES_ENFORCE_BIND end
	 
   end
   
   return slurm.SUCCESS
end

function slurm_job_modify(job_desc, job_rec, part_list, modify_uid)
   if modify_uid == 0 then
      return slurm.SUCCESS
   elseif modify_uid == 1015 then
      package.path = ';/share/apps/admins/slurm-lua/?.lua;' .. package.path
      unload_new_updated_packages()
      local prince = require "prince"
      return prince.job_modification(job_desc, job_rec, part_list, modify_uid)
   else
      return slurm.ERROR
   end
end

slurm.log_info("**** SLURM Lua plugin initialized with Lua version %s ****", _VERSION)

create_USERS_from_etc_passwd()

return slurm.SUCCESS

