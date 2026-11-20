-- Minimal WoW API stubs to exercise AllyNameColors.lua under lua5.1.
local path = arg[1]
local unpack = unpack

-- FontString with distinct text/vertex colors and hookable methods.
local function NewFS(name)
    local fs = { _text = name, tc = {1, 0.82, 0, 1}, vc = {1, 1, 1, 1}, _forbidden = false }
    local mt = { __index = {
        SetTextColor = function(self, r, g, b, a) self.tc = { r, g, b, a or 1 } end,
        SetVertexColor = function(self, r, g, b, a) self.vc = { r, g, b, a or 1 } end,
        SetFontObject = function(self) end,
        GetTextColor = function(self) return unpack(self.tc) end,
        GetVertexColor = function(self) return unpack(self.vc) end,
        GetText = function(self) return self._text end,
        IsForbidden = function(self) return self._forbidden end,
    } }
    return setmetatable(fs, mt)
end

function hooksecurefunc(t, method, hook)
    local orig = t[method]
    t[method] = function(...) local r = { orig(...) }; hook(...); return unpack(r) end
end

local units = {}   -- token -> { player, hostile, party, raid, guild, guid, class }
local plates = {}  -- token -> nameplate
local function Plate(fs)
    local uf = { name = fs, IsForbidden = function() return false end }
    return { UnitFrame = uf, IsForbidden = function() return false end }
end
C_NamePlate = { GetNamePlateForUnit = function(u) return plates[u] end }
function UnitIsPlayer(u) return units[u] and units[u].player end
function UnitIsUnit(a, b) return a == b end
function UnitCanAttack(_, u) return units[u] and units[u].hostile end
function UnitExists(u) return units[u] ~= nil end
local inRaid = false
function IsInRaid() return inRaid end
function UnitInParty(u) return units[u] and units[u].party end
function UnitInSubgroup(u) return units[u] and units[u].party end
function UnitInRaid(u) return units[u] and units[u].raid and 5 or nil end
function UnitIsInMyGuild(u) return units[u] and units[u].guild end
function UnitGUID(u) return units[u] and units[u].guid end
function UnitClass(u) return "Warrior", units[u] and units[u].class end
C_FriendList = { IsFriend = function(g) return g == "Player-friend" end }
C_BattleNet = { GetAccountInfoByGUID = function(g) if g == "Player-bnet" then return { isFriend = true } end end }
C_ClassColor = { GetClassColor = function(tok) if tok == "WARRIOR" then return { r = 0.78, g = 0.61, b = 0.43 } end end }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
function InCombatLockdown() return false end
function geterrorhandler() return function(e) error(e) end end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
SlashCmdList = {}
local printed = {}
function print(...) local s = table.concat({ ... }, " "); printed[#printed + 1] = s; io.write("  chat: ", s, "\n") end

local frame
function CreateFrame()
    frame = { events = {} }
    function frame:RegisterEvent(ev) if ev == "UNIT_FACTION_BOGUS" then error("unknown") end self.events[ev] = true end
    function frame:SetScript(_, fn) self.onEvent = fn end
    return frame
end

-- EllesmereUI plugin API stub that runs buildPage with a recording widget factory.
local registered
EllesmereUI = {
    RegisterPlugin = function(id, spec) registered = { id = id, spec = spec }; return true end,
    OpenPlugin = function(id) print("OpenPlugin " .. id) return true end,
}

-- EllesmereUI Nameplates stub: health bar mode's pooled friendly plates. Like
-- the real SetUnit, the plate takes its unit before Ellesmere paints the name
-- (class orange for players, NPC green for NPCs).
local CLASS = { 1, 0.49, 0.04 }
local NPCGREEN = { 0, 1, 0 }
local barPlates, barPool = {}, {}
EllesmereNameplates_NS = { friendlyPlates = barPlates }
local ENS = EllesmereNameplates_NS
local function BarSetUnit(plate, unit)
    plate.unit = unit
    plate.name:SetTextColor(unpack(units[unit].player and CLASS or NPCGREEN))
end
function ENS.TryAddFriendlyPlate(unit)
    local u = units[unit]
    if not u or u.hostile or barPlates[unit] then return end
    local plate = table.remove(barPool) or { name = NewFS("") }
    barPlates[unit] = plate
    BarSetUnit(plate, unit)
end
function ENS.RemoveFriendlyPlate(unit)
    local plate = barPlates[unit]
    if not plate then return end
    plate.unit = nil
    barPlates[unit] = nil
    barPool[#barPool + 1] = plate
end
local systemRuns = 0
function ENS.UpdateFriendlyNameplateSystem() systemRuns = systemRuns + 1 end
-- Ellesmere's own repaint of every live plate (a color setting changed).
local function RefreshFriendlyColors()
    for unit, plate in pairs(barPlates) do BarSetUnit(plate, unit) end
end

assert(loadfile(path))("AllyNameColors")
local function Fire(ev, ...) frame.onEvent(frame, ev, ...) end
Fire("ADDON_LOADED", "AllyNameColors")
assert(AllyNameColorsDB.party.on == true, "defaults filled")

local function Add(token, info, text)
    units[token] = info
    local fs = NewFS(text or "Bob")
    plates[token] = Plate(fs)
    Fire("NAME_PLATE_UNIT_ADDED", token)
    return fs
end
local function near(c, r, g, b) return math.abs(c[1] - r) < 1e-3 and math.abs(c[2] - g) < 1e-3 and math.abs(c[3] - b) < 1e-3 end

-- Party member
local p = Add("nameplate1", { player = true, party = true, guid = "Player-p", class = "WARRIOR" })
assert(near(p.tc, 0.667, 0.667, 1), "party color")
-- Blizzard repaints (vertex class color) -> we repaint
p:SetVertexColor(0.78, 0.61, 0.43)
assert(near(p.vc, 1, 1, 1) and near(p.tc, 0.667, 0.667, 1), "repaint after Blizzard vertex write")
p:SetTextColor(1, 0, 0)
assert(near(p.tc, 0.667, 0.667, 1), "repaint after Blizzard text write")

-- Friend, BNet friend, guild, others
local f1 = Add("nameplate2", { player = true, guid = "Player-friend" })
assert(near(f1.tc, 1, 0.502, 1), "friend color")
local f2 = Add("nameplate3", { player = true, guid = "Player-bnet" })
assert(near(f2.tc, 1, 0.502, 1), "bnet friend color")
local g = Add("nameplate4", { player = true, guild = true, guid = "Player-g" })
assert(near(g.tc, 0.251, 1, 0.251), "guild color")
local o = Add("nameplate5", { player = true, guid = "Player-o", class = "WARRIOR" })
assert(near(o.tc, 0.857, 0.857, 0.857), "others color")

-- Enemy and NPC untouched
local e = Add("nameplate6", { player = true, hostile = true })
assert(near(e.tc, 1, 0.82, 0), "enemy untouched")
local n = Add("nameplate7", { player = false })
assert(near(n.tc, 1, 0.82, 0), "npc untouched")

-- Leaves party -> falls through to others after roster event
units.nameplate1.party = false
Fire("GROUP_ROSTER_UPDATE"); RunTimers()
assert(near(p.tc, 0.857, 0.857, 0.857), "left party -> others")

-- Raid: guildie in raid other subgroup -> raid wins over guild
inRaid = true
units.nameplate4.raid = true
Fire("GROUP_ROSTER_UPDATE"); RunTimers()
assert(near(g.tc, 1, 0.498, 0), "raid beats guild")
-- Raid off -> guild
local spec = registered.spec
assert(registered.id == "AllyNameColors" and spec.label == "Ally Name Colors")
AllyNameColorsDB.raid.on = false
Fire("GROUP_ROSTER_UPDATE"); RunTimers()
assert(near(g.tc, 0.251, 1, 0.251), "raid off -> guild")
inRaid = false

-- Others class color
AllyNameColorsDB.others.class = true
Fire("GROUP_ROSTER_UPDATE"); RunTimers()
assert(near(o.tc, 0.78, 0.61, 0.43), "others class color")

-- Duel: friend turns hostile -> colors handed back; then friendly again -> repainted
units.nameplate2.hostile = true
Fire("UNIT_FACTION", "nameplate2"); RunTimers()
assert(near(f1.tc, 1, 0.82, 0), "hostile -> restored native")
units.nameplate2.hostile = false
Fire("UNIT_FACTION", "nameplate2"); RunTimers()
assert(near(f1.tc, 1, 0.502, 1), "friendly again -> repainted")

-- Removal restores native color; pooled FS reused for an NPC stays untouched
Fire("NAME_PLATE_UNIT_REMOVED", "nameplate5")
assert(near(o.tc, 1, 0.82, 0), "removed -> restored")
units.nameplate5 = { player = false }
Fire("NAME_PLATE_UNIT_ADDED", "nameplate5")
o:SetTextColor(0, 1, 0)
assert(near(o.tc, 0, 1, 0), "pooled FS on NPC not repainted")

-- Custom-mode warning
Add("nameplate8", { player = true, guid = "Player-x" }, "|cffdbdbdb|cffffff0060|r|r|cffdbdbdb | |r|cffdbdbdbBob|r")
local warnedOnce = false
for _, s in ipairs(printed) do if s:find("Custom") then warnedOnce = true end end
assert(warnedOnce, "custom warning")
-- No warning text for class mode string
local before = #printed
Add("nameplate9", { player = true, guid = "Player-y" }, "|cffffff0060|r | Bob")

-- Health bar mode. Ellesmere's event handler calls ns.TryAddFriendlyPlate; the
-- addon's own NAME_PLATE_UNIT_ADDED may come before or after it.
local function AddBar(token, info, addonFirst)
    units[token] = info
    plates[token] = Plate(NewFS("hidden Blizzard name"))
    if addonFirst then Fire("NAME_PLATE_UNIT_ADDED", token) end
    ENS.TryAddFriendlyPlate(token)
    if not addonFirst then Fire("NAME_PLATE_UNIT_ADDED", token) end
    return barPlates[token]
end
local function RemoveBar(token)
    ENS.RemoveFriendlyPlate(token)
    Fire("NAME_PLATE_UNIT_REMOVED", token)
    units[token], plates[token] = nil, nil
end

local bp = AddBar("nameplate11", { player = true, party = true, guid = "Player-bp", class = "DRUID" })
assert(near(bp.name.tc, 0.667, 0.667, 1), "bar: party color over Ellesmere's class color")
local bp2 = AddBar("nameplate12", { player = true, party = true, guid = "Player-bp2" }, true)
assert(near(bp2.name.tc, 0.667, 0.667, 1), "bar: party color when the addon gets the event first")
RefreshFriendlyColors()
assert(near(bp.name.tc, 0.667, 0.667, 1), "bar: repaint after Ellesmere's repaint")

-- The pooled plate goes to an NPC: Ellesmere's NPC color stands, nothing stale restored.
RemoveBar("nameplate11")
local npcPlate = AddBar("nameplate13", { player = false })
assert(npcPlate == bp, "pool reuse")
assert(near(npcPlate.name.tc, 0, 1, 0), "bar: NPC keeps Ellesmere's color")
RefreshFriendlyColors()
assert(near(npcPlate.name.tc, 0, 1, 0), "bar: NPC keeps Ellesmere's color after a repaint")
-- ...then to a guild member: that player's group.
RemoveBar("nameplate13")
local gp = AddBar("nameplate14", { player = true, guild = true, guid = "Player-gp" })
assert(gp == bp and near(gp.name.tc, 0.251, 1, 0.251), "bar: reused plate takes the new player's group")

-- Leaving the party: the roster refresh repaints.
units.nameplate12.party = false
Fire("GROUP_ROSTER_UPDATE"); RunTimers()
assert(near(bp2.name.tc, 0.857, 0.857, 0.857), "bar: left party -> others")

-- Hostile while Ellesmere still holds the plate: Ellesmere's write stands.
units.nameplate14.hostile = true
gp.name:SetTextColor(unpack(CLASS))
assert(near(gp.name.tc, 1, 0.49, 0.04), "bar: hostile unit not painted")
units.nameplate14.hostile = false

-- A plate added by Ellesmere's local sweep (mode switch): picked up once the
-- system update it runs in has finished.
units.nameplate15 = { player = true, party = true, guid = "Player-sw" }
plates.nameplate15 = Plate(NewFS("hidden"))
local sw = { name = NewFS(""), unit = "nameplate15" }
barPlates.nameplate15 = sw
sw.name:SetTextColor(unpack(CLASS))
ENS.UpdateFriendlyNameplateSystem()
assert(systemRuns == 1, "original system update ran")
RunTimers()
assert(near(sw.name.tc, 0.667, 0.667, 1), "bar: swept plate painted after the system update")

-- A settings change reaches bar plates.
AllyNameColorsDB.party.r, AllyNameColorsDB.party.g, AllyNameColorsDB.party.b = 0, 0, 1
Fire("GROUP_ROSTER_UPDATE"); RunTimers()
assert(near(sw.name.tc, 0, 0, 1), "bar: new party color")
SlashCmdList.ALLYNAMECOLORS("check")

-- Page build with recording widgets
local rows = {}
EllesmereUI.Widgets = {
    SectionHeader = function(_, _, text) rows[#rows + 1] = "H:" .. text; return {}, 40 end,
    DualRow = function(_, _, _, l, r)
        rows[#rows + 1] = l.type .. ":" .. l.text .. " | " .. r.type .. ":" .. r.text
        assert(type(l.getValue()) == "boolean")
        local cr, cg, cb = r.getValue(); assert(cr and cg and cb)
        r.setValue(0.1, 0.2, 0.3); l.setValue(true)
        return {}, 50
    end,
}
local h = spec.modules[1].buildPage("Colors", {}, -10)
print("page height " .. h .. ": " .. table.concat(rows, "; "))
spec.modules[1].onReset()
assert(AllyNameColorsDB.party.r == 0.667, "reset")

-- Slash
SlashCmdList.ALLYNAMECOLORS("check")
SlashCmdList.ALLYNAMECOLORS("")
print("ALL OK")
