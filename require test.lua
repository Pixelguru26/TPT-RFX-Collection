-- ==========================================
-- Library import
-- ==========================================

-- mniip's download thing (mostly)
local pattern = "http://w*%.?(.-)(/.*)"
local function download_file(url)
	if not http then
		print("TPT 95.0 or greater required to use http api")
		return false
	end
	local req = http.get(url)
	local timeout_after = socket.gettime() + 3
	while true do
		local status = req:status()
		if status ~= "running" then
			local body, status_code = req:finish()
			if status_code and status_code ~= 200 then
				print("http download failed with status code " .. status_code)
				return nil
			end
			return body
		end

		if socket.gettime() > timeout_after then
			print("http download timed out")
			req:cancel()
			return
		end
	end
end
-- downloads to a location
local function download_to(source,location)
	local file = download_file(source)
	if file then
		f=io.open(location,"w")
		f:write(file)
		f:close()
		return true
	end
	return false
end

local function endswith(str, suffix)
	return str:sub(-string.len(suffix)) == suffix
end

local function download_lib(source, location)
	if tpt.confirm("Missing Library", "This script requires the library [["..location.."]] to work. It can be downloaded from [["..source.."]], would you like to do this automatically?") then
		return download_to(source, location)
	end
	return false
end

local function safereq(dir, source)
	local status, out = pcall(require, dir)
	if status then
		return out
	else
		status = download_lib(source, endswith(dir,".lua") and dir or dir..".lua")
		if status then
			status, out = pcall(require, dir)
			if status then
				return out
			else
				print(out)
			end
		else
			print("download err/cancellation")
		end
	end
end

-- ==========================================
-- Example
-- ==========================================

local serpent = safereq("lib/serpent", "https://raw.githubusercontent.com/pkulchenko/serpent/master/src/serpent.lua")

if serpent then

end