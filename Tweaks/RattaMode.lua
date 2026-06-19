local _, Me = ...

Me.tweaks = Me.tweaks or {};

-- Ratta Mode
do
	local sounds = {5545203, 5545205, 5545207};
	local soundIndex = 1;

	local function OnChatMsg(self, event, msg, playerName, ...)
		if playerName == "Iâlluen-ArgentDawn" then
			local soundFile = sounds[soundIndex];
			PlaySoundFile(soundFile);
			if event == "CHAT_MSG_YELL" then
                -- play twice so it's a little louder if shes yelling
				PlaySoundFile(soundFile);
			end
			soundIndex = soundIndex % #sounds + 1;
		end
		return false;
	end

	Me.tweaks[#Me.tweaks + 1] = {
		id = "ratta_mode",
		name = "Ratta Mode",
		description = "plays a rat squeak whenever the ratta speaks in /s or /y",
		defaultEnabled = false,
		onEnable = function()
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SAY", OnChatMsg);
			ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_YELL", OnChatMsg);
		end,
		onDisable = function()
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_SAY", OnChatMsg);
			ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_YELL", OnChatMsg);
		end,
	};
end
