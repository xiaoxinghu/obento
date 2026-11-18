-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Monitor scale is Hyprland's scale for the output. It sizes everything
-- Wayland-native, accepts fractions (1.6, 1.75), and applies immediately.
-- "auto" lets Hyprland pick per display.
local omarchy_monitor_scale = "auto"
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Top-aligned: laptop (1728 logical pixels wide), Gigabyte, then portrait LG.
-- Match by display rather than DP number so reconnecting the dock won't swap rules.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
hl.monitor({ output = "desc:GIGA-BYTE TECHNOLOGY CO. LTD. Gigabyte M32U 22131B000314", mode = "3840x2160@60", position = "1728x0", scale = 2 })
hl.monitor({ output = "desc:LG Electronics LG ULTRAFINE 111NTPCHT328", mode = "3840x2160@60", position = "3648x0", scale = 2, transform = 3 })

-- GDK scale is GDK_SCALE, the factor GTK draws its own UI at. It's what
-- sizes X11/XWayland windows, which Omarchy leaves unscaled so they stay
-- crisp instead of being stretched by the compositor. GTK only honors whole
-- numbers, so use the nearest integer to the monitor scale, and restart an
-- app for a change to reach it.
local omarchy_gdk_scale = 2
hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
