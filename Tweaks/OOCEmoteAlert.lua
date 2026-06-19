local _, Me = ...

Me.tweaks = Me.tweaks or {};

-- OOC Emote Alert
do
	local Enums = AddOn_TotalRP3.Enums;

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
		description = "Plays a warning sound if you send a custom emote while out of character.",
		defaultEnabled = false,
		onEnable = function()
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_EMOTE", OnChatMsg);
		end,
		onDisable = function()
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_EMOTE", OnChatMsg);
		end,
	};
end
