local addonName, Me = ...

Me.tweaks = Me.tweaks or {};

local function CONFIG_KEY(tweakID)
	return "galetweak_" .. tweakID;
end
Me.CONFIG_KEY = CONFIG_KEY;

-- Sub-setting config key for a tweak (e.g. galetweak_map_scan_alert_chat_frame).
local function SUB_KEY(tweakID, subID)
	return CONFIG_KEY(tweakID) .. "_" .. subID;
end
Me.SUB_KEY = SUB_KEY;

-- Read a tweak sub-setting value at runtime.
function Me.GetSubValue(tweakID, subID)
	return TRP3_API.configuration.getValue(SUB_KEY(tweakID, subID));
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

		-- Sub-settings declared by a tweak. These are greyed out while the
		-- parent tweak is disabled via dependentOnOptions.
		if tweak.subConfig then
			for _, sub in ipairs(tweak.subConfig) do
				local element;
				if sub.type == "dropdown" then
					element = {
						inherit = "TRP3_ConfigDropDown",
						title = sub.name,
						help = sub.help,
						configKey = SUB_KEY(tweak.id, sub.id),
						listContent = sub.listContent,
						listCancel = true,
						dependentOnOptions = { CONFIG_KEY(tweak.id) },
					};
				elseif sub.type == "check" then
					element = {
						inherit = "TRP3_ConfigCheck",
						title = sub.name,
						help = sub.help,
						configKey = SUB_KEY(tweak.id, sub.id),
						dependentOnOptions = { CONFIG_KEY(tweak.id) },
					};
				end
				if element then
					elements[#elements + 1] = element;
				end
			end
		end
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
		-- Per-addon SavedVariables, used by tweaks that persist data to disk
		-- (e.g. the map scan log). Flushed to WTF/.../SavedVariables/Galetweak.lua on logout.
		GaletweakDB = GaletweakDB or {};

		for _, tweak in ipairs(Me.tweaks) do
			TRP3_API.configuration.registerConfigKey(CONFIG_KEY(tweak.id), tweak.defaultEnabled);
			TRP3_API.configuration.registerHandler(CONFIG_KEY(tweak.id), function()
				OnTweakConfigChanged(tweak);
			end);

			-- Register any sub-setting keys before applying the tweak so that
			-- onEnable can read them safely.
			if tweak.subConfig then
				for _, sub in ipairs(tweak.subConfig) do
					TRP3_API.configuration.registerConfigKey(SUB_KEY(tweak.id, sub.id), sub.default);
				end
			end

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
