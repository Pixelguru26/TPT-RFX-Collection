-- Pixel's deferred update script
-- Version 1.1

local debug_currentParticle = 0
local debug_mousex, debug_mousey = 0, 0
local jacobsmod = tpt.version.jacob1s_mod
local debugMode = true
if debugMode then
	tpt.setdebug(0x8)
end

-- ==========================================

-- Global library function, add this to your mod
slowticks = slowticks or {}
function slowticks.add(id, fn)
	if not slowticks[id] then
		slowticks[id] = {}
	end
	table.insert(slowticks[id], fn)
	return fn
end

-- Optional, because why would you ever use this
function slowticks.remove(id, fn)
	local ret
	if slowticks[id] then
		for i = #slowticks[id], 0, -1 do
			if slowticks[id][i] == fn then
				ret = table.remove(slowticks[id], i)
			end
		end
	end
	return ret
end

-- ==========================================

local slowticks = slowticks

local function tryStep(id, dt)
	local ptype = sim.partProperty(id, sim.FIELD_TYPE)
	local status, err
	if ptype and slowticks[ptype] then
		local x, y = sim.partPosition(id)
		for i,v in ipairs(slowticks[ptype]) do
			status, err = pcall(v, dt, id, x, y, ptype)
			if not status then
				print(err)
			end
		end
	end
end

local updateRoutine = coroutine.create(function()
	-- Local variables used in loop
	local reps = 0
	local subreps = 0
	-- Delta ticks (performance compensation system)
	-- dt acts as an estimate of how many update ticks were skipped per callback
	local dt, newdt = 1, 1
	-- Main loop
	while true do
		dt = newdt
		newdt = 1
		if sim.NUM_PARTS > 0 then
			-- Main update
			subreps = 0
			for id in sim.parts() do
				-- Yield after one scan line and at least one particle
				if reps > 1 and reps > sim.NUM_PARTS / sim.YRES then
					reps = 0
					newdt = newdt + 1
					coroutine.yield()
				end

				-- Call appropriate function if applicable
				tryStep(id, dt)

				reps = reps + 1
				subreps = subreps + 1
			end
			-- Protects against an incredibly strange case involving FIGH
			if subreps < 1 then
				coroutine.yield()
			end
		else
			-- Halt loop in case of empty parts array
			newdt = newdt + 1
			coroutine.yield()
		end
	end
end)

event.register(event.tick, function()
	if tpt.set_pause() == 0 or sim.framerender() > 0 then -- I can't find a better way to detect simulation pausing
		-- print("UPDATE", os.clock())
		coroutine.resume(updateRoutine)
	end
end)

local function particleDebug(mode, x, y)
	-- Largely translated from ParticleDebug.cpp
	local i = 0
	if mode then
		i = sim.partID(x, y)
		if (x < 0 or x > sim.XRES or y < 0 or y > sim.YRES or i < debug_currentParticle) then
			i = sim.XRES*sim.YRES
			print("(slowtick) Ticking particles from #"..debug_currentParticle.." to end.")
		else
			print("(slowtick) Ticking particles #"..debug_currentParticle.." - #"..i)
		end
	else
		if sim.NUM_PARTS < 1 then return end
		i = debug_currentParticle
		while (i < sim.XRES*sim.YRES and (sim.partProperty(i, sim.FIELD_TYPE) == nil or sim.partProperty(i, sim.FIELD_TYPE) == 0)) do
			i = i + 1
		end
		if i == sim.XRES*sim.YRES then
			print("(slowtick) Blank tick.")
		else
			print("(slowtick) Ticking particle #"..i)
		end
	end
	for j = debug_currentParticle, i do
		tryStep(j, 1/sim.NUM_PARTS)
	end
	if i < sim.XRES*sim.YRES then
		debug_currentParticle = i + 1
	else
		debug_currentParticle = 0
	end
end

event.register(event.mousemove, function(x, y, dx, dy)
	debug_mousex = x
	debug_mousey = y
end)

event.register(event.keypress, function(key, scan, rep, shift, ctrl, alt)
	if not rep then
		if key == 102 then
			-- Support for Jacob's mod
			if jacobsmod then
				debugMode = bit.band(tpt.setdebug(), 0x8) ~= 0
			end
			if debugMode then
				if alt then
					-- An individual particle is being updated.
					particleDebug(false)
				elseif shift then
					-- This is overridden by the alt modifier
					local x, y = sim.adjustCoords(debug_mousex, debug_mousey)
					particleDebug(true, x, y)
				elseif not ctrl then
					if debug_currentParticle > 0 then
						print("(slowtick) Ticking particles #"..debug_currentParticle.." - end")
						while debug_currentParticle <= sim.XRES*sim.YRES do
							tryStep(debug_currentParticle, 1/sim.NUM_PARTS)
							debug_currentParticle = debug_currentParticle + 1
						end
						debug_currentParticle = 0
					else
						coroutine.resume(updateRoutine)
					end
				end
			else
				coroutine.resume(updateRoutine)
			end
		end
	end
end)

-- ==========================================
