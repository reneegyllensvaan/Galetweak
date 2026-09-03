local _, Me = ...

Me.tweaks = Me.tweaks or {};

-- IC Mode UI Toggle
--
-- Switches a few roleplay-relevant UI elements based on whether the player is
-- in character (IC) or out of character (OOC):
--
--   * Damage meter: hidden while IC, shown while OOC. If the Details! addon is
--     detected its windows are used (and Blizzard's built-in damage meter is
--     left disabled); otherwise the built-in damageMeterEnabled CVar is toggled.
--   * Eavesdropper: shown while IC (so you can overhear nearby roleplay), hidden
--     while OOC.
--
-- The config key id is kept as "damage_meter" for SavedVariables continuity,
-- even though the tweak now covers more than the damage meter.
do
	local Enums = AddOn_TotalRP3.Enums;

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- RP status
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local function IsInCharacter()
		return AddOn_TotalRP3.Player.GetCurrentUser():GetRoleplayStatus() ~= Enums.ROLEPLAY_STATUS.OUT_OF_CHARACTER;
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Built-in damage meter
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local function SetBuiltInMeterEnabled(enabled)
		C_CVar.SetCVar("damageMeterEnabled", enabled and "1" or "0");
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Details!
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	-- Array indices (not Details' meu_id) of the windows that were open before we
	-- hid them, so we can restore exactly the set the player had open on return
	-- to OOC. Indices are safe here because the instance array can't shift while
	-- the windows are hidden.
	local detailsOpenBeforeHide = {};
	local detailsHidden = false;

	local function IsDetailsAvailable()
		return type(Details) == "table"
			and type(Details.GetInstance) == "function"
			and type(Details.tabela_instancias) == "table";
	end

	local function HideDetails()
		if not IsDetailsAvailable() or detailsHidden then
			return;
		end

		detailsHidden = true;
		wipe(detailsOpenBeforeHide);

		for index, instance in ipairs(Details.tabela_instancias) do
			if instance and not instance.ignore_mass_showhide and instance:IsEnabled() then
				detailsOpenBeforeHide[#detailsOpenBeforeHide + 1] = index;
				instance:ShutDown(true);
			end
		end
	end

	local function ShowDetails()
		if not IsDetailsAvailable() or not detailsHidden then
			return;
		end

		detailsHidden = false;

		-- Restore only the windows we hid. On first run (login while OOC)
		-- detailsHidden is false and nothing is touched, leaving Details' own
		-- saved window state intact.
		for _, index in ipairs(detailsOpenBeforeHide) do
			local instance = Details:GetInstance(index);
			if instance and not instance.ignore_mass_showhide and not instance:IsEnabled() then
				-- all=true keeps the window in its previous group (matches
				-- Details' own mass reopen path).
				instance:EnableInstance(nil, true);
			end
		end
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Eavesdropper
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local function IsEavesdropperAvailable()
		return type(ED) == "table"
			and type(ED.Frame) == "table"
			and type(ED.Frame.Show) == "function"
			and type(ED.Frame.Hide) == "function";
	end

	local function SetEavesdropperVisible(visible)
		if not IsEavesdropperAvailable() then
			return;
		end

		if visible then
			ED.Frame:Show();
		else
			ED.Frame:Hide();
		end

		-- Mirror Eavesdropper's own /ed show|hide commands so its saved
		-- visibility state agrees with the toggled frame.
		if type(ED.Database) == "table" and type(ED.Database.SetCharSetting) == "function" then
			ED.Database:SetCharSetting("WindowVisible", visible);
		end
	end

	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
	-- Apply the UI state for the current RP status
	--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

	local function ApplyUiState()
		local isInCharacter = IsInCharacter();

		if isInCharacter then
			-- IC: no damage meter, but show Eavesdropper to overhear roleplay.
			HideDetails();
			SetBuiltInMeterEnabled(false);
			SetEavesdropperVisible(true);
		else
			-- OOC: bring the damage meter back (Details if available, otherwise
			-- Blizzard's built-in meter), and hide Eavesdropper.
			if IsDetailsAvailable() then
				ShowDetails();
				SetBuiltInMeterEnabled(false);
			else
				SetBuiltInMeterEnabled(true);
			end
			SetEavesdropperVisible(false);
		end
	end

	Me.tweaks[#Me.tweaks + 1] = {
		id = "damage_meter",
		name = "IC Mode UI Toggle",
		description = "Hides the damage meter (Details!, or Blizzard's built-in meter) while in character, and hides Eavesdropper while out of character.",
		defaultEnabled = true,
		onEnable = function()
			ApplyUiState();

			-- Details and Eavesdropper can finish initializing after TRP3 starts
			-- galetweak, so re-apply once shortly after login to catch any frames
			-- that weren't ready yet.
			C_Timer.After(1.0, function()
				if TRP3_API.configuration.getValue(Me.CONFIG_KEY("damage_meter")) then
					ApplyUiState();
				end
			end);

			TRP3_API.RegisterCallback(TRP3_Addon, TRP3_Addon.Events.ROLEPLAY_STATUS_CHANGED, ApplyUiState);
		end,
		onDisable = function()
			TRP3_API.UnregisterCallback(TRP3_Addon, TRP3_Addon.Events.ROLEPLAY_STATUS_CHANGED, ApplyUiState);

			-- Forget any Details windows we had hidden so a later re-enable
			-- recomputes from the player's current window state.
			detailsHidden = false;
			wipe(detailsOpenBeforeHide);
		end,
	};
end
