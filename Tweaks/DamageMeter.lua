local _, Me = ...

Me.tweaks = Me.tweaks or {};

-- Damage Meter Toggle
do
	local Enums = AddOn_TotalRP3.Enums;

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
