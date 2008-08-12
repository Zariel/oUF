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
}

local eventsTable = {
	["[curhp]"] = {"UNIT_HEALTH"},
	["[perhp]"] = {"UNIT_HEALTH", "UNIT_MAXHEALTH"}
	["[maxhp]"] = {"UNIT_MAXHEALTH"},
	["[curpp]"] = {"UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MANA", "UNIT_RAGE"},
	["[maxpp]"] = {"UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXMANA", "UNIT_MAXRAGE"},
	["[perpp]"] = {"UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_MANA", "UNIT_RAGE"},
	["[level]"] = {"UNIT_LEVEL"},
	["[name]"] = {"UNIT_NAME_UPDATE"},
}

local colors = setmetatable({
	["<red>"] = function() return '|cffff0000' end,
	["<green>"] = function() return "|cff00ff00" end,
	["<blue>"] = function() return "|cff0000ff" end,
	["<class>"] = function(unit)
		local col = RAID_CLASS_COLORS[select(2, UnitClass(unit)) or "WARRIOR"]
		return string.format("|cff%02x%02x%02x", col.r*255, col.g*255, col.b*255)
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

-- Need work around for this, for lookup
local function compile(self, str, obj, unit)
	-- Do color substitutions now
	assert(type(obj) == "table")
	assert(type(str) == "string")

	objUnitLookup[obj] = unit
	objStrLookup[obj] = str

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

	if not strHandlers[str] then
		-- Check each tag to ensure that it actually exists
		for tag in str:gmatch("%b[]") do
			assert(tags[tag])

		end

		strHandlers[str] = function(unit)
			if unit then
				runit = unit
				return (str:gsub("%b[]", tagHandler):gsub("%b<>", colorHandler))
			end
		end
	end

	return strHandlers[str]
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
			local handle = compile(str, obj, unit)
			obj:SetText(handle(unit))
		end
		return
	end
	for i, obj in ipairs(eventLookup[event]) do
		-- is the unit the one we want
		if objUnitLookup[obj] == unit then
			-- recompile the string
			local str = objStrLookup[obj]
			local handle = compile(str, obj, unit)
			obj:SetText(handle(unit))
		end
	end
end

f:SetScript("OnEvent", OnEvent)

oUF.Compile = Compile
