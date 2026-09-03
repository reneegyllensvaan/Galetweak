local _, Me = ...

Me.tweaks = Me.tweaks or {};

-- Map Scan logging / alerting.
--
-- TRP3's player map scanner broadcasts a "C_SCAN" command carrying the mapID
-- the scanner is currently viewing. Every client that can hear the broadcast
-- receives it via AddOn_TotalRP3.Communications.broadcast.registerCommand.
--
-- We expose two independent tweaks that each register their own callback on
-- the same command (registerCommand appends to a list, so callbacks coexist
-- with TRP3's own C_SCAN handler):
--
--   * Map Scan Alert  — prints a chatbox message ONLY when a scan targets the
--     player's current location (an alert that *you* were scanned).
--   * Map Scan Log    — appends EVERY scan heard on the broadcast channel
--     (zone, sender, timestamp) to a persisted SavedVariables log, regardless
--     of whether it targets the player or whether the alert tweak is enabled.
--
-- TRP3's broadcast API has no unregister, so each callback stays registered
-- for the session and gates itself on its own config key (becoming a no-op
-- when its tweak is disabled).

do
	local SCAN_COMMAND = "C_SCAN";
	local MAX_LOG_ENTRIES = 30000;

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Chat frame enumeration
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	-- Builds the dropdown options for the available chat frames. Values are the
	-- chat frame index (ChatFrame<N>), which is what gets stored in the config.
	local function BuildChatFrameList()
		local list = {};
		local maxWindows = MAX_WOW_CHAT_WINDOWS or 10;

		for i = 1, maxWindows do
			local frame = _G["ChatFrame" .. i];
			if frame then
				local name = GetChatWindowInfo(i);
				local label = (name and name ~= "") and name or ("Chat Frame " .. i);
				list[#list + 1] = { label, i };
			end
		end

		if #list == 0 then
			list[1] = { "Default", 1 };
		end

		return list;
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Zone helpers
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	-- Resolves a TRP3 scan mapID to a human-readable zone label. For open-world
	-- scans mapID is a uiMapID; for housing scans it's a neighborhood GUID.
	local function GetZoneLabel(mapID)
		local numericID = tonumber(mapID);
		if numericID then
			local info = C_Map.GetMapInfo(numericID);
			if info and info.name and info.name ~= "" then
				return info.name;
			end
			return ("Map %d"):format(numericID);
		end
		return tostring(mapID);
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Location matching (for the chatbox alert)
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local function IsScanForCurrentLocation(mapID)
		local Map = AddOn_TotalRP3 and AddOn_TotalRP3.Map;
		if not Map then
			return false;
		end

		local inInstance, instanceType = IsInInstance();
		if inInstance then
			if instanceType == "interior" then
				-- Inside a house: the scan targets the house's neighborhood.
				local houseInfo = C_Housing.GetCurrentHouseInfo();
				return houseInfo ~= nil and houseInfo.neighborhoodGUID == mapID;
			elseif instanceType == "neighborhood" then
				-- Walking around the neighborhood: scan targets this neighborhood.
				return C_Housing.GetCurrentNeighborhoodGUID() == mapID;
			end
			-- Any other instance type (dungeon/raid/etc.) can't be scanned.
			return false;
		end

		-- Open world: the scan carries the uiMapID the scanner is viewing.
		return tonumber(mapID) == Map.getPlayerMapID();
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Chatbox alert
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local ALERT_TWEAK_ID = "map_scan_alert";

	local function FormatAlertMessage(displayName)
		return string.format("|cff69CCF0[Galetweak]|r You were map-scanned by |cff69CCF0%s|r.", displayName);
	end

	local function LogToChatFrame(message)
		local index = Me.GetSubValue(ALERT_TWEAK_ID, "chat_frame") or 1;
		local frame = _G["ChatFrame" .. index] or DEFAULT_CHAT_FRAME;
		if frame and frame.AddMessage then
			-- AddMessage expects 0-1 color values; pass white so the embedded
			-- |c color codes in the message are respected.
			frame:AddMessage(message, 1, 1, 1);
		end
	end

	local function OnScanForAlert(sender, mapID)
		-- No-op if the alert tweak is disabled (broadcast API has no unregister).
		if not TRP3_API.configuration.getValue(Me.CONFIG_KEY(ALERT_TWEAK_ID)) then
			return;
		end

		-- Don't alert on our own scan broadcasts.
		if sender == TRP3_API.globals.player_id then
			return;
		end

		-- Only alert when the scan actually targets the player's location.
		if not IsScanForCurrentLocation(mapID) then
			return;
		end

		local displayName = Ambiguate(sender or UNKNOWN, "none") or sender or UNKNOWN;
		LogToChatFrame(FormatAlertMessage(displayName));
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- File log (SavedVariables)
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local LOG_TWEAK_ID = "map_scan_log";

	local function AppendToScanLog(sender, mapID)
		-- WoW's addon sandbox cannot write to arbitrary files at runtime. The
		-- only disk persistence available is SavedVariables, which are flushed
		-- to WTF/Account/<account>/SavedVariables/Galetweak.lua on logout or
		-- UI reload. We accumulate entries here and let the engine persist them.
		GaletweakDB = GaletweakDB or {};
		GaletweakDB.mapScanLog = GaletweakDB.mapScanLog or {};

		local scannerName = sender or UNKNOWN;
		local displayName = Ambiguate(scannerName, "none") or scannerName;
		local zoneLabel = GetZoneLabel(mapID);

		-- Format: [timestamp] sender scanned zone (mapID)
		local entry = string.format("[%s] %s scanned %s (%s)",
			date("%Y-%m-%d %H:%M:%S"), scannerName, zoneLabel, tostring(mapID));

		tinsert(GaletweakDB.mapScanLog, entry);

		-- Cap the log so it doesn't grow without bound across sessions.
		while #GaletweakDB.mapScanLog > MAX_LOG_ENTRIES do
			tremove(GaletweakDB.mapScanLog, 1);
		end
	end

	local function OnScanForLog(sender, mapID)
		-- No-op if the log tweak is disabled (broadcast API has no unregister).
		if not TRP3_API.configuration.getValue(Me.CONFIG_KEY(LOG_TWEAK_ID)) then
			return;
		end

		-- Log every scan heard on the broadcast channel, including our own.
		AppendToScanLog(sender, mapID);
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Registration helpers
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local alertRegistered = false;
	local logRegistered = false;

	local function GetBroadcast()
		return AddOn_TotalRP3 and AddOn_TotalRP3.Communications and AddOn_TotalRP3.Communications.broadcast;
	end

	local function EnsureAlertRegistered()
		if alertRegistered then
			return;
		end
		local broadcast = GetBroadcast();
		if not broadcast or not broadcast.registerCommand then
			return;
		end
		broadcast.registerCommand(SCAN_COMMAND, OnScanForAlert);
		alertRegistered = true;
	end

	local function EnsureLogRegistered()
		if logRegistered then
			return;
		end
		local broadcast = GetBroadcast();
		if not broadcast or not broadcast.registerCommand then
			return;
		end
		broadcast.registerCommand(SCAN_COMMAND, OnScanForLog);
		logRegistered = true;
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Tweaks
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	Me.tweaks[#Me.tweaks + 1] = {
		id = ALERT_TWEAK_ID,
		name = "Map Scan Alert",
		description = "Prints a chatbox message when another player scans the map for your location. Logs scans even when your location broadcast is disabled or you are out of character.",
		defaultEnabled = false,
		subConfig = {
			{
				id = "chat_frame",
				type = "dropdown",
				name = "Map scan alert chat frame",
				help = "Which chat window the map scan alert message is printed to.",
				default = 1,
				listContent = BuildChatFrameList(),
			},
		},
		onEnable = function()
			EnsureAlertRegistered();
		end,
		onDisable = function()
			-- No unregister in TRP3's broadcast API; the callback no-ops via
			-- the config-key check in OnScanForAlert when this tweak is off.
		end,
	};

	Me.tweaks[#Me.tweaks + 1] = {
		id = LOG_TWEAK_ID,
		name = "Map Scan Log (file)",
		description = "Records every map scan heard on the TRP3 broadcast channel (zone, sender, timestamp) to the Galetweak SavedVariables log, written to disk on logout or UI reload. Independent of the Map Scan Alert chatbox toggle.",
		defaultEnabled = false,
		onEnable = function()
			EnsureLogRegistered();
		end,
		onDisable = function()
			-- No unregister in TRP3's broadcast API; the callback no-ops via
			-- the config-key check in OnScanForLog when this tweak is off.
		end,
	};
end
