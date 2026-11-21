-- Ultrawide HUD & Display Tweaks for VOID/BREAKER - settings. Restart the game after editing this file.
return {
    -- Key that opens/closes the in-game settings menu (sliders for HUD width
    -- and opacity). Escape or the "Close" button also close it.
    MenuKey = "F7",

    -- Default HUD width as a fraction of the screen width (0.60 = 60 %).
    -- Values changed in-game are saved to Mods/UltrawideDisplayTweaks/saved_aspect.txt
    -- and take precedence. "Reset" in the menu returns to this default.
    DefaultWidth = 0.60,
    -- Alternative default as an aspect ratio (16/9 = classic, 21/9 = a bit wider).
    -- Only used when DefaultWidth = 0.
    TargetAspect = 16 / 9,
    -- Narrowest allowed area (1 = square).
    MinAspect = 1.0,

    -- Initial HUD opacity: 1 = fully opaque, 0.5 = half transparent.
    -- Values changed in-game are saved to Mods/UltrawideDisplayTweaks/saved_opacity.txt.
    Opacity = 1.0,
    -- Lowest allowed opacity, so the HUD never disappears completely.
    MinOpacity = 0.1,
    -- HUD elements (widget object names) that always stay fully opaque.
    OpacityExclude = { "Dynamic_Crosshair_W" },
    -- Default for "Flat HUD": true = draw the HUD without the game's tilted,
    -- tinted look. Can be toggled in the menu (saved to saved_flat.txt).
    FlatHUD = false,

    -- Image settings in the menu (applied to the player camera's post-process).
    -- false = hide them and never touch the camera.
    ImageSettings = true,
    -- Default exposure compensation in EV (0 = game default, -1 = half as bright).
    -- Values changed in-game are saved to Mods/UltrawideDisplayTweaks/saved_image.txt.
    Exposure = 0.0,
    ExposureMin = -4.0,
    ExposureMax = 2.0,
    -- Default bloom strength as a multiplier of the game's value (1 = 100 %).
    Bloom = 1.0,
    BloomMax = 1.5,

    -- Monitor aspect ratio. 0 = detect automatically.
    -- Examples: 32/9, 21/9, 5120/1440, 3440/1440
    ScreenAspect = 0,

    -- HUD widgets to center (exact class names).
    --   WBP_PlayerIcons_C = health, weapons, ammo, abilities, crosshair, prompts
    --   WBP_Mission_C     = mission objectives (top right)
    -- Do NOT add menus or world markers (ScreenIndicator_C).
    Widgets = { "WBP_PlayerIcons_C", "WBP_Mission_C" },

    -- Game menus that are centered like the HUD (part of the menu's class
    -- name, case-insensitive). Newly opened menus are logged to UE4SS.log as
    -- "game menu opened: <class>", so names can be looked up there.
    CenteredMenus = { "Inventory", "Researcher" },
    -- Name of the game's menu stack inside the root widget.
    MenuStackName = "MenuStack",
    -- How often (ms) the active game menu is checked.
    MenuWatchMs = 100,

    -- Widget the settings menu is attached to (the game's root UI widget).
    MenuHost = "VB_RootPlayerWidget_C",
    -- Slider width of the settings menu in UI units.
    MenuWidth = 420,

    -- How often (ms) to look for newly created HUD widgets.
    ScanIntervalMs = 1000,
    -- How often (ms) the menu reads its sliders while it is open.
    MenuPollMs = 30,

    -- Optional hotkeys without a default key. Set a key name to enable,
    -- e.g. "F5" (valid names: see Mods/Keybinds/Scripts/main.lua).
    -- NarrowerKey / WiderKey: move the HUD closer to the center / further out.
    NarrowerKey = "",
    WiderKey    = "",
    -- Step per key press (aspect ratio units; 0.1 is about 2.8 % of the width on 32:9).
    Step = 0.1,
    -- MoreTransparentKey / LessTransparentKey: change the HUD opacity.
    MoreTransparentKey = "",
    LessTransparentKey = "",
    -- Step per key press (0.1 = 10 %).
    OpacityStep = 0.1,
    -- ToggleKey: turn centering and opacity on/off (for comparison).
    ToggleKey = "",
    -- ResetKey: discard the in-game adjusted values, back to TargetAspect and Opacity.
    ResetKey = "",
    -- DumpKey: write the full widget tree to UE4SS.log (for troubleshooting).
    DumpKey  = "",

    -- true = log every anchor change to UE4SS.log.
    Diagnostics = false,
    -- true = when the menu is opened the first time, log the HUD's RetainerBox
    -- effect materials to UE4SS.log (troubleshooting transparency).
    LogRetainerInfo = false,
}
