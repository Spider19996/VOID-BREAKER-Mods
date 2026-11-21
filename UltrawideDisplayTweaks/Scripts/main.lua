-- Ultrawide HUD & Display Tweaks (VOID/BREAKER)
--
-- On ultrawide monitors, squeezes the VOID/BREAKER HUD widgets into
-- a centered area (16:9 by default) by adjusting the anchors of their
-- CanvasPanelSlot inside the root widget (VB_RootPlayerWidget_C/FullScreenStack).
-- All HUD elements are anchored relative to that slot, so they move along.
local cfg = require("config")
local TAG = "[UltrawideDisplayTweaks] "
local enabled = true
local errorsReported = {}

local function log(msg) print(TAG .. msg .. "\n") end

local function reportOnce(key, err)
    if errorsReported[key] then return end
    errorsReported[key] = true
    log("ERROR (" .. key .. "): " .. tostring(err))
end

-- Runs fn every ms milliseconds ON THE GAME THREAD. LoopAsync would run the
-- callback on a separate thread, touching the Lua state concurrently with
-- game-thread hooks, which can corrupt it and crash the game.
local function gameLoop(ms, what, fn)
    local function tick()
        local ok, err = pcall(fn)
        if not ok then reportOnce(what, err) end
        return false
    end
    if LoopInGameThreadWithDelay then
        LoopInGameThreadWithDelay(ms, tick)
    else
        LoopAsync(ms, function() ExecuteInGameThread(tick) return false end)
    end
end

local layoutLib
local function getScreenAspect()
    if cfg.ScreenAspect and cfg.ScreenAspect > 0 then return cfg.ScreenAspect end
    -- Preferred: actual viewport size.
    local ok, aspect = pcall(function()
        layoutLib = layoutLib or StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        local pc = FindFirstOf("PlayerController")
        if not (layoutLib and layoutLib:IsValid() and pc and pc:IsValid()) then return nil end
        local size = layoutLib:GetViewportSize(pc)
        if size.X > 0 and size.Y > 0 then return size.X / size.Y end
    end)
    if ok and aspect then return aspect end
    -- Fallback: configured screen resolution.
    ok, aspect = pcall(function()
        local gus = FindFirstOf("GameUserSettings")
        if not (gus and gus:IsValid()) then return nil end
        local r = gus:GetScreenResolution()
        if r.X > 0 and r.Y > 0 then return r.X / r.Y end
    end)
    if ok and aspect then return aspect end
    return nil
end

-- Absolute path of this mod's folder. Relative paths do not work: the
-- process working directory is not the ue4ss folder.
local function resolveModDir()
    -- 1) Path of this script, if Lua reports it as absolute.
    local ok, dir = pcall(function()
        local src = debug.getinfo(1, "S").source
        if src:sub(1, 1) ~= "@" then return nil end
        src = src:sub(2)
        if not (src:match("^%a:[/\\]") or src:sub(1, 1) == "/") then return nil end
        local d = src:gsub("[/\\]Scripts[/\\][^/\\]+$", "")
        if d ~= src then return d end
    end)
    if ok and dir then return dir end
    -- 2) Game directory as reported by UE4SS.
    ok, dir = pcall(function()
        local win64 = IterateGameDirectories().Game.Binaries.Win64
        return win64.__absolute_path .. "\\ue4ss\\Mods\\UltrawideDisplayTweaks"
    end)
    if ok and dir then return dir end
    return "Mods/UltrawideDisplayTweaks"
end

local MOD_DIR = resolveModDir()
local SEP = MOD_DIR:find("\\", 1, true) and "\\" or "/"

-- Target aspect ratio set in-game (persisted). nil = use the default.
local SAVE_FILE = MOD_DIR .. SEP .. "saved_aspect.txt"
local target = nil

-- Default target: DefaultWidth (fraction of the screen) if set, else TargetAspect.
local function effectiveTarget(screenAspect)
    if target then return target end
    if (cfg.DefaultWidth or 0) > 0 and screenAspect then return cfg.DefaultWidth * screenAspect end
    return cfg.TargetAspect or 16 / 9
end

local function loadSaved()
    local f = io.open(SAVE_FILE, "r")
    if not f then return end
    local v = tonumber(f:read("*l") or "")
    f:close()
    if v and v > 0 then target = v end
end

local function save()
    if not target then os.remove(SAVE_FILE) return end
    local f, err = io.open(SAVE_FILE, "w")
    if not f then reportOnce("save", err) return end
    f:write(string.format("%.4f\n", target))
    f:close()
end

loadSaved()

-- Current HUD opacity (1 = fully opaque); adjustable in-game and persisted.
local OPACITY_FILE = MOD_DIR .. SEP .. "saved_opacity.txt"
local opacity = cfg.Opacity or 1.0

local function clampOpacity(v)
    return math.max(cfg.MinOpacity or 0.1, math.min(1.0, v))
end

do
    local f = io.open(OPACITY_FILE, "r")
    if f then
        local v = tonumber(f:read("*l") or "")
        f:close()
        if v then opacity = clampOpacity(v) end
    end
end

local function saveOpacity()
    local f, err = io.open(OPACITY_FILE, "w")
    if not f then reportOnce("save opacity", err) return end
    f:write(string.format("%.4f\n", opacity))
    f:close()
end

-- Flat HUD: draw the HUD without the game's tilted/tinted RetainerBox effect.
local FLAT_FILE = MOD_DIR .. SEP .. "saved_flat.txt"
local flat = cfg.FlatHUD == true

do
    local f = io.open(FLAT_FILE, "r")
    if f then
        local v = f:read("*l")
        f:close()
        if v == "1" then flat = true elseif v == "0" then flat = false end
    end
end

local function saveFlat()
    local f, err = io.open(FLAT_FILE, "w")
    if not f then reportOnce("save flat", err) return end
    f:write(flat and "1\n" or "0\n")
    f:close()
end

-- Image settings: exposure compensation (EV) and bloom strength (multiplier of
-- the game's own value). 0 EV / 100 % = untouched.
local IMAGE_FILE = MOD_DIR .. SEP .. "saved_image.txt"
local exposure = cfg.Exposure or 0.0
local bloom = cfg.Bloom or 1.0

do
    local f = io.open(IMAGE_FILE, "r")
    if f then
        local e, b = (f:read("*l") or ""):match("^%s*([%-%d%.]+)%s+([%-%d%.]+)")
        f:close()
        if tonumber(e) then exposure = tonumber(e) end
        if tonumber(b) then bloom = tonumber(b) end
    end
end

local function saveImage()
    local f, err = io.open(IMAGE_FILE, "w")
    if not f then reportOnce("save image", err) return end
    f:write(string.format("%.3f %.3f\n", exposure, bloom))
    f:close()
end

-- Left anchor for the desired centered area (0 = full width).
local function leftAnchor(screenAspect)
    if not enabled or not screenAspect then return 0 end
    local width = math.min(1, effectiveTarget(screenAspect) / screenAspect)
    return (1 - width) / 2
end

local function near(a, b) return math.abs(a - b) < 1e-4 end

-- Sets a widget's horizontal anchors, whether it sits in a CanvasPanel or
-- directly in the viewport. Returns true if something was changed.
local function setHorizontal(w, left)
    local slot = w.Slot
    if slot and slot:IsValid() and slot:IsA("/Script/UMG.CanvasPanelSlot") then
        local a = slot:GetAnchors()
        -- A widget the game is tearing down can return garbage here.
        if not (a and a.Minimum and a.Maximum) then return false end
        if near(a.Minimum.X, left) and near(a.Maximum.X, 1 - left) then return false end
        slot:SetAnchors({ Minimum = { X = left, Y = a.Minimum.Y }, Maximum = { X = 1 - left, Y = a.Maximum.Y } })
        return true
    end
    if w:IsInViewport() then
        local a = w:GetAnchorsInViewport()
        if not (a and a.Minimum and a.Maximum) then return false end
        if near(a.Minimum.X, left) and near(a.Maximum.X, 1 - left) then return false end
        w:SetAnchorsInViewport({ Minimum = { X = left, Y = a.Minimum.Y }, Maximum = { X = 1 - left, Y = a.Maximum.Y } })
        return true
    end
    return false
end

-- Opacity is applied to the direct children of each HUD widget's root panel,
-- so single elements (e.g. the crosshair) can be kept fully opaque.
-- The game itself fades some elements in/out via their render opacity, so we
-- never just overwrite it: we remember the value the game set ("base") and
-- apply base * factor. If the game changes it later, that becomes the new base.
local opacityExclude = {}
for _, n in ipairs(cfg.OpacityExclude or {}) do opacityExclude[n] = true end

local opacityState = {} -- child address -> { base = game value, applied = our value }

local function applyOpacity(child, factor)
    local addr = child:GetAddress()
    local cur = child:GetRenderOpacity()
    local s = opacityState[addr]
    if not s or not near(cur, s.applied) then
        -- First visit, or the game changed the value since we last set it.
        s = { base = cur }
        opacityState[addr] = s
    end
    local want = s.base * factor
    s.applied = want
    if near(cur, want) then return false end
    child:SetRenderOpacity(want)
    return true
end

-- Most of the HUD sits inside RetainerBoxes, which render their content to a
-- texture and draw it through an effect material (the tilted, tinted look).
-- "Flat HUD" switches retained rendering off, so the content is drawn
-- normally without that effect; it is restored when Flat HUD is turned off.
-- Only boxes that had it enabled are touched.
local retainerDisabled = {} -- retainer address -> true while we disabled it

local function setRetainers(panel, retain, depth)
    if depth > 4 then return end
    for i = 0, panel:GetChildrenCount() - 1 do
        local c = panel:GetChildAt(i)
        if c and c:IsValid() then
            if c:IsA("/Script/UMG.RetainerBox") then
                local addr = c:GetAddress()
                if retain and retainerDisabled[addr] then
                    c:SetRetainRendering(true)
                    retainerDisabled[addr] = nil
                elseif not retain and not retainerDisabled[addr] then
                    -- bRetainRender is protected; if it cannot be read, assume on.
                    local isOn = true
                    pcall(function() isOn = c.bRetainRender end)
                    if isOn ~= false then
                        c:SetRetainRendering(false)
                        retainerDisabled[addr] = true
                    end
                end
            end
            if c:IsA("/Script/UMG.PanelWidget") then
                local ok, err = pcall(setRetainers, c, retain, depth + 1)
                if not ok then reportOnce("retainer child", err) end
            end
        end
    end
end

-- The game's RetainerBox effect materials (tilt, glitch tint) are "Masked":
-- they discard pixels below a fixed alpha threshold and also shift the colour
-- when their input alpha drops. So the effect box itself must always be drawn
-- at full opacity. To still make the HUD transparent, each effect box is moved
-- into a wrapper RetainerBox of our own WITHOUT an effect material: the effect
-- renders unchanged into the wrapper's texture, and the wrapper draws that
-- texture with normal translucency. Opacity is then applied to the wrapper.
-- Slate also passes a retainer's opacity on to the content it renders into its
-- texture (so it would be applied twice, and the effect would still see it).
-- The effect box inside therefore gets the inverse opacity (1/o): inside the
-- texture it renders at o * 1/o = 100 %, and the wrapper draws it once at o.
-- No references to game objects are kept between scans (the game may destroy
-- them at any time); wrappers are recognised by their structure instead:
-- a RetainerBox without effect material whose content is one with an effect.
local innerBase = {} -- effect box address -> its own opacity before wrapping

local function isObj(o)
    local t = type(o)
    if t ~= "userdata" and t ~= "table" then return false end
    local ok, valid = pcall(function() return o:IsValid() end)
    return ok and valid
end

local function hasEffectMaterial(rb)
    local mat
    pcall(function() mat = rb:GetEffectMaterial() end)
    return isObj(mat)
end

local function wrapRetainer(tree, root, rb)
    local slot = rb.Slot
    if not (isObj(slot) and slot:IsA("/Script/UMG.CanvasPanelSlot")) then return false end
    local anchors, offsets, alignment = slot:GetAnchors(), slot:GetOffsets(), slot:GetAlignment()
    local zorder, autosize = slot:GetZOrder(), slot:GetAutoSize()
    -- Copy the values: the slot is destroyed when the child is moved.
    anchors = { Minimum = { X = anchors.Minimum.X, Y = anchors.Minimum.Y },
                Maximum = { X = anchors.Maximum.X, Y = anchors.Maximum.Y } }
    offsets = { Left = offsets.Left, Top = offsets.Top, Right = offsets.Right, Bottom = offsets.Bottom }
    alignment = { X = alignment.X, Y = alignment.Y }

    -- Give the effect box back the opacity the game set, we now fade the wrapper.
    local addr = rb:GetAddress()
    local st = opacityState[addr]
    local base = st and st.base or rb:GetRenderOpacity()
    rb:SetRenderOpacity(base)
    opacityState[addr] = nil

    local wrap = StaticConstructObject(StaticFindObject("/Script/UMG.RetainerBox"), tree)
    wrap:SetVisibility(4) -- SelfHitTestInvisible: never blocks mouse input
    wrap:SetContent(rb)   -- also removes rb from its current parent
    local ns = root:AddChildToCanvas(wrap)
    ns:SetAnchors(anchors)
    ns:SetOffsets(offsets)
    ns:SetAlignment(alignment)
    ns:SetZOrder(zorder)
    ns:SetAutoSize(autosize)
    innerBase[addr] = base
    log("wrapped " .. rb:GetFName():ToString() .. " for smooth transparency")
    return true
end

local function wrapEffectRetainers(tree, root)
    local todo = {}
    for i = 0, root:GetChildrenCount() - 1 do
        local c = root:GetChildAt(i)
        if isObj(c) and c:IsA("/Script/UMG.RetainerBox") and hasEffectMaterial(c) then
            todo[#todo + 1] = c
        end
    end
    for _, rb in ipairs(todo) do
        local ok, err = pcall(wrapRetainer, tree, root, rb)
        if not ok then reportOnce("wrap retainer", err) end
    end
end

local function setOpacity(w, factor)
    local tree = w.WidgetTree
    local root = tree and tree:IsValid() and tree.RootWidget
    if not (root and root:IsValid() and root:IsA("/Script/UMG.PanelWidget")) then
        return applyOpacity(w, factor)
    end
    -- Wrap lazily, only once the HUD actually becomes transparent.
    if factor < 0.999 and root:IsA("/Script/UMG.CanvasPanel") then
        wrapEffectRetainers(tree, root)
    end
    local ok, err = pcall(setRetainers, root, not (enabled and flat), 0)
    if not ok then reportOnce("retainer", err) end
    local changed = false
    for i = 0, root:GetChildrenCount() - 1 do
        local child = root:GetChildAt(i)
        if child and child:IsValid() and not opacityExclude[child:GetFName():ToString()] then
            changed = applyOpacity(child, factor) or changed
        end
    end
    -- Compensate inside the wrappers (only while they render to a texture;
    -- with Flat HUD retained rendering is off and opacity is applied once).
    local retained = not (enabled and flat)
    for i = 0, root:GetChildrenCount() - 1 do
        local child = root:GetChildAt(i)
        if isObj(child) and child:IsA("/Script/UMG.RetainerBox") and not hasEffectMaterial(child)
            and child:GetChildrenCount() > 0 then
            local inner = child:GetChildAt(0)
            if isObj(inner) and inner:IsA("/Script/UMG.RetainerBox") and hasEffectMaterial(inner) then
                local base = innerBase[inner:GetAddress()] or 1.0
                local want = base
                if retained and factor > 0.001 then want = base / factor end
                if not near(inner:GetRenderOpacity(), want) then
                    inner:SetRenderOpacity(want)
                    changed = true
                end
            end
        end
    end
    return changed
end

-- Exposure and bloom are applied to the post-process settings of the camera
-- components. Camera post-process settings are blended on top of all level
-- volumes, so they win everywhere. The camera's blend weight is never changed. Only the two "override" flags we need are
-- touched; the game's own values are remembered and restored at 0 EV / 100 %.
local DEFAULT_BLOOM = 0.675 -- engine default BloomIntensity
local camState = {} -- camera address -> remembered game values

local function levelBloom()
    -- Bloom the level volumes would give: highest-priority unbound volume
    -- that overrides it, else the engine default.
    local best, bestPrio = nil, -math.huge
    for _, v in ipairs(FindAllOf("PostProcessVolume") or {}) do
        pcall(function()
            if v:IsValid() and v.bEnabled ~= false and v.bUnbound and v.Settings.bOverride_BloomIntensity
                and v.Priority > bestPrio then
                best, bestPrio = v.Settings.BloomIntensity, v.Priority
            end
        end)
    end
    return best or DEFAULT_BLOOM
end

local function applyImageTo(cam, ev, bl)
    -- Cameras with blend weight 0 (e.g. the main menu camera) ignore their
    -- post-process settings on purpose; raising the weight would also switch
    -- on all their other dormant settings (depth of field etc.). Skip them.
    if cam.PostProcessBlendWeight < 0.001 then return end
    local pp = cam.PostProcessSettings
    local addr = cam:GetAddress()
    local st = camState[addr]
    if not st then
        st = {
            biasOverride = pp.bOverride_AutoExposureBias, bias = pp.AutoExposureBias,
            bloomOverride = pp.bOverride_BloomIntensity, bloom = pp.BloomIntensity,
        }
        if not st.bloomOverride then st.bloom = levelBloom() end
        camState[addr] = st
    end
    -- Exposure
    if not near(ev, 0) then
        local base = st.biasOverride and st.bias or 0
        if not pp.bOverride_AutoExposureBias then pp.bOverride_AutoExposureBias = true end
        if not near(pp.AutoExposureBias, base + ev) then pp.AutoExposureBias = base + ev end
    elseif pp.bOverride_AutoExposureBias ~= st.biasOverride or not near(pp.AutoExposureBias, st.bias) then
        pp.bOverride_AutoExposureBias = st.biasOverride
        pp.AutoExposureBias = st.bias
    end
    -- Bloom
    if not near(bl, 1) then
        if not pp.bOverride_BloomIntensity then pp.bOverride_BloomIntensity = true end
        if not near(pp.BloomIntensity, st.bloom * bl) then pp.BloomIntensity = st.bloom * bl end
    elseif pp.bOverride_BloomIntensity ~= st.bloomOverride then
        pp.bOverride_BloomIntensity = st.bloomOverride
        if st.bloomOverride then pp.BloomIntensity = st.bloom end
    end
end

local function applyImage()
    if cfg.ImageSettings == false then return end
    local ev = enabled and exposure or 0
    local bl = enabled and bloom or 1
    for _, cam in ipairs(FindAllOf("CameraComponent") or {}) do
        local ok, err = pcall(function()
            if cam:IsValid() then applyImageTo(cam, ev, bl) end
        end)
        if not ok then reportOnce("image", err) end
    end
end

-- Applies the current anchors and opacity to all configured HUD widgets.
local function scan()
    local left = leftAnchor(getScreenAspect())
    local factor = enabled and opacity or 1.0
    for _, cls in ipairs(cfg.Widgets or {}) do
        local list = FindAllOf(cls)
        if list then
            for _, w in ipairs(list) do
                local ok, changed = pcall(function()
                    return w:IsValid() and setHorizontal(w, left)
                end)
                if not ok then
                    reportOnce("apply " .. cls, changed)
                elseif changed and cfg.Diagnostics then
                    log(string.format("%s -> anchors X %.3f .. %.3f", cls, left, 1 - left))
                end
                local okO, errO = pcall(function()
                    if w:IsValid() then setOpacity(w, factor) end
                end)
                if not okO then reportOnce("opacity " .. cls, errO) end
            end
        end
    end
    applyImage()
end

local function rescan(what)
    local ok, err = pcall(scan)
    if not ok then reportOnce(what, err) end
end

-- Periodic scan: catches HUD widgets that are recreated (new mission, respawn,
-- resolution change). Game objects must only be touched on the game thread.
gameLoop(cfg.ScanIntervalMs or 1000, "loop", scan)

-- Binds fn to a key; an empty key name leaves the function unbound.
local function bind(keyName, fn)
    if type(keyName) ~= "string" or keyName == "" then return end
    local k = Key[keyName]
    if k then
        RegisterKeyBind(k, function() ExecuteInGameThread(fn) end)
    else
        log("unknown key name in config: " .. keyName)
    end
end

-- Changes the target aspect by delta, clamped between MinAspect and the screen.
local function adjust(delta)
    local screen = getScreenAspect()
    local maxAspect = screen or 10
    local cur = effectiveTarget(screen)
    local new = math.max(cfg.MinAspect or 1.0, math.min(maxAspect, cur + delta))
    if near(new, cur) then return end
    target = new
    enabled = true
    save()
    log(string.format("target %.2f -> HUD uses %.0f %% of the screen width", target,
        100 * (screen and math.min(1, target / screen) or 1)))
    rescan("adjust")
end

bind(cfg.NarrowerKey, function() adjust(-(cfg.Step or 0.1)) end)
bind(cfg.WiderKey,    function() adjust(cfg.Step or 0.1) end)

-- Changes the HUD opacity by delta, clamped between MinOpacity and 1.
local function adjustOpacity(delta)
    local new = clampOpacity(opacity + delta)
    if near(new, opacity) then return end
    opacity = new
    enabled = true
    saveOpacity()
    log(string.format("opacity %.0f %%", opacity * 100))
    rescan("opacity")
end

bind(cfg.MoreTransparentKey, function() adjustOpacity(-(cfg.OpacityStep or 0.1)) end)
bind(cfg.LessTransparentKey, function() adjustOpacity(cfg.OpacityStep or 0.1) end)

bind(cfg.ToggleKey, function()
    enabled = not enabled
    log(enabled and "on" or "off")
    rescan("toggle")
end)

-- Reset: discard the in-game adjusted values, back to the defaults.
bind(cfg.ResetKey, function()
    target = nil
    opacity = clampOpacity(cfg.Opacity or 1.0)
    flat = cfg.FlatHUD == true
    exposure = cfg.Exposure or 0.0
    bloom = cfg.Bloom or 1.0
    enabled = true
    os.remove(SAVE_FILE)
    os.remove(OPACITY_FILE)
    os.remove(FLAT_FILE)
    os.remove(IMAGE_FILE)
    log(string.format("reset to target %.2f, opacity %.0f %%", effectiveTarget(getScreenAspect()), opacity * 100))
    rescan("reset")
end)

-- Dump: write the full widget tree of all viewport widgets to UE4SS.log.
-- Useful to find the right class names when the game's HUD changes.
local function className(w)
    return w:GetClass():GetFName():ToString()
end

local function slotInfo(w)
    local info = ""
    pcall(function()
        local s = w.Slot
        if not (s and s:IsValid()) then return end
        local cls = s:GetClass():GetFName():ToString()
        info = " slot=" .. cls
        if cls == "CanvasPanelSlot" then
            local a, o = s:GetAnchors(), s:GetOffsets()
            info = info .. string.format(" anchors=%.2f,%.2f-%.2f,%.2f offs=%.0f,%.0f,%.0f,%.0f",
                a.Minimum.X, a.Minimum.Y, a.Maximum.X, a.Maximum.Y, o.Left, o.Top, o.Right, o.Bottom)
        end
    end)
    return info
end

local dumpLines
local function walk(w, depth)
    if dumpLines > 2500 or depth > 16 or not (w and w:IsValid()) then return end
    dumpLines = dumpLines + 1
    local visible = true
    pcall(function() visible = w:IsVisible() end)
    log(string.format("%s%s '%s'%s%s", string.rep("  ", depth + 1), className(w),
        w:GetFName():ToString(), visible and "" or " [hidden]", slotInfo(w)))
    if not visible then return end
    if w:IsA("/Script/UMG.UserWidget") then
        local tree = w.WidgetTree
        if tree and tree:IsValid() then walk(tree.RootWidget, depth + 1) end
    elseif w:IsA("/Script/UMG.PanelWidget") then
        local n = w:GetChildrenCount()
        for i = 0, n - 1 do walk(w:GetChildAt(i), depth + 1) end
    elseif w:IsA("/Script/CommonUI.CommonActivatableWidgetContainerBase") then
        -- CommonUI stacks (e.g. the game's MenuStack) are no panels: show the active entry.
        local active
        pcall(function() active = w:GetActiveWidget() end)
        if isObj(active) then walk(active, depth + 1) end
    end
end

local function dumpTree()
    log(string.format("--- widget tree (screen aspect %s) ---", tostring(getScreenAspect())))
    dumpLines = 0
    for _, w in ipairs(FindAllOf("UserWidget") or {}) do
        local ok, err = pcall(function()
            if w:IsValid() and w:IsInViewport() then walk(w, 0) end
        end)
        if not ok then log("dump error: " .. tostring(err)) end
    end
    log("--- end of widget tree ---")
end

bind(cfg.DumpKey, dumpTree)

---------------------------------------------------------------------------
-- Game menus (inventory etc.)
-- The game shows its menus in a CommonUI stack ("MenuStack") inside the root
-- widget. When the active menu matches CenteredMenus, the whole stack is
-- moved into the same centered area as the HUD; for every other menu it
-- stays full width.
---------------------------------------------------------------------------
local logMenus = false   -- menu option: dump each newly opened game menu
local seenMenus = {}
local lastActiveAddr = nil

local centeredMenus = {}
for _, m in ipairs(cfg.CenteredMenus or {}) do centeredMenus[#centeredMenus + 1] = string.lower(m) end

local function menuMatches(name)
    local n = string.lower(name)
    for _, m in ipairs(centeredMenus) do
        if n:find(m, 1, true) then return true end
    end
    return false
end

local function findByName(w, name, depth)
    if depth > 8 or not isObj(w) then return nil end
    if w:GetFName():ToString() == name then return w end
    if w:IsA("/Script/UMG.PanelWidget") then
        for i = 0, w:GetChildrenCount() - 1 do
            local found = findByName(w:GetChildAt(i), name, depth + 1)
            if found then return found end
        end
    end
    return nil
end

local function findMenuStack()
    local name = cfg.MenuStackName or "MenuStack"
    for _, host in ipairs(FindAllOf(cfg.MenuHost or "VB_RootPlayerWidget_C") or {}) do
        if isObj(host) and host:IsInViewport() then
            local stack
            pcall(function() stack = host[name] end)
            if not isObj(stack) then
                local tree = host.WidgetTree
                if isObj(tree) then stack = findByName(tree.RootWidget, name, 0) end
            end
            if isObj(stack) then return stack end
        end
    end
    return nil
end

local function updateMenuStack()
    local stack = findMenuStack()
    if not stack then return end
    local active
    pcall(function() active = stack:GetActiveWidget() end)
    local name = isObj(active) and className(active) or nil
    local addr = name and active:GetAddress() or nil
    if name and not seenMenus[name] then
        seenMenus[name] = true
        log("game menu opened: " .. name .. (menuMatches(name) and "  [centered]" or ""))
    end
    if logMenus and addr and addr ~= lastActiveAddr then
        log("--- game menu tree: " .. name .. " ---")
        dumpLines = 0
        walk(active, 0)
        log("--- end of game menu tree ---")
    end
    lastActiveAddr = addr
    local left = (name and menuMatches(name)) and leftAnchor(getScreenAspect()) or 0
    setHorizontal(stack, left)
end

gameLoop(cfg.MenuWatchMs or 100, "menu stack", updateMenuStack)

---------------------------------------------------------------------------
-- In-game settings menu
-- Built at runtime from plain UMG widgets (Border, VerticalBox, TextBlock,
-- Slider, CheckBox, Button) and added to the game's root canvas
-- (VB_RootPlayerWidget_C), so it is not affected by our own centering/opacity.
-- UMG delegates (OnValueChanged, OnClicked) cannot be bound from Lua, so the
-- widgets are polled while the menu is open.
---------------------------------------------------------------------------
local menu = nil        -- table with the menu widgets, nil if not built
local menuOpen = false
local menuPoll = {}     -- last seen values while open

local VIS_VISIBLE, VIS_COLLAPSED = 0, 1

local function uclass(name)
    local c = StaticFindObject("/Script/UMG." .. name)
    assert(c and c:IsValid(), "UMG class not found: " .. name)
    return c
end

local function findRootCanvas()
    for _, r in ipairs(FindAllOf(cfg.MenuHost or "VB_RootPlayerWidget_C") or {}) do
        if r:IsValid() and r:IsInViewport() then
            local tree = r.WidgetTree
            local root = tree and tree:IsValid() and tree.RootWidget
            if root and root:IsValid() and root:IsA("/Script/UMG.CanvasPanel") then
                return r, tree, root
            end
        end
    end
end

-- Our menu widgets live inside the game's root widget. Before touching any of
-- them, make sure that very root widget still exists (looked up fresh by
-- address), otherwise the cached references may point to freed memory.
local function menuValid()
    if not menu then return false end
    local alive = false
    for _, h in ipairs(FindAllOf(cfg.MenuHost or "VB_RootPlayerWidget_C") or {}) do
        if isObj(h) and h:GetAddress() == menu.hostAddr then alive = true break end
    end
    if not alive then return false end
    local ok, valid = pcall(function()
        return menu.border:IsValid() and menu.canvas:IsValid() and menu.host:IsInViewport()
    end)
    return ok and valid
end

local function buildMenu()
    local host, tree, canvas = findRootCanvas()
    if not host then return nil, "HUD root widget not found (open the menu in a mission)" end
    local function new(cls) return StaticConstructObject(uclass(cls), tree) end
    local function text(str, size)
        local t = new("TextBlock")
        t:SetText(FText(str))
        pcall(function()
            local font = t.Font
            font.Size = size or 16
            t:SetFont(font)
        end)
        return t
    end
    local function pad(slot, l, t, r, b)
        pcall(function() slot:SetPadding({ Left = l, Top = t, Right = r, Bottom = b }) end)
    end
    local function slider(minV, maxV)
        local s = new("Slider")
        s:SetMinValue(minV)
        s:SetMaxValue(maxV)
        s:SetStepSize(0.01)
        pcall(function() s:SetSliderBarColor({ R = 0.35, G = 0.35, B = 0.4, A = 1 }) end)
        pcall(function() s:SetSliderHandleColor({ R = 1, G = 1, B = 1, A = 1 }) end)
        local box = new("SizeBox")
        box:SetWidthOverride(cfg.MenuWidth or 420)
        box:SetHeightOverride(28)
        box:SetContent(s)
        return s, box
    end
    local function button(label)
        local b = new("Button")
        -- The default engine button brush is white, like the default text:
        -- tint the brush dark so the label stays readable.
        pcall(function() b:SetBackgroundColor({ R = 0.12, G = 0.13, B = 0.16, A = 1 }) end)
        b:SetContent(text(label, 14))
        return b
    end

    local m = { host = host, hostAddr = host:GetAddress(), canvas = canvas }
    m.border = new("Border")
    pcall(function() m.border:SetBrushColor({ R = 0.02, G = 0.02, B = 0.03, A = 0.88 }) end)
    pcall(function() m.border:SetPadding({ Left = 24, Top = 18, Right = 24, Bottom = 18 }) end)
    local vbox = new("VerticalBox")
    m.border:SetContent(vbox)

    local function row(w, top) pad(vbox:AddChildToVerticalBox(w), 0, top or 0, 0, 0) end

    row(text("Ultrawide HUD & Display Tweaks", 20))
    row(text("HUD", 18), 14)
    m.enabled = new("CheckBox")
    m.enabled:SetContent(text("  Mod enabled", 15))
    row(m.enabled, 14)

    m.widthLabel = text("", 15)
    row(m.widthLabel, 14)
    local minWidth = 0.2
    local screen = getScreenAspect()
    if screen then minWidth = math.min(1, (cfg.MinAspect or 1.0) / screen) end
    local widthBox
    m.width, widthBox = slider(minWidth, 1.0)
    row(widthBox, 4)

    m.opacityLabel = text("", 15)
    row(m.opacityLabel, 14)
    local opacityBox
    m.opacity, opacityBox = slider(cfg.MinOpacity or 0.1, 1.0)
    row(opacityBox, 4)

    m.flat = new("CheckBox")
    m.flat:SetContent(text("  Flat HUD (no tilt / tint)", 15))
    row(m.flat, 14)

    if cfg.ImageSettings ~= false then
        row(text("Image", 18), 22)
        m.exposureLabel = text("", 15)
        row(m.exposureLabel, 10)
        local exposureBox
        m.exposure, exposureBox = slider(cfg.ExposureMin or -4.0, cfg.ExposureMax or 2.0)
        row(exposureBox, 4)
        m.bloomLabel = text("", 15)
        row(m.bloomLabel, 14)
        local bloomBox
        m.bloom, bloomBox = slider(0.0, cfg.BloomMax or 1.5)
        row(bloomBox, 4)
    end

    local buttons = new("HorizontalBox")
    m.logMenus = new("CheckBox")
    m.logMenus:SetContent(text("  Log opened game menus (troubleshooting)", 13))
    row(m.logMenus, 22)

    m.reset = button("  Reset  ")
    m.dump = button("  Dump widget tree  ")
    m.close = button("  Close  ")
    pad(buttons:AddChildToHorizontalBox(m.reset), 0, 0, 12, 0)
    pad(buttons:AddChildToHorizontalBox(m.dump), 0, 0, 12, 0)
    buttons:AddChildToHorizontalBox(m.close)
    row(buttons, 18)
    m.buttons = { reset = false, dump = false, close = false }

    local cs = canvas:AddChildToCanvas(m.border)
    cs:SetAnchors({ Minimum = { X = 0.5, Y = 0.5 }, Maximum = { X = 0.5, Y = 0.5 } })
    cs:SetAlignment({ X = 0.5, Y = 0.5 })
    cs:SetPosition({ X = 0, Y = 0 })
    cs:SetAutoSize(true)
    cs:SetZOrder(10000)
    return m
end

local function currentWidth()
    local screen = getScreenAspect()
    return screen and math.min(1, effectiveTarget(screen) / screen) or 1
end

local function updateLabels()
    menu.widthLabel:SetText(FText(string.format("HUD width: %.0f %% of the screen", currentWidth() * 100)))
    menu.opacityLabel:SetText(FText(string.format("HUD opacity: %.0f %%", opacity * 100)))
    if menu.exposure then
        menu.exposureLabel:SetText(FText(string.format("Exposure: %+.2f EV", exposure)))
        menu.bloomLabel:SetText(FText(string.format("Bloom: %.0f %%", bloom * 100)))
    end
end

local function syncMenuFromState()
    menu.enabled:SetIsChecked(enabled)
    menu.flat:SetIsChecked(flat)
    menu.logMenus:SetIsChecked(logMenus)
    menu.width:SetValue(currentWidth())
    menu.opacity:SetValue(opacity)
    menuPoll = { enabled = enabled, flat = flat, width = menu.width:GetValue(), opacity = menu.opacity:GetValue() }
    if menu.exposure then
        menu.exposure:SetValue(exposure)
        menu.bloom:SetValue(bloom)
        menuPoll.exposure = menu.exposure:GetValue()
        menuPoll.bloom = menu.bloom:GetValue()
    end
    updateLabels()
end

local widgetLib
local function setInputForMenu(open)
    local pc = FindFirstOf("PlayerController")
    if not (pc and pc:IsValid()) then return end
    widgetLib = widgetLib or StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    pc.bShowMouseCursor = open
    if open then
        widgetLib:SetInputMode_UIOnlyEx(pc, menu.border, 0, false)
    else
        widgetLib:SetInputMode_GameOnly(pc, false)
    end
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    if menuValid() then
        pcall(function() menu.border:SetVisibility(VIS_COLLAPSED) end)
    else
        menu = nil
    end
    local ok, err = pcall(setInputForMenu, false)
    if not ok then reportOnce("menu input close", err) end
    save()
    saveOpacity()
    saveFlat()
    saveImage()
end

-- One-time diagnostic: log the HUD RetainerBoxes and their effect materials
-- (parameters, blend mode, opacity mask clip value) to UE4SS.log. Needed to
-- make transparency work together with the tilted effect.
local retainerInfoLogged = false

local function isObject(o)
    if type(o) ~= "userdata" then return false end
    local ok, valid = pcall(function() return o:IsValid() end)
    return ok and valid
end

local function logMaterial(mat, indent, depth)
    if depth > 4 or not isObject(mat) then return end
    log(indent .. mat:GetFullName())
    for _, prop in ipairs({ "ScalarParameterValues", "VectorParameterValues", "TextureParameterValues" }) do
        local ok, err = pcall(function()
            local arr = mat[prop]
            if not arr then return end
            arr:ForEach(function(_, e)
                local v = e:get()
                local val = v.ParameterValue
                local str
                if type(val) == "number" then
                    str = string.format("%.4f", val)
                elseif prop == "VectorParameterValues" then
                    str = string.format("(%.3f, %.3f, %.3f, %.3f)", val.R, val.G, val.B, val.A)
                else
                    str = (val and val:IsValid()) and val:GetFullName() or "nil"
                end
                log(string.format("%s  %s %s = %s", indent, prop:gsub("ParameterValues", ""),
                    v.ParameterInfo.Name:ToString(), str))
            end)
        end)
        if not ok then log(indent .. "  (" .. prop .. " not readable: " .. tostring(err) .. ")") end
    end
    pcall(function()
        log(string.format("%s  BlendMode=%s OpacityMaskClipValue=%s Domain=%s", indent,
            tostring(mat.BlendMode), tostring(mat.OpacityMaskClipValue), tostring(mat.MaterialDomain)))
    end)
    pcall(function()
        local o = mat.BasePropertyOverrides
        log(string.format("%s  overrides: clip=%s (override %s) blend=%s (override %s)", indent,
            tostring(o.OpacityMaskClipValue), tostring(o.bOverride_OpacityMaskClipValue),
            tostring(o.BlendMode), tostring(o.bOverride_BlendMode)))
    end)
    local parent
    pcall(function() parent = mat.Parent end)
    if isObject(parent) then logMaterial(parent, indent .. "  ", depth + 1) end
end

local function logRetainers(panel, depth)
    if depth > 4 then return end
    for i = 0, panel:GetChildrenCount() - 1 do
        local c = panel:GetChildAt(i)
        if c and c:IsValid() then
            if c:IsA("/Script/UMG.RetainerBox") then
                local info = {}
                for _, k in ipairs({ "bRetainRender", "Phase", "PhaseCount", "RenderOnInvalidation", "RenderOnPhase" }) do
                    pcall(function() info[#info + 1] = k .. "=" .. tostring(c[k]) end)
                end
                pcall(function() info[#info + 1] = "TextureParameter=" .. c.TextureParameter:ToString() end)
                log(string.format("RetainerBox '%s' %s", c:GetFName():ToString(), table.concat(info, " ")))
                local mat
                pcall(function() mat = c:GetEffectMaterial() end)
                if not isObject(mat) then pcall(function() mat = c.EffectMaterial end) end
                if isObject(mat) then logMaterial(mat, "    ", 0) else log("    (no effect material)") end
            end
            if c:IsA("/Script/UMG.PanelWidget") then logRetainers(c, depth + 1) end
        end
    end
end

local function logRetainerInfo()
    if retainerInfoLogged then return end
    retainerInfoLogged = true
    log("--- RetainerBox diagnostics ---")
    for _, cls in ipairs(cfg.Widgets or {}) do
        for _, w in ipairs(FindAllOf(cls) or {}) do
            local ok, err = pcall(function()
                local tree = w.WidgetTree
                local root = tree and tree:IsValid() and tree.RootWidget
                if root and root:IsValid() and root:IsA("/Script/UMG.PanelWidget") then
                    log("in " .. cls .. ":")
                    logRetainers(root, 0)
                end
            end)
            if not ok then log("diagnostics error: " .. tostring(err)) end
        end
    end
    log("--- end RetainerBox diagnostics ---")
end

local function openMenu()
    if menuOpen then return end
    if cfg.LogRetainerInfo ~= false then pcall(logRetainerInfo) end
    -- Do not open on top of a game menu (its mouse cursor is already shown),
    -- because closing ours would switch the game back to gameplay input.
    local pc = FindFirstOf("PlayerController")
    if pc and pc:IsValid() and pc.bShowMouseCursor then
        log("menu not opened: a game menu is open")
        return
    end
    if not menuValid() then
        local ok, m = pcall(buildMenu)
        if not ok or not m then
            reportOnce("menu build", m)
            return
        end
        menu = m
    end
    syncMenuFromState()
    menu.border:SetVisibility(VIS_VISIBLE)
    menuOpen = true
    local ok, err = pcall(setInputForMenu, true)
    if not ok then reportOnce("menu input open", err) end
end

-- Returns true once per click (pressed -> released while hovered).
local function clicked(name)
    local b = menu[name]
    local pressed = b:IsPressed()
    local was = menu.buttons[name]
    menu.buttons[name] = pressed
    return was and not pressed and b:IsHovered()
end

local function pollMenu()
    if not menuOpen then return end
    if not menuValid() then
        -- Root widget was recreated (level change): drop the menu.
        menuOpen = false
        menu = nil
        pcall(setInputForMenu, false)
        return
    end
    local changed = false
    local en = menu.enabled:IsChecked()
    if en ~= menuPoll.enabled then
        menuPoll.enabled = en
        enabled = en
        changed = true
    end
    if menu.exposure then
        local ev = menu.exposure:GetValue()
        if not near(ev, menuPoll.exposure) then
            menuPoll.exposure = ev
            exposure = math.floor(ev * 20 + 0.5) / 20 -- 0.05 EV steps
            changed = true
        end
        local bl = menu.bloom:GetValue()
        if not near(bl, menuPoll.bloom) then
            menuPoll.bloom = bl
            bloom = bl
            changed = true
        end
    end
    local fl = menu.flat:IsChecked()
    if fl ~= menuPoll.flat then
        menuPoll.flat = fl
        flat = fl
        changed = true
    end
    local w = menu.width:GetValue()
    if not near(w, menuPoll.width) then
        menuPoll.width = w
        local screen = getScreenAspect()
        if screen then target = w * screen end
        changed = true
    end
    local o = menu.opacity:GetValue()
    if not near(o, menuPoll.opacity) then
        menuPoll.opacity = o
        opacity = clampOpacity(o)
        changed = true
    end
    if clicked("reset") then
        target = nil
        opacity = clampOpacity(cfg.Opacity or 1.0)
        flat = cfg.FlatHUD == true
        exposure = cfg.Exposure or 0.0
        bloom = cfg.Bloom or 1.0
        enabled = true
        syncMenuFromState()
        changed = true
    end
    if changed then
        updateLabels()
        rescan("menu")
    end
    local lm = menu.logMenus:IsChecked()
    if lm ~= logMenus then
        logMenus = lm
        lastActiveAddr = nil
        log(logMenus and "logging opened game menus" or "stopped logging game menus")
    end
    if clicked("dump") then dumpTree() end
    if clicked("close") then closeMenu() end
end

gameLoop(cfg.MenuPollMs or 30, "menu poll", function()
    if menuOpen then pollMenu() end
end)

bind(cfg.MenuKey, function()
    if menuOpen then closeMenu() else openMenu() end
end)

-- Escape closes the menu (only while it is open; otherwise the key is ignored).
if Key.ESCAPE then
    RegisterKeyBind(Key.ESCAPE, function()
        if menuOpen then ExecuteInGameThread(closeMenu) end
    end)
end

log(string.format("loaded: saved target %s, screen %s, widgets %s",
    tostring(target), (cfg.ScreenAspect or 0) > 0 and tostring(cfg.ScreenAspect) or "auto",
    table.concat(cfg.Widgets or {}, ", ")))
log("settings folder: " .. MOD_DIR)
