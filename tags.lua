local print = function(...)
	local str = ""
	for i = 1, select("#", ...) do
		str = str .. tostring(select(i, ...)) .. " "
	end
	ChatFrame1:AddMessage(str)
end

local ToHex = function(r, g, b)
	return string.format("|cff%02x%02x%02x", r*255, g*255, b*255)
end

local siVal = function(val)
	if val >= 1e4 then
		return string.format("%.1fk", val / 1e3)
	else
		return val
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_TARGET_CHANGED")

local registry = setmetatable({}, {
	__index = function(self, event)
		self[event] = true
		f:RegisterEvent(event)
	end,
	__call = function(self, event, obj)
		return self[event]
	end,
})

local tags = {
	["[curhp]"] = function(u) return UnitHealth(u) end,
	["[maxhp]"] = function(u) return UnitHealthMax(u) end,
	["[perhp]"] = function(u) return math.floor((UnitHealth(u) / UnitHealthMax(u)) * 100) end,
	["[perpp]"] = function(u) return math.floor((UnitPower(u) / UnitPowerMax(u)) * 100) end,
	["[curpp]"] = function(u) return UnitMana(u) end,
	["[maxpp]"] = function(u) return UnitManaMax(u) end,
	["[level]"] = function(u) return UnitLevel(u) end,
	["[class]"] = function(u) return UnitClass(u) end,
	["[name]"] = function(u) return UnitName(u) end,
	["[race]"] = function(u) return UnitRace(u) end,
	["[missinghp]"] = function(u) return UnitHealthMax(u) - UnitHealth(u) end,
	["[missingpp]"] = function(u) return UnitManaMax(u) - UnitMana(u) end,
	["[smartcurhp]"] = function(u) return siVal(UnitHealthMax(u)) end,
	["[smartmaxhp]"] = function(u) return siVal(UnitHealth(u)) end,
	["[smartcurpp]"] = function(u) return siVal(UnitMana(u)) end,
	["[smartmaxpp]"] = function(u) return siVal(UnitManaMax(u)) end,
}

local eventsTable = {
	["[curhp]"] = {"UNIT_HEALTH"},
	["[smartcurhp]"] = {"UNIT_HEALTH"},
	["[perhp]"] = {"UNIT_HEALTH", "UNIT_MAXHEALTH"},
	["[maxhp]"] = {"UNIT_MAXHEALTH"},
	["[smartmaxhp]"] = {"UNIT_MAXHEALTH"},
	["[curpp]"] = {"UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MANA", "UNIT_RAGE"},
	["[smartcurpp]"] = {"UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MANA", "UNIT_RAGE"},
	["[maxpp]"] = {"UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXMANA", "UNIT_MAXRAGE"},
	["[smartmaxpp]"] = {"UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXMANA", "UNIT_MAXRAGE"},
	["[perpp]"] = {"UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MANA", "UNIT_RAGE"},
	["[level]"] = {"UNIT_LEVEL"},
	["[name]"] = {"UNIT_NAME_UPDATE"},
	["[missinghp]"] = {"UNIT_HEALTH", "UNIT_MAXHEALTH"},
	["[missingmp]"] = {"UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MANA", "UNIT_RAGE"},
}

local colors = setmetatable({
	["<red>"] = '|cffff0000',
	["<green>"] = "|cff00ff00",
	["<blue>"] = "|cff0000ff",
	["<class>"] = function(unit)
		local col = RAID_CLASS_COLORS[select(2, UnitClass(unit)) or "WARRIOR"]
		return ToHex(col.r, col.g, col.b)
	end,
	["<hostility>"] = function(unit)
		local col = UnitReactionColor[UnitReaction(unit, "player")] or { r = 1, g = 1, b = 1}
		return ToHex(col.r, col.g, col.b)
	end,
	["<r>"] = function() return "|r" end,
}, {
	__index = function(self, s)
		self[s] = "|cff" .. s:sub(2,-2)
		return self[s]
	end,
})

local runit
local colorHandler = function(s)
	if type(colors[s]) == "function" then
		return colors[s](runit)
	else
		return colors[s]
	end
end

local tagHandler = function(s)
	return tags[s](runit)
end

local strHandlers = {}
local eventObj = setmetatable({}, {__index = function(self, key)
	self[key] = {}
	return self[key]
end})

-- event < -- > obj
local eventLookup = {}
-- obj < -- > str
local objStrLookup = {}
-- obj < -- > unit
local objUnitLookup = {}
-- event check
local eventCheck = {}

local RegisterTag = function(self, str, obj, unit)
	assert(type(obj) == "table", error("Bad arg #2 object should be a table"))
	assert(type(str) == "string", error("Bad arg #1 string should be a string"))

	objUnitLookup[obj] = unit
	objStrLookup[obj] = str

	-- Have to do this here to find out what events each tag needs and
	-- register it when needed
	if not eventChange[str] then
		for tag in str:gmatch("%b[]") do
			if eventsTable[tag] then
				for i, event in ipairs(eventsTable[tag]) do
					registry(event)
					eventLookup[event] = eventLookup[event] or {}
					-- obj to update when event fires
					if not eventObj[event][obj] then
						table.insert(eventLookup[event], obj)
						eventObj[event][obj] = true
					end
				end
			end
		end
		eventCheck[str] = true
	end

	if not strHandlers[str] then
		-- Check each tag to ensure that it actually exists
		for tag in str:gmatch("%b[]") do
			assert(tags[tag], error("Unknown tag " .. tag))
		end

		strHandlers[str] = function(unit)
			if unit then
				runit = unit
				return (str:gsub("%b[]", tagHandler):gsub("%b<>", colorHandler))
			end
		end
	end

	obj:SetText(strHandlers[str](unit))
end

-- Usage:
--
-- element - an element that uses tags
--
-- local handler = compile("[curhp]/[maxhp]")
-- element:SetFormattedText(handler("player"))

local OnEvent = function(self, event, unit)
	if event == "PLAYER_TARGET_CHANGED" then
		for obj, str in pairs(objStrLookup) do
			local unit = objUnitLookup[obj]
			RegisterTag(oUF, str, obj, unit)
		end
		return
	end
	for i, obj in ipairs(eventLookup[event]) do
		-- is the unit the one we want
		if objUnitLookup[obj] == unit then
			-- recompile the string
			local str = objStrLookup[obj]
			RegisterTag(oUF, str, obj, unit)
		end
	end
end

f:SetScript("OnEvent", OnEvent)

oUF.RegisterTag = RegisterTag
