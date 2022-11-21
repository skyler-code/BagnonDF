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
	local itemInfo = C_Container.GetContainerItemInfo(slotInfo.bagId, slotInfo.slotId)
	if itemInfo and IsEquippableItem(itemInfo.hyperlink) then
		return self:BelongsToSet(itemInfo.itemID, (search or ''):lower())
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
		local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		return itemID and Search:Find(search, C_Item.GetItemNameByID(itemID))
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
		local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		local lvl = select(4, GetItemInfo(itemID))
		if lvl then
			return Search:Compare(operator, lvl, num)
		end
	end
}

Lib.Filters.requiredlevel = {
	tags = {'r', 'req', 'rl', 'reql', 'reqlvl'},

	canSearch = function(self, _, search)
		return tonumber(search)
	end,

	match = function(self, slotInfo, operator, num)
		local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		local lvl = select(5, GetItemInfo(itemID))
		if lvl then
			return Search:Compare(operator, lvl, num)
		end
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


--[[ Retail Keywords ]]--

if C_ArtifactUI then
	Lib.Filters.artifact = {
		keyword1 = ITEM_QUALITY6_DESC:lower(),
		keyword2 = RELICSLOT:lower(),

		canSearch = function(self, operator, search)
			return not operator and self.keyword1:find(search) or self.keyword2:find(search)
		end,

		match = function(self, slotInfo)
			local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
			return itemID and C_ArtifactUI.GetRelicInfoByItemID(itemID)
		end
	}
end

if C_AzeriteItem and C_CurrencyInfo and C_CurrencyInfo.GetAzeriteCurrencyID then
	Lib.Filters.azerite = {
		keyword = C_CurrencyInfo.GetBasicCurrencyInfo(C_CurrencyInfo.GetAzeriteCurrencyID()).name:lower(),

		canSearch = function(self, operator, search)
			return not operator and self.keyword:find(search)
		end,

		match = function(self, slotInfo)
			local itemID = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
			return C_AzeriteItem.IsAzeriteItemByID(itemID) or C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(itemID)
		end
	}
end


--[[ Tooltips ]]--

Lib.Filters.tip = {
	tags = {'tt', 'tip', 'tooltip'},
	onlyTags = true,

	canSearch = function(self, _, search)
		return search
	end,

	match = function(self, slotInfo, _, search)
		local itemInfo = C_Container.GetContainerItemInfo(slotInfo.bagId, slotInfo.slotId)
		if itemInfo and itemInfo.hyperlink:find('item:') then
			local tooltipData = C_TooltipInfo.GetBagItem(slotInfo.bagId, slotInfo.slotId)
			for k, line in ipairs(tooltipData.lines) do
				TooltipUtil.SurfaceArgs(line)
				if Search:Find(search, line.leftText) then
					return true
				end
			end
		end
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
		local id = C_Container.GetContainerItemID(slotInfo.bagId, slotInfo.slotId)
		if not id then
			return
		end

		local cached = self.cache[search][id]
		if cached ~= nil then
			return cached
		end

		local tooltipData = C_TooltipInfo.GetBagItem(id)
		local matches = false
		for k, line in ipairs(tooltipData.lines) do
			TooltipUtil.SurfaceArgs(line)
			if search == line.leftText then
				matches = true
				break
			end
		end

		self.cache[search][id] = matches
		return matches
	end,

	cache = setmetatable({}, {__index = function(t, k) local v = {} t[k] = v return v end}),
	keywords = {
		[ITEM_SOULBOUND:lower()] = ITEM_BIND_ON_PICKUP,
		[QUESTS_LABEL:lower()] = ITEM_BIND_QUEST,
		[GetItemClassInfo(Enum.ItemClass.Questitem):lower()] = ITEM_BIND_QUEST,
		[PROFESSIONS_USED_IN_COOKING:lower()] = PROFESSIONS_USED_IN_COOKING,
		[APPEARANCE_LABEL:lower()] = TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN,
		[TOY:lower()] = TOY,

  	['bound'] = ITEM_BIND_ON_PICKUP,
  	['bop'] = ITEM_BIND_ON_PICKUP,
		['boe'] = ITEM_BIND_ON_EQUIP,
		['bou'] = ITEM_BIND_ON_USE,
		['boa'] = ITEM_BIND_TO_BNETACCOUNT,
	}
}
