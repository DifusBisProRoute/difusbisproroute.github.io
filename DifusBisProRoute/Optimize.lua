-- Difu'sBisProRoute: "Optimize current" tab.
-- Reads the gear the character really owns (equipped, bags and the last bank visit), reads each item's
-- stats (guide data when the item is known, the item tooltip otherwise) and builds the best set from it:
-- as close as possible to 440 Defense (Protection) and 8% hit, then the most EP.
local ADDON, PR = ...
local UI = PR.UI

local CC = C_Container or {}
local GetNumSlots = CC.GetContainerNumSlots or _G.GetContainerNumSlots
local GetSlotLink = CC.GetContainerItemLink or _G.GetContainerItemLink
local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant

-- inventory slot ids (paper doll) for each guide slot
PR.INV_SLOT = { head = 1, neck = 2, shoulder = 3, back = 15, chest = 5, wrist = 9, hands = 10, waist = 6, legs = 7,
  feet = 8, finger1 = 11, finger2 = 12, trinket1 = 13, trinket2 = 14, mainhand = 16, offhand = 17, ranged = 18 }

-- equip location -> guide slots it can go in (offhand depends on the spec)
local function slotsFor(equipLoc, classID, subClassID)
  if equipLoc == "INVTYPE_HEAD" then return { "head" }
  elseif equipLoc == "INVTYPE_NECK" then return { "neck" }
  elseif equipLoc == "INVTYPE_SHOULDER" then return { "shoulder" }
  elseif equipLoc == "INVTYPE_CLOAK" then return { "back" }
  elseif equipLoc == "INVTYPE_CHEST" or equipLoc == "INVTYPE_ROBE" then return { "chest" }
  elseif equipLoc == "INVTYPE_WRIST" then return { "wrist" }
  elseif equipLoc == "INVTYPE_HAND" then return { "hands" }
  elseif equipLoc == "INVTYPE_WAIST" then return { "waist" }
  elseif equipLoc == "INVTYPE_LEGS" then return { "legs" }
  elseif equipLoc == "INVTYPE_FEET" then return { "feet" }
  elseif equipLoc == "INVTYPE_FINGER" then return { "finger1", "finger2" }
  elseif equipLoc == "INVTYPE_TRINKET" then return { "trinket1", "trinket2" }
  elseif PR.IsWL() then -- Warlock: staff or one-hand + held in off-hand, wand
    if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_WEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then return { "mainhand" }
    elseif equipLoc == "INVTYPE_HOLDABLE" or equipLoc == "INVTYPE_WEAPONOFFHAND" then return { "offhand" }
    elseif equipLoc == "INVTYPE_RANGEDRIGHT" and classID == 2 and subClassID == 19 then return { "ranged" } end
    return {}
  elseif equipLoc == "INVTYPE_WEAPONMAINHAND" then return { "mainhand" }
  elseif equipLoc == "INVTYPE_WEAPON" then return PR.IsFury() and { "mainhand", "offhand" } or { "mainhand" }
  elseif equipLoc == "INVTYPE_WEAPONOFFHAND" then return PR.IsFury() and { "offhand" } or {}
  elseif equipLoc == "INVTYPE_SHIELD" then return PR.IsFury() and {} or { "offhand" }
  elseif equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_THROWN" then return { "ranged" }
  elseif equipLoc == "INVTYPE_RANGEDRIGHT" then
    if classID == 2 and subClassID == 19 then return {} end -- wands
    return { "ranged" }
  end
  return {}
end

-- ---------------------------------------------------------------------------
-- Tooltip reader (English client; Spanish patterns are a best effort)
-- ---------------------------------------------------------------------------
local tip
local function scanTip()
  if not tip then
    tip = CreateFrame("GameTooltip", "DifusBisProRouteScanTip", nil, "GameTooltipTemplate")
  end
  tip:SetOwner(WorldFrame, "ANCHOR_NONE")
  return tip
end

local function num(s) if not s then return nil end return tonumber((s:gsub(",", "."))) end

local PAT = {
  { "sp", "spells and effects by up to (%d+)" }, { "sp", "hechizos.-hasta (%d+)" },
  { "int", "^%+(%d+) Intellect" }, { "int", "^%+(%d+) Intelecto" },
  { "spi", "^%+(%d+) Spirit" }, { "spi", "^%+(%d+) Esp[ií]ritu" },
  { "mp5", "Restores (%d+) mana per 5" }, { "mp5", "Restaura (%d+) de man[aá]" },
  { "pen", "magical resistances of your spell targets by (%d+)" },
  { "sta", "^%+(%d+) Stamina" }, { "sta", "^%+(%d+) Aguante" },
  { "str", "^%+(%d+) Strength" }, { "str", "^%+(%d+) Fuerza" },
  { "agi", "^%+(%d+) Agility" }, { "agi", "^%+(%d+) Agilidad" },
  { "armor", "^(%d+) Armor" }, { "armor", "^(%d+) [Aa]rmadura" }, { "armor", "^[Aa]rmadura:? (%d+)" },
  { "bv", "^(%d+) Block$" }, { "bv", "^(%d+) [Bb]loqueo$" },
  { "def", "Increased Defense %+(%d+)" }, { "def", "^%+(%d+) Defense" }, { "def", "[Dd]efensa aumentada %+(%d+)" }, { "def", "^%+(%d+) [Dd]efensa" },
  { "hit", "chance to hit by ([%d%.,]+)%%" }, { "hit", "probabilidad de golpear.-([%d%.,]+)%%" },
  { "crit", "critical strike by ([%d%.,]+)%%" }, { "crit", "golpe cr[ií]tico.-([%d%.,]+)%%" },
  { "dodge", "dodge an attack by ([%d%.,]+)%%" }, { "dodge", "esquivar.-([%d%.,]+)%%" },
  { "parry", "parry an attack by ([%d%.,]+)%%" }, { "parry", "parar.-([%d%.,]+)%%" },
  { "blk", "block attacks with a shield by ([%d%.,]+)%%" },
  { "bv", "block value of your shield by (%d+)" }, { "bv", "valor de bloqueo.-(%d+)" },
  { "ap", "Attack Power by (%d+)" }, { "ap", "^%+(%d+) Attack Power" }, { "ap", "poder de ataque.-(%d+)" },
  { "exp", "Dodged or Parried by ([%d%.,]+)%%" },
}

PR.ownedStatCache = {}
local function readTooltip(link)
  local c = PR.ownedStatCache[link]
  if c then return c end
  local t = scanTip()
  t:ClearLines()
  t:SetHyperlink(link)
  local st, o = {}, {}
  local n = t:NumLines() or 0
  if n == 0 then return nil end -- item data not loaded yet
  local _, myClass = UnitClass("player")
  local myClassLoc = UnitClass("player")
  for i = 2, n do
    local fs = _G["DifusBisProRouteScanTipTextLeft" .. i]
    local line = fs and fs:GetText()
    if line and line ~= "" then
      -- skip set bonuses, on-use / chance-on-hit effects and spell-only stats
      local low = line:lower()
      local skip = line:find("^%(") or low:find("^set:") or low:find("^conjunto") or low:find("^use:") or low:find("^uso:")
        or low:find("^chance on hit") or low:find("spell") or low:find("hechizo")
      if line:find("^Classes:") or line:find("^Clases:") then
        if not line:find(myClassLoc, 1, true) and not line:upper():find(myClass, 1, true) then o.unusable = true end
      end
      if skip and PR.IsWL() and not low:find("^set:") and not low:find("^conjunto") and not low:find("^use:") and not low:find("^uso:") and not low:find("^chance on hit") and not line:find("^%(") then
        skip = false
        local function grab(pat) local v = line:match(pat); return v and num(v) end
        local shp = grab("Shadow spells and effects by up to (%d+)") or grab("Sombra.-hasta (%d+)")
        local fip = grab("Fire spells and effects by up to (%d+)") or grab("Fuego.-hasta (%d+)")
        local shit = grab("chance to hit with spells by ([%d%.,]+)%%") or grab("golpear con hechizos.-([%d%.,]+)%%")
        local scrit = grab("critical strike with spells by ([%d%.,]+)%%") or grab("cr[ií]tico con hechizos.-([%d%.,]+)%%")
        if shp then st.shp = (st.shp or 0) + shp; skip = true end
        if fip then st.fip = (st.fip or 0) + fip; skip = true end
        if shit then st.hit = (st.hit or 0) + shit; skip = true end
        if scrit then st.crit = (st.crit or 0) + scrit; skip = true end
      end
      if not skip then
        for _, p in ipairs(PAT) do
          local v = line:match(p[2])
          if v then st[p[1]] = (st[p[1]] or 0) + (num(v) or 0) end
        end
        local dps = line:match("%(([%d%.,]+) damage per second%)") or line:match("%(([%d%.,]+) daño por segundo%)")
        if dps then o.dps = num(dps) end
        local rt = _G["DifusBisProRouteScanTipTextRight" .. i]
        local right = (rt and rt:IsShown() and rt:GetText()) or ""
        local spd = line:match("^Speed ([%d%.,]+)") or right:match("^Speed ([%d%.,]+)") or right:match("^Velocidad ([%d%.,]+)")
        if spd then o.spd = num(spd) end
      end
    end
    local r = fs and fs:GetTextColor()
    if r and r > 0.99 and select(2, fs:GetTextColor()) < 0.2 and line and (line:find("^Requires") or line:find("^Requiere")) then
      o.unusable = true -- red requirement line (level, skill, reputation)
    end
  end
  o.st = st
  PR.ownedStatCache[link] = o
  return o
end

-- ---------------------------------------------------------------------------
-- Owned items
-- ---------------------------------------------------------------------------
local function bagRange()
  local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
  local t = {}
  for b = 0, last do t[#t + 1] = b end
  return t
end
local function bankRange()
  local t = { (Enum and Enum.BagIndex and Enum.BagIndex.Bank) or -1 }
  local first = (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) + 1
  for b = first, first + (NUM_BANKBAGSLOTS or 7) - 1 do t[#t + 1] = b end
  return t
end
local function linksIn(bags, out)
  if not (GetNumSlots and GetSlotLink) then return out end
  for _, b in ipairs(bags) do
    local ok, n = pcall(GetNumSlots, b)
    if ok and n and n > 0 then
      for s = 1, n do
        local link = GetSlotLink(b, s)
        if link then out[#out + 1] = link end
      end
    end
  end
  return out
end

-- called on BANKFRAME_OPENED / PLAYERBANKSLOTS_CHANGED: the bank can only be read while it is open
function PR.ScanBankLinks()
  if not PR.char then return end
  PR.char.bankLinks = linksIn(bankRange(), {})
  PR.char.bankScanned = time and time() or true
end

local function linkId(link) return tonumber(link:match("item:(%d+)")) end
local function linkEnchant(link) return tonumber(link:match("item:%d+:(%d+)")) or 0 end

-- guide enchants by enchant id (the id inside item links = WoWSims effect id)
local ENCH
local function enchById(id)
  if not ENCH then
    ENCH = {}
    for _, list in pairs(PR.SPEC_SLOTS) do
      for _, sl in ipairs(list) do if sl.ench and sl.ench.ws then ENCH[sl.ench.ws] = sl.ench end end
    end
  end
  return ENCH[id]
end

local function addStats(a, b)
  local t = {}
  for k, v in pairs(a or {}) do t[k] = v end
  for k, v in pairs(b or {}) do t[k] = (t[k] or 0) + v end
  return t
end

-- stats of the enchant on an item link: guide enchant if we know it, otherwise tooltip(with) - tooltip(without)
local function enchantStats(link, id)
  local e = linkEnchant(link)
  if e == 0 then return nil, 0 end
  local g = enchById(e)
  if g then return g.st, e, g.n end
  local with, base = readTooltip(link), readTooltip("item:" .. id)
  if not (with and base) then return {}, e end
  local d = {}
  for k, v in pairs(with.st) do
    local x = v - (base.st[k] or 0)
    if x > 0 then d[k] = x end
  end
  return d, e
end

-- slotKey -> list of options { id, link, q, st, dps, spd, spec, loc }
function PR.OwnedCandidates()
  local cands, pending, seen = {}, 0, {}
  for _, sl in ipairs(PR.SLOTS) do cands[sl.k] = {} end
  local lvl = UnitLevel("player") or 60
  local function add(link, loc)
    local id = linkId(link)
    if not id then return end
    local key = id .. ":" .. loc
    if seen[id] and (seen[id] == "equipped" or loc ~= "equipped") then return end
    local name, _, q, _, minLvl, _, _, _, equipLoc = PR.GetItemInfo(link)
    if not name then pending = pending + 1; return end
    if (minLvl or 0) > lvl then return end
    local classID, subClassID
    if GetInstant then local r = { GetInstant(link) }; classID, subClassID = r[6], r[7] end
    local slots = slotsFor(equipLoc, classID, subClassID)
    if #slots == 0 then return end
    local known = PR.ITEM[id]
    local o
    if known then
      o = { st = known.st, dps = known.dps, spd = known.spd, pe = known.pe, two = known.two, set = known.set }
    else
      local r = readTooltip("item:" .. id) -- base item, without the enchant
      local full = readTooltip(link)
      if not (r and full) then pending = pending + 1; return end
      if full.unusable then return end
      o = { st = r.st, dps = r.dps, spd = r.spd, two = (equipLoc == "INVTYPE_2HWEAPON") or nil }
    end
    local est, eid, en = enchantStats(link, id)
    o.baseSt, o.ench, o.enchN = o.st, eid, en
    if est then o.st = addStats(o.st, est) end
    o.id, o.link, o.q, o.n, o.loc, o.spec = id, link, q, name, loc, PR.spec
    o.key = key .. ":" .. eid
    seen[id] = loc
    for _, k in ipairs(slots) do
      local list = cands[k]
      if list then
        -- replace a bag/bank copy by the equipped one
        local found
        for i, x in ipairs(list) do if x.id == id then found = i end end
        if found then list[found] = o else list[#list + 1] = o end
      end
    end
  end
  for _, k in ipairs({ "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet",
    "finger1", "finger2", "trinket1", "trinket2", "mainhand", "offhand", "ranged" }) do
    local link = GetInventoryItemLink("player", PR.INV_SLOT[k])
    if link then add(link, "equipped") end
  end
  for _, link in ipairs(linksIn(bagRange(), {})) do add(link, "bags") end
  for _, link in ipairs(PR.char.bankLinks or {}) do add(link, "bank") end
  return cands, pending
end

-- the set the character has on right now, with the same model as the plan
function PR.EquippedPick(cands)
  local pick = {}
  for k, slot in pairs(PR.INV_SLOT) do
    local link = GetInventoryItemLink("player", slot)
    local id = link and linkId(link)
    if id then for _, o in ipairs(cands[k] or {}) do if o.id == id then pick[k] = o end end end
  end
  return pick
end

-- totals for a pick table (slot -> option), same formulas as PR.Calc
function PR.CalcPick(pick)
  local fury = PR.IsFury()
  local g = { def = 0, hit = 0, ep = 0, missing = {}, missDef = 0 }
  for _, sl in ipairs(PR.SLOTS) do
    if not PR.char.off[sl.k] then
      local o = pick[sl.k]
      if o then
        g.def = g.def + ((o.st and o.st.def) or 0)
        g.hit = g.hit + ((o.st and o.st.hit) or 0)
        g.ep = g.ep + PR.EP(o, sl.k)
        if sl.ench and (o.ench or 0) == 0 then
          g.missing[#g.missing + 1] = sl
          g.missDef = g.missDef + ((sl.ench.st and sl.ench.st.def) or 0)
        end
      end
    end
  end
  local R = PR.Ranks()
  g.D = (fury or PR.IsWL()) and nil or (300 + R.anticip * PR.TALENTS.anticip.per + g.def)
  if PR.IsWL() then g.hit = g.hit + (PR.WLRanks()) end -- total spell hit (gear + Suppression)
  return g
end

local lastKey, lastRes
function PR.OptimizeCurrent(force)
  local cands, pending = PR.OwnedCandidates()
  local parts = { PR.spec, PR.useEnchants and 1 or 0, PR.Ranks().anticip }
  for _, sl in ipairs(PR.SLOTS) do
    if PR.char.off[sl.k] then parts[#parts + 1] = "x" .. sl.k end
    for _, o in ipairs(cands[sl.k]) do parts[#parts + 1] = sl.k .. o.key end
  end
  local key = table.concat(parts, "|")
  if not force and key == lastKey and lastRes then return lastRes end
  local res = PR.RunOptimizer(cands)
  res.cands, res.pending = cands, pending
  res.cur = PR.EquippedPick(cands)
  -- rings and trinkets: if the chosen pair is already on, keep the order you wear them in
  for _, pr in ipairs({ { "finger1", "finger2" }, { "trinket1", "trinket2" } }) do
    local a, b = pr[1], pr[2]
    local pa, pb, ca, cb = res.pickO[a], res.pickO[b], res.cur[a], res.cur[b]
    if (pa and cb and pa.id == cb.id) or (pb and ca and pb.id == ca.id) then
      res.pickO[a], res.pickO[b] = pb, pa
    end
  end
  res.curStats = PR.CalcPick(res.cur)
  res.newStats = PR.CalcPick(res.pickO)
  lastKey, lastRes = key, res
  return res
end

-- ---------------------------------------------------------------------------
-- Tab UI
-- ---------------------------------------------------------------------------
local ORDER = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet",
  "finger1", "finger2", "trinket1", "trinket2", "mainhand", "offhand", "ranged" }
local ROW_H = 30

function UI.BuildOpt(parent)
  local H = UI.H
  local p = CreateFrame("Frame", nil, parent)
  p:SetSize(parent:GetWidth(), 10)
  p:Hide()
  p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); p.title:SetPoint("TOPLEFT", 4, -4)
  p.sub = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); p.sub:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -4)
  p.sub:SetPoint("RIGHT", p, "RIGHT", -8, 0); p.sub:SetJustifyH("LEFT")
  p.rescan = H.button(p, 120); p.rescan:SetPoint("TOPRIGHT", -4, -2)
  p.rescan:SetScript("OnClick", function() PR.ownedStatCache = {}; UI.SafeUpdate() end)
  p.sum = p:CreateFontString(nil, "OVERLAY", "GameFontNormal"); p.sum:SetPoint("TOPLEFT", p.sub, "BOTTOMLEFT", 0, -10)
  p.sum:SetPoint("RIGHT", p, "RIGHT", -8, 0); p.sum:SetJustifyH("LEFT")
  p.cur = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); p.cur:SetPoint("TOPLEFT", p.sum, "BOTTOMLEFT", 0, -4)
  p.cur:SetPoint("RIGHT", p, "RIGHT", -8, 0); p.cur:SetJustifyH("LEFT")
  p.rows = {}
  for i, k in ipairs(ORDER) do
    local r = CreateFrame("Button", nil, p, "BackdropTemplate")
    r:SetHeight(ROW_H)
    H.backdrop(r, 0.5); r:SetBackdropColor(0.07, 0.07, 0.08, 0.55); r:SetBackdropBorderColor(0.3, 0.3, 0.32, 0.6)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(24, 24); r.icon:SetPoint("LEFT", 4, 0)
    r.slot = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.slot:SetPoint("LEFT", 34, 0); r.slot:SetWidth(78); r.slot:SetJustifyH("LEFT")
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.name:SetPoint("LEFT", 114, 0); r.name:SetWidth(220); r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.stats = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.stats:SetPoint("LEFT", 338, 0); r.stats:SetWidth(120); r.stats:SetJustifyH("LEFT")
    r.loc = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.loc:SetPoint("RIGHT", -6, 0); r.loc:SetJustifyH("RIGHT")
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.08)
    r:SetScript("OnEnter", function(self)
      if self.link then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.link)
        if self.enchHint then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine(PR.T("noEnchTip") .. " " .. self.enchHint, 1, 0.4, 0.3, true)
        end
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.key = k
    p.rows[i] = r
  end
  p.note = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); p.note:SetJustifyH("LEFT")
  UI.opt = p
end

local function locText(loc)
  if loc == "equipped" then return "|cff7fbf7f" .. PR.T("locEq") .. "|r"
  elseif loc == "bags" then return "|cffffd100" .. PR.T("locBags") .. "|r"
  elseif loc == "bank" then return "|cff4fc3f7" .. PR.T("locBank") .. "|r" end
  return ""
end
local function statText(o)
  local st, t = (o and o.st) or {}, {}
  if (st.def or 0) > 0 then t[#t + 1] = "Def +" .. st.def end
  if (st.hit or 0) > 0 then t[#t + 1] = string.format("%s %g%%", PR.T("hitShort"), st.hit) end
  if (st.exp or 0) > 0 and PR.IsFury() then t[#t + 1] = string.format("Exp %g%%", st.exp) end
  return table.concat(t, " · ")
end

-- returns the height used
function UI.UpdateOpt()
  local p = UI.opt
  if not p then return 0 end
  p:Show()
  local fury = PR.IsFury()
  local res = PR.OptimizeCurrent()
  p.title:SetText(PR.T("optTitle"))
  p.rescan:SetText(PR.T("rescan"))
  local bankNote = PR.char.bankScanned and PR.T("optBankOk") or ("|cffe5604f" .. PR.T("optBankNo") .. "|r")
  local wl = PR.IsWL()
  p.sub:SetText(PR.T(wl and "optSubWL" or fury and "optSubF" or "optSub") .. "  " .. bankNote)
  local n, c = res.newStats, res.curStats
  local cap = PR.MODEL.defCap
  local hc = wl and PR.WMODEL.hitCap or fury and PR.FMODEL.hitCap or PR.MODEL.hitCap
  local function defStr(D) return ((D >= cap) and UI.H.GOOD or "|cffe5604f") .. math.floor(D + 0.5) .. "|r / " .. cap end
  local function hitStr(h) return ((h >= hc - 0.05) and UI.H.GOOD or "|cffffd100") .. string.format("%.1f%%", h) .. "|r / " .. hc .. "%" end
  if fury or wl then
    p.sum:SetText(string.format("%s: %s %s · EP %d", PR.T("optBest"), PR.T("hitShort"), hitStr(n.hit), n.ep))
    p.cur:SetText(string.format("%s: %s %.1f%% · EP %d", PR.T("optNow"), PR.T("hitShort"), c.hit, c.ep))
  else
    p.sum:SetText(string.format("%s: Def %s · %s %s · EP %d", PR.T("optBest"), defStr(n.D), PR.T("hitShort"), hitStr(n.hit), n.ep))
    p.cur:SetText(string.format("%s: Def %d · %s %.1f%% · EP %d", PR.T("optNow"), c.D, PR.T("hitShort"), c.hit, c.ep))
  end
  local y = 4 + p.title:GetStringHeight() + 4 + p.sub:GetStringHeight() + 10 + p.sum:GetStringHeight() + 4 + p.cur:GetStringHeight() + 12
  local changes = 0
  for i, k in ipairs(ORDER) do
    local r = p.rows[i]
    local sl
    for _, s in ipairs(PR.SLOTS) do if s.k == k then sl = s end end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("RIGHT", p, "RIGHT", 0, 0)
    local o = res.pickO[k]
    local cur = res.cur[k]
    r.slot:SetText(sl and string.upper(PR.tx(sl.n)) or k)
    if PR.char.off[k] then
      r.icon:SetTexture(134400); r.name:SetText("|cff9d9d9d" .. PR.T("offTag") .. "|r"); r.stats:SetText(""); r.loc:SetText(""); r.link = nil; r.enchHint = nil
      r:SetBackdropBorderColor(0.3, 0.3, 0.32, 0.6)
    elseif o then
      r.icon:SetTexture(PR.GetItemIcon(o.id) or 134400)
      r.name:SetText(UI.H.qualityHex(o.q) .. (o.n or PR.ItemName(o.id)) .. "|r")
      local miss = sl and sl.ench and (o.ench or 0) == 0
      r.stats:SetText(statText(o) .. (miss and ("  |cffe5604f" .. PR.T("noEnch") .. "|r") or ""))
      r.enchHint = miss and sl.ench.n or nil
      local sib = ({ finger1 = "finger2", finger2 = "finger1", trinket1 = "trinket2", trinket2 = "trinket1" })[k]
      local swap = (not cur or cur.id ~= o.id) and not (sib and res.cur[sib] and res.cur[sib].id == o.id)
      if swap then changes = changes + 1 end
      r.loc:SetText((swap and ("|cffffd100" .. PR.T("optSwap") .. "|r  ") or "") .. locText(o.loc))
      r.link = o.link
      if swap then r:SetBackdropBorderColor(1, 0.82, 0, 0.9) else r:SetBackdropBorderColor(0.3, 0.3, 0.32, 0.6) end
    else
      r.icon:SetTexture(134400); r.name:SetText("|cff9d9d9d" .. PR.T("optNone") .. "|r"); r.stats:SetText(""); r.loc:SetText(""); r.link = nil; r.enchHint = nil
      r:SetBackdropBorderColor(0.3, 0.3, 0.32, 0.6)
    end
    r:Show()
    y = y + ROW_H + 4
  end
  p.note:ClearAllPoints(); p.note:SetPoint("TOPLEFT", 4, -(y + 4)); p.note:SetPoint("RIGHT", p, "RIGHT", -8, 0)
  local notes = { string.format(PR.T("optChanges"), changes) }
  if #n.missing > 0 then
    local names = {}
    for _, sl in ipairs(n.missing) do names[#names + 1] = PR.tx(sl.n) end
    local line = "|cffe5604f" .. string.format(PR.T("optMissEnch"), #n.missing, table.concat(names, ", ")) .. "|r"
    if not fury and n.missDef > 0 then line = line .. " " .. string.format(PR.T("optMissDef"), n.missDef, math.floor(n.D + n.missDef + 0.5)) end
    notes[#notes + 1] = line
  end
  if res.pending > 0 then notes[#notes + 1] = string.format(PR.T("optPending"), res.pending) end
  notes[#notes + 1] = PR.T("optHow")
  p.note:SetText(table.concat(notes, "\n"))
  y = y + 8 + p.note:GetStringHeight() + 8
  p:SetHeight(y)
  return y
end
