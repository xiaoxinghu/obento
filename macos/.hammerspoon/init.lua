hs.loadSpoon("SpoonInstall")

-- The `hs` command line tool talks to Hammerspoon through this.
require("hs.ipc")

-- Dictation in any app, through the `dictate` CLI.
local dictation = require("dictation")
hs.hotkey.bind({ "alt" }, "space", dictation.toggle)

-- Independent app shortcut: does not hide other applications.
hs.hotkey.bind({ "alt" }, "e", function()
	hs.application.launchOrFocus("Emacs")
end)

-- App groups, not Spaces. The first app in each list receives focus.
-- Other applications and window layouts are left alone.
local appGroups = {
	["1"] = { "com.google.Chrome" },
	["2"] = { "com.apple.MobileSMS", "com.apple.mail" },
	["3"] = { "org.gnu.Emacs" },
}

local function showGroup(bundleIDs)
	-- Launch/focus in reverse order so the first app ends up in front.
	for i = #bundleIDs, 1, -1 do
		hs.application.launchOrFocusByBundleID(bundleIDs[i])
	end
end

for key, bundleIDs in pairs(appGroups) do
	local group = bundleIDs
	hs.hotkey.bind({ "alt" }, key, function()
		showGroup(group)
	end)
end
