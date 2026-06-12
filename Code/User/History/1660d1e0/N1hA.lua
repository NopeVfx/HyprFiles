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

-- Apply GTK3 Theme
hypr.exec("gsettings set org.gnome.desktop.interface gtk-theme 'Everforest-Dark'")

-- Apply GTK4 Theme (HyprMod)
hypr.exec("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
