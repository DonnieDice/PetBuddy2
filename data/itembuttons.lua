--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, addon = ...;
local RGX = _G.RGXFramework;
local PetBattles = RGX:GetPetBattles();
local unpackFunc = unpack or table.unpack;

local ITEM_BUTTON_CATEGORIES = {
	{
		key = "heal_spell",
		menuText = "Heal pets spell",
		type = "spell",
		alwaysVisible = true,
		defaultEnabled = true,
		
		items = {
			125439,
		},
	},
	
	{
		key = "battle_bandage",
		menuText = "Battle bandage",
		type = "item",
		alwaysVisible = true,
		defaultEnabled = true,
		
		items = {
			86143,
		},
	},
	
	{
		key = "battle_stones",
		menuText = "Battle stones",
		type = "item",
		iconTexture = "INTERFACE\\ICONS\\Icon_UpgradeStone_Rare.blp",
		tooltipTitle = "Battle Stones",
		tooltipDescription = "Pet quality and level-up stones",
		target = "target",
		defaultEnabled = false,
		
		items = {
			-- Rare stones
			92741,
			92679,
			92675,
			92676,
			92683,
			92665,
			92677,
			92682,
			92678,
			92680,
			92681,
			92742,
			98715,

			-- Level stones
			122457, -- Ultimate stone (patch 6.1)
			116429,
			127755, -- Fel stone 6.2
			116424,
			116422,
			116374,
			116421,
			116416,
			116417,
			116419,
			116420,
			116423,
			116418,
		},
	},
	
	{
		key = "pet_consumables",
		menuText = "Consumables and toys",
		type = "item",
		iconTexture = "Interface\\ICONS\\INV_Misc_Petbiscuit_01.blp",
		tooltipTitle = "Consumables and Toys",
		tooltipDescription = "Treats, utility items, toys, and costumes",
		target = "target",
		defaultEnabled = false,
		
		items = {
			-- Miscellaneous + treats
			37431,
			43352,
			43626,
			71153,
			89906,
			98112,
			98114,
			163697,
			139003,
			139036,
			163789,
			163790,
			163791,
			163796,
			165840,
			166732,
			166733,
			166734,
			166735,
			166737,
			166738,
			183111,
			183112,
			183113,
			223970,
			226021,

			-- Battle pet toys
			44820,
			37460,
			89139,
			127707,
			127695,
			127696,
			129958,
			129961,
			140231,
			163205,
			163704,
			163705,
			174925,

			-- Costume items
			103786,
			103789,
			103795,
			103797,
			116172,
			116810,
			116811,
			116812,
			128650,
		},
	},
	{
		key = "pet_rewards",
		menuText = "Supply bags and containers",
		type = "item",
		iconTexture = "Interface\\ICONS\\INV_Misc_Bag_10_Black.blp",
		tooltipTitle = "Supply Bags and Containers",
		tooltipDescription = "Pet supply bags and battle pet container items",
		target = "target",
		defaultEnabled = false,

		items = {
			-- Battle pet containing items
			21310,
			39878,
			112107,
			137599,
			137608,
			153190,
			153191,
			182607,

			-- Supplies bags
			89125,
			94207,
			93146,
			93147,
			93148,
			93149,
			91086,
			98095,
			116062,
			118697,
			122535,
			127751,
			120321,
			116202,
			142447,
			143753,
			146317,
			151638,
		},
	},
	{
		key = "pet_currencies",
		menuText = "Pet currencies",
		type = "item",
		iconTexture = "Interface\\ICONS\\INV_Misc_Coin_01.blp",
		tooltipTitle = "Pet Currencies",
		tooltipDescription = "Charm and pet-related currency items",
		target = "target",
		defaultEnabled = false,

		items = {
			101529, -- Celestial Coin
			116415, -- Shiny Pet Charm
			151191, -- Old Bottle Cap
			163036, -- Polished Pet Charm
			165835, -- Pristine Gizmo
			169665, -- Cleansed Remains
			174360, -- Shadowy Gem
		},
	},
};

local MAX_ITEM_BUTTONS = 6;
local itemButtonEventBridgeRegistered = false;

-- Set when a secure-attribute write is refused during combat lockdown so the
-- buttons can be rebuilt deterministically on PLAYER_REGEN_ENABLED. Without
-- this, deferred buttons would only recover incidentally on the next bag update.
local pendingItemButtonAttributeRefresh = false;

local function SafeSetButtonAttribute(button, key, value)
	if(not button or type(button.SetAttribute) ~= "function") then
		return false;
	end

	if(InCombatLockdown and InCombatLockdown()) then
		pendingItemButtonAttributeRefresh = true;
		return false;
	end

	local ok, err = pcall(button.SetAttribute, button, key, value);
	if(not ok and RGX and type(RGX.Debug) == "function") then
		RGX:Debug("[BPU] SetAttribute failed", tostring(key), tostring(err));
	end

	return ok;
end

local function ClearButtonSecureAction(button)
	if(not button or not button._bpuHasSecureAction) then
		return;
	end

	SafeSetButtonAttribute(button, "type", nil);
	SafeSetButtonAttribute(button, "unit", nil);
	SafeSetButtonAttribute(button, "spell", nil);
	SafeSetButtonAttribute(button, "item", nil);
	button._bpuHasSecureAction = nil;
	button._bpuSecureActionKind = nil;
end

local function DispatchItemButtonEvent(event, ...)
	-- Combat ended: if any secure-attribute write was deferred during lockdown,
	-- rebuild the buttons now so their secure actions are reapplied out of combat.
	if(event == "PLAYER_REGEN_ENABLED") then
		if(pendingItemButtonAttributeRefresh) then
			pendingItemButtonAttributeRefresh = false;
			addon:UpdateItemButtons();
		end
		return;
	end

	if(event == "BAG_UPDATE_DELAYED" and BattlePetUtilityFrameButtons and BattlePetUtilityFrameButtons:IsShown()) then
		addon:UpdateItemButtons();
	end

	for i = 1, MAX_ITEM_BUTTONS do
		local button = BattlePetUtilityFrameButtons and BattlePetUtilityFrameButtons["itemButton" .. i];
		if(button and button:IsShown() and button.actionType) then
			BattlePetUtilityFrameButton_OnEvent(button, event, ...);
		end
	end

	for i = 1, 20 do
		local button = _G["BattlePetUtilityFlyoutButton" .. i];
		if(button and button:IsShown() and button.actionType) then
			BattlePetUtilityFrameButton_OnEvent(button, event, ...);
		end
	end
end

local function EnsureItemButtonEventBridge()
	if(itemButtonEventBridgeRegistered or not RGX or type(RGX.RegisterEvent) ~= "function") then
		return;
	end

	RGX:RegisterEvent("SPELL_UPDATE_COOLDOWN", DispatchItemButtonEvent, "BPU_ItemButton_SPELL_UPDATE_COOLDOWN");
	RGX:RegisterEvent("BAG_UPDATE_DELAYED", DispatchItemButtonEvent, "BPU_ItemButton_BAG_UPDATE_DELAYED");
	RGX:RegisterEvent("BAG_UPDATE_COOLDOWN", DispatchItemButtonEvent, "BPU_ItemButton_BAG_UPDATE_COOLDOWN");
	RGX:RegisterEvent("PLAYER_REGEN_ENABLED", DispatchItemButtonEvent, "BPU_ItemButton_PLAYER_REGEN_ENABLED");
	itemButtonEventBridgeRegistered = true;
end

local function GetCategoryByKey(categoryKey)
	for _, category in ipairs(ITEM_BUTTON_CATEGORIES) do
		if(category.key == categoryKey) then
			return category;
		end
	end
	return nil;
end

function addon:GetPetItemCategoryDefinitions()
	return ITEM_BUTTON_CATEGORIES;
end

function addon:InitializePetItemCategoryDefaults()
	if(not self.db or not self.db.global) then return end

	if(type(self.db.global.PetItemCategories) ~= "table") then
		self.db.global.PetItemCategories = {};
	end

	for _, category in ipairs(ITEM_BUTTON_CATEGORIES) do
		if(category.key and self.db.global.PetItemCategories[category.key] == nil) then
			if(category.defaultEnabled == nil) then
				self.db.global.PetItemCategories[category.key] = true;
			else
				self.db.global.PetItemCategories[category.key] = category.defaultEnabled and true or false;
			end
		end
	end
end

function addon:IsPetItemCategoryEnabled(categoryKey)
	local category = GetCategoryByKey(categoryKey);
	local defaultEnabled = true;
	if(category and category.defaultEnabled ~= nil) then
		defaultEnabled = category.defaultEnabled and true or false;
	end

	if(not self.db or not self.db.global or type(self.db.global.PetItemCategories) ~= "table") then
		return defaultEnabled;
	end

	local value = self.db.global.PetItemCategories[categoryKey];
	if(value == nil) then
		return defaultEnabled;
	end

	return value and true or false;
end

function addon:SetPetItemCategoryEnabled(categoryKey, enabled)
	if(not self.db or not self.db.global) then return end
	if(type(self.db.global.PetItemCategories) ~= "table") then
		self.db.global.PetItemCategories = {};
	end

	self.db.global.PetItemCategories[categoryKey] = enabled and true or false;
end

function addon:GetPetItemCategoryMenuData(includeTitle)
	if(includeTitle == nil) then
		includeTitle = true;
	end

	local menuData = {};
	if(includeTitle) then
		tinsert(menuData, {
			text = "Quick Item Buttons",
			isTitle = true,
			notCheckable = true,
		});
	end

	for _, category in ipairs(ITEM_BUTTON_CATEGORIES) do
		if(category.key) then
			tinsert(menuData, {
				text = category.menuText or category.tooltipTitle or tostring(category.key),
				func = function()
					local enabled = addon:IsPetItemCategoryEnabled(category.key);
					addon:SetPetItemCategoryEnabled(category.key, not enabled);
					addon:RestoreSavedSettings();
				end,
				checked = function()
					return addon:IsPetItemCategoryEnabled(category.key);
				end,
				isNotRadio = true,
				disabled = PetBattles:IsInBattle(),
			});
		end
	end

	return menuData;
end

local function IsSpellUsableCompat(spellID)
	if(type(IsUsableSpell) == "function") then
		local usable = IsUsableSpell(spellID);
		if(type(usable) == "table") then
			return usable.isUsable and true or false;
		end
		return usable and true or false;
	end

	if(C_Spell and type(C_Spell.IsSpellUsable) == "function") then
		local usable = C_Spell.IsSpellUsable(spellID);
		if(type(usable) == "table") then
			return usable.isUsable and true or false;
		end
		return usable and true or false;
	end

	return true;
end

local function GetSpellInfoCompat(spellID)
	if(type(GetSpellInfo) == "function") then
		return GetSpellInfo(spellID);
	end

	if(C_Spell and type(C_Spell.GetSpellInfo) == "function") then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellID);
		if(ok and type(info) == "table") then
			return info.name, nil, info.iconID;
		end
	end

	return nil, nil, nil;
end

local function GetSpellCooldownCompat(spellID)
	if(type(GetSpellCooldown) == "function") then
		return GetSpellCooldown(spellID);
	end

	if(C_Spell and type(C_Spell.GetSpellCooldown) == "function") then
		local ok, info = pcall(C_Spell.GetSpellCooldown, spellID);
		if(ok and type(info) == "table") then
			return info.startTime or info.start or 0, info.duration or 0, info.isEnabled, info.modRate;
		end
	end

	return 0, 0, 0, 1;
end

local function IsSpellKnownCompat(spellID)
	if(type(IsSpellKnown) == "function") then
		return IsSpellKnown(spellID);
	end

	if(C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function") then
		return C_SpellBook.IsSpellKnown(spellID);
	end

	if(C_Spell and type(C_Spell.IsSpellDataCached) == "function") then
		return C_Spell.IsSpellDataCached(spellID);
	end

	return false;
end

local function IsItemUsableCompat(itemID)
	if(type(IsUsableItem) == "function") then
		local usable = IsUsableItem(itemID);
		if(type(usable) == "table") then
			return usable.isUsable and true or false;
		end
		return usable and true or false;
	end

	if(C_Item and type(C_Item.IsUsableItem) == "function") then
		local usable = C_Item.IsUsableItem(itemID);
		if(type(usable) == "table") then
			return usable.isUsable and true or false;
		end
		return usable and true or false;
	end

	return true;
end

local function GetItemInfoCompat(itemID)
	if(type(GetItemInfo) == "function") then
		return GetItemInfo(itemID);
	end

	if(C_Item and type(C_Item.GetItemInfo) == "function") then
		local results = { pcall(C_Item.GetItemInfo, itemID) };
		if(results[1]) then
			if(type(results[2]) == "table") then
				local info = results[2];
				return info.itemName or info.name, nil, nil, nil, nil, info.itemType, nil, nil, nil, info.iconFileID or info.iconID;
			end
			return select(2, unpackFunc(results));
		end
	end

	return nil;
end

local function GetItemIconCompat(itemID)
	if(C_Item and type(C_Item.GetItemIconByID) == "function") then
		local ok, icon = pcall(C_Item.GetItemIconByID, itemID);
		if(ok and icon) then
			return icon;
		end
	end

	if(type(GetItemIcon) == "function") then
		return GetItemIcon(itemID);
	end

	return nil;
end

local function GetItemCountCompat(itemID)
	if(type(GetItemCount) == "function") then
		return GetItemCount(itemID) or 0;
	end

	if(C_Item and type(C_Item.GetItemCount) == "function") then
		local ok, count = pcall(C_Item.GetItemCount, itemID);
		if(ok and count) then
			return count;
		end
	end

	return 0;
end

local function GetItemCooldownCompat(itemID)
	if(type(GetItemCooldown) == "function") then
		return GetItemCooldown(itemID);
	end

	if(C_Container and type(C_Container.GetItemCooldown) == "function") then
		local ok, start, duration, enable = pcall(C_Container.GetItemCooldown, itemID);
		if(ok) then
			return start or 0, duration or 0, enable;
		end
	end

	return 0, 0, 0;
end

local function StyleButtonIcon(button)
	if(not button or not button.icon) then return end

	button.icon:ClearAllPoints();
	button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3);
	button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3);
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92);
end

local function GetFlyoutArrow(button)
	return button.PBFlyoutArrow or button.FlyoutArrow or button.Arrow;
end

local function EnsureFlyoutArrow(button)
	local arrow = GetFlyoutArrow(button);
	if(not arrow) then
		arrow = button:CreateTexture(nil, "OVERLAY", nil, 6);
		arrow:SetTexture("Interface\\Buttons\\ActionBarFlyoutButton");
		arrow:SetTexCoord(0.62500000, 0.98437500, 0.82812500, 0.74218750);
		arrow:SetSize(23, 11);
	end

	button.PBFlyoutArrow = arrow;
	return arrow;
end

local function GetFlyoutBorder(button)
	return button.PBFlyoutBorder or button.FlyoutBorder;
end

local function EnsureFlyoutBorder(button)
	local border = GetFlyoutBorder(button);
	if(not border) then
		border = button:CreateTexture(nil, "OVERLAY", nil, 5);
		border:SetTexture("Interface\\AddOns\\BattlePetUtility\\media\\border");
		border:SetPoint("TOPLEFT", button, "TOPLEFT", -11, 11);
		border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 11, -11);
	end

	button.PBFlyoutBorder = border;
	return border;
end

local function ApplyCooldownSafely(button, start, duration)
	if(not button or not button.cooldown or type(button.cooldown.SetCooldown) ~= "function") then
		return;
	end

	if(button._cooldownTimer) then
		RGX:CancelTimer(button._cooldownTimer);
		button._cooldownTimer = nil;
	end

	button._cooldownTimer = RGX:After(0, function()
		button._cooldownTimer = nil;
		if(not button.cooldown or type(button.cooldown.SetCooldown) ~= "function") then
			return;
		end
		-- pcall: GetItemCooldown can return tainted "secret" values during restricted execution
		pcall(button.cooldown.SetCooldown, button.cooldown, start or 0, duration or 0);
	end);
end

function addon:CheckSameItems(oldItems, newItems)
	for cid, items in pairs(newItems) do
		if(not oldItems[cid]) then
			-- print("Categories are different");
			return false
		end
		
		for i, itemID in pairs(items) do
			if(not oldItems[cid][i] or oldItems[cid][i] ~= itemID) then
				-- if(not oldItems[cid][i]) then print("Different amount of items")
				-- elseif(oldItems[cid][i] ~= itemID) then print("Different items found") end
				
				return false
			end
		end
	end
	
	-- print("Items should be the same");
	return true;
end

function addon:UpdateItemButtons()
	if(InCombatLockdown()) then return end
	if(not BattlePetUtilityFrame:IsShown()) then return end

	addon:InitializePetItemCategoryDefaults();
	
	if(not addon.previousItems) then
		addon.previousItems = {};
	end
	
	local totalItems, extraButtonData = {}, {};
	
	local currentButtonIndex = 1;
	
	for categoryIndex, data in ipairs(ITEM_BUTTON_CATEGORIES) do
		if(addon:IsPetItemCategoryEnabled(data.key)) then
			local foundItems = {};
			local buttonData = {};
			
			for _, id in ipairs(data.items) do
				if(data.type == "item") then
					if(GetItemCountCompat(id) > 0 or data.alwaysVisible) then
						tinsert(foundItems, id);
					end
				elseif(data.type == "spell") then
					if(IsSpellKnownCompat(id) or data.alwaysVisible) then
						tinsert(foundItems, id);
					end
				end
			end
			
			local numFoundItems = #foundItems;
			if(numFoundItems > 0) then
				if(numFoundItems == 1) then
					buttonData = {
						type = data.type,
						actionData = foundItems[1];
						target = data.target,
					};
				elseif(numFoundItems > 1) then
					buttonData = {
						type = "flyout",
						actionData = {
							iconTexture = data.iconTexture,
							tooltipTitle = data.tooltipTitle,
							tooltipDescription = data.tooltipDescription,
							buttons = {},
						};
					};
					
					for _, id in ipairs(foundItems) do
						tinsert(buttonData.actionData.buttons, {
							type = data.type,
							actionID = id,
							target = data.target,
						})
					end
				end
				
				totalItems[categoryIndex] = foundItems;
				extraButtonData[currentButtonIndex] = buttonData;
				currentButtonIndex = currentButtonIndex + 1;
			end
		end
	end
	
	-- local isSameItems = addon:CheckSameItems(addon.previousItems, totalItems);
	
	-- if(not isSameItems) then
		for i=1,MAX_ITEM_BUTTONS do
			local currentButton = BattlePetUtilityFrameButtons['itemButton' .. i];
			if(currentButton) then currentButton:Hide() end
		end
		
		for currentButtonIndex, buttonData in ipairs(extraButtonData) do
			if(currentButtonIndex > MAX_ITEM_BUTTONS) then break end
			local currentButton = BattlePetUtilityFrameButtons['itemButton' .. currentButtonIndex];
			if(currentButton) then
				BattlePetUtilityFrameButton_Initialize(currentButton, buttonData.type, buttonData.actionData, buttonData.target or nil);
			end
		end
		-- print("Updating buttons")
	-- else
	-- 	-- print("Skipping update because same items");
	-- end
	
	addon.previousItems = totalItems;
end

function BattlePetUtilityFrameButtons_OnShow(self)
	if(not addon._enabled) then
		addon._pendingItemButtonRefresh = true;
		return;
	end

	EnsureItemButtonEventBridge();
	addon._pendingItemButtonRefresh = nil;
	addon:UpdateItemButtons();
end

function BattlePetUtilityFrameButtons_OnHide(self)
end

function BattlePetUtilityFrameButtons_OnEvent(self, event, ...)
	BattlePetUtilityFlyout_Close();
	addon:UpdateItemButtons();
end

function BattlePetUtilityFrameButton_Initialize(self, type, actionData, target)
	self.icon = self.icon or self.Icon;
	self.cooldown = self.cooldown or self.Cooldown;
	self.Count = self.Count or self.count;

	if(not self.icon) then
		self:Hide();
		return;
	end

	StyleButtonIcon(self);

	if(type == nil) then
		self.actionType = nil;
		self.actionData = nil;
		ClearButtonSecureAction(self);
		self:Hide();
		return;
	end

	self:Show();
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	
	-- self.icon:SetTexCoord("0.055", "0.945", "0.055", "0.945")
	
	self.actionType = type;
	self.actionData = actionData;
	
	self.Count:SetText("");
	self.icon:SetVertexColor(1, 1, 1);
	
	self:SetScript("PreClick", nil);
	self:SetScript("PostClick", function()
		if(self.actionType ~= "flyout") then
			self:SetChecked(false);
		end
	end);
	
	-- self:SetScript("OnEnter", function()
	-- 	print(self.actionData, target);
	-- end);
	
	local flyoutArrow = EnsureFlyoutArrow(self);
	local flyoutBorder = EnsureFlyoutBorder(self);
	if(flyoutArrow) then flyoutArrow:Hide(); end
	if(flyoutBorder) then flyoutBorder:Hide(); end
	
	if(self.actionType == "spell") then
		local spellName, _, spellIcon = GetSpellInfoCompat(self.actionData);
		if(not spellName) then
			self.icon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark");
			self.icon:SetVertexColor(0.55, 0.25, 0.25);
			ClearButtonSecureAction(self);
			return;
		end

		self.icon:SetTexture(spellIcon);
		
		SafeSetButtonAttribute(self, "type", "spell");
		SafeSetButtonAttribute(self, "unit", target or "player");
		SafeSetButtonAttribute(self, "spell", spellName);
		self._bpuHasSecureAction = true;
		self._bpuSecureActionKind = "spell";
		
		if(IsSpellKnownCompat(self.actionData) and IsSpellUsableCompat(self.actionData)) then
			self.icon:SetVertexColor(1, 1, 1);
		else
			self.icon:SetVertexColor(0.55, 0.25, 0.25);
		end
		
		local start, duration = GetSpellCooldownCompat(self.actionData);
		ApplyCooldownSafely(self, start, duration);
	elseif(self.actionType == "item") then
		local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfoCompat(self.actionData);
		itemTexture = itemTexture or GetItemIconCompat(self.actionData);
		self.icon:SetTexture(itemTexture or "Interface\\ICONS\\INV_Misc_QuestionMark");
		
		SafeSetButtonAttribute(self, "type", "item");
		SafeSetButtonAttribute(self, "unit", target or "player");
		SafeSetButtonAttribute(self, "item", itemName or ("item:" .. tostring(self.actionData)));
		self._bpuHasSecureAction = true;
		self._bpuSecureActionKind = "item";
		
		-- self:SetScript("PreClick", function()
		-- 	print(self.actionData, target, itemName);
		-- end);
		
		local itemCount = GetItemCountCompat(self.actionData);
		if(IsConsumableItem(self.actionData)) then
			self.Count:SetText(itemCount);
		else
			self.Count:SetText("");
		end
		
		if(itemCount > 0 and IsItemUsableCompat(self.actionData)) then
			self.icon:SetVertexColor(1, 1, 1);
		elseif(itemCount > 0 and not IsItemUsableCompat(self.actionData)) then
			self.icon:SetVertexColor(0.55, 0.25, 0.25);
		else
			self.icon:SetVertexColor(0.55, 0.55, 0.55);
		end
		
		local start, duration = GetItemCooldownCompat(self.actionData);
		ApplyCooldownSafely(self, start, duration);
	elseif(self.actionType == "flyout") then
		self.icon:SetTexture(self.actionData.iconTexture);
		
		if(self.actionData.count) then
			self.Count:SetText(self.actionData.count);
		end
		
		ClearButtonSecureAction(self);
		
		local arrow = EnsureFlyoutArrow(self);
		if(arrow) then
			arrow:Show();
			arrow:ClearAllPoints();
			arrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -7);
			SetClampedTextureRotation(arrow, 180);
		end
		
		local border = EnsureFlyoutBorder(self);
		if(border and border.SetSize) then
			border:SetSize(47, 47);
		end
		
		self:SetScript("PreClick", function()
			if(BattlePetUtilityFlyout:IsShown() and BattlePetUtilityFlyout.anchorFrame ~= self) then
				BattlePetUtilityFlyout_Close();
			end
			
			if(not BattlePetUtilityFlyout:IsShown()) then
				BattlePetUtilityFlyout_Open(self);
			else
				BattlePetUtilityFlyout_Close();
			end
		end);
	elseif(self.actionType == "custom") then
		self.icon:SetTexture(self.actionData.iconTexture);
		
		if(self.actionData.count) then
			self.Count:SetText(self.actionData.count);
		end
		
		ClearButtonSecureAction(self);
		self:SetScript("PreClick", self.actionData.func);
	else
		self.icon:SetTexture("Interface\\Icons\\inv_misc_toy_02");
		self.icon:SetVertexColor(0.3, 0.3, 0.3);
	end
end

function BattlePetUtilityFlyout_Open(parentButton)
	if(not parentButton) then return false end
	
	BattlePetUtilityFlyout.anchorFrame = parentButton;
	
	BattlePetUtilityFlyout_SetFlyoutButtons(parentButton.actionData.buttons);
	
	local border = EnsureFlyoutBorder(parentButton);
	if(border) then border:Show(); end
	-- parentButton.FlyoutBorderShadow:Show();
	local arrow = EnsureFlyoutArrow(parentButton);
	if(arrow) then
		arrow:SetPoint("BOTTOM", parentButton, "BOTTOM", 0, -10);
	end
	
	-- parentButton:SetChecked(false);
	
	BattlePetUtilityFlyout:SetPoint("TOP", parentButton, "BOTTOM", 0, 0);
	BattlePetUtilityFlyout:Show();
end

function BattlePetUtilityFlyout_Close()
	if(BattlePetUtilityFlyout.anchorFrame) then
		BattlePetUtilityFlyout.anchorFrame:SetChecked(false);
	
		local border = GetFlyoutBorder(BattlePetUtilityFlyout.anchorFrame);
		if(border) then border:Hide(); end
		local arrow = GetFlyoutArrow(BattlePetUtilityFlyout.anchorFrame);
		if(arrow) then
			arrow:SetPoint("BOTTOM", BattlePetUtilityFlyout.anchorFrame, "BOTTOM", 0, -7);
		end
		
		BattlePetUtilityFlyout.anchorFrame = nil;
	end
	
	BattlePetUtilityFlyout:Hide();
end

function BattlePetUtilityFlyout_CreateFlyoutButton(index)
	local previousButton = _G["BattlePetUtilityFlyoutButton" .. (index-1)];
	if(not previousButton) then return false end
	
	if(_G["BattlePetUtilityFlyoutButton" .. index]) then return _G["BattlePetUtilityFlyoutButton" .. index] end
	
	local button = CreateFrame("Button", "BattlePetUtilityFlyoutButton" .. index, previousButton, "BattlePetUtilityButtonTemplate", index);
	button:ClearAllPoints();
	button:SetPoint("TOP", previousButton, "BOTTOM", 0, -5);
	
	return button;
end

function BattlePetUtilityFlyout_SetFlyoutButtons(buttonData)
	for index = 1, 20 do
		local button = _G['BattlePetUtilityFlyoutButton' .. index];
		if(button) then
			button:Hide();
		end
	end
	
	for index, data in pairs(buttonData) do
		local button = _G['BattlePetUtilityFlyoutButton' .. index];
		if(not button) then
			button = BattlePetUtilityFlyout_CreateFlyoutButton(index);
		end
		
		BattlePetUtilityFrameButton_Initialize(button, data.type, data.actionID, data.target);
		button:Show();
		
		button:SetScript("PostClick", function()
			BattlePetUtilityFlyout_Close();
		end);
	end
end

function BattlePetUtilityFlyout_OnShow(self)
	CloseMenus();
end

function BattlePetUtilityFlyout_OnHide(self)
	BattlePetUtilityFlyout_Close();
end

function BattlePetUtilityFrameButton_OnEvent(self, event, ...)
	if(event == "SPELL_UPDATE_COOLDOWN") then
		local start, duration = GetSpellCooldownCompat(self.actionData);
		ApplyCooldownSafely(self, start, duration)
	elseif(event == "BAG_UPDATE_DELAYED" and self.actionType == "item") then
		local itemCount = GetItemCountCompat(self.actionData);
		if(IsConsumableItem(self.actionData)) then
			self.Count:SetText(itemCount);
		else
			self.Count:SetText("");
		end
		
		if(itemCount > 0 and IsItemUsableCompat(self.actionData)) then
			self.icon:SetVertexColor(1, 1, 1);
		elseif(itemCount > 0 and not IsItemUsableCompat(self.actionData)) then
			self.icon:SetVertexColor(0.55, 0.25, 0.25);
		else
			self.icon:SetVertexColor(0.55, 0.55, 0.55);
		end
	elseif(event == "BAG_UPDATE_COOLDOWN" and self.actionType == "item") then
		local start, duration = GetItemCooldownCompat(self.actionData);
		ApplyCooldownSafely(self, start, duration);
	end
end

-- function addon:IsUnusableSpell(spellID)
	
-- end

function addon:IsPlayerInCelestialTournament()
	local name, type, difficulty, _, _, _, _, mapID = GetInstanceInfo();
	return difficulty == 12 and mapID == 1161;
end

function BattlePetUtilityFrameButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
	
	if(self.actionType == "spell") then
		GameTooltip:SetSpellByID(self.actionData);
		
		if(not IsSpellUsableCompat(self.actionData)) then
			if(addon:IsPlayerInCelestialTournament()) then
				GameTooltip:AddLine("Cannot use while in Celestial Tournament.", 1, 0.2, 0.2);
			else
				GameTooltip:AddLine("Cannot use right now.", 1, 0.2, 0.2);
			end
		end
	elseif(self.actionType == "item") then
		GameTooltip:SetItemByID(self.actionData);
		
		if(not IsItemUsableCompat(self.actionData) and GetItemCountCompat(self.actionData) > 0) then
			if(addon:IsPlayerInCelestialTournament()) then
				GameTooltip:AddLine("Cannot use while in Celestial Tournament.", 1, 0.2, 0.2);
			else
				GameTooltip:AddLine("Cannot use right now.", 1, 0.2, 0.2);
			end
		end
	elseif(self.actionType == "flyout") then
		GameTooltip:ClearLines();
		GameTooltip:AddLine(self.actionData.tooltipTitle, 1, 1, 1);
		GameTooltip:AddLine(self.actionData.tooltipDescription);
		
		local border = EnsureFlyoutBorder(self);
		if(border) then border:Show(); end
		-- self.FlyoutBorderShadow:Show();
		local arrow = EnsureFlyoutArrow(self);
		if(arrow) then
			arrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -10);
		end
	elseif(self.actionType == "custom") then
		GameTooltip:ClearLines();
		GameTooltip:AddLine(self.actionData.tooltipTitle, 1, 1, 1);
		GameTooltip:AddLine(self.actionData.tooltipDescription);
	end
	
	GameTooltip:Show();
end

function BattlePetUtilityFrameButton_OnLeave(self)
	if(self.actionType == "flyout") then
		if(not BattlePetUtilityFlyout:IsShown() or BattlePetUtilityFlyout.anchorFrame ~= self) then
			local border = GetFlyoutBorder(self);
			if(border) then border:Hide(); end
			-- self.FlyoutBorderShadow:Hide();
			local arrow = GetFlyoutArrow(self);
			if(arrow) then
				arrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -7);
			end
		end
	end
	
	GameTooltip:Hide();
end

function IsConsumableItem(item)
	local _, _, _, _, _, itemType = GetItemInfoCompat(item);
	return itemType == "Consumable";
end
