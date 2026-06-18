local addonName, Me = ...

local Enums = AddOn_TotalRP3.Enums;

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Tweak definitions
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local function CONFIG_KEY(tweakID)
	return "galetweak_" .. tweakID;
end

Me.tweaks = {};

-- Damage Meter Toggle
do
	local function UpdateDamageMeterCVar()
		local isInCharacter = AddOn_TotalRP3.Player.GetCurrentUser():GetRoleplayStatus() ~= Enums.ROLEPLAY_STATUS.OUT_OF_CHARACTER;
		C_CVar.SetCVar("damageMeterEnabled", isInCharacter and "0" or "1");
	end

	Me.tweaks[#Me.tweaks + 1] = {
		id = "damage_meter",
		name = "Damage Meter Toggle",
		description = "Disables the damage meter while in character, and enables it while out of character.",
		defaultEnabled = true,
		onEnable = function()
			UpdateDamageMeterCVar();
			TRP3_API.RegisterCallback(TRP3_Addon, TRP3_Addon.Events.ROLEPLAY_STATUS_CHANGED, UpdateDamageMeterCVar);
		end,
		onDisable = function()
			TRP3_API.UnregisterCallback(TRP3_Addon, TRP3_Addon.Events.ROLEPLAY_STATUS_CHANGED, UpdateDamageMeterCVar);
		end,
	};
end

-- OOC Emote Alert
do
	local function OnChatMsg(self, event, msg, ...)
		local playerName = ...;

		if strsplit("-", playerName) ~= UnitName("player") then
			return false;
		end

		if AddOn_TotalRP3.Player.GetCurrentUser():GetRoleplayStatus() == Enums.ROLEPLAY_STATUS.OUT_OF_CHARACTER then
			PlaySound(SOUNDKIT.RAID_WARNING);
		end

		return false;
	end

	Me.tweaks[#Me.tweaks + 1] = {
		id = "ooc_emote_alert",
		name = "OOC Emote Alert",
		description = "Plays a warning sound if you send an emote while out of character.",
		defaultEnabled = false,
		onEnable = function()
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_EMOTE", OnChatMsg);
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_TEXT_EMOTE", OnChatMsg);
		end,
		onDisable = function()
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_EMOTE", OnChatMsg);
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_TEXT_EMOTE", OnChatMsg);
		end,
	};
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Tweak lifecycle helpers
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local function ApplyTweak(tweak)
	local configKey = CONFIG_KEY(tweak.id);

	if TRP3_API.configuration.getValue(configKey) then
		tweak.onEnable();
	end
end

local function RemoveTweak(tweak)
	local configKey = CONFIG_KEY(tweak.id);

	if TRP3_API.configuration.getValue(configKey) then
		tweak.onDisable();
	end
end

local function OnTweakConfigChanged(tweak)
	local configKey = CONFIG_KEY(tweak.id);

	if TRP3_API.configuration.getValue(configKey) then
		tweak.onEnable();
	else
		tweak.onDisable();
	end
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Configuration page
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local CONFIG_PAGE_ID = "module_config_galetweak";

local function RegisterConfigPage()
	local elements = {};

	for _, tweak in ipairs(Me.tweaks) do
		elements[#elements + 1] = {
			inherit = "TRP3_ConfigCheck",
			title = tweak.name,
			help = tweak.description,
			configKey = CONFIG_KEY(tweak.id),
		};
	end

	local pageTitle = C_AddOns.GetAddOnMetadata(addonName, "Title");

	TRP3_API.configuration.registerConfigurationPage({
		id = CONFIG_PAGE_ID,
		title = pageTitle,
		menuText = pageTitle,
		pageText = pageTitle,
		elements = elements,
	});
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- Module registration
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

TRP3_API.module.registerModule({
	id = "galetweak",
	name = C_AddOns.GetAddOnMetadata(addonName, "Title"),
	description = C_AddOns.GetAddOnMetadata(addonName, "Notes"),
	version = tonumber(C_AddOns.GetAddOnMetadata(addonName, "Version"):match("^%d+%.%d+")),
	hotReload = true,
	onStart = function()
		for _, tweak in ipairs(Me.tweaks) do
			TRP3_API.configuration.registerConfigKey(CONFIG_KEY(tweak.id), tweak.defaultEnabled);
			TRP3_API.configuration.registerHandler(CONFIG_KEY(tweak.id), function()
				OnTweakConfigChanged(tweak);
			end);
			ApplyTweak(tweak);
		end

		RegisterConfigPage();
	end,
	onDisable = function()
		for _, tweak in ipairs(Me.tweaks) do
			RemoveTweak(tweak);
		end
	end,
});
