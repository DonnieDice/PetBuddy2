local ADDON_NAME, addon = ...

function addon.RefreshDropdownMenu(menuFrame)
	if type(CloseDropDownMenus) == "function" then
		pcall(CloseDropDownMenus)
	end
end

function addon:OpenContextMenu(contextMenuData, parentframe, anchor, point, relativePoint)
	if not _G.RGXDropdowns then
		if type(addon.PrintMessage) == "function" then
			addon:PrintMessage("|cffff5555RGX-Framework not found. Cannot open dropdown menu.|r")
		end
		return
	end

	if not contextMenuData then
		contextMenuData = addon:GetPrimaryMenuData()
	end

	_G.RGXDropdowns:CreateContextMenu({
		items = contextMenuData,
		parentFrame = parentframe or BattlePetUtilityFrame,
		anchor = anchor or "cursor",
		onButtonCreated = function(buttonFrame, item)
			if type(item.onEnter) == "function" then
				buttonFrame:HookScript("OnEnter", function(self) item.onEnter(self, item) end)
			end
			if type(item.onLeave) == "function" then
				buttonFrame:HookScript("OnLeave", function(self) item.onLeave(self, item) end)
			end
		end
	})
end

function addon:OpenDropDownMenu(menuData, menuFrame, anchor, x, y, displayMode, autoHideDelay)
	addon:OpenContextMenu(menuData, nil, anchor)
end
