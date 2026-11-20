-- Ally Name Colors: colors the names on friendly player nameplates by who the
-- player is to you (party, raid, friend, guild, everyone else).
--
-- Name Only mode: it paints Blizzard's own name FontString (UnitFrame.name),
-- the one EllesmereUI writes its "60 | Name" text into, with SetTextColor. It
-- never changes the text, so Ellesmere's composition (level in its difficulty
-- color, title, guild line, brackets) stays as Ellesmere built it. An inline
-- color code outranks SetTextColor, so Ellesmere's friendly Name Color must be
-- Class, not Custom (Custom wraps the name in one).
--
-- Health bar mode: Ellesmere hides Blizzard's frame and draws a plate of its
-- own, so the name painted there is Ellesmere's plate.name (see "EllesmereUI
-- bar plates" below). Ellesmere colors that one with SetTextColor in both Name
-- Color settings, so Custom doesn't get in the way there.
--
-- Settings: a page of its own in the EllesmereUI panel (Plugin API), opened
-- with /allycolors.

local ADDON = ...

local DEFAULTS = {
    party  = { on = true, r = 0.667, g = 0.667, b = 1.000 },   -- party chat blue
    raid   = { on = true, r = 1.000, g = 0.498, b = 0.000 },   -- raid chat orange
    friend = { on = true, r = 1.000, g = 0.502, b = 1.000 },   -- whisper pink
    guild  = { on = true, r = 0.251, g = 1.000, b = 0.251 },   -- guild chat green
    -- Everyone else: the light gray EllesmereUI's Custom Name Color had here.
    others = { class = false, r = 0.857, g = 0.857, b = 0.857 },
}
-- Precedence: the first group a player is in (and that is on) wins.
local ORDER = { "party", "raid", "friend", "guild" }

local db = DEFAULTS   -- the saved table from ADDON_LOADED on

local issecretvalue = issecretvalue or function() return false end
-- True only for a plain truthy value; a secret one is never truth-tested.
local function Yes(v) return not issecretvalue(v) and v and true or false end

local function Chat(msg)
    print("|cff0cd29fAlly Name Colors:|r " .. msg)
end

-------------------------------------------------------------------------------
--  Who a player is to you
-------------------------------------------------------------------------------
local function PlainGUID(unit)
    local guid = UnitGUID(unit)
    if issecretvalue(guid) or type(guid) ~= "string" then return nil end
    return guid
end

local Is = {}
-- Party: your party, or your own subgroup in a raid.
function Is.party(unit)
    if IsInRaid() then
        return UnitInSubgroup ~= nil and Yes(UnitInSubgroup(unit))
    end
    return Yes(UnitInParty(unit))
end
-- Raid: anyone in your raid (your own subgroup lands here when Party is off).
-- The raid index can read secret; only its type is asked.
function Is.raid(unit)
    return IsInRaid() and type(UnitInRaid(unit)) == "number"
end
-- Friend: a WoW friend, or a character of a Battle.net friend.
function Is.friend(unit)
    local guid = PlainGUID(unit)
    if not guid then return false end
    if C_FriendList and C_FriendList.IsFriend and Yes(C_FriendList.IsFriend(guid)) then
        return true
    end
    if C_BattleNet and C_BattleNet.GetAccountInfoByGUID then
        local info = C_BattleNet.GetAccountInfoByGUID(guid)
        if type(info) == "table" then
            local f = info.isFriend
            return issecretvalue(f) or f ~= false
        end
    end
    return false
end
function Is.guild(unit)
    return UnitIsInMyGuild ~= nil and Yes(UnitIsInMyGuild(unit))
end

-- r, g, b and the group key ("others" when none applies).
local function ColorFor(unit)
    for _, key in ipairs(ORDER) do
        local c = db[key]
        if c.on then
            local ok, hit = pcall(Is[key], unit)
            if ok and hit then return c.r, c.g, c.b, key end
        end
    end
    local o = db.others
    if o.class then
        local _, tok = UnitClass(unit)
        if not issecretvalue(tok) and type(tok) == "string" then
            local cc = (C_ClassColor and C_ClassColor.GetClassColor(tok))
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[tok])
            if cc then return cc.r, cc.g, cc.b, "others" end
        end
    end
    return o.r, o.g, o.b, "others"
end

-------------------------------------------------------------------------------
--  Plates
--
--  Our own registry from NAME_PLATE_UNIT_ADDED/REMOVED: GetNamePlates() leaves
--  friendly player plates out. Everything we keep per FontString sits in
--  weak-keyed tables of our own, never in fields on Blizzard's widgets.
-------------------------------------------------------------------------------
local unitFS  = {}                                   -- unit token -> name FontString
local fsUnit  = setmetatable({}, { __mode = "k" })   -- name FontString -> unit token
local hooked  = setmetatable({}, { __mode = "k" })   -- FontString -> true (hooks are permanent)
local native  = setmetatable({}, { __mode = "k" })   -- FontString -> { text = {r,g,b,a}, vertex = {r,g,b,a} }
local painting = false

-- The name FontString of a unit's plate, or nil for a missing or forbidden one
-- (friendly plates inside instances are forbidden to addons).
local function NameFS(unit)
    local np = C_NamePlate.GetNamePlateForUnit(unit)
    if not np or np:IsForbidden() then return nil end
    local uf = np.UnitFrame
    if not uf or uf:IsForbidden() then return nil end
    return uf.name
end

-- A player you can't attack who isn't you. A secret answer counts as no.
local function IsAllyPlayer(unit)
    local p = UnitIsPlayer(unit)
    if issecretvalue(p) or not p then return false end
    local me = UnitIsUnit(unit, "player")
    if issecretvalue(me) or me then return false end
    local hostile = UnitCanAttack("player", unit)
    if issecretvalue(hostile) or hostile then return false end
    return true
end

-- Ellesmere's Custom Name Color wraps the name in a color code, which hides
-- ours. Say so once per session.
local warned = false
local function NameHasColorCode(fs)
    local t = fs:GetText()
    if issecretvalue(t) or type(t) ~= "string" then return false end
    local line = t:match("^[^\n]*")
    line = line:gsub("|c%x%x%x%x%x%x%x%x[%[%]]|r$", "")   -- a group bracket after the name
    return line:find("|c%x%x%x%x%x%x%x%x[^|]+|r$") ~= nil
end
local function WarnIfCustom(fs)
    if warned or not NameHasColorCode(fs) then return end
    warned = true
    Chat("EllesmereUI's friendly Name Color is set to Custom, which covers these colors. "
        .. "In the EllesmereUI panel open Nameplates > Friendly and click the Class Color swatch "
        .. "next to Name Color. (Everyone else then takes the color set in /allycolors.)")
end

local function Write(fs, r, g, b)
    -- Vertex color multiplies over the whole string, the level's own color
    -- code included, so it only ever goes to white. Text color goes last: on a
    -- client where the two are one setting, the last write is what shows.
    fs:SetVertexColor(1, 1, 1)
    fs:SetTextColor(r, g, b)
end

local function Restore(fs)
    local n = native[fs]
    if not n or fs:IsForbidden() then return end
    painting = true
    pcall(function()
        fs:SetVertexColor(unpack(n.vertex))
        fs:SetTextColor(unpack(n.text))
    end)
    painting = false
end

local function Release(unit)
    local fs = unitFS[unit]
    unitFS[unit] = nil
    if not fs or fsUnit[fs] ~= unit then return end
    fsUnit[fs] = nil
    Restore(fs)
end

local function Paint(fs)
    if painting then return end
    local unit = fsUnit[fs]
    if not unit then return end
    -- Pooled frames: a plate that moved on without a REMOVED is someone
    -- else's now, so let it go without touching it.
    if NameFS(unit) ~= fs then
        fsUnit[fs] = nil
        if unitFS[unit] == fs then unitFS[unit] = nil end
        return
    end
    -- Turned hostile (a duel, a PvP flag): hand the colors back.
    if not IsAllyPlayer(unit) then Release(unit) return end
    local r, g, b = ColorFor(unit)
    painting = true
    local ok, err = pcall(Write, fs, r, g, b)
    painting = false
    if not ok then geterrorhandler()(err) return end
    WarnIfCustom(fs)
end

-- Blizzard repaints the name on target, soft-target and name updates. Paint
-- ours over it. The arguments are never read: they can be secret class colors.
local function OnColorWrite(fs)
    if not painting and fsUnit[fs] then Paint(fs) end
end

local function Hook(fs)
    if hooked[fs] then return end
    hooked[fs] = true
    -- The colors this FontString had before we ever painted it, to hand back
    -- when the plate goes to someone we don't paint. Only passed to setters.
    native[fs] = { text = { fs:GetTextColor() }, vertex = { fs:GetVertexColor() } }
    hooksecurefunc(fs, "SetTextColor", OnColorWrite)
    hooksecurefunc(fs, "SetVertexColor", OnColorWrite)
    hooksecurefunc(fs, "SetFontObject", OnColorWrite)
end

local function Track(unit)
    if type(unit) ~= "string" or not unit:find("^nameplate%d") then return end
    if unitFS[unit] then Release(unit) end
    local fs = NameFS(unit)
    if not fs then return end
    -- A pooled FontString still mapped to another token: hand it back first.
    local prev = fsUnit[fs]
    if prev then Release(prev) end
    if not IsAllyPlayer(unit) then return end
    Hook(fs)
    unitFS[unit], fsUnit[fs] = fs, unit
    Paint(fs)
end

-- Plates on screen that we don't hold: there at load or after a loading
-- screen, or a player who was hostile and isn't now.
local function ScanPlates()
    for i = 1, 40 do
        local unit = "nameplate" .. i
        local fs = unitFS[unit]
        if not (fs and fsUnit[fs] == unit) and UnitExists(unit) then Track(unit) end
    end
end

-------------------------------------------------------------------------------
--  EllesmereUI bar plates
--
--  With Name Only off, Ellesmere hides Blizzard's frame and draws its own
--  plate from a pool: ns.friendlyPlates[unit], with the name on plate.name and
--  the unit on plate.unit. Its namespace is global as EllesmereNameplates_NS.
--  These are Ellesmere's internals, so when any of it is missing this path
--  stays off and Name Only works as before.
--
--  The plate's unit is read live on every paint, so a pooled plate that moved
--  on to someone else is handled without a release. Ellesmere's color is never
--  put back by us: it repaints the plate itself on every SetUnit, and a plate
--  showing someone we don't color (a friendly NPC) keeps Ellesmere's write.
-------------------------------------------------------------------------------
local barPlate = setmetatable({}, { __mode = "k" })   -- Ellesmere name FontString -> its plate

local function EUI()
    local ns = EllesmereNameplates_NS
    if type(ns) == "table" and type(ns.friendlyPlates) == "table" then return ns end
end

-- The unit an Ellesmere plate shows right now, or nil once it's back in the pool.
local function BarUnit(plate)
    local ns = EUI()
    local unit = plate.unit
    if ns and type(unit) == "string" and ns.friendlyPlates[unit] == plate then return unit end
end

local function PaintBar(fs)
    if painting then return end
    local plate = barPlate[fs]
    local unit = plate and BarUnit(plate)
    if not unit or not IsAllyPlayer(unit) then return end
    local r, g, b = ColorFor(unit)
    painting = true
    -- Ellesmere never touches this string's vertex color, so text color is all.
    local ok, err = pcall(fs.SetTextColor, fs, r, g, b)
    painting = false
    if not ok then geterrorhandler()(err) end
end

-- Ellesmere repaints the name on spawn, color settings and roster changes.
-- As with Blizzard's, the arguments are never read.
local function OnBarColorWrite(fs)
    if not painting then PaintBar(fs) end
end

local function TrackBar(plate)
    local fs = type(plate) == "table" and plate.name
    if type(fs) ~= "table" or type(fs.SetTextColor) ~= "function" then return end
    if not barPlate[fs] then
        barPlate[fs] = plate
        hooksecurefunc(fs, "SetTextColor", OnBarColorWrite)
    end
    PaintBar(fs)
end

local function ScanBarPlates()
    local ns = EUI()
    if not ns then return end
    for _, plate in pairs(ns.friendlyPlates) do TrackBar(plate) end
end

local function RefreshAll()
    for unit, fs in pairs(unitFS) do
        if fsUnit[fs] == unit then Paint(fs) end
    end
    ScanPlates()
    ScanBarPlates()
end

-- Roster, guild and friend events come in bursts: one repaint per burst.
local queued = false
local function QueueRefresh()
    if queued then return end
    queued = true
    C_Timer.After(0.1, function()
        queued = false
        RefreshAll()
    end)
end

-- Ellesmere adds a bar plate through ns.TryAddFriendlyPlate on
-- NAME_PLATE_UNIT_ADDED: hooking it paints the new plate right after
-- Ellesmere's own paint, whichever order the two addons get the event in.
-- Mode switches and zone changes add plates through Ellesmere's local copy,
-- which the hook can't see, but they all run UpdateFriendlyNameplateSystem.
local hookedEUI = false
local function HookEllesmere()
    if hookedEUI then return end
    local ns = EUI()
    if not ns then return end
    hookedEUI = true
    if type(ns.TryAddFriendlyPlate) == "function" then
        hooksecurefunc(ns, "TryAddFriendlyPlate", function(unit)
            local plate = type(unit) == "string" and ns.friendlyPlates[unit]
            if plate then TrackBar(plate) end
        end)
    end
    if type(ns.UpdateFriendlyNameplateSystem) == "function" then
        hooksecurefunc(ns, "UpdateFriendlyNameplateSystem", QueueRefresh)
    end
end
HookEllesmere()   -- the toc's OptionalDeps load Ellesmere first

-------------------------------------------------------------------------------
--  Saved settings
-------------------------------------------------------------------------------
local function FillDefaults(saved)
    for key, def in pairs(DEFAULTS) do
        if type(saved[key]) ~= "table" then saved[key] = {} end
        for k, v in pairs(def) do
            if saved[key][k] == nil then saved[key][k] = v end
        end
    end
    return saved
end

local function ResetSettings()
    AllyNameColorsDB = AllyNameColorsDB or {}
    wipe(AllyNameColorsDB)
    db = FillDefaults(AllyNameColorsDB)
    RefreshAll()
    -- Our page, if it's the one showing, takes the new values.
    local E = EllesmereUI
    local key = E and E.GetPluginModuleKey and E.GetPluginModuleKey(ADDON, "Colors")
    if key and E.GetActiveModule and E:GetActiveModule() == key and E.RefreshPage then
        E:RefreshPage()
    end
end

-------------------------------------------------------------------------------
--  EllesmereUI plugin page
-------------------------------------------------------------------------------
local ROWS = {
    { key = "party",  text = "Party Members", tip = "Your party, or your own group in a raid." },
    { key = "raid",   text = "Raid Members",  tip = "Everyone else in your raid. With Party Members off, your own group too." },
    { key = "friend", text = "Friends",       tip = "Your WoW friends and the characters of your Battle.net friends." },
    { key = "guild",  text = "Guild Members", tip = "Members of your guild." },
}

local function ColorGetter(key)
    return function() local c = db[key]; return c.r, c.g, c.b end
end
local function ColorSetter(key)
    return function(r, g, b)
        local c = db[key]
        c.r, c.g, c.b = r, g, b
        RefreshAll()
    end
end

local function BuildPage(pageName, parent, yOffset)
    local W = EllesmereUI.Widgets
    local y = yOffset
    local _, h = W:SectionHeader(parent, "GROUPS", y); y = y - h
    for _, row in ipairs(ROWS) do
        local key = row.key
        _, h = W:DualRow(parent, y,
            { type = "toggle", text = row.text, tooltip = row.tip,
              getValue = function() return db[key].on end,
              setValue = function(v) db[key].on = v and true or false; RefreshAll() end },
            { type = "colorpicker", text = "Color",
              getValue = ColorGetter(key), setValue = ColorSetter(key) })
        y = y - h
    end
    _, h = W:SectionHeader(parent, "EVERYONE ELSE", y); y = y - h
    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Use Class Color",
          tooltip = "Players in none of the groups above take their class color instead of the color on the right.",
          getValue = function() return db.others.class end,
          setValue = function(v) db.others.class = v and true or false; RefreshAll() end },
        { type = "colorpicker", text = "Color",
          getValue = ColorGetter("others"), setValue = ColorSetter("others") })
    y = y - h
    return math.abs(y)
end

local function RegisterPlugin()
    if not (EllesmereUI and EllesmereUI.RegisterPlugin) then return end
    EllesmereUI.RegisterPlugin(ADDON, {
        label = "Ally Name Colors",
        modules = {
            {
                key = "Colors",
                title = "Name Colors",
                description = "Name colors on friendly player nameplates, with or without the health bar. Someone "
                    .. "in more than one group takes the first one listed. In Name Only mode this needs "
                    .. "Nameplates > Friendly > Name Color set to Class Color.",
                pages = { "Colors" },
                buildPage = BuildPage,
                onReset = ResetSettings,
            },
        },
    })
end
RegisterPlugin()

-------------------------------------------------------------------------------
--  Slash command
-------------------------------------------------------------------------------
local function Check()
    local n = 0
    local ns = EUI()
    -- Bar plates first; a unit that has one hides its Blizzard name, so that
    -- one isn't listed.
    if ns then
        for unit, plate in pairs(ns.friendlyPlates) do
            local fs = type(plate) == "table" and plate.name
            if fs and barPlate[fs] == plate and BarUnit(plate) == unit and IsAllyPlayer(unit) then
                n = n + 1
                local _, _, _, key = ColorFor(unit)
                local tr, tg, tb = fs:GetTextColor()
                local ok, line = pcall(string.format, "%s (bar): %s, text %.2f %.2f %.2f", unit, key, tr, tg, tb)
                Chat(ok and line or (unit .. " (bar): " .. key))
            end
        end
    end
    for unit, fs in pairs(unitFS) do
        if fsUnit[fs] == unit and not (ns and ns.friendlyPlates[unit]) then
            n = n + 1
            local _, _, _, key = ColorFor(unit)
            local tr, tg, tb = fs:GetTextColor()
            local vr, vg, vb = fs:GetVertexColor()
            -- Colors Blizzard wrote can read secret; format refuses those.
            local ok, line = pcall(string.format, "%s: %s, text %.2f %.2f %.2f, vertex %.2f %.2f %.2f%s",
                unit, key, tr, tg, tb, vr, vg, vb,
                NameHasColorCode(fs) and ", name has a color code (Ellesmere Custom)" or "")
            Chat(ok and line or (unit .. ": " .. key))
        end
    end
    Chat(n .. " friendly player plate(s) tracked.")
end

SLASH_ALLYNAMECOLORS1 = "/allycolors"
SLASH_ALLYNAMECOLORS2 = "/anc"
SlashCmdList.ALLYNAMECOLORS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "check" then
        Check()
    elseif msg == "reset" then
        ResetSettings()
        Chat("colors reset to defaults.")
    elseif EllesmereUI and EllesmereUI.OpenPlugin then
        if InCombatLockdown() then Chat("the settings open after combat.") return end
        EllesmereUI.OpenPlugin(ADDON)
    else
        Chat("the settings page needs EllesmereUI. /allycolors check | reset")
    end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
local REFRESH_EVENTS = {
    "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE",
    "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_FRIEND_ACCOUNT_OFFLINE", "BN_CONNECTED",
    "UNIT_FACTION",
}
local refreshOn = {}
for _, ev in ipairs(REFRESH_EVENTS) do
    -- An event this client doesn't have would throw.
    if pcall(f.RegisterEvent, f, ev) then refreshOn[ev] = true end
end

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Track(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Release(arg1)
    elseif event == "ADDON_LOADED" then
        if arg1 == "EllesmereUINameplates" then HookEllesmere() end
        if arg1 == ADDON then
            AllyNameColorsDB = AllyNameColorsDB or {}
            db = FillDefaults(AllyNameColorsDB)
            RefreshAll()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ScanPlates()
        QueueRefresh()
    elseif refreshOn[event] then
        QueueRefresh()
    end
end)
