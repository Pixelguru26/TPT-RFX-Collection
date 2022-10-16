
local mod = {}
local c0 = 273.15

-- ==========================================

slowticks = slowticks or {}
function slowticks.add(id, fn)
	if not slowticks[id] then
		slowticks[id] = {}
	end
	table.insert(slowticks[id], fn)
	return fn
end

-- ==========================================

mod.customs = {}
function mod.customs.blod(x, y)
	local id = sim.partID(x, y)
	-- Replace or create
	if id then
		sim.partChangeType(id, elem.DEFAULT_PT_OIL)
	else
		id = sim.partCreate(-1, x, y, elem.DEFAULT_PT_OIL)
	end
	-- Define properties
	if id and id > -1 then
		sim.partProperty(id, sim.FIELD_DCOLOUR, 0xFF891c2a)
		sim.partProperty(id, sim.FIELD_CTYPE, elem.DEFAULT_PT_FIGH)
	end
	return id
end

-- ==========================================

mod.solvents = {}
mod.solvents.watr = {
	[elem.DEFAULT_PT_SAWD] = {
		temp = 80,
		rate = 5,
		result = nil,
		ctype = elem.DEFAULT_PT_GUN,
		presult = elem.DEFAULT_PT_NONE,
		pctype = nil
	},
	[elem.DEFAULT_PT_BCOL] = {
		temp = 80,
		rate = 5,
		result = nil,
		ctype = elem.DEFAULT_PT_GUN,
		presult = elem.DEFAULT_PT_NONE,
		pctype = nil
	},
	[elem.DEFAULT_PT_YEST] = {
		temp = 30,
		rate = 10,
		result = elem.DEFAULT_PT_OIL,
		ctype = nil,
		presult = elem.DEFAULT_PT_NONE,
		pctype = nil
	},
	[elem.DEFAULT_PT_STNE] = {
		temp = -c0,
		rate = 2,
		result = elem.DEFAULT_PT_SLTW,
		ctype = nil,
		presult = elem.DEFAULT_PT_SAND,
		pctype = nil
	},
	[elem.DEFAULT_PT_SLTW] = { -- saltwater diffuses
		temp = -c0,
		rate = 50,
		result = elem.DEFAULT_PT_SLTW,
		ctype = nil,
		presult = nil,
		pctype = nil
	}
}

-- Dissolves stuff other than salt
slowticks.add(elem.DEFAULT_PT_DSTW, slowticks.add(elem.DEFAULT_PT_WATR, function(dt, i, x, y, t)
	local ct = sim.partProperty(i, sim.FIELD_CTYPE)
	if ct == 0 then
		local ptype
		local dissolveType
		for id in sim.neighbors(x, y) do
			ptype = sim.partProperty(id, sim.FIELD_TYPE)
			dissolveType = mod.solvents.watr[ptype]
			if dissolveType then
				if sim.partProperty(i, sim.FIELD_TEMP) >= dissolveType.temp+c0 and dissolveType.rate >= math.random(0, 100) then
					-- Apply target ctype, if applicable
					if dissolveType.pctype then
						sim.partProperty(id, sim.FIELD_CTYPE, dissolveType.pctype)
					end
					-- Convert target
					if dissolveType.presult then
						if dissolveType.presult == elem.DEFAULT_PT_NONE then
							sim.partChangeType(id, dissolveType.presult)
						else
							sim.partKill(id)
						end
					end
					-- Heat cost
					sim.partProperty(i, sim.FIELD_TEMP, sim.partProperty(i, sim.FIELD_TEMP) - dissolveType.temp)
					-- Result type
					if dissolveType.result then
						if type(dissolveType.result) == "function" then

						else
							sim.partChangeType(i, dissolveType.result)
						end
					else
						-- DSTW becomes WATR, with an added check to ensure no extra type change events are thrown.
						if sim.partProperty(i, sim.FIELD_TYPE) ~= elem.DEFAULT_PT_WATR then
							sim.partProperty(i, sim.FIELD_TYPE, elem.DEFAULT_PT_WATR)
						end
					end
					-- Result ctype
					if dissolveType.ctype then
						sim.partProperty(i, sim.FIELD_CTYPE, dissolveType.ctype)
					end
					break
				end
			end
		end
	end
end))

-- Deposits solutes
slowticks.add(elem.DEFAULT_PT_WTRV, function(dt, i, x, y, t)
	local ct = sim.partProperty(i, sim.FIELD_CTYPE)
	local continue = true
	if ct ~= 0 then
		for nx = -1, 1 do
			for ny = -1, 1 do
				if x+nx > -1 and x+nx < sim.XRES and y+ny > -1 and y+ny < sim.YRES then
					if sim.partCreate(-1, x+nx, y+ny, ct) >= 0 then
						sim.partProperty(i, sim.FIELD_CTYPE, 0)
						continue = false
						break
					end
				end
			end
			if not continue then break end
		end
	end
end)

-- Cooks into coal more easily than vanilla, and with some variety
slowticks.add(elem.DEFAULT_PT_WOOD, function(dt, i, x, y, t)
	local pressure = sim.pressure(x/sim.CELL, y/sim.CELL)
	local tmp = sim.partProperty(i, sim.FIELD_TMP)
	if math.random(500, 1000) < tmp then
		sim.partProperty(i, sim.FIELD_LIFE, 110)
		sim.partChangeType(i, pressure > 5 and elem.DEFAULT_PT_COAL or elem.DEFAULT_PT_BCOL)
	end
end)

-- Grows a stem!
slowticks.add(elem.DEFAULT_PT_PLNT, function(dt, i, x, y, t)
	local temp = sim.partProperty(i, sim.FIELD_TEMP)
	local tmp = sim.partProperty(i, sim.FIELD_TMP)
	if tmp == 0 and temp > 18+c0 and temp < 50+c0 then
		if math.random() > 0.7 then
			local air = 0
			local p, ptype
			local wood = 0
			for dx = -1, 1 do
				for dy = -1, 1 do
					p = sim.partID(x+dx, y+dy)
					if p then
						ptype = sim.partProperty(p, sim.FIELD_TYPE)
						if ptype == elem.DEFAULT_PT_WOOD then
							wood = wood + 1
						end
					else
						air = air + 1
					end
				end
			end
			if air == 0 and wood > 0 and wood < 3 then
				sim.partProperty(i, sim.FIELD_TMP, 0)
				sim.partChangeType(i, elem.DEFAULT_PT_WOOD)
			end
		end
	end
end)

-- Doesn't account for enclosed spaces very well, unfortunately
-- slowticks.add(elem.DEFAULT_PT_FIRE, function(dt, i, x, y, t)
-- 	local pressure = sim.pressure(x/sim.CELL, y/sim.CELL)
-- 	local temp = sim.partProperty(i, sim.FIELD_TEMP)
-- 	temp = temp + pressure * dt
-- 	sim.partProperty(i, sim.FIELD_TEMP, temp)
-- end)

mod.ores = {
	{ t = nil, weight = 200},
	{ t = elem.DEFAULT_PT_BMTL, weight = 40},
	{ t = elem.DEFAULT_PT_METL, weight = 20},
	{ t = elem.DEFAULT_PT_IRON, weight = 10},
	{ t = elem.DEFAULT_PT_TUNG, weight = 5 },
	{ t = elem.DEFAULT_PT_PTNM, weight = 2 },
	{ t = elem.DEFAULT_PT_TTAN, weight = 2 },
	{ t = elem.DEFAULT_PT_GOLD, weight = 1 }
}

elem.property(elem.DEFAULT_PT_ROCK, "ChangeType", function(i, x, y, t, nt)
	local tmp = sim.partProperty(i, sim.FIELD_TMP)
	if tmp == 0 and nt == elem.DEFAULT_PT_LAVA then
		if math.random(0, 100) < 10 then
			local ctype = t
			local weightsum = 0
			for i,v in ipairs(mod.ores) do
				weightsum = weightsum + v.weight
			end
			local rand = math.random(0, weightsum)
			for i,v in ipairs(mod.ores) do
				if rand < v.weight then
					ctype = v.t
					break
				end
				rand = rand - v.weight
			end
			if ctype then
				local ptype
				local id
				for x, y in sim.brush(x, y, math.random(1,3), math.random(1,3), 0) do
					id = sim.partID(x, y)
					if id then
						ptype = sim.partProperty(id, sim.FIELD_TYPE)
						if ptype == t or ptype == nt then
							sim.partProperty(id, sim.FIELD_CTYPE, ctype)
						end
					end
				end
			else
				sim.partProperty(i, sim.FIELD_TMP, 1)
			end
		else
			sim.partProperty(i, sim.FIELD_TMP, 1)
		end
	end
end)

-- elem.property(elem.DEFAULT_PT_WATR, "ChangeType", function(i, x, y, t, nt)
-- 	if nt == elem.DEFAULT_PT_WTRV and sim.partProperty(i, sim.FIELD_CTYPE) ~= 0 then
-- 		if sim.partCreate(-3, x, y, sim.partProperty(i, sim.FIELD_CTYPE)) >= 0 then
-- 			sim.partProperty(i, sim.FIELD_CTYPE, 0)
-- 		end
-- 	end
-- end)

-- elem.property(elem.DEFAULT_PT_SLTW, "ChangeType", function(i, x, y, t, nt)
-- 	print("TRANSITION", i, x, y, t, nt)
-- end)

-- Cannot be implemented per issue #863
-- elem.property(elem.DEFAULT_PT_FIGH, "ChangeType", function(i, x, y, t, nt)
-- 	-- print(i, x, y, t, nt)
-- 	if x > 0 and x < sim.XRES-1 and y > 0 and y < sim.YRES-1 then
-- 		if nt ~= elem.DEFAULT_PT_FIGH then
-- 			local id
-- 			for dx = -1, 1 do
-- 				for dy = -1, 1 do
-- 					id = mod.customs.blod(x+dx, y+dy)
-- 					if id and id > -1 then
-- 						sim.partProperty(id, sim.FIELD_VX, math.random()*4-2)
-- 						sim.partProperty(id, sim.FIELD_VY, math.random()*4-2)
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end
-- end)

event.register(event.tick, function()
	if tpt.set_pause() == 0 then -- I can't find a better way to detect simulation pausing
	end
end)
