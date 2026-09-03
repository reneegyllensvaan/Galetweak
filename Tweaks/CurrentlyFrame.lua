-------------------------------------------------------------------------------
-- TRP3 Currently Frame by Tammya-Moonguard (2018)
-- Adds a standalone frame to edit your currently status.
-- Integrated into Galetweak.
-------------------------------------------------------------------------------

local addonName, Me = ...

local L = TRP3_API.loc

local CONFIG_POS_X     = "CONFIG_TRP3CURRENTLYFRAME_POS_X";
local CONFIG_POS_Y     = "CONFIG_TRP3CURRENTLYFRAME_POS_Y";
local CONFIG_POS_A     = "CONFIG_TRP3CURRENTLYFRAME_POS_A";
local CONFIG_SHOW      = "CONFIG_TRP3CURRENTLYFRAME_SHOW";
local CONFIG_SHOW_OOC  = "CONFIG_TRP3CURRENTLYFRAME_SHOW_OOC";

-------------------------------------------------------------------------------
-- Called when the module is initialized.
--
local function onInit()
	Me.AddLocales()
	L = TRP3_API.loc

	Me.frame = CreateFrame("Frame", "TRP3CurrentlyFrame", UIParent, "TRP3CurrentlyTemplate")
	Me.frame.host = Me

	Me.frame.textooc.label:SetText(L.CM_OOC)

	-- Dragonflight-era styling: replace the old ornate TextPanel-Border panels
	-- with a flat, subtly rounded panel and a much quieter caption.
	Me.frame:SetBackdrop {
		bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background";
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border";
		tile     = true;
		edgeSize = 16;
		tileSize = 16;
		insets   = { left = 5, right = 5, top = 5, bottom = 5 };
	}
	Me.frame:SetBackdropColor(0.07, 0.07, 0.09, 0.85)
	Me.frame:SetBackdropBorderColor(0.05, 0.05, 0.06, 0.9)

	Me.frame.textooc.label:SetTextColor(0.55, 0.55, 0.60, 1)

	Me.frame.UpdateHeight = function(self)
		if not TRP3_API.configuration.getValue(CONFIG_SHOW_OOC) then
			self:SetHeight(-(self.text:GetBottom() - self:GetTop()) + 14)
		else
			self:SetHeight(-(self.textooc:GetBottom() - self:GetTop()) + 14)
		end
	end
end

-------------------------------------------------------------------------------
-- Update frame display.
--
local function updateFrame()
	local show_ooc = TRP3_API.configuration.getValue(CONFIG_SHOW_OOC)

	-- Update visibility.
	if TRP3_API.profile.getData("player/character/RP") == 1
			and TRP3_API.configuration.getValue(CONFIG_SHOW) then
		Me.frame:Show()
		if show_ooc then
			Me.frame.textooc:Show()
		else
			Me.frame.textooc:Hide()
		end
	else
		Me.frame:Hide()
	end

	-- Update text from profile currently.
	Me.frame.text:SetText(TRP3_API.profile.getData("player/character").CU or "")
	Me.frame.textooc:SetText(TRP3_API.profile.getData("player/character").CO or "")

	Me.frame:UpdateHeight()
end

-------------------------------------------------------------------------------
-- The /cur slash command.
--
local function SlashCommandCur(msg)
	Me:SetCurrently(msg)
end

-------------------------------------------------------------------------------
-- The /cooc slash command.
--
local function SlashCommandCooc(msg)
	Me:SetCurrently(msg, true)
end

-------------------------------------------------------------------------------
-- Secondary initialization.
--
local function onStart()
	local self = Me
	TRP3_API.currently_frame = Me

	SlashCmdList.CUR  = SlashCommandCur
	SlashCmdList.COOC = SlashCommandCooc
	SLASH_CUR1  = "/cur"
	SLASH_COOC1 = "/cooc"

	-- Add alternate slash commands if the translation is different.
	if L.CURFRAME_SLASH_CMD ~= "/cur" then
		SLASH_CUR2 = L.CURFRAME_SLASH_CMD
	end

	if L.CURFRAME_SLASH_CMD2 ~= "/cooc" then
		SLASH_COOC2 = L.CURFRAME_SLASH_CMD2
	end

	TRP3_API.configuration.registerConfigKey(CONFIG_POS_A, "TOP");
	TRP3_API.configuration.registerConfigKey(CONFIG_POS_X, 0);
	TRP3_API.configuration.registerConfigKey(CONFIG_POS_Y, -60);

	-- handler for when the show toggle is changed.
	TRP3_API.configuration.registerHandler(CONFIG_SHOW, updateFrame)
	TRP3_API.configuration.registerHandler(CONFIG_SHOW_OOC, updateFrame)

	function Me:ResetConfig()
		TRP3_API.configuration.setValue(CONFIG_POS_A, "TOP");
		TRP3_API.configuration.setValue(CONFIG_POS_X, 0);
		TRP3_API.configuration.setValue(CONFIG_POS_Y, -60);
		TRP3_API.configuration.setValue(CONFIG_SHOW, true);
		TRP3_API.configuration.setValue(CONFIG_SHOW_OOC, false);
	end

	Me.frame:ClearAllPoints()
	Me.frame:SetPoint(
		TRP3_API.configuration.getValue(CONFIG_POS_A),
		UIParent,
		TRP3_API.configuration.getValue(CONFIG_POS_A),
		TRP3_API.configuration.getValue(CONFIG_POS_X),
		TRP3_API.configuration.getValue(CONFIG_POS_Y));

	Me.frame:SetMovable(true)

	-- Make the whole frame (background and border) a drag handle, not just the
	-- caption. The EditBoxes have enableMouse=false, so clicks on them fall
	-- through to the frame and drag it too (text is edited via /cur|/cooc).
	local function StartDrag(self, button)
		if button == "LeftButton" then
			Me.frame:StartMoving()
		end
	end

	local function StopDrag(self, button)
		if button == "LeftButton" then
			Me.frame:StopMovingOrSizing()
			local anchor, _, _, x, y = Me.frame:GetPoint(1)

			TRP3_API.configuration.setValue(CONFIG_POS_A, anchor)
			TRP3_API.configuration.setValue(CONFIG_POS_X, x)
			TRP3_API.configuration.setValue(CONFIG_POS_Y, y)
		end
	end

	Me.frame:SetScript("OnMouseDown", StartDrag)
	Me.frame:SetScript("OnMouseUp", StopDrag)

	function Me:SetCurrently(text, ooc)
		if not ooc then
			Me.frame.text:SetText(text or "")
		else
			Me.frame.textooc:SetText(text or "")
		end
		Me:SaveCurrently()
	end

	function Me:SaveCurrently()
		local character = TRP3_API.profile.getData("player/character")
		local old_cu = character.CU
		local old_co = character.CO
		character.CU = self.frame.text:GetText()
		character.CO = self.frame.textooc:GetText()
		local changed = false
		if old_cu ~= character.CU then
			changed = true
			-- If the current player is being viewed, then update the UI widgets with what
			-- we type in.
			local context = TRP3_API.navigation.page.getCurrentContext()
			if context and context.isPlayer then
				TRP3_RegisterMiscViewCurrentlyIC:SetText(character.CU or "")
			end
		end

		if old_co ~= character.CO then
			changed = true
			local context = TRP3_API.navigation.page.getCurrentContext()
			if context and context.isPlayer then
				TRP3_RegisterMiscViewCurrentlyOOC:SetText(character.CO or "")
			end
		end

		if changed then
			-- Update profile version (v) and then trigger an event for other TRP handlers.
			-- Seems a little ugly that we are touching the version number which should
			--  probably be left to TRP3 implementation details.
			character.v = TRP3_API.utils.math.incrementNumber(character.v or 1, 2)
			TRP3_Addon:TriggerEvent(
				TRP3_Addon.Events.REGISTER_DATA_UPDATED,
				TRP3_API.globals.player_id,
				TRP3_API.profile.getPlayerCurrentProfileID(),
				"character"
			)
		end
	end

	TRP3_API.RegisterCallback(TRP3_Addon, TRP3_Addon.Events.REGISTER_DATA_UPDATED,
		function(self, player_id, profileID)
			if player_id == TRP3_API.globals.player_id then
				updateFrame()
			end
		end)

	-- If the user clicks on the world (screen with no UI element), remove
	--  focus from the frames.
	WorldFrame:HookScript("OnMouseDown", function()
		if Me.frame.text:HasFocus() then
			Me.frame.text:ClearFocus()
		end
		if Me.frame.textooc:HasFocus() then
			Me.frame.textooc:ClearFocus()
		end
	end)

	updateFrame()
end

------------------------------------------------------------------------------
-- Register with TRP3.
--
local MODULE_INFO = {
	["name"]        = C_AddOns.GetAddOnMetadata(addonName, "Title");
	["description"] = C_AddOns.GetAddOnMetadata(addonName, "Notes");
	["version"]     = tonumber(C_AddOns.GetAddOnMetadata(addonName, "Version"):match("^%d+%.%d+"));
	["id"]          = "trp3_currently_frame";
	["onStart"]     = onStart;
	["onInit"]      = onInit;
	["minVersion"]  = 3;
};

TRP3_API.module.registerModule(MODULE_INFO);
