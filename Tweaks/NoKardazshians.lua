local _, Me = ...

Me.tweaks = Me.tweaks or {};

-- No Kar'dazshians
do
	local WINDCHIME = "Windrunner";

	local function OnMonsterChat(self, event, msg, sender, ...)
		if sender and sender:find(WINDCHIME, 1, true) then
			return true;
		end
		return false;
	end

	Me.tweaks[#Me.tweaks + 1] = {
		id = "no_kardazshians",
		name = "No Kar'dazshians",
		description = "Filters out NPC chat lines from anyone with \"Windrunner\" in their name.",
		defaultEnabled = false,
		onEnable = function()
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_MONSTER_SAY", OnMonsterChat);
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_MONSTER_YELL", OnMonsterChat);
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", OnMonsterChat);
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", OnMonsterChat);
		end,
		onDisable = function()
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_MONSTER_SAY", OnMonsterChat);
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_MONSTER_YELL", OnMonsterChat);
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_MONSTER_WHISPER", OnMonsterChat);
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_MONSTER_EMOTE", OnMonsterChat);
		end,
	};
end
