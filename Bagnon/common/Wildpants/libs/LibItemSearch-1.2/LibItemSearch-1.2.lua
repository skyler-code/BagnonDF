--[[
	ItemSearch
		An item text search engine of some sort
--]]

local Search = LibStub('CustomSearch-1.0')
local Unfit = LibStub('Unfit-1.0')
local Lib = LibStub:NewLibrary('LibItemSearch-1.2', 24)
if Lib then
	Lib.Filters = {}
else
	return
end

--[[ User API ]]--

function Lib:Matches(slotInfo, search)
	return Search(slotInfo, search, self.Filters)
end

function Lib:Tooltip(slotInfo, search)
	return bagId and self.Filters.tip:match(slotInfo, nil, search)
end

function Lib:TooltipPhrase(slotInfo, search)
	return bagId and self.Filters.tipPhrases:match(slotInfo, nil, search)
end

function Lib:ForQuest(slotInfo)
	return self:Tooltip(slotInfo, GetItemClassInfo(Enum.ItemClass.Questitem):lower())
end

function Lib:IsReagent(slotInfo)
	return self:TooltipPhrase(slotInfo, PROFESSIONS_USED_IN_COOKING)
end

function Lib:InSet(slotInfo, search)
	local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
	if itemID and IsEquippableItem(itemID) then
		return self:BelongsToSet(itemID, (search or ''):lower())
	end
end


--[[ Internal API ]]--

function Lib:TooltipLine(slotInfo, line)
	local tooltipData = C_TooltipInfo.GetBagItem(slotInfo.bagId, slotInfo.slotId)
	for _, line in ipairs(tooltipData.lines) do
		TooltipUtil.SurfaceArgs(line)
	end
	return tooltipData.lines[line].leftText
end


if IsAddOnLoaded('ItemRack') then
	local sameID = ItemRack.SameID

	function Lib:BelongsToSet(id, search)
		for name, set in pairs(ItemRackUser.Sets) do
			if name:sub(1,1) ~= '' and Search:Find(search, name) then
				for _, item in pairs(set.equip) do
					if sameID(id, item) then
						return true
					end
				end
			end
		end
	end

elseif IsAddOnLoaded('Wardrobe') then
	function Lib:BelongsToSet(id, search)
		for _, outfit in ipairs(Wardrobe.CurrentConfig.Outfit) do
			local name = outfit.OutfitName
			if Search:Find(search, name) then
				for _, item in pairs(outfit.Item) do
					if item.IsSlotUsed == 1 and item.ItemID == id then
						return true
					end
				end
			end
		end
	end

elseif C_EquipmentSet then
	function Lib:BelongsToSet(id, search)
		for i, setID in pairs(C_EquipmentSet.GetEquipmentSetIDs()) do
			local name = C_EquipmentSet.GetEquipmentSetInfo(setID)
			if Search:Find(search, name) then
				local items = C_EquipmentSet.GetItemIDs(setID)
				for _, item in pairs(items) do
					if id == item then
						return true
					end
				end
			end
		end
	end

else
	function Lib:BelongsToSet() end
end


--[[ General Filters ]]--

Lib.Filters.name = {
	tags = {'n', 'name'},

	canSearch = function(self, operator, search)
		return not operator and search
	end,

	match = function(self, slotInfo, _, search)
		local itemLoc = ItemLocation:CreateFromBagAndSlot(slotInfo.bagId, slotInfo.slotId)
		return itemLoc:IsValid() and Search:Find(search, C_Item.GetItemName(itemLoc))
	end
}

Lib.Filters.type = {
	tags = {'t', 'type', 's', 'slot'},

	canSearch = function(self, operator, search)
		return not operator and search
	end,

	match = function(self, slotInfo, _, search)
		local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		local type, subType, _, equipSlot = itemID and select(6, GetItemInfo(itemID))
		return Search:Find(search, type, subType, _G[equipSlot])
	end
}

Lib.Filters.level = {
	tags = {'l', 'level', 'lvl', 'ilvl'},

	canSearch = function(self, _, search)
		return tonumber(search)
	end,

	match = function(self, slotInfo, operator, num)
		local itemLoc = ItemLocation:CreateFromBagAndSlot(slotInfo.bagId, slotInfo.slotId)
		local lvl = itemLoc:IsValid() and C_Item.GetCurrentItemLevel(itemLoc)
		return lvl and Search:Compare(operator, lvl, num)
	end
}

Lib.Filters.requiredlevel = {
	tags = {'r', 'req', 'rl', 'reql', 'reqlvl'},

	canSearch = function(self, _, search)
		return tonumber(search)
	end,

	match = function(self, slotInfo, operator, num)
		local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		local lvl = itemId and select(5, GetItemInfo(itemID))
		return lvl and Search:Compare(operator, lvl, num)
	end
}

Lib.Filters.itemId = {
	tags = {'itemid', 'id'},

	canSearch = function(self, _, search)
		return tonumber(search)
	end,

	match = function(self, slotInfo, _, num)
		local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		return itemID and itemID == num
	end
}

Lib.Filters.anima = {
	keyword = 'anima',

	canSearch = function(self, _, search)
		return not operator and self.keyword:find(search)
	end,

	match = function(self, slotInfo, _, search)
		local id = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		return id and C_Item.IsAnimaItemByID(id)
	end
}

Lib.Filters.keystone = {
	keywords = {"key", "keystone"},

	canSearch = function(self, _, search)
		for _, name in ipairs(self.keywords) do
			if name:find(search) then
				return true
			end
		end
	end,

	match = function(self, slotInfo, _, search)
		local id = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		return id and C_Item.IsItemKeystoneByID(id)
	end
}

Lib.Filters.sets = {
	tags = {'s', 'set'},

	canSearch = function(self, operator, search)
		return not operator and search
	end,

	match = function(self, slotInfo, _, search)
		return Lib:InSet(slotInfo, search)
	end,
}

Lib.Filters.quality = {
	tags = {'q', 'quality'},
	keywords = {},

	canSearch = function(self, _, search)
		for quality, name in pairs(self.keywords) do
			if name:find(search) then
				return quality
			end
		end
	end,

	match = function(self, slotInfo, operator, num)
		local itemInfo = C_Container.GetContainerItemInfo(slotInfo.bagId, slotInfo.slotId)
		if itemInfo then
			local quality = itemInfo.hyperlink:find('battlepet') and tonumber(itemInfo.hyperlink:match('%d+:%d+:(%d+)')) or itemInfo.quality
			return Search:Compare(operator, quality, num)
		end
	end,
}

for i = 0, #ITEM_QUALITY_COLORS do
	Lib.Filters.quality.keywords[i] = _G['ITEM_QUALITY' .. i .. '_DESC']:lower()
end

--[[ Classic Keywords ]]--

Lib.Filters.items = {
	keyword = ITEMS:lower(),

	canSearch = function(self, operator, search)
		return not operator and self.keyword:find(search)
	end,

	match = function(self, slotInfo)
		return true
	end
}

Lib.Filters.usable = {
	keyword = USABLE_ITEMS:lower(),

	canSearch = function(self, operator, search)
		return not operator and self.keyword:find(search)
	end,

	match = function(self, slotInfo)
		local itemInfo = C_Container.GetContainerItemInfo(slotInfo.bagId, slotInfo.slotId)
		if itemInfo and not Unfit:IsItemUnusable(itemInfo.hyperlink) then
			local lvl = select(5, GetItemInfo(itemInfo.itemID))
			return lvl and (lvl == 0 or lvl > UnitLevel('player'))
		end
	end
}

--[[ Tooltips ]]--

local cacheAge
local tipCache = setmetatable({}, {__index = function(t, k) local v = {} t[k] = v return v end})
local timesRan = 0

local function checkTipCache(search, slotInfo, find)
	local timestamp = GetTime()
	if cacheAge and (timestamp - cacheAge) > 15 then
		wipe(tipCache)
		cacheAge = nil
	end

	local id = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
	if not id then
		return
	end

	local cached = tipCache[search][id]
	if cached ~= nil then
		return cached
	end

	local matches = false
	local tooltipData = C_TooltipInfo.GetBagItem(slotInfo.bagId, slotInfo.slotId)
	for k, line in ipairs(tooltipData.lines) do
		TooltipUtil.SurfaceArgs(line)
		if find then
			if Search:Find(search, line.leftText) or Search:Find(search, line.rightText) then
				matches = true
				break
			end
		else
			if search == line.leftText or search == line.rightText then
				matches = true
				break
			end
		end
	end

	if not cacheAge then
		cacheAge = timestamp
	end
	tipCache[search][id] = matches
	return matches
end

Lib.Filters.tip = {
	tags = {'tt', 'tip', 'tooltip'},
	onlyTags = true,

	canSearch = function(self, _, search)
		return search
	end,

	match = function(self, slotInfo, _, search)
		return checkTipCache(search, slotInfo, true)
	end
}

Lib.Filters.tipPhrases = {
	canSearch = function(self, _, search)
		if #search >= 3 then
			for key, query in pairs(self.keywords) do
				if key:find(search) then
					return query
				end
			end
		end
	end,

	match = function(self, slotInfo, _, search)
		return checkTipCache(search, slotInfo)
	end,

	keywords = {
		[ITEM_BIND_ON_PICKUP:lower()] = ITEM_BIND_ON_PICKUP,
		[ITEM_SOULBOUND:lower()] = ITEM_SOULBOUND,
		[QUESTS_LABEL:lower()] = ITEM_BIND_QUEST,
		[GetItemClassInfo(Enum.ItemClass.Questitem):lower()] = ITEM_BIND_QUEST,
		[PROFESSIONS_USED_IN_COOKING:lower()] = PROFESSIONS_USED_IN_COOKING, -- Crafting Reagent
		[APPEARANCE_LABEL:lower()] = TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
		[TOY:lower()] = TOY,
		[ITEM_COSMETIC:lower()] = ITEM_COSMETIC,

		['bound'] = ITEM_SOULBOUND,
		['bop'] = ITEM_BIND_ON_PICKUP,
		['boe'] = ITEM_BIND_ON_EQUIP,
		['bou'] = ITEM_BIND_ON_USE,
		['boa'] = ITEM_BNETACCOUNTBOUND,
	}
}
