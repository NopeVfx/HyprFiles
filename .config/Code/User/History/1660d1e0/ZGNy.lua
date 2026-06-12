require("modules.monitors")
require("modules.binds")
require("modules.autostart")
require("modules.env")
require("modules.decorations")
require("modules.layout")
require("modules.misc")
require("modules.input")
require("modules.windowrules")

-- HyprMod managed settings
require("hyprland-gui")

-- Wrap inside the startup event listener
hl.on("hyprland.start", function ()
    -- Apply GTK3 Theme
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Everforest-Dark'")

    -- Apply GTK4 Theme (HyprMod)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
end)

-- Set Environment Variables
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
