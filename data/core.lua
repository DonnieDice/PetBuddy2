--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, addon = ...;
_G[ADDON_NAME] = addon;

addon.E = addon.E or {};
addon.ADDON_TITLE = "Battle Pet Utility!";
addon.ADDON_TITLE_COMPACT = "BattlePetUtility!";
addon.ADDON_TITLE_COLORED = "|cffb512fcB|r|cffffffffattle |cffb512fcP|r|cffffffffet |cffb512fcU|r|cfffffffftility|r|cffb512fc!|r";
addon.ADDON_TITLE_COMPACT_COLORED = "|cffb512fcB|r|cffffffffattle|r|cffb512fcP|r|cffffffffet|r|cffb512fcU|r|cfffffffftility|r|cffb512fc!|r";
local E = addon.E;
local unpackFunc = unpack or table.unpack;
local RGX = assert(_G.RGXFramework, "BattlePetUtility: RGX-Framework not loaded");
local PetBattles = RGX:GetPetBattles();
local PET_TYPE_TEXTURE_SUFFIX = {
	[1] = "Humanoid",
	[2] = "Dragon",
	[3] = "Flying",
	[4] = "Undead",
	[5] = "Critter",
	[6] = "Magical",
	[7] = "Elemental",
	[8] = "Beast",
	[9] = "Water",
	[10] = "Mechanical",
};

local FRAME_DEFAULT_HEIGHT = 208;
local FRAME_MINIMIZED_PADDING = 6;
local ZONE_TRACKER_RESERVED_HEIGHT = 112;
local AUTOSUMMON_BLOCK_AFTER_DISMOUNT = 3.0;
local AUTOSUMMON_BLOCK_AFTER_LOGIN = 5.0;
local AUTOSUMMON_BLOCK_AFTER_COMBAT = 2.0;

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

local function GetItemCountCompat(itemID, includeBank)
	if(type(GetItemCount) == "function") then
		return tonumber(GetItemCount(itemID, includeBank)) or tonumber(GetItemCount(itemID)) or 0;
	end

	if(C_Item and type(C_Item.GetItemCount) == "function") then
		local ok, count = pcall(C_Item.GetItemCount, itemID, includeBank);
		if(ok and count) then
			return tonumber(count) or 0;
		end
	end

	return 0;
end

local function GetPetTypeTexturePath(petType)
	if(type(GetPetTypeTexture) == "function") then
		local texturePath = GetPetTypeTexture(petType);
		if(texturePath and texturePath ~= "") then
			return texturePath;
		end
	end

	local suffix = nil;
	if(type(PET_TYPE_SUFFIX) == "table") then
		suffix = PET_TYPE_SUFFIX[petType];
	end

	if(not suffix) then
		suffix = PET_TYPE_TEXTURE_SUFFIX[petType] or "Humanoid";
	end

	return "Interface\\PetBattles\\PetIcon-" .. suffix;
end

local function GetSafeRarityColor(rarity)
	local normalized = tonumber(rarity) or 1;
	if(normalized < 1) then
		normalized = 1;
	end

	return ITEM_QUALITY_COLORS[normalized - 1] or ITEM_QUALITY_COLORS[1] or NORMAL_FONT_COLOR;
end

addon._timers = addon._timers or {};

function addon:RegisterEvent(event, handler)
	if(not event) then return end
	local cb = handler or event;
	local id = "BPU_" .. event;
	if(type(cb) == "function") then
		-- Wrap to preserve original calling convention: handler(addon, event, ...)
		local fn = cb;
		local ok, result = pcall(RGX.RegisterEvent, RGX, event, function(evt, ...) fn(addon, evt, ...); end, id);
		return ok and result ~= false;
	else
		local ok, result = pcall(RGX.RegisterEvent, RGX, event, cb, id, self);
		return ok and result ~= false;
	end
end

function addon:UnregisterEvent(event)
	if(not event) then return end
	RGX:UnregisterEvent(event, "BPU_" .. event);
end

local function RunTimerCallback(callback, args)
	if(type(callback) == "string") then
		local method = addon[callback];
		if(type(method) == "function") then
			method(addon, unpackFunc(args, 1, args.n));
		end
	elseif(type(callback) == "function") then
		callback(unpackFunc(args, 1, args.n));
	end
end

function addon:ScheduleTimer(callback, delay, ...)
	if(not callback or delay == nil) then return nil end

	local args = { n = select("#", ...), ... };
	local timer;

	timer = RGX:After(math.max(0, delay), function()
		addon._timers[timer] = nil;
		RunTimerCallback(callback, args);
	end);

	self._timers[timer] = true;
	return timer;
end

function addon:ScheduleRepeatingTimer(callback, delay, ...)
	if(not callback or delay == nil) then return nil end

	local args = { n = select("#", ...), ... };
	local ticker = RGX:Every(math.max(0.01, delay), function()
		RunTimerCallback(callback, args);
	end);

	self._timers[ticker] = true;
	return ticker;
end

function addon:CancelTimer(timerHandle)
	if(not timerHandle) then return end
	RGX:CancelTimer(timerHandle);
	self._timers[timerHandle] = nil;
end

function addon:CancelAllTimers()
	for timerHandle in pairs(self._timers) do
		RGX:CancelTimer(timerHandle);
		self._timers[timerHandle] = nil;
	end
end

addon.MEDIA_PATH = "Interface\\AddOns\\BattlePetUtility\\media\\";
addon.LOGO_TEXTURE = addon.MEDIA_PATH .. "logo.tga";
addon.CHAT_PREFIX = "|T" .. addon.LOGO_TEXTURE .. ":16:16:0:0|t - |cffffffff[|r|cffb512fcBPU|r|cffffffff]|r ";
addon.CHAT_DEBUG_PREFIX = addon.CHAT_PREFIX .. "|cff808080[DEBUG]|r ";
addon.HEADER_TITLE_TEXT = "|cffb512fcB|r|cffffffffattle |cffb512fcP|r|cffffffffet |cffb512fcU|r|cfffffffftility|r|cffb512fc!|r";

local function GetAddonVersion()
	if(C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function") then
		return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "unknown";
	elseif(type(GetAddOnMetadata) == "function") then
		return GetAddOnMetadata(ADDON_NAME, "Version") or "unknown";
	end

	return "unknown";
end

function addon:PrintMessage(message)
	local line = (self.CHAT_PREFIX or "") .. tostring(message or "");
	if(DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function") then
		DEFAULT_CHAT_FRAME:AddMessage(line);
	else
		print(line);
	end
end

function addon:PrintDebug(message)
	local line = (self.CHAT_DEBUG_PREFIX or "") .. tostring(message or "");
	if(DEFAULT_CHAT_FRAME and type(DEFAULT_CHAT_FRAME.AddMessage) == "function") then
		DEFAULT_CHAT_FRAME:AddMessage(line);
	else
		print(line);
	end
end

function addon:ShowWelcomeMessage()
	if(not self.db or self.db.global.ShowWelcomeMessage == false) then return end

	self:PrintMessage("Welcome! Use |cffb07fff/BPU|r to toggle, and |cffb07fff/BPU help|r for commands.");
	self:PrintMessage("|cffffff00Version:|r |cff8080ff" .. GetAddonVersion() .. "|r");
end

function addon:ToggleWelcomeMessage()
	if(not self.db) then return end

	self.db.global.ShowWelcomeMessage = not self.db.global.ShowWelcomeMessage;
	if(self.db.global.ShowWelcomeMessage) then
		self:PrintMessage("|cff00ff00Welcome message enabled.|r");
	else
		self:PrintMessage("|cffff0000Welcome message disabled.|r");
	end
end

function addon:PrintHelp()
	self:PrintMessage("|cffffff00Battle Pet Utility|r|cffb512fc!|r |cffffff00Commands:|r");
	self:PrintMessage(" |cffb07fff/BPU|r - Toggle Battle Pet Utility|cffb512fc!|r");
	self:PrintMessage(" |cffb07fff/BPU help|r - Show command help");
	self:PrintMessage(" |cffb07fff/BPU welcome|r - Toggle login welcome message");
	self:PrintMessage(" |cffb07fff/BPU version|r - Show current version");
	self:PrintMessage(" |cffb07fff/BPU icon on|r or |cffb07fffoff|r - Show/hide minimap icon");
end

-- Function to toggle the minimap icon visibility
function addon:ToggleMinimapIcon(show)
	if(not self.db or not self.db.global) then return end
	self.db.global.MinimapIcon = self.db.global.MinimapIcon or {};
	if(show ~= nil) then
		self.db.global.MinimapIcon.enabled = show;
	else
		self.db.global.MinimapIcon.enabled = not self.db.global.MinimapIcon.enabled;
	end
	if(type(self.UpdateMinimapIconVisibility) == "function") then
		self:UpdateMinimapIconVisibility();
	end
	if(show == false) then
		self:PrintMessage("|cffffcc00Minimap icon hidden.|r Use |cffb07fff/BPU icon on|r to show it again.");
	elseif(show == true) then
		self:PrintMessage("|cff00ff00Minimap icon shown.|r");
	end
end

local function UpdateHeaderButtonVisual(button, hovered)
	if(not button or not button.label) then
		return;
	end

	local kind = button.buttonKind;
	if(kind == "close") then
		if(hovered) then
			button.label:SetTextColor(1.0, 0.94, 0.98);
		else
			button.label:SetTextColor(0.96, 0.87, 1.0);
		end
	else
		if(hovered) then
			button.label:SetTextColor(0.98, 0.95, 1.0);
		else
			button.label:SetTextColor(0.95, 0.90, 1.0);
		end
	end
end

local function UpdatePepePlacement()
	if(not BattlePetUtilityFrameTitle or not BattlePetUtilityFrameTitle.pepeFrame) then
		return;
	end

	local pepeFrame = BattlePetUtilityFrameTitle.pepeFrame;
	pepeFrame:ClearAllPoints();

	local useLeftSide = addon.db and addon.db.global and addon.db.global.PepeOnLeft == true;
	if(useLeftSide) then
		pepeFrame:SetPoint("BOTTOM", BattlePetUtilityFrameTitle.logo, "TOP", 2, -5);
	else
		pepeFrame:SetPoint("BOTTOM", BattlePetUtilityFrameTitle.closeButton, "TOP", 0, -7);
	end
end

local function RefreshHeaderArt()
	if(BattlePetUtilityFrameTitle and BattlePetUtilityFrameTitle.logo) then
		BattlePetUtilityFrameTitle.logo:SetTexture(addon.LOGO_TEXTURE);
	end

	if(BattlePetUtilityFrameTitle and BattlePetUtilityFrameTitle.titleText) then
		BattlePetUtilityFrameTitle.titleText:SetText(addon.HEADER_TITLE_TEXT);
	end

	if(BattlePetUtilityFrameTitle and BattlePetUtilityFrameTitle.closeButton) then
		UpdateHeaderButtonVisual(BattlePetUtilityFrameTitle.closeButton, false);
	end

	if(BattlePetUtilityFrameTitle and BattlePetUtilityFrameTitle.minimizeButton) then
		UpdateHeaderButtonVisual(BattlePetUtilityFrameTitle.minimizeButton, false);
	end

	UpdatePepePlacement();
end

function addon:RefreshHeaderArt()
	RefreshHeaderArt();
end

local PetsBattleData = {};
addon.PendingStartupRefreshes = addon.PendingStartupRefreshes or 0;

local function TryLoadCollectionsUI()
	if(C_AddOns and type(C_AddOns.LoadAddOn) == "function") then
		pcall(C_AddOns.LoadAddOn, "Blizzard_Collections");
		return;
	end

	if(type(LoadAddOn) ~= "function") then
		return;
	end

	pcall(LoadAddOn, "Blizzard_Collections");
end

function addon:IsFrameMinimized()
	if(not self.db or not self.db.global) then
		return false;
	end

	return self.db.global.IsMinimized == true;
end

function addon:UpdateMinimizeState()
	if(not self.db or not BattlePetUtilityFrame or InCombatLockdown()) then
		return;
	end

	-- Coalescing debounce: immediate execution, then block rapid calls
	if(self._pendingMinimizeUpdate) then
		return;
	end
	self._pendingMinimizeUpdate = true;

	self:_DoUpdateMinimizeState();

	RGX:After(0.1, function()
		self._pendingMinimizeUpdate = false;
	end);
end

function addon:_DoUpdateMinimizeState()
	local minimized = self:IsFrameMinimized();
	BattlePetUtilityFrame.minimized = minimized;

	-- HideMainGUI: hide everything except title bar + zone tracker (compact)
	-- Minimized: hide everything except title bar (no zone tracker)
	local hideMain = self.db.global.HideMainGUI == true;

	local titleHeight = 24;
	if(BattlePetUtilityFrameTitle and type(BattlePetUtilityFrameTitle.GetHeight) == "function") then
		titleHeight = BattlePetUtilityFrameTitle:GetHeight() or titleHeight;
	end

	if(minimized) then
		-- Minimized: show only title bar, hide everything else including zone tracker
		BattlePetUtilityFrame:SetHeight(titleHeight + FRAME_MINIMIZED_PADDING);

		-- Immediately hide zone tracker; RefreshZoneTracker's debounce may skip
		-- the pending call and leave stale text (e.g. value "8 / 12") hanging
		-- outside the collapsed frame.
		if(BattlePetUtilityFrameZoneTracker) then
			BattlePetUtilityFrameZoneTracker:Hide();
		end
		if(type(BattlePetUtilityFlyout_Close) == "function") then
			BattlePetUtilityFlyout_Close();
		end
	elseif(hideMain) then
		-- Hide main GUI body: show title bar + compact zone tracker
		local zoneHeight = 40;
		if(self.db.global.ShowZoneTracker) then
			BattlePetUtilityFrame:SetHeight(titleHeight + zoneHeight + FRAME_MINIMIZED_PADDING);
		else
			BattlePetUtilityFrame:SetHeight(titleHeight + FRAME_MINIMIZED_PADDING);
		end
	else
		-- Expanded: full height with pet frames + zone tracker
		-- Buttons and loadouts are anchored below Pet3 and don't need extra frame height
		local expandedHeight = FRAME_DEFAULT_HEIGHT;
		if(self.db.global.ShowZoneTracker) then
			expandedHeight = expandedHeight + ZONE_TRACKER_RESERVED_HEIGHT;
		end
		self.ExpandedFrameHeight = expandedHeight;
		BattlePetUtilityFrame:SetHeight(self.ExpandedFrameHeight or expandedHeight);
	end

	-- Hide/show pet frames
	for i = 1, 3 do
		local petFrame = _G["BattlePetUtilityFramePet" .. i];
		if(petFrame) then
			if(minimized or hideMain) then
				petFrame:Hide();
			else
				petFrame:Show();
			end
		end
	end

	if(not minimized and not hideMain) then
		self:UpdatePets();
	end

	-- Hide spell selection when minimized or hidden
	if((minimized or hideMain) and BattlePetUtilityFrame.spellSelect) then
		BattlePetUtilityFrame.spellSelect:Hide();
		if(type(BattlePetUtilityPetFrame_ResetAbilitySwitches) == "function") then
			BattlePetUtilityPetFrame_ResetAbilitySwitches();
		end
	end

	-- Hide/show buttons and loadouts
	if(BattlePetUtilityFrameButtons) then
		if(minimized or hideMain) then
			BattlePetUtilityFrameButtons:Hide();
		else
			-- Restore button visibility based on utility menu state
			if(self.db.global.ShowPetItems) then
				BattlePetUtilityFrameButtons:Show();
				self:UpdateItemButtons();
			end
		end
	end

	if(BattlePetUtilityFrameLoadouts) then
		if(minimized or hideMain) then
			BattlePetUtilityFrameLoadouts:Hide();
			if(BattlePetUtilityFrameLoadouts.toggleButton) then
				BattlePetUtilityFrameLoadouts.toggleButton:SetEnabled(false);
				if(BattlePetUtilityFrameLoadouts.toggleButton.icon) then
					BattlePetUtilityFrameLoadouts.toggleButton.icon:SetDesaturated(true);
				end
			end
		else
			-- Restore loadout visibility based on utility menu state
			if(self.db.global.ShowPetLoadouts) then
				BattlePetUtilityFrameLoadouts:Show();
				if(type(BattlePetUtilityFrameLoadouts_UpdateList) == "function") then
					BattlePetUtilityFrameLoadouts_UpdateList();
				end
			end
			if(BattlePetUtilityFrameLoadouts.toggleButton) then
				BattlePetUtilityFrameLoadouts.toggleButton:SetEnabled(true);
				if(BattlePetUtilityFrameLoadouts.toggleButton.icon) then
					BattlePetUtilityFrameLoadouts.toggleButton.icon:SetDesaturated(false);
				end
			end
		end
	end

	-- Update minimize button icon
	local minimizeButton = BattlePetUtilityFrameTitle and BattlePetUtilityFrameTitle.minimizeButton;
	if(minimizeButton) then
		if(minimized) then
			minimizeButton.label:SetText("+");
		else
			minimizeButton.label:SetText("-");
		end
		UpdateHeaderButtonVisual(minimizeButton, false);
	end

	if(type(self.RefreshZoneTracker) == "function") then
		self:RefreshZoneTracker();
	end
end

function addon:HasLoadedTeamSelection()
	if(not C_PetJournal or type(C_PetJournal.GetPetLoadOutInfo) ~= "function") then
		return false;
	end

	for slotIndex = 1, 3 do
		local petID, _, _, _, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
		if(petID and not locked) then
			return true;
		end
	end

	return false;
end

function addon:RunStartupRefresh()
	if(not BattlePetUtilityFrame) then
		return false;
	end

	if(type(self.RestoreSavedSettings) == "function") then
		self:RestoreSavedSettings();
	else
		self:UpdateUtilityMenuState();
		self:UpdateMinimizeState();
		self:UpdatePets();
		if(type(self.RefreshZoneTracker) == "function") then
			self:RefreshZoneTracker();
		end
	end

	return self:HasLoadedTeamSelection();
end

function addon:QueueStartupRefresh(delay)
	self.PendingStartupRefreshes = (self.PendingStartupRefreshes or 0) + 1;
	self:ScheduleTimer(function()
		local ready = addon:RunStartupRefresh();
		addon.PendingStartupRefreshes = math.max(0, (addon.PendingStartupRefreshes or 1) - 1);
		if(not ready and addon.PendingStartupRefreshes == 0) then
			addon:QueueStartupRefresh(1.0);
		end
	end, delay or 0.5);
end

function addon:SetFrameMinimized(shouldMinimize)
	if(not self.db or InCombatLockdown()) then
		return;
	end

	local targetState = shouldMinimize and true or false;
	if(self.db.global.IsMinimized == targetState) then
		return;
	end

	self.db.global.IsMinimized = targetState;
	self:UpdateMinimizeState();
	self:UpdateUtilityMenuState();
end

function addon:ToggleFrameMinimized()
	self:SetFrameMinimized(not self:IsFrameMinimized());
end

function addon:RegisterRuntimeUpdateEvents()
	self:RegisterEvent("PET_BATTLE_PET_CHANGED", self.UpdatePets);
	self:RegisterEvent("PET_BATTLE_HEALTH_CHANGED", self.UpdatePets);
	self:RegisterEvent("PET_BATTLE_LEVEL_CHANGED", self.UpdatePets);
	self:RegisterEvent("PET_BATTLE_XP_CHANGED", self.UpdatePets);
	self:RegisterEvent("PET_JOURNAL_NEW_BATTLE_SLOT", self.UpdatePets);
	self:RegisterEvent("UPDATE_SUMMONPETS_ACTION");
	self:RegisterEvent("PET_JOURNAL_LIST_UPDATE");
end

function addon:OnEnable()
	TryLoadCollectionsUI();
	
	addon.LoginTime = GetTime();
	addon.PetHealTime = 0;
	
	addon:RegisterEvent("PET_BATTLE_OPENING_START");
	addon:RegisterEvent("PET_BATTLE_CLOSE");
	
	addon:RegisterRuntimeUpdateEvents();
	addon:RegisterEvent("PLAYER_ENTERING_WORLD");
	addon:RegisterEvent("PLAYER_ALIVE", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("PLAYER_UNGHOST", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("PLAYER_CONTROL_GAINED", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("UNIT_EXITED_VEHICLE", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("UNIT_AURA", addon.HandleAutoSummonTrigger);
	
	addon:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	
	addon:RegisterEvent("CURSOR_CHANGED", addon.CURSOR_UPDATE);
	
	addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	addon:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	addon:RegisterEvent("GOSSIP_SHOW");
	addon:RegisterEvent("GOSSIP_CLOSED");
	addon:RegisterEvent("GOSSIP_CONFIRM");
	
	addon:RegisterEvent("BARBER_SHOP_OPEN");
	addon:RegisterEvent("BARBER_SHOP_CLOSE");
	
	addon:UpdatePets();
	addon:HandleAutoSummonTrigger("PLAYER_ENTERING_WORLD");
	addon.PendingStartupRefreshes = 0;
	addon:QueueStartupRefresh(0.25);
	addon:QueueStartupRefresh(0.75);
	addon:QueueStartupRefresh(1.5);
	
	addon:ScheduleRepeatingTimer(function()
		addon:UpdateAutoResummon();

		if(GossipFrame:IsShown() and addon.PetHealer and addon.PetHealer.IsGarrisonNPC) then
			addon:UpdateWoundedText();
		end
	end, 1.0);
end

function addon:RefreshPetJournalLoadOut()
	-- Refresh the Blizzard Pet Journal loadout UI so our selected team is restored
	if(type(PetJournal_UpdatePetLoadOut) == "function") then
		PetJournal_UpdatePetLoadOut();
	else
		addon:UpdatePets();
	end
end

function BattlePetUtilitySetUtility(utility_id)
	if(not addon or not addon.db) then return end
	if(InCombatLockdown()) then return end
	
	BattlePetUtilityFrame:Show();
	
	addon.db.global.PetUtilityMenuState = utility_id or 0;
	addon:UpdateUtilityMenuState();
end

function BattlePetUtilityFocusSearch()
	BattlePetUtilitySetUtility(2);
	if(type(BattlePetUtilityFrameLoadoutsScrollFrame_ToggleVisibility) == "function") then
		BattlePetUtilityFrameLoadoutsScrollFrame_ToggleVisibility(true);
	end
end

function BattlePetUtilityPetFrame_ResetAbilitySwitches(self)
	for slotIndex = 1, 3 do
		local petFrame = _G['BattlePetUtilityFramePet' .. slotIndex];
		if(petFrame ~= self) then
			petFrame.SwitchingAbilities = false;
			petFrame.stats:Show();
			petFrame.abilities:Hide();
			
			petFrame.abilities.spell1.selected:Hide();
			petFrame.abilities.spell2.selected:Hide();
			petFrame.abilities.spell3.selected:Hide();
		end
	end
end

function BattlePetUtilityPetFrame_OnClick(self, button)
	if(InCombatLockdown()) then return end
	
	if(button == "LeftButton") then
		BattlePetUtilityPetFrame_ResetAbilitySwitches(self);
		
		self.SwitchingAbilities = not self.SwitchingAbilities;
		if(self.SwitchingAbilities) then
			self.stats:Hide();
			self.abilities:Show();
		else
			self.stats:Show();
			self.abilities:Hide();
		end
		
		if(BattlePetUtilityFrame.spellSelect.currentAnchor) then
			-- BattlePetUtilityFrame.spellSelect.selected:Hide();
			BattlePetUtilityFrame.spellSelect.currentAnchor:SetChecked(false);
		end
		BattlePetUtilityFrame.spellSelect:Hide();
		
	elseif(button == "RightButton") then
		addon:OpenContextMenu();
	end
end

function addon:UpdateUtilityMenuState()
	if(InCombatLockdown()) then return end

	local minimized = addon:IsFrameMinimized();
	local hideMain = minimized or (addon.db.global.HideMainGUI == true);
	local menuState = tonumber(addon.db.global.PetUtilityMenuState) or 0;
	menuState = math.floor(menuState);
	if(menuState < 0 or menuState > 3) then
		menuState = 0;
	end
	addon.db.global.PetUtilityMenuState = menuState;

	local showItems = (menuState == 1 or menuState == 3);
	local showLoadouts = (menuState == 2 or menuState == 3);
	local scrollFrame = BattlePetUtilityFrameLoadoutsScrollFrame;
	local showLoadoutList = (showLoadouts and scrollFrame and scrollFrame:IsShown()) and true or false;

	addon.db.global.ShowPetItems = showItems;
	addon.db.global.ShowPetLoadouts = showLoadouts;

	BattlePetUtilityFrameButtons:ClearAllPoints();
	BattlePetUtilityFrameButtons:SetPoint("TOPLEFT", BattlePetUtilityFramePet3, "BOTTOMLEFT", 0, 0);
	BattlePetUtilityFrameLoadouts:ClearAllPoints();
	if(showItems) then
		BattlePetUtilityFrameLoadouts:SetPoint("TOPLEFT", BattlePetUtilityFrameButtons, "TOPLEFT", 0, 0);
	else
		BattlePetUtilityFrameLoadouts:SetPoint("TOPLEFT", BattlePetUtilityFramePet3, "BOTTOMLEFT", 0, 0);
	end

	if(showItems and not minimized and not hideMain) then
		BattlePetUtilityFrameButtons:Show();
		addon:UpdateItemButtons();
	else
		BattlePetUtilityFrameButtons:Hide();
	end

	if(showLoadouts and not minimized and not hideMain) then
		BattlePetUtilityFrameLoadouts:Show();
		BattlePetUtilityFrameLoadouts_UpdateList();
	else
		BattlePetUtilityFrameLoadouts:Hide();
	end

	if(type(BattlePetUtilityFrameLoadoutsScrollFrame_ToggleVisibility) == "function") then
		BattlePetUtilityFrameLoadoutsScrollFrame_ToggleVisibility(showLoadoutList and not minimized and not hideMain);
	end

	if(type(addon.RefreshZoneTracker) == "function") then
		addon:RefreshZoneTracker();
	end
end

function addon:SyncUtilityMenuState()
	if(not self.db or not self.db.global) then
		return 0;
	end

	local menuState = tonumber(self.db.global.PetUtilityMenuState);
	if(menuState ~= nil) then
		menuState = math.floor(menuState);
	end

	if(menuState == nil or menuState < 0 or menuState > 3) then
		local showItems = self.db.global.ShowPetItems == true;
		local showLoadouts = self.db.global.ShowPetLoadouts == true;

		if(showItems and showLoadouts) then
			menuState = 3;
		elseif(showLoadouts) then
			menuState = 2;
		elseif(showItems) then
			menuState = 1;
		else
			menuState = 0;
		end
	end

	self.db.global.PetUtilityMenuState = menuState;
	self.db.global.ShowPetItems = (menuState == 1 or menuState == 3);
	self.db.global.ShowPetLoadouts = (menuState == 2 or menuState == 3);
	return menuState;
end

function BattlePetUtilityFrame_OnMouseWheel(self, delta)
	if(InCombatLockdown() or PetBattles:IsInBattle()) then return end

	local cycle = { 0, 1, 3, 2 };
	local menuState = tonumber(addon.db.global.PetUtilityMenuState) or 0;
	local cycleIndex = 1;
	for i, state in ipairs(cycle) do
		if(state == menuState) then
			cycleIndex = i;
			break
		end
	end

	if(delta > 0) then
		cycleIndex = cycleIndex - 1;
	else
		cycleIndex = cycleIndex + 1;
	end

	if(cycleIndex < 1) then cycleIndex = #cycle; end
	if(cycleIndex > #cycle) then cycleIndex = 1; end
	menuState = cycle[cycleIndex];

	addon.db.global.PetUtilityMenuState = menuState;
	
	addon:UpdateUtilityMenuState();
	
	CloseMenus();
end

function BattlePetUtilityFrame_GetRequiredLevel(petFrame, abilityID)
	for i=1, 6 do
		if(petFrame.petAbilities[i] == abilityID) then
			return petFrame.petAbilityLevels[i];
		end
	end
	return 0;
end

function BattlePetUtilityFrame_ShowPetSelect(self)
	local slotFrame = self:GetParent():GetParent();
	local abilities = slotFrame.petAbilities;
	local slotIndex = slotFrame:GetID();

	local abilityIndex = self:GetID();
	local spellIndex1 = abilityIndex;
	local spellIndex2 = spellIndex1 + 3;
	
	-- print(slotFrame:GetName(), slotIndex, slotFrame.petID)
	
	--Get the info for the pet that has this ability
	local speciesID, customName, level, xp, maxXp, displayID, isFavorite, petName, petIcon, petType = C_PetJournal.GetPetInfoByPetID(slotFrame.petID);
	
	if BattlePetUtilityFrame.spellSelect:IsShown() then 
		if BattlePetUtilityFrame.spellSelect.slotIndex == slotIndex and 
			BattlePetUtilityFrame.spellSelect.abilityIndex == abilityIndex then
			BattlePetUtilityFrame.spellSelect:Hide();
			self.selected:Hide();
			return;
		elseif(BattlePetUtilityFrame.spellSelect.currentAnchor and BattlePetUtilityFrame.spellSelect.currentAnchor ~= self) then
			BattlePetUtilityFrame.spellSelect.currentAnchor:SetChecked(false);
			BattlePetUtilityFrame.spellSelect.currentAnchor.selected:Hide();
			BattlePetUtilityFrame.spellSelect.currentAnchor = nil;
			-- BattlePetUtilityFrame.Loadout["Pet"..BattlePetUtilityFrame.spellSelect.slotIndex]["spell"..BattlePetUtilityFrame.spellSelect.abilityIndex].selected:Hide();
		end
	end
	
	self.selected:Show();
	BattlePetUtilityFrame.spellSelect.slotIndex = slotIndex;
	BattlePetUtilityFrame.spellSelect.abilityIndex = abilityIndex;
	BattlePetUtilityFrame.spellSelect:SetFrameLevel(PetJournalLoadoutBorder:GetFrameLevel()+1);
	PetJournal_HideAbilityTooltip();
	
	--Setup spell one
	local name, icon, petType, requiredLevel;
	if (abilities[spellIndex1]) then
		name, icon, petType = C_PetJournal.GetPetAbilityInfo(abilities[spellIndex1]);
		requiredLevel = BattlePetUtilityFrame_GetRequiredLevel(slotFrame, abilities[spellIndex1]);
		BattlePetUtilityFrame.spellSelect.Spell1:SetEnabled(requiredLevel <= level);
	else
		name = "";
		icon = "";
		petType = "";
		requiredLevel = 0;
		BattlePetUtilityFrame.spellSelect.Spell1:SetEnabled(false);
	end

	if ( requiredLevel > level ) then
		BattlePetUtilityFrame.spellSelect.Spell1.additionalText = format(PET_ABILITY_REQUIRES_LEVEL, requiredLevel);
	else
		BattlePetUtilityFrame.spellSelect.Spell1.additionalText = nil;
	end
	BattlePetUtilityFrame.spellSelect.Spell1.icon:SetTexture(icon);
	BattlePetUtilityFrame.spellSelect.Spell1.icon:SetDesaturated(requiredLevel > level);
	BattlePetUtilityFrame.spellSelect.Spell1.BlackCover:SetShown(requiredLevel > level);
	BattlePetUtilityFrame.spellSelect.Spell1.LevelRequirement:SetShown(requiredLevel > level);
	BattlePetUtilityFrame.spellSelect.Spell1.LevelRequirement:SetText(requiredLevel);
	BattlePetUtilityFrame.spellSelect.Spell1.slotIndex = slotIndex;
	BattlePetUtilityFrame.spellSelect.Spell1.abilityIndex = abilityIndex;
	BattlePetUtilityFrame.spellSelect.Spell1.abilityID = abilities[spellIndex1];
	BattlePetUtilityFrame.spellSelect.Spell1.petID = slotFrame.petID;
	BattlePetUtilityFrame.spellSelect.Spell1.speciesID = slotFrame.speciesID;
	
	--Setup spell two
	if (abilities[spellIndex2]) then
		name, icon, petType = C_PetJournal.GetPetAbilityInfo(abilities[spellIndex2]);
		requiredLevel = BattlePetUtilityFrame_GetRequiredLevel(slotFrame, abilities[spellIndex2]);
		BattlePetUtilityFrame.spellSelect.Spell2:SetEnabled(requiredLevel <= level);
	else
		name = "";
		icon = "";
		petType = "";
		requiredLevel = 0;
		BattlePetUtilityFrame.spellSelect.Spell2:SetEnabled(false);
	end

	if ( requiredLevel > level ) then
		BattlePetUtilityFrame.spellSelect.Spell2.additionalText = format(PET_ABILITY_REQUIRES_LEVEL, requiredLevel);
	else
		BattlePetUtilityFrame.spellSelect.Spell2.additionalText = nil;
	end
	BattlePetUtilityFrame.spellSelect.Spell2.icon:SetTexture(icon);
	BattlePetUtilityFrame.spellSelect.Spell2.BlackCover:SetShown(requiredLevel > level);
	BattlePetUtilityFrame.spellSelect.Spell2.icon:SetDesaturated(requiredLevel > level);
	BattlePetUtilityFrame.spellSelect.Spell2.LevelRequirement:SetShown(requiredLevel > level);
	BattlePetUtilityFrame.spellSelect.Spell2.LevelRequirement:SetText(requiredLevel);
	BattlePetUtilityFrame.spellSelect.Spell2.slotIndex = slotIndex;
	BattlePetUtilityFrame.spellSelect.Spell2.abilityIndex = abilityIndex;
	BattlePetUtilityFrame.spellSelect.Spell2.abilityID = abilities[spellIndex2];
	BattlePetUtilityFrame.spellSelect.Spell2.petID = slotFrame.petID;
	BattlePetUtilityFrame.spellSelect.Spell2.speciesID = slotFrame.speciesID;
	
	BattlePetUtilityFrame.spellSelect.Spell1:SetChecked(self.abilityID == abilities[spellIndex1]);
	BattlePetUtilityFrame.spellSelect.Spell2:SetChecked(self.abilityID == abilities[spellIndex2]);
	
	BattlePetUtilityFrame.spellSelect:SetPoint("TOP", self, "BOTTOM", 0, 0);
	BattlePetUtilityFrame.spellSelect:Show();
	
	BattlePetUtilityFrame.spellSelect.currentAnchor = self;
end

function addon:UpdatePetAbility(abilityFrame, abilityID, petID)
	local speciesID, customName, level, xp, maxXp, displayID, isFavorite, petName, petIcon, petType = C_PetJournal.GetPetInfoByPetID(petID);
	local requiredLevel = BattlePetUtilityFrame_GetRequiredLevel(abilityFrame:GetParent():GetParent(), abilityID);
	
	local name, icon, typeEnum = C_PetJournal.GetPetAbilityInfo(abilityID);
	abilityFrame.icon:SetTexture(icon);
	abilityFrame.abilityID = abilityID;
	abilityFrame.petID = petID;
	abilityFrame.speciesID = speciesID;
	abilityFrame.selected:Hide();
	
	local levelTooLow = requiredLevel > level;
	abilityFrame.icon:SetDesaturated(levelTooLow);
	abilityFrame.BlackCover:SetShown(levelTooLow);
	abilityFrame.LevelRequirement:SetText(requiredLevel);
	abilityFrame.LevelRequirement:SetShown(levelTooLow);
	
	if(levelTooLow) then
		abilityFrame.additionalText = format(PET_ABILITY_REQUIRES_LEVEL, requiredLevel);
	else
		abilityFrame.additionalText = nil;
	end
end

function addon:UpdateBattleData()
	local index = 1;
	
	wipe(PetsBattleData);
	for slotIndex = 1, 3 do
		local petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
		if(locked or not petID) then break end
		
		local health = C_PetJournal.GetPetStats(petID);
		if(health > 0) then
			PetsBattleData[index] = {
				petID = petID,
				slotIndex = slotIndex,
				battleIndex = index,
			};
			
			index = index + 1;
		end
	end
end

function addon:PET_BATTLE_OPENING_START()
	if(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.SHOW and not BattlePetUtilityFrame:IsShown()) then
		BattlePetUtilityFrame:Show();
		addon.BattleVisibilityChange = true;
	elseif(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.HIDE and BattlePetUtilityFrame:IsShown()) then
		BattlePetUtilityFrame:Hide();
		addon.BattleVisibilityChange = true;
	end
	
	addon.UtilityMenu = self.db.global.PetUtilityMenuState;
	self.db.global.PetUtilityMenuState = 0;
	addon:UpdateUtilityMenuState();
	
	addon:UpdateNumWoundedPets();
	
	addon:UpdateBattleData();
	addon:UpdatePets();
end

function addon:PET_BATTLE_CLOSE()
	if(addon.BattleVisibilityChange) then
		if(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.SHOW) then
			BattlePetUtilityFrame:Hide();
		elseif(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.HIDE) then
			BattlePetUtilityFrame:Show();
		end
		
		addon.BattleVisibilityChange = false;
	end
	
	if(self.db.global.PetUtilityMenuState == 0 and addon.UtilityMenu) then
		self.db.global.PetUtilityMenuState = addon.UtilityMenu;
		addon.UtilityMenu = nil;
		addon:UpdateUtilityMenuState();
	end
	
	addon:UpdatePets();
	addon:UpdateNumWoundedPets();
	addon:ScheduleTimer(function()
		addon:UpdateAutoResummon(false);
	end, 1.0);
end

function addon:UpdatePets()
	if(InCombatLockdown()) then return end

	-- Immediate execution if no pending update, otherwise coalesce
	if(self._pendingPetsUpdate) then
		return;
	end

	-- First call executes immediately for responsive UI
	self._pendingPetsUpdate = true;
	self:_DoUpdatePets();

	-- Subsequent calls within 0.15s window will be coalesced
	RGX:After(0.15, function()
		self._pendingPetsUpdate = false;
	end);
end

function addon:SaveCurrentTeam()
  if(not self.db or not self.db.char) then return end
  if(not C_PetJournal or type(C_PetJournal.GetPetLoadOutInfo) ~= "function") then return end

  local team = {};
  local hasPets = false;

  for slotIndex = 1, 3 do
    local petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
    if(petID and not locked) then
      hasPets = true;
      team[slotIndex] = {
        petID = petID,
        abilities = { ability1, ability2, ability3 },
      };
    else
      team[slotIndex] = nil;
    end
  end

  if(hasPets) then
    self.db.char.LastActiveTeam = team;
    self.db.char.LastSavedMapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player") or nil;
  end
end

function addon:RestoreLastTeam()
  if(not self.db or not self.db.char) then return false end
  if(not self.db.char.LastActiveTeam) then return false end
  if(not C_PetJournal or type(C_PetJournal.SetPetLoadOutInfo) ~= "function") then return false end

  local team = self.db.char.LastActiveTeam;
  local canRestore = true;

  -- Verify all pets in saved team are still valid
  for slotIndex, data in ipairs(team) do
    if(data and data.petID) then
      local speciesID = C_PetJournal.GetPetInfoByPetID(data.petID);
      if(not speciesID) then
        canRestore = false;
        break
      end
    end
  end

  if(not canRestore) then
    self.db.char.LastActiveTeam = nil;
    return false;
  end

  -- Restore the team
  for slotIndex, data in ipairs(team) do
    if(data and data.petID) then
      C_PetJournal.SetPetLoadOutInfo(slotIndex, data.petID);
      if(data.abilities) then
        for spellIndex, abilityID in ipairs(data.abilities) do
          if(abilityID) then
            C_PetJournal.SetAbility(slotIndex, spellIndex, abilityID);
          end
        end
      end
    end
  end

  self:RefreshPetJournalLoadOut();
  return true;
end

function addon:ShouldRestoreLastTeam()
  if(not self.db or not self.db.char) then return false end
  if(not self.db.char.LastActiveTeam) then return false end

  -- Check if current loadout is empty (no pets in slots)
  local hasCurrentPets = false;
  for slotIndex = 1, 3 do
    local petID, _, _, _, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
    if(petID and not locked) then
      hasCurrentPets = true;
      break
    end
  end

  -- Only restore if current loadout is empty
  return not hasCurrentPets;
end

function addon:_DoUpdatePets()
  local minimized = self:IsFrameMinimized();
  local hideMain = self.db and self.db.global.HideMainGUI == true;
  if(not PetsBattleData and PetBattles:IsInBattle()) then
    addon:UpdateBattleData();
  end

  -- Auto-save current team whenever pets are updated (for restoration later)
  addon:SaveCurrentTeam();

  addon:UpdateDatabrokerText();
	
	for slotIndex = 1, 3 do
		local petFrame = _G['BattlePetUtilityFramePet' .. slotIndex];
		if(not petFrame) then return end
		
		local hasActivePetInSlot = true;
		local realSlotIndex = slotIndex;
		local battleIndex = slotIndex;
		
		if(PetBattles:IsInBattle()) then
			if(slotIndex > PetBattles:GetNumPets(1)) then
				hasActivePetInSlot = false;
			elseif(PetsBattleData[slotIndex]) then
				realSlotIndex = PetsBattleData[slotIndex].slotIndex;
				battleIndex = PetsBattleData[slotIndex].battleIndex;
			end
		end
		
		if(hasActivePetInSlot) then
			local petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(realSlotIndex);
			
			if(petID and not locked) then
				petFrame.petID = petID;
				
				local speciesID, customName, level, xp, maxXp, displayID, isFavorite, speciesName, icon, petType, creatureID = C_PetJournal.GetPetInfoByPetID(petID);
				local health, maxHealth, _, _, rarity = C_PetJournal.GetPetStats(petID);
				local isDead = (health == 0);
				
				--Read ability/ability levels into the correct tables
				C_PetJournal.GetPetAbilityList(speciesID, petFrame.petAbilities, petFrame.petAbilityLevels);
				
				addon:UpdatePetAbility(petFrame.abilities.spell1, ability1, petID);
				addon:UpdatePetAbility(petFrame.abilities.spell2, ability2, petID);
				addon:UpdatePetAbility(petFrame.abilities.spell3, ability3, petID);
		
				petFrame.abilities.typeInfo.petID = petID;
				petFrame.abilities.typeInfo.speciesID = speciesID;
				petFrame.abilities.typeInfo.abilityID = PET_BATTLE_PET_TYPE_PASSIVES[petType];
				petFrame.abilities.typeInfo.icon:SetTexture(GetPetTypeTexturePath(petType));
				
				if(GetCursorInfo() ~= "battlepet") then
					petFrame.glowHighlight:Hide();
				end
				
				if(PetBattles:IsInBattle()) then
					health = PetBattles:GetHealth(1, battleIndex);
					maxHealth = PetBattles:GetMaxHealth(1, battleIndex);
					
					isDead = (health == 0);
					
					local activePetIndex = PetBattles:GetActivePet(1);
					if(activePetIndex == battleIndex) then
						petFrame.glowHighlight:Show();
					end
				end
				
				local rarityColor = GetSafeRarityColor(rarity);
				
				petFrame.icon:Show();
				petFrame.icon:SetTexture(icon);
				petFrame.iconBorder:SetVertexColor(rarityColor.r, rarityColor.g, rarityColor.b);
				
				petFrame.petTypeTexture:Show();
				petFrame.petTypeTexture:SetTexture(GetPetTypeTexturePath(petType));

				petFrame.petName:SetFormattedText("%s[%d]|r %s", rarityColor.hex, level, customName or speciesName);
				
				if(not petFrame.SwitchingAbilities) then
					petFrame.stats:Show();
					petFrame.stats.petHealth:Show();
				end
				
				petFrame.stats.petHealth:SetMinMaxValues(0, maxHealth);
				petFrame.stats.petHealth:SetValue(health);
				
				local healthText = "";
				if(not self.db or not self.db.global.PetStatsText.ShowHealthPercentage or not maxHealth or maxHealth <= 0) then
					healthText = string.format("%d/%d", health, maxHealth);
				else
					healthText = string.format("%d/%d (%d%%)", health, maxHealth, health / maxHealth * 100);
				end
				
				petFrame.stats.petHealth.text:SetText(healthText);
				
				petFrame.dragButton.petTypeIcon:Show();
				petFrame.dragButton.petTypeIcon:SetTexture(GetPetTypeTexturePath(petType));
				
				if(level < 25 and maxXp > 0) then
					if(not petFrame.SwitchingAbilities) then
						petFrame.stats.petExperience:Show();
					end
					
					petFrame.stats.petExperience:SetMinMaxValues(0, maxXp);
					petFrame.stats.petExperience:SetValue(xp);
					
					local xpText = "";
					if(not self.db or self.db.global.PetStatsText.RemainingExperience) then
						xpText = string.format("%d", maxXp - xp);
					else
						xpText = string.format("%d/%d", xp, maxXp);
					end
					
					if(not self.db or self.db.global.PetStatsText.ShowExperiencePercentage) then
						local percentage = 0;
						if(not self.db or not self.db.global.PetStatsText.RemainingExperience) then
							percentage = xp / maxXp * 100;
						else
							percentage = (maxXp - xp) / maxXp * 100;
						end
						
						xpText = string.format("%s (%d%%)", xpText, percentage);
					end
					
					petFrame.stats.petExperience.text:SetText(xpText);
				else
					petFrame.stats.petExperience:Hide();
					petFrame.stats.petExperience:SetMinMaxValues(0, 1);
					petFrame.stats.petExperience:SetValue(0);
					petFrame.stats.petExperience.text:SetText("");
				end
				
				if(isDead) then
					petFrame.isDead:Show();
				else
					petFrame.isDead:Hide();
				end
				
				petFrame.slotInfoText:Hide();
			else
				petFrame.petID = nil;
				
				petFrame.icon:Hide();
				petFrame.isDead:Show();
				
				petFrame.iconBorder:SetVertexColor(0.8, 0.1, 0.1);
				
				petFrame.dragButton.petTypeIcon:Hide();
				petFrame.petTypeTexture:Hide();
				
				if(locked) then
					petFrame.stats:Hide();
					
					petFrame.petName:SetText("|cffffee00Slot Locked|r");
					
					petFrame.slotInfoText:Show();
					
					if(self.db.global.ShowPetItems and not minimized) then
						BattlePetUtilityFrameButtons:Show();
					end
					
					if(slotIndex == 1) then
						BattlePetUtilityFrameButtons:Hide();
						petFrame.slotInfoText:SetText("Learn Battle Pet Training to Unlock This Slot");
					elseif(slotIndex == 2) then
						petFrame.slotInfoText:SetText("Earn Achievement |cffffff00[Newbie]|r to Unlock This Slot");
					elseif(slotIndex == 3) then
						petFrame.slotInfoText:SetText("Earn Achievement |cffffff00[Just a Pup]|r to Unlock This Slot");
					end
				elseif(not petID and locked == false) then
					petFrame.stats:Hide();
					
					petFrame.petName:SetText("|cffffee00Empty Slot|r");
					
					petFrame.slotInfoText:Show();
					petFrame.slotInfoText:SetText("Add a Battle Pet to This Slot");
				end
			end
			
			if(minimized or hideMain) then
				petFrame:Hide();
			else
				petFrame:Show();
			end
		else
			petFrame:Hide();
		end
	end

	if(type(BattlePetUtilityFrameLoadouts_UpdateList) == "function") then
		local ok, err = pcall(BattlePetUtilityFrameLoadouts_UpdateList);
		if(not ok) then
			self:PrintDebug("Loadout list refresh failed: " .. tostring(err));
		end
	end

	if(type(self.RefreshZoneTracker) == "function") then
		self:RefreshZoneTracker();
	end
end

function BattlePetUtilityFrame_StartMoving(button)
	if(button and button ~= "LeftButton") then return end

	if(not addon.db or not addon.db.global) then return end
	if(addon.db.global.IsFrameLocked) then return end
	
	CloseMenus();
	
	BattlePetUtilityFrame:StartMoving();
	BattlePetUtilityFrame:SetUserPlaced(false);
	BattlePetUtilityFrame.IsMoving = true;
	
	-- BattlePetUtilityPetFrame_ResetAbilitySwitches();
end

function BattlePetUtilityFrame_StopMoving(button)
	if(button and button ~= "LeftButton") then return end

	if(BattlePetUtilityFrame.IsMoving) then
		BattlePetUtilityFrame:StopMovingOrSizing();
		BattlePetUtilityFrame.IsMoving = false;
		BattlePetUtilityFrame_SavePosition();
	end
end

function addon:UPDATE_SUMMONPETS_ACTION()
	addon:UpdatePets();
	addon:UpdateAutoResummon();
end

function addon:PET_JOURNAL_LIST_UPDATE()
	if(type(addon.InvalidateZoneQualityCache) == "function") then
		addon:InvalidateZoneQualityCache();
	end
	addon:UpdatePets();
	addon:UpdateAutoResummon();
end

local function IsCursorOverFrame(frame)
	if(not frame or not frame:IsShown()) then return false end

	local left, bottom, width, height = frame:GetRect();
	if(not left or not bottom or not width or not height) then
		return false;
	end

	local right = left + width;
	local top = bottom + height;
	local scale = UIParent:GetEffectiveScale();
	local cursorX, cursorY = GetCursorPosition();
	cursorX = cursorX / scale;
	cursorY = cursorY / scale;

	return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top;
end

----------------------------

BattlePetUtility_PetCharmsMixin = {}

function addon:RefreshPetCharms()
	local frame = BattlePetUtilityFrameTitlePetCharms;
	if(not frame) then return end;
	local charmIcon, charmsNumAmount = self:GetPetCharmsInfo();
	if(charmIcon ~= nil and charmsNumAmount ~= nil) then
		frame.text:SetText(tostring(charmsNumAmount));
		frame.icon:SetTexture(charmIcon);
	end
	self:UpdateDatabrokerText();
end

function BattlePetUtility_PetCharmsMixin:OnShow()
	addon:RefreshPetCharms();
end

function BattlePetUtility_PetCharmsMixin:OnHide()
end

local PET_CHARM_ITEM_IDS = {
	163036, -- Polished Pet Charm
	116415, -- Shiny Pet Charm
};

local function BuildPetCharmNameSet()
	local names = {
		["pet charm"] = true,
		["polished pet charm"] = true,
		["shiny pet charm"] = true,
	};

	for _, itemID in ipairs(PET_CHARM_ITEM_IDS) do
		local itemName = GetItemInfoCompat(itemID);
		if(itemName and itemName ~= "") then
			names[string.lower(itemName)] = true;
		end
	end

	return names;
end

local function IsPetCharmName(name, charmNameSet)
	if(type(name) ~= "string" or name == "") then
		return false;
	end

	local lowered = string.lower(name);
	if(charmNameSet[lowered]) then
		return true;
	end

	return string.find(lowered, "pet charm", 1, true) ~= nil;
end

local function GetTrackedItemCount(itemID)
	if(C_Item and type(C_Item.GetItemCount) == "function") then
		local ok, count = pcall(C_Item.GetItemCount, itemID, true, false, true, true);
		if(ok and type(count) == "number") then
			return count;
		end
	end

	return GetItemCountCompat(itemID, true);
end

function addon:GetPetCharmsInfo()
	local entries = {};
	local totalAmount = 0;
	local displayIcon = nil;
	local charmNameSet = BuildPetCharmNameSet();

	for _, itemID in ipairs(PET_CHARM_ITEM_IDS) do
		local amount = GetTrackedItemCount(itemID);
		local itemName = GetItemInfoCompat(itemID);
		local itemIcon = GetItemIconCompat(itemID);

		if(itemIcon and not displayIcon) then
			displayIcon = itemIcon;
		end

		if(amount > 0) then
			totalAmount = totalAmount + amount;
			tinsert(entries, {
				source = "item",
				id = itemID,
				name = itemName or ("Item " .. tostring(itemID)),
				amount = amount,
				icon = itemIcon,
			});
		end
	end

	if(C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyListSize) == "function" and type(C_CurrencyInfo.GetCurrencyListInfo) == "function") then
		local count = C_CurrencyInfo.GetCurrencyListSize();
		for index = 1, count do
			local info = C_CurrencyInfo.GetCurrencyListInfo(index);
			if(type(info) == "table" and not info.isHeader and not info.isTypeUnused) then
				local amount = tonumber(info.quantity or info.totalQuantity) or 0;
				if(amount > 0 and IsPetCharmName(info.name, charmNameSet)) then
					local icon = info.iconFileID or info.icon;
					totalAmount = totalAmount + amount;
					tinsert(entries, {
						source = "currency",
						id = info.currencyTypesID or info.currencyType,
						name = info.name or "Pet Charm",
						amount = amount,
						icon = icon,
					});

					if(icon and not displayIcon) then
						displayIcon = icon;
					end
				end
			end
		end
	end

	if(not displayIcon) then
		displayIcon = GetItemIconCompat(PET_CHARM_ITEM_IDS[1]) or "Interface\\Icons\\INV_Misc_QuestionMark";
	end

	return displayIcon, totalAmount, entries;
end

function BattlePetUtility_PetCharmsMixin:OnEvent(event, ...)
	local charmIcon, charmsNumAmount = addon:GetPetCharmsInfo();
	if(charmIcon ~= nil and charmsNumAmount ~= nil) then
		self.text:SetText(tostring(charmsNumAmount));
		self.icon:SetTexture(charmIcon);
	end
	addon:UpdateDatabrokerText();
end

function BattlePetUtility_PetCharmsMixin:OnEnter()
	local _, charmsNumAmount, charmEntries = addon:GetPetCharmsInfo();
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR");
	GameTooltip:ClearLines();
	GameTooltip:AddLine("Pet Charms");
	GameTooltip:AddLine(" ");
	GameTooltip:AddDoubleLine("Total", tostring(charmsNumAmount or 0), 1, 1, 1, 1, 1, 1);

	if(type(charmEntries) == "table" and #charmEntries > 0) then
		table.sort(charmEntries, function(a, b)
			return (a.amount or 0) > (b.amount or 0);
		end);

		for _, entry in ipairs(charmEntries) do
			local entryName = entry.name or "Pet Charm";
			GameTooltip:AddDoubleLine(entryName, tostring(entry.amount or 0), 0.75, 0.85, 1.0, 1, 1, 1);
		end
	end
	GameTooltip:Show();
end

function BattlePetUtility_PetCharmsMixin:OnLeave()
	GameTooltip:Hide();
end

-------------------------

function BattlePetUtilityFrameDragButton_OnClick(self, button)
	local type, petID = GetCursorInfo();
	if(type == "battlepet") then
		local _, dialog = StaticPopup_Visible("BATTLE_PET_RELEASE");
		if(dialog and dialog.data == petID) then
			StaticPopup_Hide("BATTLE_PET_RELEASE");
		end
		if(PetJournal_IsPendingCage(petID)) then
			UIErrorsFrame:AddMessage(ERR_PET_JOURNAL_PET_PENDING_CAGE, 1.0, 0.1, 0.1, 1.0);
			ClearCursor();
			return;
		end
		
		C_PetJournal.SetPetLoadOutInfo(self:GetParent():GetID(), petID);
		addon:RefreshPetJournalLoadOut();
		ClearCursor();
	else
		local petID = self:GetParent().petID;
		if(petID) then
			if(button == "LeftButton" and not PetBattles:IsInBattle()) then
				-- C_PetJournal.PickupPet(petID);
				
			elseif(button == "MiddleButton" and not InCombatLockdown()) then
				C_PetJournal.SummonPetByGUID(petID);
				
			elseif(button == "RightButton") then
				if(not CollectionsJournal:IsShown()) then
					ToggleCollectionsJournal(2);
				end
				PetJournal_ShowPetCardByID(petID);
			end
		end
	end
	
	CloseMenus();
end
	
function BattlePetUtilityFrameDragButton_OnDragStart(self)
	local parent = self:GetParent();
	local petID = parent.petID;
	if(not petID) then return end

	local slotIndex = parent:GetID();
	if(type(slotIndex) ~= "number") then
		return;
	end

	local _, _, _, _, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
	if(locked) then
		BattlePetUtilityFrame._dragSourceSlot = nil;
		BattlePetUtilityFrame._dragSourcePetID = nil;
		return;
	end

	if(not PetBattles:IsInBattle()) then
		C_PetJournal.PickupPet(petID);
		-- Remember the slot the pet was picked up from so OnReceiveDrag can
		-- perform a swap between two loadout slots.
		BattlePetUtilityFrame._dragSourceSlot = slotIndex;
		BattlePetUtilityFrame._dragSourcePetID = petID;

		CloseMenus();
	end
end

local function ClearBattlePetUtilityDragState()
	BattlePetUtilityFrame._dragSourceSlot = nil;
	BattlePetUtilityFrame._dragSourcePetID = nil;
end

local function TrySwapPetLoadoutSlots(sourceSlot, targetSlot)
	if(type(sourceSlot) ~= "number" or type(targetSlot) ~= "number") then
		return false;
	end

	if(sourceSlot < 1 or sourceSlot > 3 or targetSlot < 1 or targetSlot > 3 or sourceSlot == targetSlot) then
		return false;
	end

	local sourcePetID, _, _, _, sourceLocked = C_PetJournal.GetPetLoadOutInfo(sourceSlot);
	local targetPetID, _, _, _, targetLocked = C_PetJournal.GetPetLoadOutInfo(targetSlot);
	if(sourceLocked or targetLocked or not sourcePetID) then
		return false;
	end

	C_PetJournal.SetPetLoadOutInfo(targetSlot, sourcePetID);
	if(targetPetID) then
		C_PetJournal.SetPetLoadOutInfo(sourceSlot, targetPetID);
	else
		C_PetJournal.SetPetLoadOutInfo(sourceSlot, nil);
	end

	return true;
end

function BattlePetUtilityFrameDragButton_OnReceiveDrag(self)
	local parent = self:GetParent();
	local targetSlot = parent:GetID();
	local _, _, _, _, locked = C_PetJournal.GetPetLoadOutInfo(targetSlot);
	if(locked) then
		ClearCursor();
		ClearBattlePetUtilityDragState();
		return;
	end

	local sourceSlot = BattlePetUtilityFrame._dragSourceSlot;
	if(TrySwapPetLoadoutSlots(sourceSlot, targetSlot)) then
		addon:RefreshPetJournalLoadOut();
		ClearCursor();
		ClearBattlePetUtilityDragState();
		CloseMenus();
		return;
	end

	local type, petID = GetCursorInfo();
	if(type == "battlepet") then
		local _, dialog = StaticPopup_Visible("BATTLE_PET_RELEASE");
		if ( dialog and dialog.data == petID ) then
			StaticPopup_Hide("BATTLE_PET_RELEASE");
		end
		if ( PetJournal_IsPendingCage(petID) ) then
			UIErrorsFrame:AddMessage(ERR_PET_JOURNAL_PET_PENDING_CAGE, 1.0, 0.1, 0.1, 1.0);
			ClearCursor();
			ClearBattlePetUtilityDragState();
			return;
		end

		C_PetJournal.SetPetLoadOutInfo(targetSlot, petID);

		addon:RefreshPetJournalLoadOut();
		ClearCursor();
	end

	ClearBattlePetUtilityDragState();
	CloseMenus();
end

function BattlePetUtilityFrameDragButton_OnEnter(self)
	if(not addon.db or not addon.db.global) then return end
	if(not addon.db.global.ShowPetTooltips) then return end
	
	-- local slotIndex = self:GetParent():GetID();
	-- if(not slotIndex) then return end
	
	local petID = self:GetParent().petID;
	-- local petID = C_PetJournal.GetPetLoadOutInfo(slotIndex);
	if(not petID) then return end
	
	local speciesID, name, level = C_PetJournal.GetPetInfoByPetID(petID);
	local health, maxHealth, power, speed, breedQuality = C_PetJournal.GetPetStats(petID);
	
	if(speciesID and speciesID > 0) then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT", -2, -74);
		BattlePetToolTip_Show(speciesID, level, breedQuality-1, maxHealth, power, speed, name);
	end
end

function BattlePetUtilityFrameDragButton_OnLeave(self)
	GameTooltip:Hide();
	BattlePetTooltip:Hide();
end

function BattlePetUtilityFrame_OnClick(self, button, ...)
	if(button == "RightButton") then
		if(BattlePetUtilityFrameLoadouts and BattlePetUtilityFrameLoadouts:IsShown() and IsCursorOverFrame(BattlePetUtilityFrameLoadouts)) then
			return;
		end

		addon:OpenContextMenu();
	end
end

function BattlePetUtilityFrameTitle_OnMouseDown(self, button)
	if(button == "LeftButton") then
		BattlePetUtilityFrame_StartMoving(button);
	end
end

function BattlePetUtilityFrameTitle_OnMouseUp(self, button)
	if(button == "LeftButton") then
		BattlePetUtilityFrame_StopMoving(button);
	elseif(button == "RightButton") then
		addon:OpenContextMenu();
	end
end

function BattlePetUtilityFrameMinimizeButton_OnClick(self)
	if(not addon) then return end
	addon:ToggleFrameMinimized();
end

function BattlePetUtilityHeaderButton_OnLoad(self, kind)
	self.buttonKind = kind;
	self:RegisterForClicks("LeftButtonUp");
	self:SetFrameStrata("HIGH");
	self:SetFrameLevel(self:GetParent():GetFrameLevel() + 8);
	UpdateHeaderButtonVisual(self, false);
end

function BattlePetUtilityHeaderButton_OnClick(self, button)
	if(button ~= "LeftButton") then
		return;
	end

	if(self.buttonKind == "close") then
		if(BattlePetUtilityFrame) then
			BattlePetUtilityFrame:Hide();
		end
	else
		BattlePetUtilityFrameMinimizeButton_OnClick(self);
	end
end

function BattlePetUtilityHeaderButton_OnEnter(self)
	UpdateHeaderButtonVisual(self, true);
	if(self.buttonKind == "minimize") then
		BattlePetUtilityFrameMinimizeButton_OnEnter(self);
	end
end

function BattlePetUtilityHeaderButton_OnLeave(self)
	UpdateHeaderButtonVisual(self, false);
	if(self.buttonKind == "minimize") then
		BattlePetUtilityFrameMinimizeButton_OnLeave(self);
	end
end

function BattlePetUtilityFrameMinimizeButton_OnEnter(self)
	if(not addon) then return end

	GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	GameTooltip:ClearLines();
	if(addon:IsFrameMinimized()) then
		GameTooltip:AddLine("Restore Battle Pet Utility|cffb512fc!|r");
		GameTooltip:AddLine("Show the full battle pet HUD.", 0.9, 0.9, 0.9, true);
	else
		GameTooltip:AddLine("Minimize Battle Pet Utility|cffb512fc!|r");
		GameTooltip:AddLine("Collapse to the title bar.", 0.9, 0.9, 0.9, true);
	end
	GameTooltip:Show();
end

function BattlePetUtilityFrameMinimizeButton_OnLeave(self)
	GameTooltip:Hide();
end

function BattlePetUtilityFrame_OnShow(self)
	if(not addon.db) then return end

	addon.db.global.Visible = true;
	RefreshHeaderArt();

	addon:RegisterRuntimeUpdateEvents();
	if(type(addon.RestoreSavedSettings) == "function") then
		addon:RestoreSavedSettings();
	else
		addon:UpdateUtilityMenuState();
		addon:RefreshMedia();
		addon:UpdateMinimizeState();
		addon:UpdatePets();
	end
	addon.PendingStartupRefreshes = 0;
	addon:QueueStartupRefresh(0.3);
	addon:QueueStartupRefresh(1.0);

	BattlePetUtilityPetFrame_ResetAbilitySwitches();
	BattlePetUtilityFrameTitlePetCharms:OnShow();
end

function BattlePetUtilityFrame_OnHide(self)
	if(not addon.db) then return end
	
	-- if(InCombatLockdown()) then
		addon.db.global.Visible = false;
	-- end
	
	addon:UnregisterEvent("PET_BATTLE_PET_CHANGED");
	addon:UnregisterEvent("PET_BATTLE_HEALTH_CHANGED");
	addon:UnregisterEvent("PET_BATTLE_LEVEL_CHANGED");
	addon:UnregisterEvent("PET_BATTLE_XP_CHANGED");
	
	addon:UnregisterEvent("PET_JOURNAL_NEW_BATTLE_SLOT");
	
	addon:UnregisterEvent("UPDATE_SUMMONPETS_ACTION");
	addon:UnregisterEvent("PET_JOURNAL_LIST_UPDATE");
end

function addon:PLAYER_REGEN_DISABLED()
	self.CombatExitTimer = 0;
	self:PrintDebug("Entered combat, summon blocked");

	if(self.db.global.HideInCombat and BattlePetUtilityFrame:IsShown()) then
		BattlePetUtilityFrame:Hide();
		addon.CombatHidden = true;
	end
end

function addon:PLAYER_REGEN_ENABLED()
	self.CombatExitTimer = GetTime();
	self:PrintDebug("Exited combat, will attempt summon in " .. AUTOSUMMON_BLOCK_AFTER_COMBAT .. "s");

	if(self.db.global.HideInCombat and self.CombatHidden) then
		BattlePetUtilityFrame:Show();
		addon.CombatHidden = false;
	end

	self.db.global.Visible = BattlePetUtilityFrame:IsShown();
	addon:UpdateUtilityMenuState();
	addon:ScheduleTimer(function()
		addon:UpdateAutoResummon(false);
	end, 0.5);

	if(self.db and self.db.global.AutoSummonPet) then
		self:ScheduleTimer(function()
			self:HandleAutoSummonTrigger("PLAYER_REGEN_ENABLED");
		end, AUTOSUMMON_BLOCK_AFTER_COMBAT);
	end
end

function addon:CURSOR_UPDATE()
	if(PetBattles:IsInBattle()) then return end
	
	addon.CursorUpdateTimer = addon:ScheduleTimer(function()
		local lastCursor = addon.CurrentCursor;
		addon.CurrentCursor = GetCursorInfo();
		
		if(not addon.CursorTimerTick) then addon.CursorTimerTick = 0 end
		addon.CursorTimerTick = addon.CursorTimerTick + 1;
		
		local cancelTimer = false;
		if(addon.CursorTimerTick >= 30) then cancelTimer = true; end
		
		if(addon.CurrentCursor ~= lastCursor) then
			if(addon.CurrentCursor == "battlepet") then
				for i=1,3 do
					local button = _G['BattlePetUtilityFramePet'..i..'DragButton'];
					button:GetParent().glowHighlight:Show();
				end
			else
				for i=1,3 do
					local button = _G['BattlePetUtilityFramePet'..i..'DragButton'];
					button:GetParent().glowHighlight:Hide();
				end
			end
			
			addon.CursorTimerTick = 0;
			cancelTimer = true;
		end
		
		if(cancelTimer) then addon:CancelTimer(addon.CursorUpdateTimer); end
	end, 0.01);
end

addon.SummonDisabledTimer = addon.SummonDisabledTimer or 0;
addon.CombatExitTimer = addon.CombatExitTimer or 0;

hooksecurefunc("Dismount", function()
	if(not InCombatLockdown()) then
		addon.SummonDisabledTimer = GetTime();
		addon:PrintDebug("Dismount detected, blocking summon for " .. AUTOSUMMON_BLOCK_AFTER_DISMOUNT .. "s");
	end
end);

function addon:HandleAutoSummonTrigger(event, ...)
	if(not self.db or not self.db.global.AutoSummonPet) then
		return;
	end

	if(event == "UNIT_AURA") then
		local unit = ...;
		if(unit ~= "player") then
			return;
		end
	elseif(event == "UNIT_EXITED_VEHICLE") then
		local unit = ...;
		if(unit ~= "player") then
			return;
		end
	end

	-- Immediate attempt when state changes, then delayed retries for login/loading transitions.
	addon:UpdateAutoResummon(false);

	if(event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_CONTROL_GAINED" or event == "UNIT_EXITED_VEHICLE") then
		addon:ScheduleTimer(function()
			addon:UpdateAutoResummon(false);
		end, 1.5);
		addon:ScheduleTimer(function()
			addon:UpdateAutoResummon(false);
		end, 4.0);
	end
end

local function PlayerHasAuraSpellID(spell_id)
	if(type(spell_id) ~= "number") then
		return false;
	end

	if(not C_UnitAuras or type(C_UnitAuras.GetPlayerAuraBySpellID) ~= "function") then
		return false;
	end

	local ok, auraData = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spell_id);
	return ok and auraData ~= nil;
end

function addon:IsPlayerEating()
	return PlayerHasAuraSpellID(33264) or PlayerHasAuraSpellID(160599);
end

local WINTERSPRING_CUB_ID = 68646;
local WINTERSPRING_MAP_ID = 83;
local VENOMHIDE_HATCHLING_ID = 46362;
local UNGORO_MAP_ID = 78;

function addon:IsDoingMountQuest()
	local checkMapId = nil;
	if(GetItemCountCompat(WINTERSPRING_CUB_ID)    >= 1) then checkMapId = WINTERSPRING_MAP_ID end
	if(GetItemCountCompat(VENOMHIDE_HATCHLING_ID) >= 1) then checkMapId = UNGORO_MAP_ID end
	return checkMapId ~= nil and C_Map.GetBestMapForUnit("player") == checkMapId;
end

function addon:CanSafelySummonPet()
	return not (not HasFullControl() or UnitOnTaxi("player")
				or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player")
				or addon.BarberShopOpen
				or IsMounted() or IsFalling() or (GetTime()-addon.SummonDisabledTimer) < AUTOSUMMON_BLOCK_AFTER_DISMOUNT
				or (GetTime()-addon.LoginTime) < AUTOSUMMON_BLOCK_AFTER_LOGIN
				or (addon.CombatExitTimer > 0 and (GetTime()-addon.CombatExitTimer) < AUTOSUMMON_BLOCK_AFTER_COMBAT)
				or UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
				or IsStealthed()
				or addon:IsPlayerEating()
				or addon:IsDoingMountQuest());
end

function addon:UpdateAutoResummon(forceSummon)
	if(InCombatLockdown()) then return end
	if(not addon:CanSafelySummonPet() and not forceSummon) then return end
	
	local summonedPet = C_PetJournal.GetSummonedPetGUID();
	if(summonedPet and self.db.char.AutoSummonLastPetID ~= summonedPet) then
		self.db.char.AutoSummonLastPetID = summonedPet;
		addon:UpdateDatabrokerText();
	end
	
	if(not self.db.global.AutoSummonPet or (summonedPet and not forceSummon)) then return end
	
	local petID = nil;
	
	if(self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.LAST_PET) then
		if(self.db.char.AutoSummonLastPetID) then
			local speciesID = C_PetJournal.GetPetInfoByPetID(self.db.char.AutoSummonLastPetID);
			
			if(speciesID) then
				petID = self.db.char.AutoSummonLastPetID;
			else
				self.db.char.AutoSummonLastPetID = nil;
			end
		end
	elseif(self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.FAVORITE) then
		C_PetJournal.SummonRandomPet(false);
	elseif(self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.ANY) then
		C_PetJournal.SummonRandomPet(true);
	end
	
	if(petID and petID ~= summonedPet) then
		C_PetJournal.SummonPetByGUID(petID);
		addon.SummonDisabledTimer = GetTime();
	end
end

function addon:PLAYER_ENTERING_WORLD(event, isInitialLogin, isReloadingUi)
  if(isInitialLogin or isReloadingUi) then
    addon.LoginTime = GetTime();
  end

  if(isInitialLogin or isReloadingUi) then
    addon:ShowWelcomeMessage();
  end

  -- Try to restore last team on initial login/reload if current loadout is empty
  if(isInitialLogin or isReloadingUi) then
    addon:ScheduleTimer(function()
      if(addon:ShouldRestoreLastTeam()) then
        addon:RestoreLastTeam();
      end
    end, 2.0);
  end

  addon:HandleAutoSummonTrigger("PLAYER_ENTERING_WORLD");
  addon.PendingStartupRefreshes = 0;
  addon:RunStartupRefresh();
  addon:QueueStartupRefresh(0.5);
  addon:QueueStartupRefresh(1.5);
end

function addon:ZONE_CHANGED_NEW_AREA()
	if(type(self.RefreshZoneTracker) == "function") then
		self:RefreshZoneTracker();
	end
end

function addon:ZONE_CHANGED()
	if(type(self.RefreshZoneTracker) == "function") then
		self:RefreshZoneTracker();
	end
end

function addon:ZONE_CHANGED_INDOORS()
	if(type(self.RefreshZoneTracker) == "function") then
		self:RefreshZoneTracker();
	end
end

function addon:PET_JOURNAL_LIST_UPDATE()
	-- Lightweight handler: only update pets and loadout list
	self:UpdatePets();
	if(type(BattlePetUtilityFrameLoadouts_UpdateList) == "function") then
		BattlePetUtilityFrameLoadouts_UpdateList();
	end
	if(type(self.RefreshZoneTracker) == "function") then
		self:RefreshZoneTracker();
	end
end

function addon:SPELL_UPDATE_COOLDOWN()
	addon.PetHealTime = GetSpellCooldownCompat(125439);
	
	if((GetTime() - addon.LoginTime) > 3 or addon.PetHealTime > 0) then
		addon:UnregisterEvent("SPELL_UPDATE_COOLDOWN");
	end
end

function ToggleBattlePetUtility()
	if(InCombatLockdown()) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffffffBattle Pet Utility|r|cffb512fc!|r |cffcc22Cannot toggle in combat|r");
		return;
	end
	
	if(BattlePetUtilityFrame:IsShown()) then
		BattlePetUtilityFrame:Hide();
	else
		BattlePetUtilityFrame:Show();
	end
	
	addon.db.global.Visible = BattlePetUtilityFrame:IsShown();
end
	
function addon:OnInitialize()
	RGX:RegisterSlashCommand({"/BPU", "/pb", "/bpu"}, function(command)
		command = string.lower(strtrim(command or ""));

		if(command == "") then
			ToggleBattlePetUtility();
		elseif(command == "help") then
			addon:PrintHelp();
		elseif(command == "welcome") then
			addon:ToggleWelcomeMessage();
		elseif(command == "version") then
			addon:PrintMessage("|cffffff00Version:|r |cff8080ff" .. GetAddonVersion() .. "|r");
		elseif(command == "icon on" or command == "icon enable" or command == "icon show") then
			addon:ToggleMinimapIcon(true);
		elseif(command == "icon off" or command == "icon disable" or command == "icon hide") then
			addon:ToggleMinimapIcon(false);
		elseif(command == "icon") then
			addon:PrintMessage("|cffffff00Usage:|r |cffb07fff/BPU icon on|r or |cffb07fffoff|r");
		else
			addon:PrintMessage("|cffffcc00Unknown command.|r Type |cffb07fff/BPU help|r.");
		end
	end, "BPU");

	addon:InitializeDatabase();
	addon:InitializeDatabroker();
	if(type(addon.InitializeMinimapIcon) == "function") then
		addon:InitializeMinimapIcon();
		if(type(addon.UpdateMinimapIconVisibility) == "function") then
			addon:UpdateMinimapIconVisibility();
		end
	end
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	addon:RegisterEvent("ZONE_CHANGED");
	addon:RegisterEvent("ZONE_CHANGED_INDOORS");
	addon:RegisterEvent("PET_JOURNAL_LIST_UPDATE");
	addon:RegisterEvent("BAG_UPDATE_DELAYED", "RefreshPetCharms");
	addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "RefreshPetCharms");
end

function addon:BARBER_SHOP_OPEN()
	addon.BarberShopOpen = true;
end

function addon:BARBER_SHOP_CLOSE()
	addon.BarberShopOpen = false;
end

function addon:OnDisable()

end

local function InitializeAddon()
	if(addon._initialized) then return end
	addon._initialized = true;

	if(type(addon.OnInitialize) == "function") then
		addon:OnInitialize();
	end
end

local function EnableAddon()
	if(addon._enabled) then return end
	addon._enabled = true;

	if(type(addon.OnEnable) == "function") then
		addon:OnEnable();
	end

	if(addon._pendingItemButtonRefresh and BattlePetUtilityFrameButtons and BattlePetUtilityFrameButtons:IsShown()
		and type(BattlePetUtilityFrameButtons_OnShow) == "function") then
		addon._pendingItemButtonRefresh = nil;
		BattlePetUtilityFrameButtons_OnShow(BattlePetUtilityFrameButtons);
	end
end

local function RegisterLoadTimeEvents()
	if(addon._loadTimeEventsRegistered) then return end
	addon._loadTimeEventsRegistered = true;

	addon:RegisterEvent("PET_BATTLE_OPENING_START");
	addon:RegisterEvent("PET_BATTLE_CLOSE");
	addon:RegisterRuntimeUpdateEvents();
	addon:RegisterEvent("PLAYER_ENTERING_WORLD");
	addon:RegisterEvent("PLAYER_ALIVE", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("PLAYER_UNGHOST", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("PLAYER_CONTROL_GAINED", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("UNIT_EXITED_VEHICLE", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("UNIT_AURA", addon.HandleAutoSummonTrigger);
	addon:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	addon:RegisterEvent("CURSOR_CHANGED", addon.CURSOR_UPDATE);
	addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	addon:RegisterEvent("PLAYER_REGEN_ENABLED");
	addon:RegisterEvent("GOSSIP_SHOW");
	addon:RegisterEvent("GOSSIP_CLOSED");
	addon:RegisterEvent("GOSSIP_CONFIRM");
	addon:RegisterEvent("BARBER_SHOP_OPEN");
	addon:RegisterEvent("BARBER_SHOP_CLOSE");
	addon:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	addon:RegisterEvent("ZONE_CHANGED");
	addon:RegisterEvent("ZONE_CHANGED_INDOORS");
	addon:RegisterEvent("PET_JOURNAL_LIST_UPDATE");
	addon:RegisterEvent("BAG_UPDATE_DELAYED", "RefreshPetCharms");
	addon:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "RefreshPetCharms");
end

RegisterLoadTimeEvents();

RGX:RegisterEvent("PLAYER_LOGIN", function()
	InitializeAddon();
	EnableAddon();
	RGX:UnregisterEvent("PLAYER_LOGIN", "BPU_Bootstrap");
end, "BPU_Bootstrap");
