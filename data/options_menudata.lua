local ADDON_NAME, addon = ...
local E = addon.E

local Fonts = _G.RGXFonts

local function NormalizeUtilityMenuState(state)
	state = tonumber(state) or 0
	state = math.floor(state)
	if state < 0 or state > 3 then
		state = 0
	end
	return state
end

function addon:GetPetItemsUtilityMenuData()
	local menu = {}
	tinsert(menu, { text = "Pet Items Options", isTitle = true, notCheckable = true })

	if type(addon.GetPetItemCategoryMenuData) == "function" then
		local categories = addon:GetPetItemCategoryMenuData(false)
		if type(categories) == "table" then
			for _, entry in ipairs(categories) do
				tinsert(menu, entry)
			end
		end
	end
	return menu
end

function addon:GetPrimaryMenuData()
	if type(addon.PrepareFontMenuItems) == "function" then
		addon:PrepareFontMenuItems()
	end

	local sharedMediaBarTextures = {}
	for _, statusbar in ipairs(addon:ListMedia("statusbar")) do
		local barName = statusbar
		tinsert(sharedMediaBarTextures, {
			text = barName,
			func = function()
				self.db.global.barTexture = barName
				addon:RefreshMedia()
				addon.RefreshDropdownMenu(addon.ContextMenu)
			end,
			checked = function() return self.db.global.barTexture == barName end,
			keepShownOnClick = true,
			onEnter = function() addon:RefreshMedia(nil, barName) end,
			onLeave = function() addon:RefreshMedia(nil, self.db.global.barTexture) end,
		})
	end

	local _fontLabel = "Default"
	if Fonts and type(Fonts.NormalizeStyle) == "function" and type(Fonts.GetDropdownFontLabel) == "function" then
		local _style = Fonts:NormalizeStyle(self.db and self.db.global and self.db.global.normalText)
		if _style and _style.font then
			_fontLabel = Fonts:GetDropdownFontLabel(_style.font)
		end
	end

	local data = {
		{
			text = "Battle Pet Utility! Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Battle Pet HUD and utility menu", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Lock Battle Pet Utility!",
			func = function() self.db.global.IsFrameLocked = not self.db.global.IsFrameLocked end,
			checked = function() return self.db.global.IsFrameLocked end,
			isNotRadio = true,
			keepShownOnClick = true,
		},
		{
			text = "Hide when entering combat",
			func = function() self.db.global.HideInCombat = not self.db.global.HideInCombat end,
			checked = function() return self.db.global.HideInCombat end,
			isNotRadio = true,
			keepShownOnClick = true,
		},
		{
			text = "Show welcome message on login",
			func = function()
				self.db.global.ShowWelcomeMessage = not self.db.global.ShowWelcomeMessage
			end,
			checked = function() return self.db.global.ShowWelcomeMessage end,
			isNotRadio = true,
			keepShownOnClick = true,
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Automation", isTitle = true, notCheckable = true,
		},
		{
			text = "When starting pet battle",
			notCheckable = true,
			hasArrow = true,
			keepShownOnClick = true,
			menuList = {
				{
					text = "Show",
					func = function()
						self.db.global.PetBattleVisiblityMode = E.VISIBILITY_MODE.SHOW
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.SHOW end,
					keepShownOnClick = true,
				},
				{
					text = "Hide",
					func = function()
						self.db.global.PetBattleVisiblityMode = E.VISIBILITY_MODE.HIDE
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.HIDE end,
					keepShownOnClick = true,
				},
				{
					text = "Do nothing",
					func = function()
						self.db.global.PetBattleVisiblityMode = E.VISIBILITY_MODE.DO_NOTHING
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.DO_NOTHING end,
					keepShownOnClick = true,
				},
			},
		},
		{
			text = "Always resummon companion",
			func = function()
				self.db.global.AutoSummonPet = not self.db.global.AutoSummonPet
				addon:UpdateDatabrokerText()
				if self.db.global.AutoSummonPet then
					addon:UpdateAutoResummon(true)
				end
			end,
			checked = function() return self.db.global.AutoSummonPet end,
			isNotRadio = true,
			keepShownOnClick = true,
			hasArrow = true,
			menuList = {
				{ text = "Resummon Options", isTitle = true, notCheckable = true },
				{
					text = "Last used pet",
					func = function()
						self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.LAST_PET
						addon:UpdateAutoResummon(true)
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.LAST_PET end,
					keepShownOnClick = true,
				},
				{
					text = "Random favorite pet",
					func = function()
						self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.FAVORITE
						addon:UpdateAutoResummon(true)
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.FAVORITE end,
					keepShownOnClick = true,
				},
				{
					text = "Any random pet",
					func = function()
						self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.ANY
						addon:UpdateAutoResummon(true)
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.ANY end,
					keepShownOnClick = true,
				},
			},
		},
		{
			text = "Automatically heal pets at stables",
			func = function() self.db.global.AutoHealPets = not self.db.global.AutoHealPets; AutoHealButton_OnShow(BattlePetUtilityAutoHealButton) end,
			checked = function() return self.db.global.AutoHealPets end,
			isNotRadio = true,
			keepShownOnClick = true,
			hasArrow = true,
			menuList = {
				{ text = "Auto Pet Healer", isTitle = true, notCheckable = true },
				{
					text = "Also automatically accept the healing fee",
					func = function() self.db.global.AutoHealPetsFee = not self.db.global.AutoHealPetsFee end,
					checked = function() return self.db.global.AutoHealPetsFee end,
					isNotRadio = true,
					keepShownOnClick = true,
				},
			}
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Displays", isTitle = true, notCheckable = true,
		},
		{
			text = "Enable cuteness",
			func = function()
				self.db.global.ShowPepe = not self.db.global.ShowPepe
				addon:RefreshHeaderArt()
				if self.db.global.ShowPepe then
					BattlePetUtilityFrameTitle.pepeFrame:Show()
				else
					BattlePetUtilityFrameTitle.pepeFrame:Hide()
				end
			end,
			checked = function() return self.db.global.ShowPepe end,
			isNotRadio = true,
			hasArrow = true,
			keepShownOnClick = true,
			menuList = {
				{ text = "Cuteness Position", notCheckable = true, isTitle = true },
				{
					text = "Right side",
					func = function()
						self.db.global.PepeOnLeft = false
						addon:RefreshHeaderArt()
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return not self.db.global.PepeOnLeft end,
					keepShownOnClick = true,
				},
				{
					text = "Left side",
					func = function()
						self.db.global.PepeOnLeft = true
						addon:RefreshHeaderArt()
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.PepeOnLeft end,
					keepShownOnClick = true,
				},
			},
		},
		{
			text = "Show pet charms",
			func = function()
				self.db.global.ShowPetCharms = not self.db.global.ShowPetCharms
				addon:RestoreSavedSettings()
			end,
			checked = function() return self.db.global.ShowPetCharms end,
			isNotRadio = true,
			keepShownOnClick = true,
		},
		{
			text = "Show pet health and experience text",
			func = function() self.db.global.PetStatsText.Enabled = not self.db.global.PetStatsText.Enabled; addon:RestoreSavedSettings() end,
			checked = function() return self.db.global.PetStatsText.Enabled end,
			isNotRadio = true,
			keepShownOnClick = true,
			hasArrow = true,
			menuList = {
				{ text = "Health Text", notCheckable = true, isTitle = true },
				{
					text = "Show percentage",
					func = function() self.db.global.PetStatsText.ShowHealthPercentage = not self.db.global.PetStatsText.ShowHealthPercentage; addon:UpdatePets() end,
					checked = function() return self.db.global.PetStatsText.ShowHealthPercentage end,
					isNotRadio = true,
					keepShownOnClick = true,
				},
				{ text = "", isTitle = true, notCheckable = true, disabled = true },
				{ text = "Experience Text", notCheckable = true, isTitle = true },
				{
					text = "Show percentage",
					func = function() self.db.global.PetStatsText.ShowExperiencePercentage = not self.db.global.PetStatsText.ShowExperiencePercentage; addon:UpdatePets() end,
					checked = function() return self.db.global.PetStatsText.ShowExperiencePercentage end,
					isNotRadio = true,
					keepShownOnClick = true,
				},
				{
					text = "Display current experience",
					func = function()
						self.db.global.PetStatsText.RemainingExperience = false
						addon:UpdatePets()
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return not self.db.global.PetStatsText.RemainingExperience end,
					keepShownOnClick = true,
				},
				{
					text = "Display experience to level",
					func = function()
						self.db.global.PetStatsText.RemainingExperience = true
						addon:UpdatePets()
						addon.RefreshDropdownMenu(addon.ContextMenu)
					end,
					checked = function() return self.db.global.PetStatsText.RemainingExperience end,
					keepShownOnClick = true,
				},
			},
		},
		{
			text = "Show pet loadouts menu",
			func = function()
				local state = tonumber(self.db.global.PetUtilityMenuState) or 0
				state = math.floor(state)
				if state < 0 or state > 3 then state = 0 end
				local hasLoadouts = (state == 2 or state == 3)
				if hasLoadouts then state = state - 2 else state = state + 2 end
				self.db.global.PetUtilityMenuState = state
				addon:RestoreSavedSettings()
			end,
			checked = function()
				local state = tonumber(self.db.global.PetUtilityMenuState) or 0
				return state == 2 or state == 3
			end,
			disabled = C_PetBattles.IsInBattle(),
			isNotRadio = true,
			keepShownOnClick = true,
		},
		{
			text = "Show pet related items",
			func = function()
				local state = NormalizeUtilityMenuState(self.db.global.PetUtilityMenuState)
				local hasItems = (state == 1 or state == 3)
				if hasItems then state = state - 1 else state = state + 1 end
				self.db.global.PetUtilityMenuState = state
				addon:RestoreSavedSettings()
			end,
			checked = function()
				local state = NormalizeUtilityMenuState(self.db.global.PetUtilityMenuState)
				return state == 1 or state == 3
			end,
			isNotRadio = true,
			hasArrow = true,
			keepShownOnClick = true,
			disabled = C_PetBattles.IsInBattle(),
			menuList = addon:GetPetItemsUtilityMenuData(),
		},
		{
			text = "Show pet tooltips",
			func = function() self.db.global.ShowPetTooltips = not self.db.global.ShowPetTooltips end,
			checked = function() return self.db.global.ShowPetTooltips end,
			isNotRadio = true,
			keepShownOnClick = true,
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Zone Tracker", isTitle = true, notCheckable = true,
		},
		{
			text = "Hide main GUI body",
			func = function()
				self.db.global.HideMainGUI = not self.db.global.HideMainGUI
				addon:UpdateMinimizeState()
			end,
			checked = function() return self.db.global.HideMainGUI end,
			isNotRadio = true,
			keepShownOnClick = true,
		},
		{
			text = "Show zone pet tracker",
			func = function()
				self.db.global.ShowZoneTracker = not self.db.global.ShowZoneTracker
				addon:RestoreSavedSettings()
			end,
			checked = function() return self.db.global.ShowZoneTracker end,
			isNotRadio = true,
			hasArrow = true,
			keepShownOnClick = true,
			menuList = {
				{ text = "Zone Tracker Options", isTitle = true, notCheckable = true },
				{
					text = "Show missing pets list",
					func = function()
						self.db.global.ShowZoneTrackerPetList = not self.db.global.ShowZoneTrackerPetList
						addon:RefreshZoneTracker()
					end,
					checked = function() return self.db.global.ShowZoneTrackerPetList end,
					isNotRadio = true,
					keepShownOnClick = true,
				},
			},
		},
		{
			text = "Show minimap icon",
			func = function()
				if type(addon.ToggleMinimapIcon) == "function" then
					addon:ToggleMinimapIcon(nil)
				end
			end,
			checked = function()
				return self.db.global.MinimapIcon and self.db.global.MinimapIcon.enabled
			end,
			isNotRadio = true,
			keepShownOnClick = true,
			tooltipTitle = "Minimap icon visibility",
			tooltipText = "You can also right-click the minimap button for options, or use |cffb07fff/BPU icon off|r and |cffb07fff/BPU icon on|r.",
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Frame Options", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Font: " .. _fontLabel,
			notCheckable = true,
			hasArrow = true,
			menuList = "bpu_fonts",
		},
		{
			text = string.format("Font size (%d pt)", addon:GetCurrentFontSize()),
			notCheckable = true,
			hasArrow = true,
			keepShownOnClick = true,
			menuList = addon:GetTextSizeMenuData(),
		},
		{
			text = "Bar texture",
			notCheckable = true,
			hasArrow = true,
			menuList = sharedMediaBarTextures,
		},
		{
			text = string.format("Change scale (%d%%)", self.db.global.WindowScale * 100),
			notCheckable = true,
			hasArrow = true,
			keepShownOnClick = true,
			menuList = addon:GetWindowScaleMenu(),
		},
	}

	return data
end
