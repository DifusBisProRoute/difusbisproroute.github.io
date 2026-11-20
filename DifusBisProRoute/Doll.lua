-- Difu'sBisProRoute: character-sheet style gear view (slots around a tank stats sheet) and slot flyout.
local ADDON, PR = ...
local UI = PR.UI

local LEFT = { "head", "neck", "shoulder", "back", "chest", "wrist" }
local RIGHT = { "hands", "waist", "legs", "feet", "finger1", "finger2", "trinket1", "trinket2" }
local BOTTOM = { "mainhand", "offhand", "ranged" }
local SLOT_SIZE, SLOT_GAP = 42, 8

local function H() return UI.H end
local function slotByKey(k) for _, s in ipairs(PR.SLOTS) do if s.k == k then return s end end end

local function fmtInt(x) return string.format("%d", math.floor(x + 0.5)) end
local function fmtPct2(x) return string.format("%.2f%%", x) end
local function fmtPct1(x) return string.format("%.1f%%", x) end
local function fmtPct1Plain(x) return string.format("%.1f", x) end
local function delta(d, fmt, lowerBetter)
  if math.abs(d) < 0.005 then return "" end
  local good = (lowerBetter and d < 0) or (not lowerBetter and d > 0)
  return "  " .. (good and H().GOOD or H().BAD) .. (d > 0 and "+" or "") .. fmt(d) .. "|r"
end

-- ---------------------------------------------------------------------------
-- Stats sheet (center)
-- ---------------------------------------------------------------------------
local SECTIONS_PROT = {
  { title = "secCaps", bars = {
    { "D", "defL", "defCap", fmtInt }, { "hit", "hitL", "hitCap", fmtPct1 },
    { "exp", "expL", "expCap", fmtPct1 }, { "full", "crushL", "crushCap", fmtPct2 } } },
  { title = "secAvoid", lines = {
    { "miss", "missL", fmtPct2 }, { "dodge", "dodgeL", fmtPct2 }, { "parry", "parryL", fmtPct2 },
    { "block", "blockL", fmtPct2 }, { "avoid", "avoidL", fmtPct2, true } } },
  { title = "secSurv", lines = {
    { "hp", "maxHp", fmtInt, true }, { "sta", "staL", fmtInt }, { "armor", "armorL", fmtInt },
    { "dr", "drL", fmtPct1 }, { "bv", "bvL", fmtInt } } },
  { title = "secOff", lines = {
    { "str", "strL", fmtInt }, { "ap", "apL", fmtInt }, { "critP", "critL", fmtPct1 },
    { "ep", "epL", fmtPct1Plain, true } } },
}
local SECTIONS_FURY = {
  { title = "secCapsF", bars = {
    { "hit", "hitL", "hitCap", fmtPct1 }, { "exp", "expL", "expCap", fmtPct1 } } },
  { title = "secOffF", lines = {
    { "crit", "critTot", fmtPct1, true }, { "ap", "apTot", fmtInt }, { "str", "strT", fmtInt }, { "agi", "agiT", fmtInt },
    { "ep", "epL", fmtPct1Plain, true } } },
  { title = "secMiscF", lines = {
    { "mh", "mhL", fmtPct1Plain }, { "oh", "ohL", fmtPct1Plain }, { "hp", "maxHp", fmtInt, true }, { "armor", "armorL", fmtInt } } },
}

local function sectionHeader(parent, y, w)
  local hdr = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  hdr:SetPoint("TOPLEFT", 8, y); hdr:SetSize(w - 16, 22)
  hdr:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  hdr:SetBackdropColor(0.22, 0.15, 0.08, 1); hdr:SetBackdropBorderColor(0.55, 0.42, 0.22, 1)
  hdr.text = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormal"); hdr.text:SetPoint("LEFT", 10, 0)
  hdr.c1 = hdr:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); hdr.c1:SetPoint("RIGHT", -142, 0)
  hdr.c2 = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); hdr.c2:SetPoint("RIGHT", -8, 0)
  return hdr
end

local function buildStats(parent, w, SECTIONS)
  local st = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  st:SetWidth(w)
  H().backdrop(st, 0.92)
  st:SetBackdropColor(0.05, 0.045, 0.04, 0.92)
  st:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.9)
  st.title = st:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); st.title:SetPoint("TOP", 0, -10)
  st.model = st:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); st.model:SetPoint("TOP", st.title, "BOTTOM", 0, -3)
  st.talents = st:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); st.talents:SetPoint("TOP", st.model, "BOTTOM", 0, -3)
  st.talents:SetWidth(w - 24)
  st.preview = st:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); st.preview:SetPoint("TOP", st.talents, "BOTTOM", 0, -3)
  st.secs = {}
  local y = -80
  for si, sec in ipairs(SECTIONS) do
    local s = { hdr = sectionHeader(st, y, w), items = {} }
    y = y - 28
    for bi, b in ipairs(sec.bars or {}) do
      local row = {}
      row.label = st:CreateFontString(nil, "OVERLAY", "GameFontNormal"); row.label:SetPoint("TOPLEFT", 16, y)
      row.value = st:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); row.value:SetPoint("TOPRIGHT", -16, y)
      local bar = CreateFrame("StatusBar", nil, st)
      bar:SetPoint("TOPLEFT", 16, y - 17); bar:SetPoint("TOPRIGHT", -16, y - 17); bar:SetHeight(10)
      bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
      bar.bg = bar:CreateTexture(nil, "BACKGROUND"); bar.bg:SetAllPoints(); bar.bg:SetColorTexture(0.16, 0.13, 0.10, 1)
      row.bar = bar
      row.note = st:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.note:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
      row.spec = b
      s.items[#s.items + 1] = row
      y = y - 46
    end
    for li, l in ipairs(sec.lines or {}) do
      local row = {}
      local stripe = st:CreateTexture(nil, "BACKGROUND", nil, 2)
      stripe:SetPoint("TOPLEFT", 10, y + 3); stripe:SetPoint("TOPRIGHT", -10, y + 3); stripe:SetHeight(19)
      stripe:SetColorTexture(1, 0.85, 0.6, (li % 2 == 1) and 0.05 or 0)
      row.label = st:CreateFontString(nil, "OVERLAY", l[4] and "GameFontNormal" or "GameFontHighlight")
      row.label:SetPoint("TOPLEFT", 16, y)
      row.value = st:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); row.value:SetPoint("TOPRIGHT", -16, y)
      row.live = st:CreateFontString(nil, "OVERLAY", "GameFontDisable"); row.live:SetPoint("TOPRIGHT", -150, y)
      row.live:SetJustifyH("RIGHT")
      row.spec = l
      s.items[#s.items + 1] = row
      y = y - 19
    end
    y = y - 10
    st.secs[si] = s
  end
  st:SetHeight(-y + 4)
  st.sections = SECTIONS
  return st
end

function UI.UpdateStats()
  local st = UI.stats
  if not st or not PR.char then return end
  local fury = PR.IsFury()
  local M = fury and PR.FMODEL or PR.MODEL
  local SECTIONS = st.sections
  local a = PR.Calc()
  local p = UI.preview and PR.Calc(UI.preview.slot, UI.preview.opt) or nil
  local v = p or a
  st.title:SetText(PR.T(fury and "capsF" or "capsT"))
  st.model:SetText(PR.T(fury and "modelF" or "model"))
  local R, live = PR.Ranks()
  if fury then
    st.talents:SetText(live and string.format(PR.T("talentsLiveF"), R.cruelty or 0) or ("|cffe5604f" .. PR.T("talentsDefF") .. "|r"))
  else
    st.talents:SetText(live and string.format(PR.T("talentsLive"), R.anticip, R.deflect, R.shieldSpec, R.tough) or ("|cffe5604f" .. PR.T("talentsDef") .. "|r"))
  end
  local L = PR.Live()
  st.preview:SetText(p and (PR.T("ifPick") .. " " .. H().qualityHex(UI.preview.opt.q) .. PR.ItemName(UI.preview.opt.id) .. "|r") or "")
  for si, sec in ipairs(SECTIONS) do
    local s = st.secs[si]
    s.hdr.text:SetText(PR.T(sec.title))
    s.hdr.c1:SetText(sec.lines and PR.T("now") or "")
    s.hdr.c2:SetText(sec.lines and PR.T("plan") or "")
    for _, row in ipairs(s.items) do
      local sp = row.spec
      local key = sp[1]
      local fmt = row.bar and sp[4] or sp[3]
      if row.bar then
        local cap = M[sp[3]]
        local capped = v[key] >= cap
        row.label:SetText(PR.T(sp[2]))
        row.value:SetText((capped and H().GOOD or "|cffffffff") .. fmt(v[key]) .. "|r |cff9d9d9d/ " .. fmt(cap) .. "|r" .. (p and delta(v[key] - a[key], fmt) or ""))
        row.bar:SetMinMaxValues(0, cap); row.bar:SetValue(math.min(cap, v[key]))
        if capped then row.bar:SetStatusBarColor(0.30, 0.75, 0.38)
        elseif key == "hit" or key == "exp" then row.bar:SetStatusBarColor(0.80, 0.62, 0.25)
        else row.bar:SetStatusBarColor(0.75, 0.18, 0.12) end
        if key == "D" then row.note:SetText(v.crit <= 0 and PR.T("critImm") or string.format(PR.T("critN"), v.crit))
        elseif key == "full" then row.note:SetText(string.format(PR.T("sbN"), v.full + 75))
        elseif key == "hit" then row.note:SetText(string.format(PR.T(fury and "hitNoteF" or "hitNote"), PR.OptimizeHit(false).hit))
        elseif key == "exp" and fury then row.note:SetText(string.format(PR.T("expNoteF")))
        else row.note:SetText("") end
      else
        row.label:SetText(PR.T(sp[2]))
        row.value:SetText(fmt(v[key]) .. (p and delta(v[key] - a[key], fmt) or ""))
        row.live:SetText(L[key] and fmt(L[key]) or "-")
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Slot buttons
-- ---------------------------------------------------------------------------
local function slotButton(parent, key, side)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(SLOT_SIZE, SLOT_SIZE)
  b.key, b.side = key, side
  b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(); b.bg:SetColorTexture(0, 0, 0, 0.8)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.border = b:CreateTexture(nil, "OVERLAY"); b.border:SetAllPoints(); b.border:SetTexture("Interface\\Common\\WhiteIconFrame")
  b.check = b:CreateTexture(nil, "OVERLAY", nil, 2); b.check:SetSize(16, 16); b.check:SetPoint("BOTTOMRIGHT", 3, -3)
  b.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b.warn = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); b.warn:SetPoint("TOPRIGHT", -3, -1); b.warn:SetText("!"); b.warn:SetTextColor(1, 0.3, 0.25)
  b.off = b:CreateTexture(nil, "OVERLAY", nil, 3); b.off:SetAllPoints(); b.off:SetColorTexture(0, 0, 0, 0.7)
  b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 0.82, 0, 0.18)
  b.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.label:SetWidth(150); b.label:SetWordWrap(false)
  if side == "left" then b.label:SetPoint("LEFT", b, "RIGHT", 6, 0); b.label:SetJustifyH("LEFT")
  elseif side == "right" then b.label:SetPoint("RIGHT", b, "LEFT", -6, 0); b.label:SetJustifyH("RIGHT")
  else b.label:SetPoint("TOP", b, "BOTTOM", 0, -2); b.label:SetJustifyH("CENTER"); b.label:SetWidth(120) end
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, mouse)
    if mouse == "RightButton" then
      PR.char.off[key] = not PR.char.off[key] or nil; PR.Refresh(false); return
    end
    if UI.fly and UI.fly:IsShown() and UI.fly.key == key then UI.fly:Hide() else UI.OpenFlyout(self) end
  end)
  b:SetScript("OnEnter", function(self)
    local sl = slotByKey(key); local o = PR.Selected(sl)
    H().showItemTooltip(self, o.id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(string.format(PR.T("slotHint"), #PR.OptsFor(sl)), 1, 0.82, 0, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function refreshSlot(b)
  local sl = slotByKey(b.key); local o = PR.Selected(sl)
  b.icon:SetTexture(PR.GetItemIcon(o.id) or 134400)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[o.q or 1]
  if c then b.border:SetVertexColor(c.r, c.g, c.b) end
  b.check:SetShown(PR.Has(o.id))
  b.warn:SetShown(o.verify and true or false)
  b.off:SetShown(PR.char.off[b.key] and true or false)
  b.icon:SetDesaturated(PR.char.off[b.key] and true or false)
  -- like the web: SLOT (grey) / item name (quality colour) / EP (+ ready check when you own it)
  local own = PR.Has(o.id) and "  |TInterface\\RAIDFRAME\\ReadyCheck-Ready:12:12|t" or ""
  b.label:SetText("|cff9d9d9d" .. string.upper(PR.tx(sl.n)) .. "|r\n" .. H().qualityHex(o.q) .. PR.ItemName(o.id) ..
    "|r\n|cffc69b6d" .. string.format("%.1f EP", PR.EP(o, sl.k)) .. "|r" .. own)
  b.label:SetWordWrap(true)
end

-- ---------------------------------------------------------------------------
-- Flyout with the 3 options
-- ---------------------------------------------------------------------------
local function buildFlyout()
  local fl = CreateFrame("Frame", "DifusBisProRouteFlyout", UI.frame, "BackdropTemplate")
  fl:SetFrameStrata("DIALOG"); fl:SetToplevel(true)
  fl:SetSize(360, 10)
  H().backdrop(fl, 1)
  fl:SetBackdropColor(0.06, 0.05, 0.04, 0.98)
  fl:SetBackdropBorderColor(1, 0.82, 0, 1)
  fl:EnableMouse(true)
  fl.title = fl:CreateFontString(nil, "OVERLAY", "GameFontNormal"); fl.title:SetPoint("TOPLEFT", 12, -10)
  fl.rows = {}
  for i = 1, 5 do
    local r = CreateFrame("Button", nil, fl, "BackdropTemplate")
    r:SetSize(336, 58); r:SetPoint("TOPLEFT", 12, -30 - (i - 1) * 62)
    r:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(40, 40); r.icon:SetPoint("LEFT", 8, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.iconBorder = r:CreateTexture(nil, "OVERLAY"); r.iconBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    r.iconBorder:SetPoint("TOPLEFT", r.icon, -1, 1); r.iconBorder:SetPoint("BOTTOMRIGHT", r.icon, 1, -1)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.name:SetPoint("TOPLEFT", 56, -7); r.name:SetPoint("RIGHT", -80, 0); r.name:SetJustifyH("LEFT")
    r.src = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.src:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2); r.src:SetPoint("RIGHT", -80, 0); r.src:SetJustifyH("LEFT")
    r.delta = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.delta:SetPoint("TOPLEFT", r.src, "BOTTOMLEFT", 0, -2); r.delta:SetPoint("RIGHT", -8, 0); r.delta:SetJustifyH("LEFT")
    r.have = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate"); r.have:SetSize(22, 22); r.have:SetPoint("TOPRIGHT", -54, -4)
    r.haveLbl = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.haveLbl:SetPoint("LEFT", r.have, "RIGHT", 0, 0); r.haveLbl:SetWidth(52); r.haveLbl:SetJustifyH("LEFT")
    r.tags = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.tags:SetPoint("TOPRIGHT", -8, -32)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.10)
    r:SetScript("OnClick", function(self)
      PR.char.sel[fl.key] = self.opt.id; PR.char.lastPre = nil; UI.preview = nil; fl:Hide(); PR.Refresh(false)
    end)
    r:SetScript("OnEnter", function(self) UI.OptEnter(self, { id = self.opt.id, slot = fl.key }) end)
    r:SetScript("OnLeave", function() UI.OptLeave() end)
    r.have:SetScript("OnClick", function(self)
      PR.char.have[r.opt.id] = self:GetChecked() and true or nil; PR.Refresh(false)
    end)
    fl.rows[i] = r
  end
  fl.ignore = CreateFrame("CheckButton", nil, fl, "UICheckButtonTemplate"); fl.ignore:SetSize(22, 22)
  fl.ignore.label = fl:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); fl.ignore.label:SetPoint("LEFT", fl.ignore, "RIGHT", 2, 0)
  fl.ignore:SetScript("OnClick", function(self) PR.char.off[fl.key] = self:GetChecked() and true or nil; PR.Refresh(false) end)
  fl:SetScript("OnHide", function() if UI.preview then UI.preview = nil; xpcall(UI.UpdateStats, PR.Err) end end)
  tinsert(UISpecialFrames, "DifusBisProRouteFlyout")
  fl:Hide()
  UI.fly = fl
  return fl
end

local function fillFlyout()
  local fl = UI.fly
  if not fl or not fl:IsShown() then return end
  local sl = slotByKey(fl.key)
  local cur = PR.Selected(sl)
  local base = PR.Calc()
  fl.title:SetText(PR.tx(sl.n) .. (sl.ench and ("  |cff9d9d9d" .. sl.ench.n .. "|r") or ""))
  local opts = PR.OptsFor(sl)
  for i, r in ipairs(fl.rows) do
    local o = opts[i]
    if o then
      r.opt = o
      r.icon:SetTexture(PR.GetItemIcon(o.id) or 134400)
      local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[o.q or 1]
      if c then r.iconBorder:SetVertexColor(c.r, c.g, c.b) end
      r.name:SetText(H().qualityHex(o.q) .. PR.ItemName(o.id) .. "|r")
      r.src:SetText(PR.tx(o.src))
      r.delta:SetText(o.id == cur.id and ("|cffffd100" .. PR.T("cur") .. "|r") or UI.DeltaText(base, PR.Calc(sl.k, o)))
      local tags = {}
      if PR.hasTag(o, "wfb" .. PR.faction) then tags[#tags + 1] = H().GOLD .. "WFB|r" end
      if PR.hasTag(o, "wtbc") then tags[#tags + 1] = "|cff5aa2ffWTBC|r" end
      if o.verify then tags[#tags + 1] = "|cffe5604f!|r" end
      r.tags:SetText(table.concat(tags, " "))
      local owned = PR.Owned(o.id)
      r.have:SetChecked(owned ~= nil or PR.char.have[o.id] == true); r.have:SetEnabled(owned == nil)
      r.haveLbl:SetText(owned and (H().GOOD .. PR.T(owned) .. "|r") or PR.T("have"))
      if o.id == cur.id then
        r:SetBackdropColor(0.25, 0.18, 0.05, 0.9); r:SetBackdropBorderColor(1, 0.82, 0, 1)
      else
        r:SetBackdropColor(0.10, 0.09, 0.08, 0.9); r:SetBackdropBorderColor(0.4, 0.36, 0.3, 1)
      end
      r:Show()
    else r:Hide() end
  end
  local n = math.min(4, #opts)
  fl.ignore:ClearAllPoints(); fl.ignore:SetPoint("TOPLEFT", 12, -30 - n * 62)
  fl.ignore:SetChecked(PR.char.off[fl.key] and true or false)
  fl.ignore.label:SetText(PR.T("ignore"))
  fl:SetHeight(30 + n * 62 + 32)
end

function UI.OpenFlyout(b)
  local fl = UI.fly or buildFlyout()
  fl.key = b.key
  fl:ClearAllPoints()
  if b.side == "left" then fl:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, 0)
  elseif b.side == "right" then fl:SetPoint("TOPRIGHT", b, "TOPLEFT", -8, 0)
  else fl:SetPoint("BOTTOM", b, "TOP", 0, 8) end
  fl:Show()
  fillFlyout()
end

-- ---------------------------------------------------------------------------
-- Doll layout
-- ---------------------------------------------------------------------------
function UI.BuildDoll(content)
  local W = H().ROW_W
  local d = CreateFrame("Frame", nil, content)
  d:SetWidth(W)
  d.slots = {}
  local colH = #RIGHT * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
  for i, k in ipairs(LEFT) do
    local b = slotButton(d, k, "left")
    -- spread the 6 left slots over the same height as the 8 right ones
    local step = (colH - SLOT_SIZE) / (#LEFT - 1)
    b:SetPoint("TOPLEFT", 0, -math.floor((i - 1) * step))
    d.slots[k] = b
  end
  for i, k in ipairs(RIGHT) do
    local b = slotButton(d, k, "right")
    b:SetPoint("TOPRIGHT", 0, -(i - 1) * (SLOT_SIZE + SLOT_GAP))
    d.slots[k] = b
  end
  local statsW = W - 2 * (SLOT_SIZE + 160)
  if statsW < 220 then statsW = W - 2 * (SLOT_SIZE + 12) end
  local st = buildStats(d, statsW, SECTIONS_PROT)
  st:SetPoint("TOP", d, "TOP", 0, 0)
  local stF = buildStats(d, statsW, SECTIONS_FURY)
  stF:SetPoint("TOP", d, "TOP", 0, 0); stF:Hide()
  UI.statsBySpec = { prot = st, fury = stF }
  UI.stats = st
  d.statsW = statsW
  d.colH = colH
  d.bottom = {}
  for i, k in ipairs(BOTTOM) do
    local b = slotButton(d, k, "bottom")
    d.slots[k] = b
    d.bottom[i] = b
  end
  d:Hide()
  UI.doll = d
end

function UI.UpdateDoll()
  local d = UI.doll
  if not d then return end
  -- labels sit beside the icons only when the stats sheet leaves room
  local roomy = d.statsW <= H().ROW_W - 2 * (SLOT_SIZE + 160)
  for k, b in pairs(d.slots) do
    refreshSlot(b)
    b.label:SetShown(roomy or b.side == "bottom")
  end
  for sp, sheet in pairs(UI.statsBySpec) do sheet:SetShown(sp == PR.spec) end
  UI.stats = UI.statsBySpec[PR.spec] or UI.stats
  UI.UpdateStats()
  local top = math.max(d.colH, UI.stats:GetHeight()) + 16
  local total = #BOTTOM * SLOT_SIZE + (#BOTTOM - 1) * 90
  for i, b in ipairs(d.bottom) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", d, "TOPLEFT", (H().ROW_W - total) / 2 + (i - 1) * (SLOT_SIZE + 90), -top)
  end
  d:SetHeight(top + SLOT_SIZE + 50) -- room for the 3-line labels under the weapons
  fillFlyout()
end
