local ADDON_NAME, addon = ...
local DEFAULT_STATUSBAR_NAME = "RenAscensionL"

local RGX = _G.RGXFramework
local Fonts = _G.RGXFonts
local Textures = _G.RGXTextures

local SIZE_OPTIONS = { 8, 9, 10, 11, 12, 13, 14, 16 }

local function BuildDefaultTextStyle(size, flags, extras)
	local style = { font = Fonts:GetDefault(), size = size, flags = flags or "" }
	if type(extras) == "table" then
		for key, value in pairs(extras) do style[key] = value end
	end
	return Fonts:CreateStyle(style)
end

local function EnsureBPUTextStyles(db)
	if type(db) ~= "table" then return end
	if type(db.titleText) ~= "table" or type(db.normalText) ~= "table" or type(db.smallText) ~= "table" then
		local legacyFont = db.fontFace or Fonts:GetDefault()
		local legacySize = tonumber(db.fontSize) or 10
		db.titleText = BuildDefaultTextStyle(legacySize + 2, "OUTLINE", {
			font = legacyFont, shadowColor = "shadow", shadowOffset = { x = 1, y = -1 },
		})
		db.normalText = BuildDefaultTextStyle(legacySize, "", { font = legacyFont })
		db.smallText = BuildDefaultTextStyle(math.max(8, legacySize - 1), "", { font = legacyFont })
	end
	db.fontFace = nil
	db.fontSize = nil
end

function addon:ListMedia(mediaType)
	if mediaType == "statusbar" then
		return Textures:ListBars()
	end
	return {}
end

function addon:FetchMedia(mediaType, name)
	if mediaType == "statusbar" then
		return Textures:GetBar(name)
	end
	return nil
end

function addon:RefreshMedia(_, barTexture)
	local selectedBarTexture = barTexture or self.db.global.barTexture
	if not Textures:Exists(selectedBarTexture) then
		selectedBarTexture = DEFAULT_STATUSBAR_NAME
		self.db.global.barTexture = selectedBarTexture
	end

	local statusBarPath = Textures:GetBar(selectedBarTexture)

	EnsureBPUTextStyles(self.db.global)
	if type(self.PrepareFontMenuItems) == "function" then
		self:PrepareFontMenuItems()
	end

	Fonts:ApplyStyleMap({
		titleText = BattlePetUtilityFontTitle,
		normalText = BattlePetUtilityFontNormal,
		smallText = BattlePetUtilityFontSmall,
	}, self.db.global)

	for i = 1, 3 do
		local petFrame = _G['BattlePetUtilityFramePet' .. i]

		petFrame.stats.petHealth:SetStatusBarTexture(statusBarPath)
		petFrame.stats.petExperience:SetStatusBarTexture(statusBarPath)
	end

	if BattlePetUtilityFrameZoneTracker and BattlePetUtilityFrameZoneTracker.bar then
		BattlePetUtilityFrameZoneTracker.bar:SetStatusBarTexture(statusBarPath)
		local qualityBars = BattlePetUtilityFrameZoneTracker.bar.qualityBars
		if type(qualityBars) == "table" then
			for _, qBar in pairs(qualityBars) do
				if qBar and qBar.SetStatusBarTexture then
					qBar:SetStatusBarTexture(statusBarPath)
				end
			end
		end
	end

	if type(self.RefreshZoneTracker) == "function" then
		self:RefreshZoneTracker()
	end
end

function addon:SetWindowScale(scale)
	self.db.global.WindowScale = scale or 1.0
	BattlePetUtilityFrame:SetScale(self.db.global.WindowScale)
end

local function GetStyleDefs()
	return {
		{
			key = "titleText",
			default = BuildDefaultTextStyle(12, "OUTLINE", {
				shadowColor = "shadow",
				shadowOffset = { x = 1, y = -1 },
			}),
		},
		{ key = "normalText", default = BuildDefaultTextStyle(10, "") },
		{ key = "smallText",  default = BuildDefaultTextStyle(9,  "") },
	}
end

function addon:PrepareFontMenuItems()
	EnsureBPUTextStyles(self.db and self.db.global)
	local styleDefs = GetStyleDefs()

	local function GetCurrentFont()
		if Fonts and type(Fonts.NormalizeStyle) == "function" then
			local style = Fonts:NormalizeStyle(self.db.global.normalText or styleDefs[2].default)
			return style.font
		end
		return nil
	end

	local function ApplySharedFont(fontName)
		if not Fonts or type(Fonts.NormalizeStyle) ~= "function" then return end
		for _, styleDef in ipairs(styleDefs) do
			local nextStyle = Fonts:NormalizeStyle(self.db.global[styleDef.key] or styleDef.default)
			nextStyle.font = fontName
			self.db.global[styleDef.key] = nextStyle
		end
		addon:RefreshMedia()
		addon.RefreshDropdownMenu(addon.ContextMenu)
	end

	addon._fontMenuItems = (Fonts and type(Fonts.CreateFontMenuItems) == "function") and Fonts:CreateFontMenuItems({
		current = GetCurrentFont,
		keepShownOnClick = true,
		onSelect = ApplySharedFont,
	}) or nil

	if addon._fontMenuItems then
		local function InjectPreviews(items)
			for _, item in ipairs(items) do
				if type(item.children) == "table" then
					InjectPreviews(item.children)
				elseif item.value ~= nil then
					item.onEnter = function()
						if item.value then
							local tempStyles = {}
							for _, styleDef in ipairs(styleDefs) do
								local nextStyle = Fonts:NormalizeStyle(self.db.global[styleDef.key] or styleDef.default)
								nextStyle.font = item.value
								tempStyles[styleDef.key] = nextStyle
							end
							Fonts:ApplyStyleMap({
								titleText = BattlePetUtilityFontTitle,
								normalText = BattlePetUtilityFontNormal,
								smallText = BattlePetUtilityFontSmall,
							}, tempStyles)
						end
					end
					item.onLeave = function()
						Fonts:ApplyStyleMap({
							titleText = BattlePetUtilityFontTitle,
							normalText = BattlePetUtilityFontNormal,
							smallText = BattlePetUtilityFontSmall,
						}, self.db.global)
					end
				end
			end
		end
		InjectPreviews(addon._fontMenuItems)
	end
end

function addon:GetCurrentFontSize()
	EnsureBPUTextStyles(self.db and self.db.global)
	if Fonts and type(Fonts.NormalizeStyle) == "function" then
		local style = Fonts:NormalizeStyle(self.db.global.normalText)
		return tonumber(style.size) or 10
	end
	return 10
end

function addon:GetTextSizeMenuData()
	EnsureBPUTextStyles(self.db and self.db.global)
	local styleDefs = GetStyleDefs()

	local function ApplySize(baseSize)
		if not Fonts or type(Fonts.NormalizeStyle) ~= "function" then return end
		local sizes = {
			titleText  = baseSize + 2,
			normalText = baseSize,
			smallText  = math.max(8, baseSize - 1),
		}
		for _, styleDef in ipairs(styleDefs) do
			local nextStyle = Fonts:NormalizeStyle(self.db.global[styleDef.key] or styleDef.default)
			nextStyle.size = sizes[styleDef.key]
			self.db.global[styleDef.key] = nextStyle
		end
		addon:RefreshMedia()
		addon.RefreshDropdownMenu(addon.ContextMenu)
	end

	local menu = {}
	for _, size in ipairs(SIZE_OPTIONS) do
		local sz = size
		tinsert(menu, {
			text = tostring(sz) .. " pt",
			func = function() ApplySize(sz) end,
			checked = function() return addon:GetCurrentFontSize() == sz end,
			keepShownOnClick = true,
		})
	end
	return menu
end

function addon:GetWindowScaleMenu()
	local windowScales = { 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5 }
	local menu = {}

	for index, scale in ipairs(windowScales) do
		tinsert(menu, {
			text = string.format("%d%%", scale * 100),
			func = function()
				addon:SetWindowScale(scale)
				addon.RefreshDropdownMenu(addon.ContextMenu)
			end,
			checked = function() return self.db.global.WindowScale == scale end,
		})
	end

	return menu
end
