local addonName, Me = ...

Me.tweaks = Me.tweaks or {};

local function CONFIG_KEY(tweakID)
	return "galetweak_" .. tweakID;
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

	elements[#elements + 1] = {
		inherit = "TRP3_ConfigCheck",
		title = "Show currently frame",
		help = "Show or hide the currently frame. You can also hide the frame by setting your OOC flag.",
		configKey = "CONFIG_TRP3CURRENTLYFRAME_SHOW",
	};

	elements[#elements + 1] = {
		inherit = "TRP3_ConfigCheck",
		title = "Show OOC editor in currently frame",
		help = "Show an editor section for OOC information in the currently frame.",
		configKey = "CONFIG_TRP3CURRENTLYFRAME_SHOW_OOC",
	};

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

		TRP3_API.configuration.registerConfigKey("CONFIG_TRP3CURRENTLYFRAME_SHOW", true);
		TRP3_API.configuration.registerConfigKey("CONFIG_TRP3CURRENTLYFRAME_SHOW_OOC", false);

		RegisterConfigPage();
	end,
	onDisable = function()
		for _, tweak in ipairs(Me.tweaks) do
			RemoveTweak(tweak);
		end
	end,
});
