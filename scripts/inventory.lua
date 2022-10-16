
local mod = {}

-- ==========================================

mod.inventory = {}
local isClicking = false
local clickButtons = {}
local clickButtonsDelayed = {}

function mod.CreateAllowed(i, x, y, t, _)
	-- This system is intentionally lax
	local selected = false
	if elem[tpt.selectedreplace] == t then selected = true end
	if clickButtons[1] and elem[tpt.selectedl] == t then selected = true end
	if clickButtons[2] and elem[tpt.selecteda] == t then selected = true end
	if clickButtons[3] and elem[tpt.selectedr] == t then selected = true end
	if selected then
		local inv = mod.inventory[t]
		if inv and inv > 0 then
			return true
		end
		return false
	else
		return true
	end
end
function mod.Create(i, x, y, t, _)
	local inv = mod.inventory[t]
	if inv and inv > 0 then
		mod.inventory[t] = inv - 1
		return true
	end
	return false
end
function mod.ChangeType(i, x, y, from, to)
	local inv = mod.inventory[from]
	-- This system is intentionally harsh
	-- There is, however, a (relatively common) edge case I don't feel like fixing: erasing while bombs detonate.
	local selected = false
	if elem[tpt.selectedreplace] == elem.DEFAULT_PT_NONE then selected = true end
	if clickButtons[1] and elem[tpt.selectedl] == elem.DEFAULT_PT_NONE then selected = true end
	if clickButtons[2] and elem[tpt.selecteda] == elem.DEFAULT_PT_NONE then selected = true end
	if clickButtons[3] and elem[tpt.selectedr] == elem.DEFAULT_PT_NONE then selected = true end
	if inv and selected and to == 0 then
		mod.inventory[from] = inv + 1
	end
end

function mod.inventory.registerElement(id, count)
	-- local idv = elem[id]
	-- if not idv then return end
	if mod.inventory[id] then return end
	mod.inventory[id] = count or 0
	elem.property(id, "CreateAllowed", mod.CreateAllowed)
	elem.property(id, "ChangeType", mod.ChangeType)
	elem.property(id, "Create", mod.Create)
	return count
end

-- ==========================================

-- Modified and reformatted from a section of Maticzpl's Subframe Chipmaker Script ( https://starcatcher.us/scripts?view=210 )

local function alignToRight(text)
	local maxWidth = 0
	local outStr = ""

	for str in string.gmatch(text, "([^\n]+)") do -- find widest line
		local width,height = graphics.textSize(str)

		if width > maxWidth then
			maxWidth = width
		end
	end

	local spaceWidth, spaceHeight = graphics.textSize(" ")

	for str in string.gmatch(text, "([^\n]+)") do
		local width,height = graphics.textSize(str)
		local line = str

		if width < maxWidth then
			for i = 1, math.floor((maxWidth - width) / spaceWidth), 1 do
				line = " "..line
			end
		end

		outStr = outStr .. line .."\n"
	end

	return outStr
end

local function displayTip(text)
	-- Set text position
	local width, height = graphics.textSize(text)
	local noDebugOffset = 14
	local textPos = { x = (597-width), y = 44 }

	local zx,zy,s = ren.zoomScope()
	local zwx,zwy,zfactor,zsize = ren.zoomWindow();

	if tpt.version.modid == 6 then -- Cracker's mod
		textPos = { x = 9, y = 50 }
		if ren.zoomEnabled() and zx + (s / 2) > 305 then
			textPos = { x = 7, y = zsize + 4 }   
		end
	else
		if ren.zoomEnabled() then            
			if tpt.version.jacob1s_mod then
				if zx + (s / 2) > 305 then -- if zoom window on the left side
					textPos = { x = 16, y = zsize + 32 }    
				else
					textPos = { x = (sim.XRES - width-15), y = zsize + 32 }
					text = alignToRight(text)
				end   
				noDebugOffset = 11
			else
				if zx + (s / 2) > 305 then -- if zoom window on the left side
					textPos = { x = 7, y = zsize + 4 }    
				else
					textPos = { x = (sim.XRES - width - 7), y = zsize + 4 }
					text = alignToRight(text)
				end
				noDebugOffset = 0
			end
		else
			text = alignToRight(text)
		end
	end

	if renderer.debugHUD() == 0 then
		textPos.y = textPos.y - noDebugOffset
	end

	-- Draw text
	-- local padding = 3
	-- graphics.fillRect(
	-- 	textPos.x - padding,textPos.y - padding,width+(padding*2),
	-- 	(height - 13)+(padding*2),
	-- 	0,0,0,255)
	graphics.drawText( textPos.x, textPos.y, text, 255, 255, 255, 180 )
end

-- ==========================================

local tip = {"Inv(l:m:r)"}
event.register(event.tick, function()
	local visible
	for k,v in pairs(mod.inventory) do
		if type(v) == "number" then
			visible = elem.property(k, "MenuVisible")
			if (v > 0 and visible <= 0) or (v <= 0 and visible > 0) then
				-- print("TOGGLING VISIBILITY", k, v, visible)
				elem.property(k, "MenuVisible", v)
			end
		end
	end
	-- Delaying clicks prevents an extra stamp action
	for k,v in pairs(clickButtons) do
		if v == 2 then
			clickButtons[k] = 0
		end
		clickButtonsDelayed[k] = v > 0
	end
	-- Display inventory
	if tpt.hud() == 1 then
		visible = false
		if clickButtons[1] and mod.inventory[elem[tpt.selectedl]] then
			tip[2] = mod.inventory[elem[tpt.selectedl]]
			visible = true
		else
			tip[2] = "na"
		end
		if clickButtons[2] and mod.inventory[elem[tpt.selecteda]] then
			tip[3] = mod.inventory[elem[tpt.selecteda]]
			visible = true
		else
			tip[3] = "na"
		end
		if clickButtons[3] and mod.inventory[elem[tpt.selectedr]] then
			tip[4] = mod.inventory[elem[tpt.selectedr]]
			visible = true
		else
			tip[4] = "na"
		end
		if visible then
			displayTip(table.concat(tip, "/"))
		end
	end
end)

event.register(event.mousedown, function(x, y, b)
	clickButtons[b] = 1
	clickButtonsDelayed[b] = true
end)
event.register(event.mouseup, function(x, y, b)
	clickButtons[b] = 2
end)

-- ==========================================

Inventory = mod.inventory

Inventory.registerElement(elem.DEFAULT_PT_GOLD)
Inventory[elem.DEFAULT_PT_GOLD] = 100
