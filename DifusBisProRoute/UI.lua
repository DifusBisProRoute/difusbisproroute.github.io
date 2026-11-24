-- Difu'sBisProRoute UI: main window (next step, route list, gear picker) and import/export box.
local ADDON, PR = ...
local UI = {}
PR.UI = UI

local GOLD = "|cffc69b6d"   -- warrior class colour
local RED = "|cffd0392b"
local GOOD, BAD = "|cff6cc07a", "|cffe5604f"
local W, H = 640, 780
local ROW_W = W - 56

local function qualityHex(q)
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
  return c and c.hex or "|cffffffff"
end

local function showItemTooltip(owner, id)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if GameTooltip.SetItemByID then GameTooltip:SetItemByID(id) else GameTooltip:SetHyperlink("item:" .. id) end
  local o = PR.ITEM[id]
  if o then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(GOLD .. PR.tx(o.src) .. "|r", 1, 1, 1, true)
    if o.verify then GameTooltip:AddLine(PR.T("verify"), 1, 0.4, 0.3, true) end
  end
  GameTooltip:Show()
end

local function backdrop(f, alpha)
  if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  f:SetBackdropColor(0.085, 0.068, 0.056, alpha or 1)
  f:SetBackdropBorderColor(0.78, 0.61, 0.43, 0.95)
end

-- dark steel buttons with a gold edge (replaces the default red panel buttons)
local function styleButton(b, primary)
  b.primary = primary
  if primary then
    b:SetBackdropColor(0.42, 0.30, 0.09, 1); b:SetBackdropBorderColor(1, 0.82, 0.25, 1)
    b.text:SetTextColor(1, 0.95, 0.80)
  else
    b:SetBackdropColor(0.13, 0.12, 0.11, 1); b:SetBackdropBorderColor(0.62, 0.50, 0.28, 1)
    b.text:SetTextColor(1, 0.82, 0)
  end
end
local function button(parent, w, label, primary)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, 22)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.text:SetPoint("CENTER", 0, 0)
  b.SetText = function(self, t) self.text:SetText(t) end
  b.GetText = function(self) return self.text:GetText() end
  b.GetFontString = function(self) return self.text end
  local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetPoint("TOPLEFT", 2, -2); hl:SetPoint("BOTTOMRIGHT", -2, 2)
  hl:SetColorTexture(1, 0.82, 0.3, 0.14)
  b:SetScript("OnMouseDown", function(self) self.text:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.text:SetPoint("CENTER", 0, 0) end)
  styleButton(b, primary)
  b:SetText(label or "")
  return b
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Talent-frame look: spec info + background art detected from the client
-- ---------------------------------------------------------------------------
local SPEC_INFO = {
  prot = { tab = 3, name = "Protection", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", bg = "WarriorProtection" },
  fury = { tab = 2, name = "Fury", icon = "Interface\\Icons\\Ability_Warrior_InnerRage", bg = "WarriorFury" },
  aff = { tab = 1, name = "Affliction", icon = "Interface\\Icons\\Spell_Shadow_DeathCoil", bg = "WarlockCurses" },
  demo = { tab = 2, name = "Demonology", icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis", bg = "WarlockSummoning" },
  destro = { tab = 3, name = "Destruction", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire", bg = "WarlockDestruction" },
}
local function specInfo(spec)
  -- GetTalentTabInfo returns different shapes per client; read it defensively
  local base = SPEC_INFO[spec or PR.spec] or SPEC_INFO.prot
  local info = { name = base.name, points = 0, icon = base.icon, bg = base.bg }
  if not GetTalentTabInfo then return info end
  local vals = { pcall(GetTalentTabInfo, base.tab) }
  if not vals[1] then return info end
  local names = {}
  for k = 2, #vals do
    local v = vals[k]
    if type(v) == "string" then
      if v:find("Interface") or v:find("\\") then info.icon = v
      elseif v:find("^Warrior") or v:find("^Warlock") then info.bg = v
      elseif #v < 32 then names[#names + 1] = v end
    elseif type(v) == "number" then
      if v > 1000 then info.iconId = info.iconId or v
      elseif v <= 71 and not info.pointsSet then info.points = v; info.pointsSet = true end
    end
  end
  if names[1] then info.name = names[1] end
  if info.iconId then info.icon = info.iconId end
  return info
end

local function fileExists(path)
  if GetFileIDFromPath then
    local ok, id = pcall(GetFileIDFromPath, path)
    return ok and id ~= nil and id ~= 0
  end
  return nil -- unknown
end

local function applyArt(f, area)
  local sp = specInfo()
  local bg = sp.bg or "WarriorProtection"
  local low = bg:lower()
  -- 1) atlases used by newer talent UIs
  if C_Texture and C_Texture.GetAtlasInfo then
    local cl = PR.IsWL() and "warlock-destruction" or "warrior-protection"
    for _, a in ipairs({ "talents-background-" .. low, "talents-background-" .. cl,
      "talentframe-background-" .. cl, "spec-background-" .. cl }) do
      if C_Texture.GetAtlasInfo(a) then
        local t = f:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetAtlas(a); t:SetAllPoints(area)
        UI.artSource = "atlas:" .. a
        return true
      end
    end
  end
  -- 2) single-file backgrounds
  local cl2 = PR.IsWL() and "warlock-destruction" or "warrior-protection"
  for _, path in ipairs({ "Interface\\TalentFrame\\" .. bg, "Interface\\TalentFrame\\bg-" .. cl2,
    "Interface\\TalentFrame\\talentbg-" .. cl2 }) do
    if fileExists(path) then
      local t = f:CreateTexture(nil, "BACKGROUND", nil, 1)
      t:SetTexture(path); t:SetAllPoints(area)
      UI.artSource = "file:" .. path
      return true
    end
  end
  -- 3) classic four-piece background (TopLeft 256x256, TopRight 64x256, BottomLeft 256x128, BottomRight 64x128)
  local base = "Interface\\TalentFrame\\" .. bg
  if fileExists(base .. "-TopLeft") then
    local parts = {
      { "-TopLeft", 0, 0, 0.8, 2 / 3 }, { "-TopRight", 0.8, 0, 1, 2 / 3 },
      { "-BottomLeft", 0, 2 / 3, 0.8, 1 }, { "-BottomRight", 0.8, 2 / 3, 1, 1 },
    }
    local holder = CreateFrame("Frame", nil, f)
    holder:SetAllPoints(area); holder:SetFrameLevel(f:GetFrameLevel())
    local function lay()
      local w, h = holder:GetWidth(), holder:GetHeight()
      for _, pp in ipairs(parts) do
        local t = pp.tex
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", holder, "TOPLEFT", pp[2] * w, -pp[3] * h)
        t:SetSize((pp[4] - pp[2]) * w, (pp[5] - pp[3]) * h)
      end
    end
    for _, pp in ipairs(parts) do
      pp.tex = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
      pp.tex:SetTexture(base .. pp[1])
      if pp[1] == "-TopLeft" then pp.tex:SetTexCoord(0, 1, 0, 1) end
    end
    holder:SetScript("OnSizeChanged", lay); lay()
    UI.artSource = "four:" .. base
    return true
  end
  -- 4) fallback: steel-blue keep at dusk, plus the spec icon as an emblem
  local t = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  t:SetAllPoints(area); t:SetColorTexture(0.10, 0.13, 0.17, 1)
  local g = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  g:SetAllPoints(area); g:SetColorTexture(1, 1, 1, 1)
  if g.SetGradient and CreateColor then
    pcall(g.SetGradient, g, "VERTICAL", CreateColor(0.05, 0.05, 0.06, 0.9), CreateColor(0.22, 0.30, 0.40, 0.55))
  else g:SetColorTexture(0, 0, 0, 0) end
  local e = f:CreateTexture(nil, "BACKGROUND", nil, 3)
  e:SetTexture(sp.icon); e:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  e:SetSize(300, 300); e:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -20, 20)
  e:SetAlpha(0.10); e:SetDesaturated(true)
  UI.artSource = "fallback"
  return false
end

local function tabButton(parent, w)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, 28)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.text:SetPoint("CENTER")
  b.SetText = function(self, t) self.text:SetText(t) end
  b.SetSelected = function(self, on)
    if on then
      self:SetBackdropColor(0.20, 0.15, 0.06, 0.95); self:SetBackdropBorderColor(1, 0.82, 0, 1)
      self.text:SetTextColor(1, 0.82, 0)
    else
      self:SetBackdropColor(0.08, 0.08, 0.09, 0.9); self:SetBackdropBorderColor(0.45, 0.45, 0.48, 1)
      self.text:SetTextColor(0.62, 0.62, 0.62)
    end
  end
  local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 0.82, 0, 0.08)
  b:SetSelected(false)
  return b
end

-- ---------------------------------------------------------------------------
-- Build
-- ---------------------------------------------------------------------------
function UI.Build()
  if UI.frame then return end
  local ok, f = pcall(CreateFrame, "Frame", "DifusBisProRouteFrame", UIParent, "PortraitFrameTemplate")
  local native = ok and f
  if not native then
    f = CreateFrame("Frame", "DifusBisProRouteFrame", UIParent, "BackdropTemplate")
    backdrop(f)
  end
  UI.frame = f
  f:SetSize(W, H)
  local pos = PR.db.pos
  if pos then f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("CENTER") end
  f:SetFrameStrata("HIGH"); f:SetToplevel(true)
  if PR.db.scale then f:SetScale(PR.db.scale) end
  f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    PR.db.pos = { p, rp, x, y }
  end)
  f:SetScript("OnShow", function() PR.db.hidden = false; PR.Refresh(false) end)
  f:SetScript("OnHide", function() PR.db.hidden = true end)
  tinsert(UISpecialFrames, "DifusBisProRouteFrame")

  -- title + portrait (native template) or own title
  local title = "Difu'sBisProRoute"
  if native and f.SetTitle then f:SetTitle(title)
  elseif native and f.TitleText then f.TitleText:SetText(title)
  else
    f.ownTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.ownTitle:SetPoint("TOP", 0, -12); f.ownTitle:SetText(title)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() f:Hide() end)
  end
  local classIcon = "Interface\\Icons\\ClassIcon_Warrior"
  if native then
    if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, classIcon)
    elseif f.portrait and SetPortraitToTexture then pcall(SetPortraitToTexture, f.portrait, classIcon) end
  end
  local top = native and -24 or -36 -- below the title bar

  -- spec header band (like the talent tree header)
  local band = CreateFrame("Frame", nil, f)
  band:SetPoint("TOPLEFT", native and 4 or 8, top); band:SetPoint("TOPRIGHT", native and -4 or -8, top); band:SetHeight(58)
  local bbg = band:CreateTexture(nil, "BACKGROUND", nil, 4); bbg:SetAllPoints(); bbg:SetColorTexture(0.07, 0.05, 0.03, 0.92)
  local bglow = band:CreateTexture(nil, "BACKGROUND", nil, 5); bglow:SetAllPoints(); bglow:SetColorTexture(1, 1, 1, 1)
  if bglow.SetGradient and CreateColor then
    pcall(bglow.SetGradient, bglow, "HORIZONTAL", CreateColor(0.55, 0.38, 0.08, 0.45), CreateColor(0.10, 0.07, 0.03, 0))
  else bglow:SetColorTexture(0, 0, 0, 0) end
  local line = band:CreateTexture(nil, "ARTWORK"); line:SetColorTexture(0.85, 0.68, 0.30, 0.9); line:SetHeight(2)
  line:SetPoint("BOTTOMLEFT", 8, 0); line:SetPoint("BOTTOMRIGHT", -8, 0)
  local diamond = band:CreateTexture(nil, "OVERLAY"); diamond:SetColorTexture(0.95, 0.78, 0.35, 1); diamond:SetSize(8, 8)
  diamond:SetPoint("CENTER", line, "CENTER"); if diamond.SetRotation then diamond:SetRotation(math.pi / 4) end
  local sp = specInfo()
  local ring = band:CreateTexture(nil, "ARTWORK", nil, 1)
  ring:SetSize(44, 44); ring:SetPoint("LEFT", native and 64 or 12, 0)
  ring:SetTexture(sp.icon)
  if ring.SetMask then pcall(ring.SetMask, ring, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
  local border = band:CreateTexture(nil, "ARTWORK", nil, 2)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetSize(78, 78)
  border:SetPoint("TOPLEFT", ring, "TOPLEFT", -6, 6)
  band.spec = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  band.spec:SetPoint("LEFT", ring, "RIGHT", 10, 6)
  band.sub = band:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  band.sub:SetPoint("TOPLEFT", band.spec, "BOTTOMLEFT", 0, -3)
  band.pts = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  band.pts:SetPoint("BOTTOMRIGHT", ring, "BOTTOMRIGHT", 4, -2)
  band.specName = sp.name; band.specPoints = sp.points
  band.ring = ring
  f.band = band

  -- spec switch (Prot / Fury, or the 3 Warlock specs), like the talent tree tabs
  local function specBtn(key, label, x)
    local b = tabButton(band, 58)
    b:SetPoint("RIGHT", -64 - x, 2)
    b:SetText(label)
    b:SetScript("OnClick", function()
      if PR.spec ~= key then
        PR.ApplySpec(key); UI.preview = nil; if UI.fly then UI.fly:Hide() end
        UI.Relabel(); PR.Refresh(false)
      end
    end)
    return b
  end
  f.specBtns = {}
  local specs = PR.ClassSpecs()
  for i = #specs, 1, -1 do
    local key = specs[i]
    f.specBtns[key] = specBtn(key, PR.T("spec_" .. key), (#specs - i) * 64)
  end

  local lang = tabButton(band, 46)
  lang:SetPoint("RIGHT", -12, 2)
  lang:SetScript("OnClick", function()
    PR.lang = (PR.lang == "es") and "en" or "es"; PR.db.lang = PR.lang
    UI.Relabel(); PR.Refresh(false)
  end)
  f.langBtn = lang

  -- art area behind everything below the band
  local area = CreateFrame("Frame", nil, f)
  area:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0); area:SetPoint("BOTTOMRIGHT", native and -4 or -8, native and 4 or 8)
  area:SetFrameLevel(f:GetFrameLevel() + 1)
  applyArt(area, area)
  local shade = area:CreateTexture(nil, "BACKGROUND", nil, 6); shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.35)

  local y0 = top - 58 - 10
  -- next step box
  local nx = CreateFrame("Frame", nil, f, "BackdropTemplate")
  nx:SetFrameLevel(area:GetFrameLevel() + 2)
  nx:SetPoint("TOPLEFT", 16, y0); nx:SetPoint("TOPRIGHT", -16, y0); nx:SetHeight(118)
  backdrop(nx, 1)
  nx:SetBackdropColor(0.16, 0.05, 0.04, 0.92)
  nx:SetBackdropBorderColor(0.85, 0.68, 0.30, 1)
  local stripe = nx:CreateTexture(nil, "ARTWORK"); stripe:SetColorTexture(0.69, 0.16, 0.13, 1); stripe:SetWidth(4)
  stripe:SetPoint("TOPLEFT", 4, -4); stripe:SetPoint("BOTTOMLEFT", 4, 4)
  nx.eyebrow = nx:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nx.eyebrow:SetTextColor(0.85, 0.68, 0.30)
  nx.eyebrow:SetPoint("TOPLEFT", 16, -12)
  nx.text = nx:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  nx.text:SetPoint("TOPLEFT", 16, -30); nx.text:SetPoint("RIGHT", -14, 0)
  nx.text:SetJustifyH("LEFT"); nx.text:SetWordWrap(true)
  nx.sub = nx:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  nx.sub:SetPoint("TOPLEFT", nx.text, "BOTTOMLEFT", 0, -6); nx.sub:SetPoint("RIGHT", -14, 0)
  nx.sub:SetJustifyH("LEFT"); nx.sub:SetWordWrap(true)
  nx.complete = button(nx, 110, nil, true); nx.complete:SetHeight(24); nx.complete:SetPoint("BOTTOMLEFT", 14, 12)
  nx.later = button(nx, 96); nx.later:SetHeight(24); nx.later:SetPoint("LEFT", nx.complete, "RIGHT", 8, 0)
  nx.skip = button(nx, 86); nx.skip:SetHeight(24); nx.skip:SetPoint("LEFT", nx.later, "RIGHT", 8, 0)
  nx.later:SetScript("OnClick", function() if UI.nextId then PR.char.steps[UI.nextId] = "later"; PR.Refresh(false) end end)
  nx.prog = nx:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  nx.prog:SetPoint("BOTTOMRIGHT", -14, 18)
  nx.complete:SetScript("OnClick", function() if UI.nextId then PR.char.steps[UI.nextId] = "done"; PR.Refresh(false) end end)
  nx.skip:SetScript("OnClick", function() if UI.nextId then PR.char.steps[UI.nextId] = "skipped"; PR.Refresh(false) end end)
  f.next = nx

  -- tabs (styled like the Primary/Secondary tabs)
  local ty = y0 - 118 - 12
  -- Gear first (pick your items), then the Route that gets them. The last tab used is remembered.
  UI.tab = (PR.char and PR.char.tab) or "gear"
  local tabs = {}
  local function mkTab(key, x)
    local t = tabButton(f, 118)
    t:SetHeight(32)
    t.text:SetFontObject("GameFontNormal")
    t:SetFrameLevel(area:GetFrameLevel() + 2)
    t:SetPoint("TOPLEFT", 16 + x, ty + 2)
    t:SetScript("OnClick", function()
      UI.tab = key; if PR.char then PR.char.tab = key end
      UI.preview = nil; if UI.fly then UI.fly:Hide() end; UI.SafeUpdate()
    end)
    tabs[key] = t
    return t
  end
  mkTab("gear", 0); mkTab("route", 122); mkTab("opt", 244)
  f.tabs = tabs
  local sync = tabButton(f, 120); sync:SetFrameLevel(area:GetFrameLevel() + 2); sync:SetPoint("TOPRIGHT", -16, ty)
  sync:SetScript("OnClick", function() UI.ShowIO("export") end)
  f.syncBtn = sync
  local simB = tabButton(f, 110); simB:SetFrameLevel(area:GetFrameLevel() + 2); simB:SetPoint("RIGHT", sync, "LEFT", -8, 0)
  simB:SetScript("OnClick", function() UI.ShowIO("sim") end)
  f.simBtn = simB

  local sd = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  sd:SetFrameLevel(area:GetFrameLevel() + 2)
  sd:SetSize(24, 24); sd:SetPoint("TOPLEFT", 16, ty - 32)
  sd:SetScript("OnClick", function(self) PR.char.showDone = self:GetChecked(); UI.SafeUpdate() end)
  sd.label = sd:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); sd.label:SetPoint("LEFT", sd, "RIGHT", 2, 0)
  f.showDone = sd
  local ss = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  ss:SetFrameLevel(area:GetFrameLevel() + 2)
  ss:SetSize(24, 24); ss:SetPoint("LEFT", sd.label, "RIGHT", 14, 0)
  ss:SetScript("OnClick", function(self) PR.char.showSkipped = self:GetChecked(); UI.SafeUpdate() end)
  ss.label = ss:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); ss.label:SetPoint("LEFT", ss, "RIGHT", 2, 0)
  f.showSkipped = ss

  -- scroll area on a dark glass panel so the art shows through softly
  local sf = CreateFrame("ScrollFrame", "DifusBisProRouteScroll", f, "UIPanelScrollFrameTemplate")
  sf:SetFrameLevel(area:GetFrameLevel() + 4)
  sf:SetPoint("TOPLEFT", 22, ty - 64); sf:SetPoint("BOTTOMRIGHT", -38, 20)
  local glass = CreateFrame("Frame", nil, f, "BackdropTemplate")
  glass:SetFrameLevel(area:GetFrameLevel() + 2)
  glass:SetPoint("TOPLEFT", sf, "TOPLEFT", -8, 8); glass:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", 30, -8)
  backdrop(glass, 0.72)
  glass:SetBackdropColor(0.03, 0.03, 0.04, 0.72)
  glass:SetBackdropBorderColor(0.55, 0.45, 0.25, 0.8)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(ROW_W, 10)
  sf:SetScrollChild(content)
  f.scroll, f.content = sf, content

  UI.headers, UI.rows, UI.opts, UI.toggles, UI.open = {}, {}, {}, {}, {}
  UI.BuildDoll(content)
  if UI.BuildOpt then UI.BuildOpt(content) end
  if PR.db.hidden then f:Hide() end
  UI.Relabel()
end

-- ---------------------------------------------------------------------------
-- Pools
-- ---------------------------------------------------------------------------
local function getHeader(i)
  local h = UI.headers[i]
  if not h then
    h = UI.frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    h:SetJustifyH("LEFT"); h:SetWidth(ROW_W); h:SetTextColor(1, 0.82, 0)
    UI.headers[i] = h
  end
  h:Show()
  return h
end

local function getRow(i)
  local r = UI.rows[i]
  if r then r:Show(); return r end
  r = CreateFrame("Frame", nil, UI.frame.content)
  r:SetSize(ROW_W, 40)
  r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
  r.check:SetSize(22, 22); r.check:SetPoint("TOPLEFT", 0, -1)
  r.title = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.title:SetPoint("TOPLEFT", 30, -4); r.title:SetPoint("RIGHT", -84, 0); r.title:SetJustifyH("LEFT"); r.title:SetWordWrap(true)
  r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4); r.sub:SetPoint("RIGHT", -84, 0); r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(true)
  r.btn = button(r, 80); r.btn:SetHeight(20); r.btn:SetPoint("TOPRIGHT", 0, -2)
  r.later = button(r, 80); r.later:SetHeight(20); r.later:SetPoint("TOPRIGHT", r.btn, "BOTTOMRIGHT", 0, -4)
  r.later:SetScript("OnClick", function() PR.char.steps[r.id] = "later"; PR.Refresh(false) end)
  r.hover = CreateFrame("Frame", nil, r)
  r.hover:SetPoint("TOPLEFT", 28, 0); r.hover:SetPoint("BOTTOMRIGHT", -84, 0)
  r.hover:SetScript("OnEnter", function(self) UI.StepTooltip(self, r.id) end)
  r.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
  r.check:SetScript("OnClick", function(self)
    if self:GetChecked() then PR.char.steps[r.id] = "done" else PR.char.steps[r.id] = nil end
    PR.Refresh(false)
  end)
  r.btn:SetScript("OnClick", function()
    local m = PR.char.steps[r.id]
    if m == "skipped" or m == "later" then PR.char.steps[r.id] = nil else PR.char.steps[r.id] = "skipped" end
    PR.Refresh(false)
  end)
  UI.rows[i] = r
  return r
end

local function getOpt(i)
  local o = UI.opts[i]
  if o then o:Show(); return o end
  o = CreateFrame("Frame", nil, UI.frame.content)
  o:SetSize(ROW_W, 56)
  o.pick = CreateFrame("CheckButton", nil, o, "UICheckButtonTemplate")
  o.pick:SetSize(20, 20); o.pick:SetPoint("LEFT", 0, 0)
  o.icon = CreateFrame("Button", nil, o)
  o.icon:SetSize(34, 34); o.icon:SetPoint("LEFT", 26, 0)
  o.icon.tex = o.icon:CreateTexture(nil, "ARTWORK"); o.icon.tex:SetAllPoints()
  o.icon:SetScript("OnEnter", function(self) UI.OptEnter(self, o) end)
  o.icon:SetScript("OnLeave", function() UI.OptLeave() end)
  o.icon:SetScript("OnClick", function() if IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(select(2, PR.GetItemInfo(o.id)) or "") end end)
  o.name = o:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  o.name:SetPoint("TOPLEFT", 70, -4); o.name:SetPoint("RIGHT", -110, 0); o.name:SetJustifyH("LEFT")
  o.sub = o:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  o.sub:SetPoint("TOPLEFT", o.name, "BOTTOMLEFT", 0, -3); o.sub:SetPoint("RIGHT", -110, 0); o.sub:SetJustifyH("LEFT")
  o.delta = o:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  o.delta:SetPoint("TOPLEFT", o.sub, "BOTTOMLEFT", 0, -3); o.delta:SetPoint("RIGHT", -110, 0); o.delta:SetJustifyH("LEFT")
  o.hover = CreateFrame("Frame", nil, o)
  o.hover:SetPoint("TOPLEFT", 70, 0); o.hover:SetPoint("BOTTOMRIGHT", -110, 0)
  o.hover:SetScript("OnEnter", function(self) UI.OptEnter(self, o) end)
  o.hover:SetScript("OnLeave", function() UI.OptLeave() end)
  o.have = CreateFrame("CheckButton", nil, o, "UICheckButtonTemplate")
  o.have:SetSize(22, 22); o.have:SetPoint("RIGHT", -84, 0)
  o.have:SetFrameLevel(o.hover:GetFrameLevel() + 2); o.pick:SetFrameLevel(o.hover:GetFrameLevel() + 2)
  o.state = o:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  o.state:SetPoint("LEFT", o.have, "RIGHT", 2, 0); o.state:SetWidth(82); o.state:SetJustifyH("LEFT")
  o.pick:SetScript("OnClick", function() PR.char.sel[o.slot] = o.id; PR.char.off[o.slot] = nil; PR.char.lastPre = nil; UI.open[o.slot] = nil; UI.preview = nil; PR.Refresh(false) end)
  o.have:SetScript("OnClick", function(self) PR.char.have[o.id] = self:GetChecked() and true or nil; PR.Refresh(false) end)
  UI.opts[i] = o
  return o
end

local function hideFrom(pool, n) for i = n, #pool do pool[i]:Hide() end end

-- ---------------------------------------------------------------------------
-- Tooltips
-- ---------------------------------------------------------------------------
function UI.StepTooltip(owner, id)
  local n = PR.NODE[id]
  if not n then return end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(PR.tx(n.title), 1, 0.82, 0)
  GameTooltip:AddLine(PR.tx(n.where), 0.7, 0.7, 0.7, true)
  GameTooltip:AddLine(" ")
  local d = PR.DescFor(n)
  if d ~= "" then GameTooltip:AddLine(d, 1, 1, 1, true) end
  if id == "reals" then GameTooltip:AddLine(string.format(PR.T("reals"), PR.CountReals()), 0.12, 1, 0) end
  if id == "t0" then GameTooltip:AddLine(string.format(PR.T("valor"), PR.ValorCount()), 0.12, 1, 0) end
  local items = PR.route.items[id]
  if items then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(PR.T("unlocks") .. ":", 0.84, 0.7, 0.35)
    for itemId in pairs(items) do
      local o = PR.ITEM[itemId]
      GameTooltip:AddLine("  " .. qualityHex(o and o.q) .. PR.ItemName(itemId) .. "|r")
    end
  end
  if n.verify then GameTooltip:AddLine(PR.T("verify"), 1, 0.4, 0.3, true) end
  GameTooltip:Show()
end

-- ---------------------------------------------------------------------------
-- Update
-- ---------------------------------------------------------------------------
function UI.Relabel()
  local f = UI.frame
  if not f then return end
  f.langBtn:SetText(PR.lang == "es" and "EN" or "ES")
  local sp = specInfo(PR.spec)
  f.band.specName, f.band.specPoints = sp.name, sp.points
  if f.band.ring then f.band.ring:SetTexture(sp.icon) end
  f.band.spec:SetText(f.band.specName)
  f.band.sub:SetText(PR.T(PR.IsWL() and "bandSubWL" or PR.IsFury() and "bandSubF" or "bandSub"))
  f.band.pts:SetText(f.band.specPoints and f.band.specPoints > 0 and tostring(f.band.specPoints) or "")
  if f.specBtns then for k, b in pairs(f.specBtns) do b:SetText(PR.T("spec_" .. k)); b:SetSelected(k == PR.spec) end end
  f.tabs.gear:SetText("|TInterface\\Icons\\INV_Chest_Plate03:18:18:0:0|t  " .. PR.T("gear"))
  f.tabs.route:SetText("|TInterface\\Icons\\INV_Misc_Map_01:18:18:0:0|t  " .. PR.T("route"))
  f.tabs.opt:SetText("|TInterface\\Icons\\INV_Misc_Bag_10:18:18:0:0|t  " .. PR.T("optTab")); f.syncBtn:SetText(PR.T("sync")); f.simBtn:SetText(PR.T("sim"))
  f.next.complete:SetText(PR.T("complete")); f.next.skip:SetText(PR.T("skip")); f.next.later:SetText(PR.T("later"))
  f.showDone.label:SetText(PR.T("showDone")); f.showSkipped.label:SetText(PR.T("showSkipped"))
end

local function itemList(id)
  local names = {}
  for itemId in pairs(PR.route.items[id] or {}) do
    local o = PR.ITEM[itemId]
    names[#names + 1] = qualityHex(o and o.q) .. PR.ItemName(itemId) .. "|r"
  end
  return table.concat(names, ", ")
end

function UI.SafeUpdate() xpcall(UI.Update, PR.Err) end

function UI.Update()
  local f = UI.frame
  if not f or not f:IsShown() or not PR.route then return end
  local r = PR.route

  -- next step + progress
  local active, done = 0, 0
  for _, id in ipairs(r.order) do
    local s = PR.Status(id)
    if s ~= "skipped" then active = active + 1; if s == "done" then done = done + 1 end end
  end
  local nxId = PR.NextStep()
  UI.nextId = nxId
  local nx = f.next
  if nxId then
    local n = PR.NODE[nxId]
    local ph = PR.PHASES[PR.PH_RANK[n.phase]]
    nx.eyebrow:SetText(PR.T("next") .. " · " .. PR.tx(ph.name))
    nx.text:SetText(PR.tx(n.title))
    nx.sub:SetText(PR.tx(n.where) .. "  -  " .. PR.T("unlocks") .. ": " .. itemList(nxId))
    nx.complete:Show(); nx.skip:Show(); nx.later:Show()
  else
    nx.eyebrow:SetText(PR.T("route"))
    local anyLater = false
    for _, id in ipairs(r.order) do if PR.Status(id) == "later" then anyLater = true end end
    nx.text:SetText(anyLater and PR.T("blockedLater") or (active > 0 and PR.T("done") or PR.T("empty")))
    nx.sub:SetText("")
    nx.complete:Hide(); nx.skip:Hide(); nx.later:Hide()
  end
  nx.prog:SetText(string.format(PR.T("progress"), done, active))

  for k, t in pairs(f.tabs) do t:SetSelected(k == UI.tab) end
  f.showDone:SetShown(UI.tab == "route"); f.showSkipped:SetShown(UI.tab == "route")
  f.showDone:SetChecked(PR.char.showDone); f.showSkipped:SetChecked(PR.char.showSkipped)

  local y, hi, ri, oi, ti = 0, 1, 1, 1, 1
  if UI.tab ~= "gear" then UI.doll:Hide(); if UI.fly then UI.fly:Hide() end; if UI.presetBar then UI.presetBar:Hide() end end
  if UI.tab ~= "opt" and UI.opt then UI.opt:Hide() end
  local function drawRow(id)
    local n, s = PR.NODE[id], PR.Status(id)
    local row = getRow(ri); ri = ri + 1
    row.id = id
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y)
    local auto = PR.auto[id] and PR.char.steps[id] ~= "done"
    local color = (s == "done" and "|cff7fbf7f") or (s == "skipped" and "|cff777777") or (s == "later" and "|cffc9a27a")
      or (id == nxId and GOLD) or "|cffffffff"
    row.title:SetText(color .. PR.tx(n.title) .. "|r" .. (auto and ("  |cff1eff00(" .. PR.T("auto") .. ")|r") or ""))
    row.sub:SetText(PR.tx(n.where) .. "  -  " .. itemList(id))
    row.check:SetChecked(s == "done")
    row.check:SetEnabled(s ~= "skipped" and not auto)
    row.btn:SetText((s == "skipped" and PR.T("restore")) or (s == "later" and PR.T("resume")) or PR.T("skip"))
    row.btn:SetShown(not auto)
    row.later:SetText(PR.T("later"))
    row.later:SetShown(s == "pending" and not auto)
    local hgt = math.max(s == "pending" and 50 or 34, row.title:GetStringHeight() + row.sub:GetStringHeight() + 16)
    row:SetHeight(hgt)
    y = y + hgt + 8
  end
  if UI.tab == "route" then
    for _, ph in ipairs(PR.PHASES) do
      local ids, tot, dn = {}, 0, 0
      for _, id in ipairs(r.order) do
        if PR.NODE[id].phase == ph.id then
          local s = PR.Status(id)
          if s ~= "skipped" then tot = tot + 1; if s == "done" then dn = dn + 1 end end
          if s ~= "later" and (s ~= "done" or PR.char.showDone) and (s ~= "skipped" or PR.char.showSkipped) then ids[#ids + 1] = id end
        end
      end
      if #ids > 0 then
        local h = getHeader(hi); hi = hi + 1
        h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y)
        h:SetText(PR.tx(ph.name) .. "  |cff888888" .. dn .. "/" .. tot .. "|r")
        y = y + 26
        for _, id in ipairs(ids) do
          drawRow(id)
        end
        y = y + 12
      end
    end
    local later = {}
    for _, id in ipairs(r.order) do if PR.Status(id) == "later" then later[#later + 1] = id end end
    if #later > 0 then
      local h = getHeader(hi); hi = hi + 1
      h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -(y + 6))
      h:SetText("|cffc9a27a" .. PR.T("laterT") .. "|r  |cff888888" .. #later .. "|r")
      y = y + 28
      for _, id in ipairs(later) do drawRow(id) end
    end
  elseif UI.tab == "opt" then
    hideFrom(UI.headers, 1); hideFrom(UI.rows, 1)
    UI.opt:ClearAllPoints(); UI.opt:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, 0); UI.opt:SetWidth(f.content:GetWidth())
    local ok, h = pcall(UI.UpdateOpt)
    if not ok then PR.Err(h); h = 0 end
    y = h + 10
  else
    -- gear tab: hide every route widget first, so nothing from Route can show through even if
    -- something below fails
    hideFrom(UI.headers, 1); hideFrom(UI.rows, 1)
    y = UI.UpdatePresets() + 14
    UI.doll:ClearAllPoints(); UI.doll:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -y)
    UI.doll:Show()
    local ok, err = pcall(UI.UpdateDoll)
    if not ok then PR.Err(err) end
    y = y + UI.doll:GetHeight() + 10
  end

  for i, t in pairs(UI.toggles) do t:SetShown(UI.tab == "gear" and i < ti) end
  hideFrom(UI.headers, hi); hideFrom(UI.rows, ri); hideFrom(UI.opts, oi)
  f.content:SetHeight(math.max(10, y))
end

-- ---------------------------------------------------------------------------
-- Slot "change" toggles and presets bar (gear tab)
-- ---------------------------------------------------------------------------
function UI.GetToggle(i)
  local t = UI.toggles[i]
  if not t then
    t = button(UI.frame.content, 120); t:SetHeight(22)
    t:SetScript("OnClick", function(self)
      UI.open[self.slot] = not UI.open[self.slot] or nil
      UI.preview = nil
      UI.SafeUpdate()
    end)
    UI.toggles[i] = t
  end
  t:Show()
  return t
end

StaticPopupDialogs["DIFUSBISPROROUTE_PRESET"] = {
  text = "%s", button1 = OKAY, button2 = CANCEL, hasEditBox = true, maxLetters = 32,
  OnAccept = function(self)
    local eb = self.editBox or self.EditBox
    local name = PR.SavePreset(eb and eb:GetText() or "")
    print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T("presetSaved"), name)); PR.Refresh(false)
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    local name = PR.SavePreset(self:GetText())
    print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T("presetSaved"), name)); parent:Hide(); PR.Refresh(false)
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Preset picker: one dropdown grouped like the web (BiS lists / optimized / my presets)
local function presetItems()
  local L = {
    { header = PR.T("pgLists") },
    { key = "wfb", label = "WoW Forever BiS List", run = function() PR.ApplyTag("wfb" .. PR.faction) end },
    { key = "wtbc", label = "wowtbc.gg", run = function() PR.ApplyTag("wtbc") end },
  }
  local function say(fmt, v) print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T(fmt), v)) end
  local function sayWL()
    local c = PR.Calc()
    print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T("doneWL"), c.hit, math.floor((PR.spec == "aff" and c.shadow or c.fire) + 0.5), c.crit, math.floor(c.ep + 0.5)))
  end
  if PR.IsWL() then
    L[#L + 1] = { header = PR.T("pgOptWL") }
    L[#L + 1] = { key = "opt", label = PR.T("optWL"), run = function() PR.ApplyMaxHit(); sayWL() end }
    L[#L + 1] = { key = "nocraft", label = PR.T("nocraftWL"), run = function() PR.ApplyMaxHit(nil, true); sayWL() end }
  elseif not PR.IsFury() then
    L[#L + 1] = { key = "bal", label = PR.T("balP"), run = function()
      if PR.ApplyRes("bal") then
        local c = PR.Calc()
        print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T("balDone"), c.D, c.hit))
      end
    end }
  end
  if PR.IsWL() then -- done above
  elseif PR.IsFury() then
    L[#L + 1] = { key = "su", label = "sixtyupgrades", run = function() PR.ApplyTag("su") end }
    L[#L + 1] = { header = PR.T("pgOptF") }
    L[#L + 1] = { key = "hit", label = PR.T("maxHitF"), run = function() say("maxHitDoneF", PR.ApplyMaxHit()) end }
    L[#L + 1] = { key = "nocraft", label = PR.T("nocraftPF"), run = function() say("nocraftDoneF", PR.ApplyMaxHit(nil, true)) end }
  else
    L[#L + 1] = { header = PR.T("pgOpt") }
    L[#L + 1] = { key = "hit", label = PR.T("maxHit"), run = function() say("maxHitDone", PR.ApplyMaxHit()) end }
    L[#L + 1] = { key = "tank", label = PR.T("tankP"), run = function() say("tankDone", PR.ApplyMaxHit("tank")) end }
    L[#L + 1] = { key = "nocraft", label = PR.T("nocraftP"), run = function() say("nocraftDone", PR.ApplyMaxHit(nil, true)) end }
    local function res(kind)
      local v, h, d = PR.ApplyRes(kind)
      if v then print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T("resDone"), v, h, d)) end
    end
    L[#L + 1] = { header = PR.T("pgRes") }
    L[#L + 1] = { key = "nr", label = PR.T("resNR"), run = function() res("nr") end }
    L[#L + 1] = { key = "fr", label = PR.T("resFR"), run = function() res("fr") end }
  end
  local mine = {}
  for i, p in ipairs(PR.char.presets) do
    if p.faction == PR.faction and (p.spec or "prot") == PR.spec then
      mine[#mine + 1] = { key = "c" .. i, label = p.name, custom = i, run = function()
        PR.ApplyPreset(i); print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T("presetApplied"), p.name)) end }
    end
  end
  if #mine > 0 then
    L[#L + 1] = { header = PR.T("pgMine") }
    for _, m in ipairs(mine) do L[#L + 1] = m end
  end
  return L
end

local function presetMenu()
  local m = UI.preMenu
  if m then return m end
  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent); catcher:SetFrameStrata("DIALOG"); catcher:SetFrameLevel(1); catcher:Hide()
  catcher:RegisterForClicks("AnyUp")
  m = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  m:SetFrameStrata("DIALOG"); m:SetFrameLevel(20); m:SetWidth(320); m:EnableMouse(true); m:Hide()
  backdrop(m)
  m:SetBackdropColor(0.07, 0.055, 0.045, 0.98); m:SetBackdropBorderColor(0.78, 0.61, 0.43, 1)
  m.rows = {}
  catcher:SetScript("OnClick", function() m:Hide() end)
  m:SetScript("OnShow", function() catcher:Show() end)
  m:SetScript("OnHide", function() catcher:Hide() end)
  tinsert(UISpecialFrames, "DifusBisProRoutePresetMenu"); _G.DifusBisProRoutePresetMenu = m
  UI.preMenu = m
  return m
end

local function openPresetMenu(anchor)
  local m = presetMenu()
  if m:IsShown() then m:Hide(); return end
  local items, y = presetItems(), -8
  for i, it in ipairs(items) do
    local r = m.rows[i]
    if not r then
      r = CreateFrame("Button", nil, m)
      r:SetHeight(22); r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      r.hl = r:CreateTexture(nil, "HIGHLIGHT"); r.hl:SetAllPoints(); r.hl:SetColorTexture(1, 0.82, 0.3, 0.16)
      r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", 10, 0); r.text:SetPoint("RIGHT", -8, 0)
      r.text:SetJustifyH("LEFT")
      r.check = r:CreateFontString(nil, "OVERLAY", "GameFontNormal"); r.check:SetPoint("RIGHT", -8, 0)
      m.rows[i] = r
    end
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, y); r:SetPoint("RIGHT", m, "RIGHT", -6, 0)
    if it.header then
      r.text:SetFontObject("GameFontNormalSmall"); r.text:SetText(string.upper(it.header)); r.text:SetTextColor(0.78, 0.61, 0.43)
      r.hl:SetAlpha(0); r.check:SetText(""); r:EnableMouse(false)
      r:SetHeight(20); y = y - 20
    else
      r.text:SetFontObject("GameFontHighlight"); r.text:SetText("   " .. it.label); r.text:SetTextColor(1, 1, 1)
      r.hl:SetAlpha(1); r:EnableMouse(true); r:SetHeight(22)
      r.check:SetText(PR.char.lastPre == it.key and "|TInterface\\RAIDFRAME\\ReadyCheck-Ready:14|t" or "")
      r:SetScript("OnClick", function(_, mouse)
        m:Hide()
        if it.custom and mouse == "RightButton" then
          local p = table.remove(PR.char.presets, it.custom)
          PR.char.lastPre = nil
          print(GOLD .. "Difu'sBisProRoute|r: " .. string.format(PR.T("presetDel"), p and p.name or "?"))
        else
          it.run(); PR.char.lastPre = it.key
        end
        PR.Refresh(false)
      end)
      r:SetScript("OnEnter", function(self)
        if it.custom then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(it.label, 0.78, 0.61, 0.43); GameTooltip:AddLine(PR.T("presetHint"), 1, 1, 1); GameTooltip:Show() end
      end)
      r:SetScript("OnLeave", function() GameTooltip:Hide() end)
      y = y - 22
    end
    r:Show()
  end
  for i = #items + 1, #m.rows do m.rows[i]:Hide() end
  m:SetHeight(-y + 8)
  m:SetScale(UI.frame:GetEffectiveScale() / UIParent:GetEffectiveScale())
  m:ClearAllPoints(); m:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
  m:Show()
end

function UI.UpdatePresets()
  local bar = UI.presetBar
  if not bar then
    bar = CreateFrame("Frame", nil, UI.frame.content)
    bar:SetPoint("TOPLEFT", 0, 0); bar:SetWidth(ROW_W); bar:SetHeight(26)
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal"); bar.label:SetPoint("LEFT", 0, 0)
    bar.drop = button(bar, 330); bar.drop:SetHeight(24); bar.drop:SetPoint("LEFT", bar.label, "RIGHT", 8, 0)
    bar.drop.text:ClearAllPoints(); bar.drop.text:SetPoint("LEFT", 10, 0); bar.drop.text:SetPoint("RIGHT", -24, 0); bar.drop.text:SetJustifyH("LEFT")
    bar.drop.arrow = bar.drop:CreateFontString(nil, "OVERLAY", "GameFontNormal"); bar.drop.arrow:SetPoint("RIGHT", -10, 0); bar.drop.arrow:SetText("v")
    bar.drop:SetScript("OnMouseDown", nil); bar.drop:SetScript("OnMouseUp", nil)
    bar.drop:SetScript("OnClick", function(self) openPresetMenu(self) end)
    bar.save = button(bar, 110); bar.save:SetHeight(24); bar.save:SetPoint("LEFT", bar.drop, "RIGHT", 8, 0)
    bar.save:SetScript("OnClick", function() StaticPopup_Show("DIFUSBISPROROUTE_PRESET", PR.T("presetName")) end)
    bar:SetScript("OnHide", function() if UI.preMenu then UI.preMenu:Hide() end end)
    UI.presetBar = bar
  end
  bar:Show()
  bar.label:SetText("Preset:")
  local cur
  for _, it in ipairs(presetItems()) do if it.key and it.key == PR.char.lastPre then cur = it.label end end
  bar.drop:SetText(cur or ("|cffaaaaaa" .. PR.T("presetPick") .. "|r"))
  bar.save:SetText(PR.T("savePreset"))
  return 26
end

-- ---------------------------------------------------------------------------
-- Tank caps panel (gear tab)
-- ---------------------------------------------------------------------------
local function pct(x) return string.format("%.2f%%", x) end
local function fmtDelta(d, fmt, lowerBetter)
  if math.abs(d) < 0.005 then return "" end
  local good = (lowerBetter and d < 0) or (not lowerBetter and d > 0)
  return " " .. (good and GOOD or BAD) .. (d > 0 and "+" or "") .. fmt(d) .. "|r"
end

function UI.DeltaText(a, b)
  local parts = {}
  local spec = PR.IsWL() and {
    { "hit", "Hit", function(x) return string.format("%.1f%%", x) end },
    { "sp", "SP", function(x) return string.format("%d", math.floor(x + 0.5)) end },
    { "crit", "Crit", function(x) return string.format("%.2f%%", x) end },
    { "int", "Int", function(x) return string.format("%d", math.floor(x + 0.5)) end },
    { "ep", "EP", function(x) return string.format("%.1f", x) end },
  } or PR.IsFury() and {
    { "hit", "Hit", function(x) return string.format("%.1f%%", x) end },
    { "crit", "Crit", function(x) return string.format("%.2f%%", x) end },
    { "ap", "AP", function(x) return string.format("%d", math.floor(x + 0.5)) end },
    { "exp", "Exp", function(x) return string.format("%.1f%%", x) end },
    { "ep", "EP", function(x) return string.format("%.1f", x) end },
  } or {
    { "D", "Def", function(x) return string.format("%d", math.floor(x + 0.5)) end },
    { "hit", "Hit", function(x) return string.format("%.1f%%", x) end },
    { "avoid", PR.T("avoidL"), function(x) return string.format("%.2f%%", x) end },
    { "block", PR.T("blockL"), function(x) return string.format("%.2f%%", x) end },
    { "armor", "Arm", function(x) return string.format("%d", math.floor(x + 0.5)) end },
    { "sta", "Sta", function(x) return string.format("%d", math.floor(x + 0.5)) end },
    { "ep", "EP", function(x) return string.format("%.1f", x) end },
  }
  for _, sp in ipairs(spec) do
    local d = (b[sp[1]] or 0) - (a[sp[1]] or 0)
    if math.abs(d) >= 0.005 then
      parts[#parts + 1] = (d > 0 and GOOD or BAD) .. (d > 0 and "+" or "") .. sp[3](d) .. " " .. sp[2] .. "|r"
    end
  end
  return #parts > 0 and table.concat(parts, "  ") or "|cff888888=|r"
end

function UI.OptEnter(owner, o)
  showItemTooltip(owner, o.id)
  local opt = PR.ITEM[o.id]
  local sl
  for _, s in ipairs(PR.SLOTS) do if s.k == o.slot then sl = s end end
  if sl and opt then
    local cur = PR.Selected(sl)
    for _, x in ipairs(sl.opts) do if x.id == o.id then opt = x end end
    if cur and cur.id ~= opt.id then
      UI.preview = { slot = sl.k, opt = opt }
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine(PR.T("ifPick"), 0.78, 0.61, 0.43)
      GameTooltip:AddLine(UI.DeltaText(PR.Calc(), PR.Calc(sl.k, opt)), 1, 1, 1, true)
      GameTooltip:Show()
      UI.UpdateStats()
    end
  end
end

function UI.OptLeave()
  GameTooltip:Hide()
  if UI.preview then UI.preview = nil; UI.UpdateStats() end
end

function UI.Toggle(show)
  if not UI.frame then UI.Build() end
  if show == nil then show = not UI.frame:IsShown() end
  UI.frame:SetShown(show)
end

-- ---------------------------------------------------------------------------
-- Import / export box
-- ---------------------------------------------------------------------------
function UI.ShowIO(mode)
  local io = UI.io
  if not io then
    io = CreateFrame("Frame", "DifusBisProRouteIO", UIParent, "BackdropTemplate")
    io:SetSize(560, 260); io:SetPoint("CENTER", 0, 120); io:SetFrameStrata("DIALOG")
    io:EnableMouse(true); io:SetMovable(true); io:RegisterForDrag("LeftButton")
    io:SetScript("OnDragStart", io.StartMoving); io:SetScript("OnDragStop", io.StopMovingOrSizing)
    backdrop(io)
    tinsert(UISpecialFrames, "DifusBisProRouteIO")
    io.label = io:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    io.label:SetPoint("TOPLEFT", 12, -12); io.label:SetPoint("RIGHT", -12, 0); io.label:SetJustifyH("LEFT"); io.label:SetWordWrap(true)
    local sf = CreateFrame("ScrollFrame", "DifusBisProRouteIOScroll", io, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -58); sf:SetPoint("BOTTOMRIGHT", -32, 40)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal); eb:SetWidth(490)
    eb:SetScript("OnEscapePressed", function() io:Hide() end)
    sf:SetScrollChild(eb)
    io.edit = eb
    -- neutral link to the project site (no donation request inside the game: Blizzard UI policy)
    io.web = io:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    io.web:SetPoint("BOTTOMRIGHT", -14, 16)
    io.web:SetText((PR.WEB_URL:gsub("^https://", ""):gsub("/$", "")))
    io.go = button(io, 100); io.go:SetPoint("BOTTOMLEFT", 12, 10)
    io.go:SetScript("OnClick", function()
      if PR.Import(io.edit:GetText()) then print(GOLD .. "Difu'sBisProRoute|r: " .. PR.T("imported")); io:Hide(); PR.Refresh(false)
      else print(GOLD .. "Difu'sBisProRoute|r: " .. PR.T("badImport")) end
    end)
    io.clear = button(io, 90); io.clear:SetPoint("LEFT", io.go, "RIGHT", 6, 0)
    io.clear:SetScript("OnClick", function() io.edit:SetText(""); io.edit:SetFocus() end)
    io.close = button(io, 80); io.close:SetPoint("BOTTOMRIGHT", -12, 10)
    io.close:SetScript("OnClick", function() io:Hide() end)
    UI.io = io
  end
  io.go:SetText(PR.T("import")); io.clear:SetText(PR.T("clear")); io.close:SetText(PR.T("close"))
  io:Show()
  if mode == "import" then
    io.label:SetText(PR.T("importTitle")); io.edit:SetText(""); io.go:Show(); io.clear:Show()
    io.edit:SetFocus()
  elseif mode == "web" then
    io.label:SetText(PR.T("webTitle")); io.go:Hide(); io.clear:Hide()
    io.edit:SetText(PR.WEB_URL); io.edit:SetFocus(); io.edit:HighlightText()
  elseif mode == "sim" then
    io.label:SetText(PR.T("simTitle")); io.go:Hide(); io.clear:Hide()
    local ok, url = xpcall(PR.SimURL, PR.Err)
    io.edit:SetText(ok and url or PR.SIM_URL); io.edit:SetFocus(); io.edit:HighlightText()
  else
    io.clear:Show()
    io.label:SetText(PR.T("exportTitle")); io.go:Show()
    local ok, txt = xpcall(PR.Export, PR.Err)
    io.edit:SetText(ok and txt or ""); io.edit:SetFocus(); io.edit:HighlightText()
  end
end

-- shared helpers for Doll.lua
UI.H = { showItemTooltip = showItemTooltip, backdrop = backdrop, button = button, qualityHex = qualityHex,
  GOLD = GOLD, GOOD = GOOD, BAD = BAD, ROW_W = ROW_W, styleButton = styleButton }
