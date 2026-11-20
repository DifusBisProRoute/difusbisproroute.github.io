-- Difu'sBisProRoute core: state, auto-detection, route computation, import/export.
local ADDON, PR = ...
_G.DifusBisProRoute = PR

-- ---------------------------------------------------------------------------
-- API compatibility: Forever's client moved several item/reputation globals into C_ namespaces
-- ---------------------------------------------------------------------------
local CI = C_Item or {}
PR.GetItemCount = CI.GetItemCount or _G.GetItemCount or function() return 0 end
PR.GetItemInfo = CI.GetItemInfo or _G.GetItemInfo or function() return nil end
PR.IsEquippedItem = CI.IsEquippedItem or _G.IsEquippedItem or function() return false end
PR.GetItemIcon = CI.GetItemIconByID or _G.GetItemIcon or function() return nil end
function PR.FactionStanding(id)
  if C_Reputation and C_Reputation.GetFactionDataByID then
    local d = C_Reputation.GetFactionDataByID(id)
    if d then return d.reaction end
  end
  if _G.GetFactionInfoByID then
    local _, _, st = _G.GetFactionInfoByID(id)
    return st
  end
end
local GetItemCount, GetItemInfo, IsEquippedItem = PR.GetItemCount, PR.GetItemInfo, PR.IsEquippedItem

function PR.Err(e)
  print("|cffff5555Difu'sBisProRoute error:|r " .. tostring(e))
  if debugstack then print(debugstack(2, 3, 0)) end
end

-- ---------------------------------------------------------------------------
-- Strings
-- ---------------------------------------------------------------------------
PR.L = {
  es = {
    title = "Difu'sBisProRoute", route = "Ruta", gear = "Equipo", sync = "Sincronizar", sim = "WoWSims", webTitle = "Web y actualizaciones (guía completa, novedades y descargas). Copia el enlace con Ctrl+C:", simTitle = "Copia este enlace (Ctrl+C) y pégalo en tu navegador: abre WoWSims Protection con el set elegido (y los enchants si están activados).",
    next = "Siguiente paso", unlocks = "Desbloquea", complete = "Completar", skip = "Omitir", restore = "Restaurar",
    progress = "%d / %d pasos", auto = "auto", done = "Ruta completa", empty = "No hay pasos pendientes",
    requires = "Requiere", verify = "Verificar fuente en Wowhead",
    equipped = "Equipado", bags = "En bolsas", bank = "En el banco", have = "Lo tengo", target = "Objetivo",
    showDone = "Mostrar hechos", showSkipped = "Mostrar omitidos",
    exportTitle = "EXPORTAR: copia este texto (Ctrl+C) y pégalo en la guía web (Fuentes y progreso > Importar desde el juego). IMPORTAR: pulsa Limpiar, pega (Ctrl+V) el texto de la guía (Copiar para el juego) y pulsa Importar.", clear = "Limpiar",
    importTitle = "Pega aquí (Ctrl+V) el texto de la guía web (Copiar para el juego) y pulsa Importar.",
    import = "Importar", close = "Cerrar", imported = "Plan importado desde la guía web.", badImport = "Texto inválido: debe empezar con PR1;",
    autoDone = "Paso completado automáticamente: %s", reals = "Tarnished Undermine Real: %d",
    valor = "Battlegear of Valor: %d/8 piezas", help = "/difu - abrir/cerrar | /difu export | /difu import | /difu lang es|en | /difu scale 0.6-1.4 | /difu sim | /difu web | /difu talentos | /difu debug | /difu reset",
    reset = "Progreso de este personaje reiniciado.", notWarrior = "Difu'sBisProRoute está pensado para Warrior; los datos son de Protection.",
    wfb = "WFB", wtbc = "WTBC",
    capsT = "Caps de tanque", model = "Plan: ítems + enchants + tus talentos y stats base, sin buffs · vs jefe 63",
    defL = "Defensa", hitL = "Hit", expL = "Pericia", crushL = "Anti-crush", critImm = "Inmune a críticos del jefe", critN = "El jefe te crítica %.2f%%",
    sbN = "Con Shield Block: %.2f%%", missL = "Fallo", dodgeL = "Esquiva", parryL = "Parada", blockL = "Bloqueo", avoidL = "Evasión total",
    armorL = "Armadura", hpL = "Vida aprox.", cur = "actual", ifPick = "Si eliges este ítem:",
    bandSub = "Ruta pre-raid · WoW Forever", bandSubF = "Ruta pre-raid DPS (dual wield) · WoW Forever", specProt = "Protection", specFury = "Fury", capsF = "Caps de Fury", modelF = "Ítems + enchants + Cruelty · Humano, sin buffs · vs jefe 63", secCapsF = "Caps", secOffF = "Daño", secMiscF = "Armas y vida", critTot = "Crítico total", apTot = "Poder de ataque", strT = "Fuerza", agiT = "Agilidad", mhL = "DPS mano derecha", ohL = "DPS mano izquierda", hitNoteF = "8%% = tope de especiales (blancos DW: 27%%) · máx. pre-raid: %.1f%%", expNoteF = "23.5 EP por 1%% hasta 6.5%%", talentsLiveF = "Talentos de tu personaje: Cruelty %d/5", talentsDefF = "No se pudieron leer tus talentos: se asume Cruelty 5/5", maxHitF = "Óptimo: 8% hit + EP", maxHitDoneF = "Preset Óptimo: %.1f%% de hit y máximo EP", nocraftPF = "Sin crafteos ni AH: 8% hit + EP", nocraftDoneF = "Preset Sin crafteos ni AH: %.1f%% de hit y máximo EP", pgOptF = "Optimizados (8% hit + máximo EP)", setOn = "Set activo: %s", secCaps = "Caps", secAvoid = "Evasión", secSurv = "Supervivencia", maxHit = "Óptimo (8% hit + 440 Def)", maxHitDone = "Preset Óptimo: %.1f%% de hit, 440+ Defensa y máximo EP", secOff = "Amenaza (EP)", tankP = "Tanque: 8% hit + 440 Def (aguante)", nocraftP = "Sin crafteos ni AH: 8% hit + 440 Def", nocraftDone = "Preset Sin crafteos ni AH: %.1f%% de hit con 440+ Defensa", presetPick = "Elegir preset...", pgLists = "Listas BiS", pgOpt = "Optimizados (8% hit + 440 Def)", pgMine = "Mis presets", tankDone = "Preset Tanque: %.1f%% de hit, 440+ Defensa y máximo aguante/armadura", strL = "Fuerza (equipo)", apL = "Poder de ataque (equipo)", critL = "Crítico (equipo)", epL = "EP (pesos WFB)",
    hitNote = "Tope, no mínimo · máx. pre-raid: %.1f%% con 440 Def (preset Óptimo)", maxHp = "Vida máxima", now = "Ahora", plan = "Plan",
    talentsLive = "Talentos de tu personaje: Anticipation %d/5 · Deflection %d/5 · Shield Spec %d/5",
    talentsDef = "No se pudieron leer tus talentos: se asume Anticipation 5/5 · Deflection 5/5 · Shield Spec 5/5", drL = "Reducción de daño", staL = "Aguante", bvL = "Valor de bloqueo", ignore = "Ignorar slot", slotHint = "Clic: cambiar entre las %d opciones. Clic derecho: ignorar slot.", later = "Después", laterT = "Para después", resume = "Retomar", change = "Cambiar (%d)", hide = "Ocultar",
    savePreset = "+ Guardar", presetName = "Nombre del preset:", presetSaved = "Preset guardado: %s", presetApplied = "Preset aplicado: %s",
    presetDel = "Preset borrado: %s", presetHint = "Clic: aplicar. Clic derecho: borrar.", blockedLater = "Lo que sigue depende de pasos que dejaste para después.",
  },
  en = {
    title = "Difu'sBisProRoute", route = "Route", gear = "Gear", sync = "Sync", sim = "WoWSims", webTitle = "Website and updates (full guide, news and downloads). Copy the link with Ctrl+C:", simTitle = "Copy this link (Ctrl+C) and paste it in your browser: it opens WoWSims Protection with the chosen set (and enchants when enabled).",
    next = "Next step", unlocks = "Unlocks", complete = "Complete", skip = "Skip", restore = "Restore",
    progress = "%d / %d steps", auto = "auto", done = "Route complete", empty = "No pending steps",
    requires = "Requires", verify = "Verify source on Wowhead",
    equipped = "Equipped", bags = "In bags", bank = "In bank", have = "I have it", target = "Target",
    showDone = "Show done", showSkipped = "Show skipped",
    exportTitle = "EXPORT: copy this text (Ctrl+C) and paste it in the web guide (Sources & progress > Import from the game). IMPORT: press Clear, paste (Ctrl+V) the text from the guide (Copy for the game) and press Import.", clear = "Clear",
    importTitle = "Paste (Ctrl+V) the text from the web guide (Copy for the game) and press Import.",
    import = "Import", close = "Close", imported = "Plan imported from the web guide.", badImport = "Invalid text: it must start with PR1;",
    autoDone = "Step completed automatically: %s", reals = "Tarnished Undermine Real: %d",
    valor = "Battlegear of Valor: %d/8 pieces", help = "/difu - toggle | /difu export | /difu import | /difu lang es|en | /difu scale 0.6-1.4 | /difu sim | /difu web | /difu talents | /difu debug | /difu reset",
    reset = "Progress for this character reset.", notWarrior = "Difu'sBisProRoute is built for Warriors; the data is for Protection.",
    wfb = "WFB", wtbc = "WTBC",
    capsT = "Tank caps", model = "Plan: items + enchants + your talents and base stats, unbuffed · vs boss 63",
    defL = "Defense", hitL = "Hit", expL = "Expertise", crushL = "Anti-crush", critImm = "Immune to boss crits", critN = "Boss crits you %.2f%%",
    sbN = "With Shield Block: %.2f%%", missL = "Miss", dodgeL = "Dodge", parryL = "Parry", blockL = "Block", avoidL = "Total avoidance",
    armorL = "Armor", hpL = "Approx. health", cur = "current", ifPick = "If you pick this item:",
    bandSub = "Pre-raid route · WoW Forever", bandSubF = "Pre-raid DPS route (dual wield) · WoW Forever", specProt = "Protection", specFury = "Fury", capsF = "Fury caps", modelF = "Items + enchants + Cruelty · Human, unbuffed · vs boss 63", secCapsF = "Caps", secOffF = "Damage", secMiscF = "Weapons & health", critTot = "Total crit", apTot = "Attack power", strT = "Strength", agiT = "Agility", mhL = "Main-hand DPS", ohL = "Off-hand DPS", hitNoteF = "8%% = special attack cap (DW white: 27%%) · pre-raid max: %.1f%%", expNoteF = "23.5 EP per 1%% up to 6.5%%", talentsLiveF = "Your talents: Cruelty %d/5", talentsDefF = "Could not read your talents: assuming Cruelty 5/5", maxHitF = "Optimal: 8% hit + EP", maxHitDoneF = "Optimal preset: %.1f%% hit and max EP", nocraftPF = "No crafts or AH: 8% hit + EP", nocraftDoneF = "No crafts / AH preset: %.1f%% hit and max EP", pgOptF = "Optimized (8% hit + max EP)", setOn = "Set bonus: %s", secCaps = "Caps", secAvoid = "Avoidance", secSurv = "Survival", maxHit = "Optimal (8% hit + 440 Def)", maxHitDone = "Optimal preset: %.1f%% hit, 440+ Defense and max EP", secOff = "Threat (EP)", tankP = "Tank: 8% hit + 440 Def (stamina)", nocraftP = "No crafts or AH: 8% hit + 440 Def", nocraftDone = "No crafts / AH preset: %.1f%% hit with 440+ Defense", presetPick = "Choose preset...", pgLists = "BiS lists", pgOpt = "Optimized (8% hit + 440 Def)", pgMine = "My presets", tankDone = "Tank preset: %.1f%% hit, 440+ Defense and max stamina/armor", strL = "Strength (gear)", apL = "Attack power (gear)", critL = "Crit (gear)", epL = "EP (WFB weights)",
    hitNote = "A cap, not a minimum · pre-raid max: %.1f%% at 440 Def (Optimal preset)", maxHp = "Max health", now = "Now", plan = "Plan",
    talentsLive = "Your talents: Anticipation %d/5 · Deflection %d/5 · Shield Spec %d/5",
    talentsDef = "Could not read your talents: assuming Anticipation 5/5 · Deflection 5/5 · Shield Spec 5/5", drL = "Damage reduction", staL = "Stamina", bvL = "Block value", ignore = "Ignore slot", slotHint = "Click: switch between the %d options. Right-click: ignore slot.", later = "Later", laterT = "Later", resume = "Resume", change = "Change (%d)", hide = "Hide",
    savePreset = "+ Save", presetName = "Preset name:", presetSaved = "Preset saved: %s", presetApplied = "Preset applied: %s",
    presetDel = "Preset deleted: %s", presetHint = "Click: apply. Right-click: delete.", blockedLater = "What comes next depends on steps you left for later.",
  },
}
function PR.T(key) return (PR.L[PR.lang] or PR.L.en)[key] or key end

-- pick a localized / faction-specific value from the generated data
function PR.tx(v)
  if v == nil then return "" end
  if type(v) == "string" then return v end
  if v.A or v.H then v = v[PR.faction] or v.A end
  if type(v) == "string" then return v end
  return v[PR.lang] or v.es or v.en or ""
end

-- ---------------------------------------------------------------------------
-- Auto-detection rules (IDs taken from the Forever quest/item database)
-- ---------------------------------------------------------------------------
PR.REALS = 226404
PR.VALOR = { 16730, 16731, 16732, 16733, 16734, 16735, 16736, 16737 }
PR.AUTO = {
  key_dm      = { items = { 18249 } },
  key_scholo  = { items = { 13704 }, quests = { A = { 5505 }, H = { 5511 } } },
  key_ubrs    = { items = { 12344 }, quests = { 4743 } },
  ad_honored  = { rep = { 529, 6 } },
  eng         = { skill = { "Engineering", "Ingeniería", 300 } },
  q_hyjal     = { quests = { 93848 } },
  q_codex     = { quests = { 7499 } },
  q_dreams    = { quests = { 5944 } },
  q_gorewood  = { quests = { A = { 6187 }, H = { 6148 } } },
  q_head      = { quests = { 92446 } },
  q_revantusk = { quests = { 7862 } },
  rep_wsg     = { rep = { 890, 8 } },
  rep_av      = { rep = { A = { 730, 8 }, H = { 729, 8 } } },
  t0          = { valor = true },
  t1          = { quests = { A = { 8912 }, H = { 8920 } } },
  t2          = { quests = { 8928 } },
  t3          = { quests = { A = { 8937 }, H = { 8944 } } },
  t4          = { quests = { 8946 } },
  t5          = { quests = { 8950 } },
  t6          = { quests = { 9015 } },
  t7          = { quests = { A = { 8959 }, H = { 9022 } } },
  t8          = { quests = { 8961 } },
  t9          = { quests = { 8966, 8967, 8968, 8969 } },
  t10         = { quests = { 8989, 8990, 8991, 8992 } },
  t11         = { quests = { 8995 } },
  t12         = { quests = { A = { 9006 }, H = { 9013 } } },
}

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
PR.NODE, PR.PH_RANK, PR.ITEM = {}, {}, {}
for i, n in ipairs(PR.NODES) do n.i = i; PR.NODE[n.id] = n end
for i, p in ipairs(PR.PHASES) do PR.PH_RANK[p.id] = i end
-- every option knows its spec and slot; PR.ITEM lists the current spec first, then the other one
for spec, list in pairs(PR.SPEC_SLOTS) do
  for _, sl in ipairs(list) do
    for _, o in ipairs(sl.opts) do o.spec = spec; o.slot = sl.k end
  end
end
PR.spec = "prot"
function PR.IsFury() return PR.spec == "fury" end
function PR.IndexItems()
  wipe(PR.ITEM)
  local order = { PR.spec }
  for sp in pairs(PR.SPEC_SLOTS) do if sp ~= PR.spec then order[#order + 1] = sp end end
  for _, sp in ipairs(order) do
    for _, sl in ipairs(PR.SPEC_SLOTS[sp]) do
      for _, o in ipairs(sl.opts) do if not PR.ITEM[o.id] then PR.ITEM[o.id] = o end end
    end
  end
end
-- switch spec: slots, item index, per-spec selection table (PR.char.sel keeps pointing at the active one)
function PR.ApplySpec(spec)
  if not PR.SPEC_SLOTS[spec] then spec = "prot" end
  PR.spec = spec
  PR.SLOTS = PR.SPEC_SLOTS[spec]
  PR.IndexItems()
  if PR.char then
    if PR.char.spec ~= spec then PR.char.lastPre = nil end
    PR.char.spec = spec
    PR.char.selBySpec = PR.char.selBySpec or {}
    PR.char.selBySpec[spec] = PR.char.selBySpec[spec] or {}
    PR.char.sel = PR.char.selBySpec[spec]
  end
  if PR.InvalidateOpt then PR.InvalidateOpt() end
end
PR.IndexItems()

-- ---------------------------------------------------------------------------
-- Game queries
-- ---------------------------------------------------------------------------
local function questDone(id)
  if PR.char and PR.char.turnedIn[id] then return true end
  if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then return C_QuestLog.IsQuestFlaggedCompleted(id) and true or false end
  if IsQuestFlaggedCompleted then return IsQuestFlaggedCompleted(id) and true or false end
  return false
end
PR.questDone = questDone

function PR.Owned(id)
  if IsEquippedItem(id) then return "equipped" end
  local bags = GetItemCount(id) or 0
  if bags > 0 then return "bags" end
  local all = GetItemCount(id, true) or 0
  if all > bags or (PR.char and PR.char.bank[id]) then return "bank" end
  return nil
end

function PR.CountReals()
  return GetItemCount(PR.REALS, true) or 0
end

function PR.ValorCount()
  local c = 0
  for _, id in ipairs(PR.VALOR) do if PR.Owned(id) then c = c + 1 end end
  return c
end

local function repAtLeast(factionID, standing)
  local st = PR.FactionStanding(factionID)
  return st ~= nil and st >= standing
end

local function skillAtLeast(n1, n2, value)
  if not GetNumSkillLines then return false end
  for i = 1, GetNumSkillLines() do
    local name, isHeader, _, rank = GetSkillLineInfo(i)
    if not isHeader and (name == n1 or name == n2) and (rank or 0) >= value then return true end
  end
  return false
end

local function list(v)
  if not v then return {} end
  if v.A or v.H then return v[PR.faction] or {} end
  return v
end

local function rawAuto(id)
  local r = PR.AUTO[id]
  if not r then return false end
  for _, q in ipairs(list(r.quests)) do if questDone(q) then return true end end
  for _, it in ipairs(r.items or {}) do if PR.Owned(it) then return true end end
  local rp = r.rep and (r.rep.A and r.rep[PR.faction] or r.rep)
  if rp and rp[1] and repAtLeast(rp[1], rp[2]) then return true end
  if r.skill and skillAtLeast(r.skill[1], r.skill[2], r.skill[3]) then return true end
  if r.valor and PR.ValorCount() >= 8 then return true end
  return false
end

-- auto-done set: direct detection, then propagate to prerequisites of done steps
function PR.ComputeAuto()
  local auto = {}
  for _, n in ipairs(PR.NODES) do if rawAuto(n.id) then auto[n.id] = true end end
  local changed = true
  while changed do
    changed = false
    for _, n in ipairs(PR.NODES) do
      if auto[n.id] then
        for _, d in ipairs(n.deps) do
          if not auto[d] then auto[d] = true; changed = true end
        end
      end
    end
  end
  PR.auto = auto
  return auto
end

-- ---------------------------------------------------------------------------
-- Selection, ownership, route
-- ---------------------------------------------------------------------------
function PR.OptsFor(sl)
  local out = {}
  for _, o in ipairs(sl.opts) do
    if (not o.fac or o.fac == PR.faction) and #out < 5 then out[#out + 1] = o end
  end
  return out
end

local function hasTag(o, tag)
  for _, b in ipairs(o.bis or {}) do if b == tag then return true end end
  return false
end
PR.hasTag = hasTag

function PR.Selected(sl)
  local opts, id = PR.OptsFor(sl), PR.char.sel[sl.k]
  for _, o in ipairs(opts) do if o.id == id then return o end end
  for _, o in ipairs(opts) do if hasTag(o, "wfb" .. PR.faction) then return o end end
  return opts[1]
end

function PR.ApplyTag(tag)
  for _, sl in ipairs(PR.SLOTS) do
    for _, o in ipairs(PR.OptsFor(sl)) do
      if hasTag(o, tag) then PR.char.sel[sl.k] = o.id; break end
    end
  end
end
-- Best hit while keeping the 440 defense cap (DP over slots on item defense, capped at what is needed).
-- Memoized: the result only depends on faction, talents, enchants and ignored slots, never on the
-- current selection, so hovering/clicking items reuses it instead of re-running the DP.
PR.optCache = {}
function PR.InvalidateOpt() PR.optCache = {} end
local function optKey(u, mode, noCraft)
  local R = PR.Ranks()
  local t = { PR.spec, PR.faction or "?", u and 1 or 0, mode or "ep", noCraft and "nc" or "all", R.anticip, PR.useEnchants and 1 or 0 }
  for _, sl in ipairs(PR.SLOTS) do if PR.char.off[sl.k] then t[#t + 1] = sl.k end end
  return table.concat(t, "|")
end

-- mode "ep" (default) = WFB stat weights · "tank" = the original version: only Stamina + armor
-- noCraft: only looted / quest / vendor / reputation items (nothing crafted, nothing from the Auction House)
PR.CRAFT_REQ = { craft = true, bs = true, plans = true, eng = true, ah = true, lw = true, prof_bs = true }
function PR.IsCraftOrAH(o)
  for _, r in ipairs(o.req or {}) do if PR.CRAFT_REQ[r] then return true end end
  return false
end
local runOpt
function PR.OptimizeHit(useUnverified, mode, noCraft)
  local ck = optKey(useUnverified, mode, noCraft)
  if PR.optCache[ck] then return PR.optCache[ck] end
  local res = runOpt(useUnverified, mode, noCraft, nil)
  if PR.IsFury() then
    -- also try forcing each 2-piece set bonus (Devilsaur = +2% hit), keep the better result
    for name, sb in pairs(PR.SET_BONUS or {}) do
      local forced, n = {}, 0
      for _, sl in ipairs(PR.SLOTS) do
        if not PR.char.off[sl.k] then
          for _, o in ipairs(PR.OptsFor(sl)) do
            if o.set == name and not (noCraft and PR.IsCraftOrAH(o)) and (useUnverified or not o.verify) then forced[sl.k] = o; n = n + 1; break end
          end
        end
      end
      if n >= sb.need then
        local r = runOpt(useUnverified, mode, noCraft, { forced = forced, st = sb.st })
        if r and (r.h > res.h or (r.h == res.h and r.score > res.score)) then res = r end
      end
    end
  end
  PR.optCache[ck] = res
  return res
end

runOpt = function(useUnverified, mode, noCraft, variant)
  local fury = PR.IsFury()
  local R = PR.Ranks()
  local enchDef = 0
  if PR.useEnchants then
    for _, sl in ipairs(PR.SLOTS) do
      if not PR.char.off[sl.k] and sl.ench and sl.ench.st and sl.ench.st.def then enchDef = enchDef + sl.ench.st.def end
    end
  end
  local need = fury and 0 or math.max(0, PR.MODEL.defCap - 300 - R.anticip * PR.TALENTS.anticip.per - enchDef)
  local HC = math.floor((fury and PR.FMODEL.hitCap or PR.MODEL.hitCap) * 10 + 0.5)
  -- state key: defense (capped at need) * 1000 + hit tenths (capped). Nodes keep a parent pointer
  -- instead of copying the whole pick table (no per-state garbage).
  local h0 = variant and variant.st.hit or 0
  local nh0 = math.min(HC, math.floor(h0 * 10 + 0.5))
  local dp = { [nh0] = { d = 0, h = nh0, hit = h0, score = fury and h0 * PR.EPW_F.hit or 0 } }
  for _, sl in ipairs(PR.SLOTS) do
    if not PR.char.off[sl.k] then
      local opts, filtered = PR.OptsFor(sl), {}
      for _, o in ipairs(opts) do if useUnverified or not o.verify then filtered[#filtered + 1] = o end end
      if #filtered > 0 then opts = filtered end
      if noCraft then
        local nc = {}
        for _, o in ipairs(opts) do if not PR.IsCraftOrAH(o) then nc[#nc + 1] = o end end
        opts = nc
      end
      if variant and variant.forced[sl.k] then opts = { variant.forced[sl.k] } end
      local k, nx = sl.k, {}
      if #opts == 0 then nx = dp end
      for _, v in pairs(#opts > 0 and dp or {}) do
        for _, o in ipairs(opts) do
          if not ((k == "finger2" and v.f1 == o.id) or (k == "trinket2" and v.t1 == o.id)) then
            local st = o.st or {}
            local nd = math.min(need, v.d + (st.def or 0))
            local hit = v.hit + (st.hit or 0)
            local nh = math.min(HC, math.floor(hit * 10 + 0.5))
            local score = v.score + (mode == "tank" and ((st.sta or 0) + (st.armor or 0) / 20) or PR.EP(o, k))
            local key = nd * 1000 + nh
            local cur = nx[key]
            if not cur or score > cur.score then
              nx[key] = { d = nd, h = nh, hit = hit, score = score, prev = v, slot = k, id = o.id,
                f1 = (k == "finger1") and o.id or v.f1, t1 = (k == "trinket1") and o.id or v.t1 }
            end
          end
        end
      end
      dp = nx
    end
  end
  local best
  for _, v in pairs(dp) do
    if v.d >= need and (not best or v.h > best.h or (v.h == best.h and v.score > best.score)) then best = v end
  end
  if not best then
    for _, v in pairs(dp) do if not best or v.d > best.d or (v.d == best.d and v.h > best.h) then best = v end end
  end
  local res = { d = best.d, h = best.h, hit = best.hit, score = best.score, pick = {} }
  local n = best
  while n and n.slot do res.pick[n.slot] = n.id; n = n.prev end
  return res
end

function PR.ApplyMaxHit(mode, noCraft)
  local best = PR.OptimizeHit(false, mode, noCraft)
  for k, id in pairs(best.pick) do PR.char.sel[k] = id end
  return best.hit
end

function PR.SavePreset(name)
  local sel = {}
  for _, sl in ipairs(PR.SLOTS) do sel[sl.k] = PR.Selected(sl).id end
  if not name or name == "" then name = "Preset " .. (#PR.char.presets + 1) end
  table.insert(PR.char.presets, { name = name, faction = PR.faction, spec = PR.spec, sel = sel })
  return name
end
function PR.ApplyPreset(i)
  local p = PR.char.presets[i]
  if p then for k, v in pairs(p.sel) do PR.char.sel[k] = v end end
  return p
end

function PR.Has(id) return PR.char.have[id] or PR.Owned(id) ~= nil end

-- ---------------------------------------------------------------------------
-- Tank stat model (same formulas as the web guide)
-- Level 60 Warrior vs level 63 boss (skill 315). WFB talents 5/15/31: Deflection +5% parry,
-- Anticipation +10 defense, Shield Specialization +5% block. Human base stats, unbuffed.
-- ---------------------------------------------------------------------------
PR.MODEL = { baseAgi = 80, baseSta = 110, baseHP = 1689, anticip = 10, deflect = 5, shieldSpec = 5,
  bossSkill = 315, bossLvl = 63, defCap = 440, hitCap = 8, expCap = 6.5, crushCap = 102.4 }
PR.useEnchants = true

-- Talents that change tank stats. Names in English and Spanish clients.
-- Each talent is recognised three ways, so it works on any client language and on Forever's tree:
-- 1) localized name, 2) its icon, 3) its classic tree position (tab, tier, column) with 5 max ranks.
PR.TALENTS = {
  anticip = { per = 4, id = 12297, pos = { 3, 2, 1 }, icon = "spell_nature_mirrorimage",                 -- Forever: +4 defense per rank
    names = { "Anticipation", "Anticipación", "Antecipação", "Antizipation", "Anticipazione" } },
  deflect = { per = 1, id = 16462, pos = { 1, 1, 2 }, icon = "ability_parry",                             -- +1% parry per rank
    names = { "Deflection", "Desvío", "Desviación", "Deflexão", "Abwehr", "Déviation", "Deviazione" } },
  shieldSpec = { per = 1, id = 12298, pos = { 3, 1, 2 }, icon = "inv_shield_06",                          -- +1% block per rank
    names = { "Shield Specialization", "Especialización en escudos", "Especialización con escudos",
      "Especialização em Escudo", "Schildspezialisierung", "Spécialisation Bouclier", "Specializzazione in Scudi" } },
  tough = { per = 2, pos = { 0, 0, 0 }, icon = "spell_holy_devotion",                         -- +2% armor; not in the Forever warrior tree
    names = { "Toughness", "Dureza", "Robustez", "Zähigkeit", "Robustesse", "Robustezza" } },
  cruelty = { per = 1, id = 12320, pos = { 2, 1, 3 }, icon = "ability_rogue_eviscerate",                  -- Fury: +1% crit per rank
    names = { "Cruelty", "Crueldad", "Crueldade", "Grausamkeit", "Cruauté", "Crudeltà" } },
}
PR.DEFAULT_RANKS = { anticip = 5, deflect = 5, shieldSpec = 5, tough = 0, cruelty = 5 }

local iconIdCache = {}
local function iconMatches(tex, wanted)
  if not tex then return false end
  if type(tex) == "string" then return tex:lower():find(wanted, 1, true) ~= nil end
  if GetFileIDFromPath then
    local id = iconIdCache[wanted]
    if id == nil then
      local ok, v = pcall(GetFileIDFromPath, "Interface\\Icons\\" .. wanted)
      id = (ok and v) or false; iconIdCache[wanted] = id
    end
    return id and id == tex or false
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Talent API adapter. Clients expose talents in different shapes:
--   classic   GetTalentInfo(tab, i) -> name, icon, tier, column, rank, maxRank
--   newer     C_SpecializationInfo.GetTalentInfo({ specializationIndex = tab, talentIndex = i }) -> table
-- Every call is pcall'd, so a client with a different signature never throws an error.
-- ---------------------------------------------------------------------------
PR.talentErr = nil
local function noteErr(e) if not PR.talentErr and e then PR.talentErr = tostring(e) end end

local function numTabs()
  if GetNumTalentTabs then
    local ok, n = pcall(GetNumTalentTabs)
    if ok and type(n) == "number" and n > 0 then return n end
    if not ok then noteErr(n) end
  end
  return 3 -- warriors: Arms, Fury, Protection
end

local function fromTable(t)
  if type(t) ~= "table" then return nil end
  local name = t.name or t.talentName
  if not name then return nil end
  return name, t.icon or t.fileID or t.texture, t.tier or t.row, t.column or t.col,
    t.rank or t.currentRank or (t.selected and 1) or 0, t.maxRank or t.maxRanks or 5
end

-- Calls fn(tab, name, icon, tier, column, rank, maxRank) for every talent the client exposes.
--   classic clients: GetTalentInfo(tab, index)
--   WoW Forever:     only C_SpecializationInfo.GetTalentInfo(query), and the query needs tier + column
--                    ("query.tier must be specified"), so we walk the tree grid: tab x tier x column.
PR.talentRaw = nil
local function rawKeys(t)
  local k = {}
  for key, v in pairs(t) do k[#k + 1] = tostring(key) .. "=" .. tostring(v) end
  table.sort(k)
  return table.concat(k, ", ")
end

local function forEachTalentClassic(fn)
  for tab = 1, numTabs() do
    local n = 30
    if GetNumTalents then
      local ok, v = pcall(GetNumTalents, tab)
      if ok and type(v) == "number" and v > 0 then n = v elseif not ok then noteErr(v) end
    end
    for i = 1, n do
      local ok, a, b, c, d, e, f = pcall(GetTalentInfo, tab, i)
      if ok then
        if type(a) == "string" then fn(tab, a, b, c, d, e, f)
        else
          local nm, ic, ti, co, rk, mx = fromTable(a)
          if nm then fn(tab, nm, ic, ti, co, rk, mx) end
        end
      else noteErr(a); break end
    end
  end
end

-- C_SpecializationInfo.GetTalentInfo(query): the query shape differs between clients, so we try
-- several shapes on a few cells and keep the first one that returns a talent. Results can be a
-- table or classic-style multiple values (name, icon, tier, column, rank, maxRank).
local QUERY = {
  { "spec+tier+col+group", function(tab, ti, co) return { specializationIndex = tab, tier = ti, column = co, groupIndex = 1, isInspect = false } end },
  { "spec+tier+col",       function(tab, ti, co) return { specializationIndex = tab, tier = ti, column = co } end },
  { "tier+col (no spec)",  function(tab, ti, co) return { tier = ti, column = co, groupIndex = 1, isInspect = false, target = "player" } end },
  { "0-based spec/tier/col", function(tab, ti, co) return { specializationIndex = tab - 1, tier = ti - 1, column = co - 1 } end },
  { "spec 1-based, tier/col 0-based", function(tab, ti, co) return { specializationIndex = tab, tier = ti - 1, column = co - 1 } end },
  { "spec 0-based, tier/col 1-based", function(tab, ti, co) return { specializationIndex = tab - 1, tier = ti, column = co } end },
  { "talentIndex", function(tab, ti, co) return { specializationIndex = tab, talentIndex = (ti - 1) * 4 + co, tier = ti, column = co } end },
}
PR.talentProbe = nil
PR.talentQuery = nil -- index into QUERY once one works

local function callCS(q)
  local r = { pcall(C_SpecializationInfo.GetTalentInfo, q) }
  if not r[1] then return false, r[2] end
  local a = r[2]
  if type(a) == "table" then
    if not PR.talentRaw then PR.talentRaw = rawKeys(a) end
    return true, fromTable(a)
  elseif type(a) == "string" then
    if not PR.talentRaw then
      local parts = {}
      for k = 2, math.min(#r, 10) do parts[#parts + 1] = tostring(r[k]) end
      PR.talentRaw = "multi: " .. table.concat(parts, ", ")
    end
    return true, a, r[3], r[4], r[5], r[6], r[7]
  end
  return true, nil, type(a)
end

local function pickQuery()
  if PR.talentQuery then return PR.talentQuery end
  local report = {}
  for qi, Q in ipairs(QUERY) do
    local nils, errs, firstErr, retType = 0, 0, nil, nil
    for tab = 1, 3 do for ti = 1, 3 do for co = 1, 4 do
      local ok, nm, ic = callCS(Q[2](tab, ti, co))
      if not ok then errs = errs + 1; firstErr = firstErr or nm
      elseif nm then
        report[#report + 1] = Q[1] .. ": OK"
        PR.talentProbe = table.concat(report, " | ")
        PR.talentQuery = qi
        return qi
      else nils = nils + 1; retType = retType or ic end
    end end end
    report[#report + 1] = string.format("%s: %d %s, %d err%s", Q[1], nils, tostring(retType or "nil"), errs,
      firstErr and (" (" .. tostring(firstErr):sub(1, 60) .. ")") or "")
  end
  PR.talentProbe = table.concat(report, " | ")
  return nil
end


-- WoW Forever stores talents in the trait system (C_ClassTalents / C_Traits), like retail.
-- Walk every node of the active config; the talent is identified by its spell ID (and name).
local function spellName(id)
  if not id then return nil end
  if C_Spell and C_Spell.GetSpellName then local ok, n = pcall(C_Spell.GetSpellName, id); if ok and n then return n end end
  if C_Spell and C_Spell.GetSpellInfo then local ok, i = pcall(C_Spell.GetSpellInfo, id); if ok and type(i) == "table" then return i.name end end
  if GetSpellInfo then local ok, n = pcall(GetSpellInfo, id); if ok then return n end end
end

PR.talentTraits = nil -- diagnostics: "config N, trees T, nodes X, bought Y"
local function forEachTrait(fn)
  if not (C_Traits and C_Traits.GetConfigInfo and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo
          and C_ClassTalents and C_ClassTalents.GetActiveConfigID) then return false end
  local okA, configID = pcall(C_ClassTalents.GetActiveConfigID)
  if not okA then noteErr(configID); return false end
  if not configID then PR.talentTraits = "no active config"; return false end
  local okC, cfg = pcall(C_Traits.GetConfigInfo, configID)
  if not okC then noteErr(cfg); return false end
  if type(cfg) ~= "table" or type(cfg.treeIDs) ~= "table" then PR.talentTraits = "config " .. tostring(configID) .. " has no trees"; return false end
  local nodes, bought, any = 0, 0, false
  for _, treeID in ipairs(cfg.treeIDs) do
    local okN, list = pcall(C_Traits.GetTreeNodes, treeID)
    for _, nodeID in ipairs(okN and type(list) == "table" and list or {}) do
      local okI, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
      if okI and type(node) == "table" then
        nodes = nodes + 1
        local rank = node.ranksPurchased or node.activeRank or node.currentRank or 0
        local maxRank = node.maxRanks or 5
        local entryID = (node.activeEntry and node.activeEntry.entryID) or (node.entryIDs and node.entryIDs[1])
        local spellID, name, icon
        if entryID and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo then
          local okE, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
          if okE and type(entry) == "table" and entry.definitionID then
            local okD, def = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
            if okD and type(def) == "table" then
              spellID = def.spellID
              name = (def.overrideName and def.overrideName ~= "") and def.overrideName or spellName(spellID)
              icon = def.overrideIcon
            end
          end
        end
        if rank > 0 then bought = bought + 1 end
        if name or spellID then
          any = true
          if not PR.talentRaw and rank > 0 then PR.talentRaw = rawKeys(node):sub(1, 200) end
          fn(nil, name or ("spell " .. tostring(spellID)), icon, nil, nil, rank, maxRank, spellID)
        end
      end
    end
  end
  PR.talentTraits = string.format("config %s, trees %d, nodes %d, bought %d", tostring(configID), #cfg.treeIDs, nodes, bought)
  return any
end

local function forEachTalent(fn)
  if GetTalentInfo then return forEachTalentClassic(fn) end
  if forEachTrait(fn) then return end
  local CS = C_SpecializationInfo
  if not (CS and CS.GetTalentInfo) then return end
  local qi = pickQuery()
  if not qi then return end
  local build, seen = QUERY[qi][2], {}
  for tab = 1, numTabs() do
    for tier = 1, 9 do
      for col = 1, 4 do
        local ok, nm, ic, ti, co, rk, mx = callCS(build(tab, tier, col))
        if not ok then noteErr(nm)
        elseif nm then
          local key = nm .. "|" .. tostring(ti or tier) .. "|" .. tostring(co or col)
          if not seen[key] then
            seen[key] = true
            fn(tab, nm, ic, tier, col, rk, mx)
          end
        end
      end
    end
  end
end

local function tabName(tab)
  if GetTalentTabInfo then
    local vals = { pcall(GetTalentTabInfo, tab) }
    if vals[1] then
      for k = 2, #vals do
        local v = vals[k]
        if type(v) == "string" and #v < 32 and not v:find("\\") and not v:find("^Warrior") then return v end
        if type(v) == "table" and v.name then return v.name end
      end
    end
  end
  return ({ "Arms", "Fury", "Protection" })[tab] or ("tab " .. tab)
end

-- Returns ranks (or nil if the talent API has no data yet) and how each talent was matched.
function PR.ReadTalents()
  local ranks, how, any = {}, {}, false
  local byName, byIcon, byPos = {}, {}, {}
  local byId = {}
  forEachTalent(function(tab, name, tex, tier, col, rank, maxRank, spellID)
    any = true
    rank = tonumber(rank) or 0
    for key, t in pairs(PR.TALENTS) do
      if spellID and t.id and spellID == t.id then byId[key] = rank end
      for _, nm in ipairs(t.names) do if name == nm then byName[key] = rank end end
      if iconMatches(tex, t.icon) then byIcon[key] = rank end
      if tab == t.pos[1] and tier == t.pos[2] and col == t.pos[3] and (tonumber(maxRank) or 5) == 5 then byPos[key] = rank end
    end
  end)
  if not any then return nil end -- talent data not loaded yet (or no usable API)
  for key in pairs(PR.TALENTS) do
    if byId[key] then ranks[key], how[key] = byId[key], "id"
    elseif byName[key] then ranks[key], how[key] = byName[key], "name"
    elseif byIcon[key] then ranks[key], how[key] = byIcon[key], "icon"
    elseif byPos[key] then ranks[key], how[key] = byPos[key], "pos"
    else ranks[key], how[key] = 0, "none" end
  end
  PR.talentHow = how
  return ranks
end

-- /difu talents: what the client reports, to check what the addon is reading (never throws)
function PR.DumpTalents()
  local P = "|cffc69b6dDifu'sBisProRoute|r "
  PR.talentErr = nil
  local api = {}
  for _, n in ipairs({ "GetNumTalentTabs", "GetTalentTabInfo", "GetNumTalents", "GetTalentInfo" }) do
    api[#api + 1] = n .. "=" .. (_G[n] and "yes" or "no")
  end
  api[#api + 1] = "C_SpecializationInfo.GetTalentInfo=" .. ((C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo) and "yes" or "no")
  print(P .. "API: " .. table.concat(api, ", "))
  local shown, total, lastTab = 0, 0, nil
  PR.talentRaw, PR.talentQuery, PR.talentProbe, PR.talentTraits = nil, nil, nil, nil
  forEachTalent(function(tab, name, tex, tier, col, rank, maxRank, spellID)
    total = total + 1
    if (tonumber(rank) or 0) > 0 then
      if tab and tab ~= lastTab then print(P .. "|cffffd100" .. tostring(tabName(tab)) .. "|r"); lastTab = tab end
      shown = shown + 1
      if spellID then
        print(string.format("  %s %s/%s  (spell %s)", tostring(name), tostring(rank), tostring(maxRank), tostring(spellID)))
      else
        print(string.format("  %s %s/%s  (tier %s, col %s, icon %s)", tostring(name), tostring(rank), tostring(maxRank), tostring(tier), tostring(col), tostring(tex)))
      end
    end
  end)
  print(P .. string.format("%d talentos leídos, %d con puntos / %d talents read, %d with points", total, shown, total, shown))
  if total == 0 then -- only when nothing was read: full diagnostics
    if PR.talentRaw then print(P .. "raw: " .. PR.talentRaw:sub(1, 240)) end
    if PR.talentTraits then print(P .. "traits: " .. PR.talentTraits) end
    if PR.talentProbe then print(P .. "probe: " .. PR.talentProbe:sub(1, 400)) end
    if C_SpecializationInfo then
      local ks = {}
      for k in pairs(C_SpecializationInfo) do ks[#ks + 1] = tostring(k) end
      table.sort(ks)
      print(P .. "C_SpecializationInfo: " .. table.concat(ks, ", "):sub(1, 400))
    end
    local other = {}
    for _, n in ipairs({ "C_ClassTalents", "C_Traits", "C_Talent", "GetSpecialization", "GetNumSpecializations", "GetActiveTalentGroup", "GetTalentTreeRoles", "IsPlayerSpell" }) do
      other[#other + 1] = n .. "=" .. (_G[n] and "yes" or "no")
    end
    print(P .. table.concat(other, ", "))
  else
    if PR.talentTraits then print(P .. "traits: " .. PR.talentTraits) end
  end
  if PR.talentErr then print(P .. "|cffff5555API error:|r " .. PR.talentErr) end
  PR.liveRanks = PR.ReadTalents()
  local R, live = PR.Ranks()
  local how = PR.talentHow or {}
  print(P .. (live and "OK" or "DEFAULT") .. string.format(": Anticipation %d (%s) · Deflection %d (%s) · Shield Spec %d (%s) · Cruelty %d (%s)",
    R.anticip or 0, how.anticip or "-", R.deflect or 0, how.deflect or "-", R.shieldSpec or 0, how.shieldSpec or "-",
    R.cruelty or 0, how.cruelty or "-"))
end

function PR.Ranks()
  if PR.liveRanks then return PR.liveRanks, true end
  return PR.DEFAULT_RANKS, false
end

function PR.BaseStats()
  if PR.baseCache then return PR.baseCache[1], PR.baseCache[2] end
  local agi, sta = PR.MODEL.baseAgi, PR.MODEL.baseSta
  if UnitStat then
    local okA, bA = pcall(UnitStat, "player", 2)
    local okS, bS = pcall(UnitStat, "player", 3)
    if okA and bA and bA > 0 then agi = bA end
    if okS and bS and bS > 0 then sta = bS end
  end
  PR.baseCache = { agi, sta }
  return agi, sta
end

-- what the game reports right now (gear + talents + buffs)
function PR.Live()
  local L = {}
  local function try(f, ...) if f then local ok, a, b = pcall(f, ...); if ok then return a, b end end end
  L.hp = try(UnitHealthMax, "player")
  local _, eff = try(UnitArmor, "player"); L.armor = eff
  L.dodge = try(GetDodgeChance); L.parry = try(GetParryChance); L.block = try(GetBlockChance)
  local base, mod = try(UnitDefense, "player"); if base then L.D = base + (mod or 0) end
  L.hit = try(GetHitModifier)
  local _, st = try(UnitStat, "player", 3); L.sta = st
  local _, sr = try(UnitStat, "player", 1); L.str = sr
  local _, ag = try(UnitStat, "player", 2); L.agi = ag
  if UnitAttackPower then
    local ok, base, pos, neg = pcall(UnitAttackPower, "player")
    if ok and base then L.ap = base + (pos or 0) + (neg or 0) end
  end
  L.crit = try(GetCritChance)
  if GetExpertise then local e = try(GetExpertise); if e then L.exp = e end end
  return L
end

-- WoW Forever BiS List tank weights (EP). Defense and hit are constraints (440 / 8%), not weights.
PR.EPW = { sta = 1, str = 0.539, agi = 0.443, armor = 0.035, ap = 0.235, crit = 5.235, dodge = 1.461, parry = 1.957, bv = 0.53, blk = 0.087, exp = 19.3, def = 0.17 }
local epCache = setmetatable({}, { __mode = "k" })
function PR.EP(o, slotK)
  if not o then return 0 end
  local c = epCache[o]
  if c and c[slotK] then return c[slotK] end
  local e = PR.EPRaw(o, slotK)
  if not c then c = {}; epCache[o] = c end
  c[slotK] = e
  return e
end
-- Fury: WoW Forever BiS List weights (WoWSims preset "Pre-BiS - Fury"); hit 16.9 EP/% up to 8% then 4.21 to 27%,
-- expertise 23.5 EP/% up to 6.5%. Item EP counts hit at 4.21; the extra value under the cap is added in CalcFury.
PR.FMODEL = { baseStr = 120, baseAgi = 80, baseSta = 110, baseHP = 1689, hitCap = 8, whiteCap = 27, expCap = 6.5 }
PR.EPW_F = { str = 2.2, agi = 1.7, ap = 1, crit = 31.64, sta = 0.1, exp = 23.5, hit = 4.21 }
function PR.EPFury(o, slotK)
  local e, st = 0, o.st or {}
  for k, w in pairs(PR.EPW_F) do e = e + (st[k] or 0) * w end
  if o.dps then
    if slotK == "mainhand" then e = e + o.dps * 12.59 + (o.spd or 0) * 23.9
    elseif slotK == "offhand" then e = e + o.dps * 2.66
    else e = e + o.dps end
  end
  return e + (o.pe or 0)
end
function PR.EPRaw(o, slotK)
  if o.spec == "fury" then return PR.EPFury(o, slotK) end
  local e, st = 0, o.st or {}
  for k, w in pairs(PR.EPW) do e = e + (st[k] or 0) * w end
  if o.dps then e = e + o.dps * (slotK == "ranged" and 1 or 1.157) end
  return e
end

function PR.CalcFury(overSlot, overOpt)
  local M = PR.FMODEL
  local g = { hit = 0, sta = 0, str = 0, agi = 0, armor = 0, exp = 0, ap = 0, crit = 0 }
  local ep, mh, oh, sets = 0, 0, 0, {}
  for _, sl in ipairs(PR.SLOTS) do
    if not PR.char.off[sl.k] then
      local o = (overSlot == sl.k and overOpt) or PR.Selected(sl)
      if o then
        ep = ep + PR.EP(o, sl.k)
        if o.set then sets[o.set] = (sets[o.set] or 0) + 1 end
        if sl.k == "mainhand" and o.dps then mh = o.dps end
        if sl.k == "offhand" and o.dps then oh = o.dps end
      end
      for k in pairs(g) do
        g[k] = g[k] + ((o and o.st and o.st[k]) or 0)
        if PR.useEnchants and sl.ench and sl.ench.st then
          local v = sl.ench.st[k] or 0
          g[k] = g[k] + v
          ep = ep + v * (PR.EPW_F[k] or 0)
        end
      end
    end
  end
  local setOn
  for name, n in pairs(sets) do
    local sb = PR.SET_BONUS and PR.SET_BONUS[name]
    if sb and n >= sb.need then
      setOn = name
      for k, v in pairs(sb.st) do g[k] = (g[k] or 0) + v; ep = ep + v * (PR.EPW_F[k] or 0) end
    end
  end
  ep = ep + math.min(g.hit, M.hitCap) * (16.9 - 4.21) - math.max(0, g.hit - M.whiteCap) * 4.21 - math.max(0, g.exp - M.expCap) * 23.5
  local R = PR.Ranks()
  local str, agi, sta = M.baseStr + g.str, M.baseAgi + g.agi, M.baseSta + g.sta
  return { fury = true, hit = g.hit, exp = g.exp, str = str, agi = agi, sta = sta, ap = 160 + str * 2 + g.ap,
    crit = agi / 20 + g.crit + (R.cruelty or 0) * PR.TALENTS.cruelty.per, hp = M.baseHP + 20 + (sta - 20) * 10,
    armor = g.armor + agi * 2, mh = mh, oh = oh, ep = ep, setOn = setOn }
end

function PR.Calc(overSlot, overOpt)
  if PR.IsFury() then return PR.CalcFury(overSlot, overOpt) end
  local M = PR.MODEL
  local g = { def = 0, hit = 0, sta = 0, agi = 0, armor = 0, exp = 0, blk = 0, dodge = 0, parry = 0, bv = 0, str = 0, ap = 0, crit = 0 }
  local ep = 0
  for _, sl in ipairs(PR.SLOTS) do
    if not PR.char.off[sl.k] then
      local o = (overSlot == sl.k and overOpt) or PR.Selected(sl)
      ep = ep + PR.EP(o, sl.k)
      for k in pairs(g) do
        g[k] = g[k] + ((o and o.st and o.st[k]) or 0)
        if PR.useEnchants and sl.ench and sl.ench.st then g[k] = g[k] + (sl.ench.st[k] or 0) end
      end
    end
  end
  local R = PR.Ranks()
  local T = PR.TALENTS
  local baseAgi, baseSta = PR.BaseStats()
  local D = 300 + R.anticip * T.anticip.per + g.def
  local d = (D - M.bossSkill) * 0.04
  local agi, sta = baseAgi + g.agi, baseSta + g.sta
  local r = { D = D, hit = g.hit, exp = g.exp, sta = sta, bv = g.bv }
  r.miss = 5 + d
  r.dodge = agi / 20 + d + g.dodge
  r.parry = 5 + R.deflect * T.deflect.per + d + g.parry
  r.block = 5 + R.shieldSpec * T.shieldSpec.per + d + g.blk
  r.crit = math.max(0, 5 - d)
  r.avoid = r.miss + r.dodge + r.parry
  r.full = r.avoid + r.block
  r.armor = g.armor * (1 + R.tough * T.tough.per / 100) + agi * 2
  r.dr = math.min(75, r.armor / (r.armor + 400 + 85 * M.bossLvl) * 100)
  r.hp = M.baseHP + 20 + (sta - 20) * 10
  r.str, r.ap, r.critP, r.ep = g.str, g.ap + g.str * 2, g.crit, ep
  return r
end

function PR.Status(id)
  local m = PR.char.steps[id]
  if m == "skipped" then return "skipped" end
  if m == "later" and not (PR.auto and PR.auto[id]) then return "later" end
  if m == "done" or (PR.auto and PR.auto[id]) then return "done" end
  return "pending"
end

-- Step descriptions mention every item a step can unlock: keep only the sentences about items you chose
-- (current spec + selection), like the web guide.
function PR.DescFor(n)
  local text = PR.tx(n.desc) or ""
  local chosen, all = {}, {}
  for _, sl in ipairs(PR.SLOTS) do
    if not PR.char.off[sl.k] then local o = PR.Selected(sl); if o then chosen[o.n] = true end end
  end
  for _, list in pairs(PR.SPEC_SLOTS) do
    for _, sl in ipairs(list) do for _, o in ipairs(sl.opts) do if #o.n > 3 then all[o.n] = true end end end
  end
  local out = {}
  -- split after ". " or "; " only, so decimals like "+1.1%" stay inside their sentence
  for sen in (text:gsub("([%.;])%s+", "%1\n")):gmatch("[^\n]+") do
    local hit, ok = false, false
    for nm in pairs(all) do
      if sen:find(nm, 1, true) then hit = true; if chosen[nm] then ok = true end end
    end
    if not hit or ok then out[#out + 1] = (sen:gsub("^%s+", "")) end
  end
  return table.concat(out, " ")
end

function PR.ComputeRoute()
  local need, items = {}, {}
  local function walk(id, itemId)
    local n = PR.NODE[id]
    if not n then return end
    if not need[id] then need[id] = true; items[id] = {} end
    items[id][itemId] = true
    for _, d in ipairs(n.deps) do walk(d, itemId) end
  end
  for _, sl in ipairs(PR.SLOTS) do
    if not PR.char.off[sl.k] then
      local o = PR.Selected(sl)
      if o and not PR.Has(o.id) then
        for _, r in ipairs(o.req) do walk(r, o.id) end
      end
    end
  end
  local ids, order, done = {}, {}, {}
  for id in pairs(need) do ids[#ids + 1] = id end
  local function key(id) local n = PR.NODE[id]; return PR.PH_RANK[n.phase] * 1000 + n.i end
  while #order < #ids do
    local best
    for _, id in ipairs(ids) do
      if not done[id] then
        local ready = true
        for _, d in ipairs(PR.NODE[id].deps) do
          if need[d] and not done[d] then ready = false; break end
        end
        if ready and (not best or key(id) < key(best)) then best = id end
      end
    end
    if not best then break end
    done[best] = true
    order[#order + 1] = best
  end
  PR.route = { order = order, need = need, items = items }
  return PR.route
end

function PR.NextStep()
  local r = PR.route
  for _, id in ipairs(r.order) do
    if PR.Status(id) == "pending" then
      local ok = true
      for _, d in ipairs(PR.NODE[id].deps) do
        local ds = r.need[d] and PR.Status(d)
        if ds == "pending" or ds == "later" then ok = false; break end
      end
      if ok then return id end
    end
  end
end

function PR.ItemName(id)
  local name = GetItemInfo(id)
  return name or (PR.ITEM[id] and PR.ITEM[id].n) or ("item:" .. id)
end

-- ---------------------------------------------------------------------------
-- WoWSims link: same IndividualSimSettings protobuf the web guide builds, wrapped in a zlib stream.
-- WoW's Lua has no deflate, so it uses "stored" (uncompressed) deflate blocks: any zlib/pako
-- inflater, including the one WoWSims uses, reads them.
-- ---------------------------------------------------------------------------
PR.WEB_URL = "https://difusbisproroute.github.io/"
PR.SIM_URL = "https://www.wowsims.com/forever/warrior/protection/"
PR.SIM_URL_FURY = "https://www.wowsims.com/forever/warrior/dps/"
PR.WS_ORDER = { "head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist", "legs", "feet",
  "finger1", "finger2", "trinket1", "trinket2", "mainhand", "offhand", "ranged" }

local function pbVar(o, n)
  while n > 127 do o[#o + 1] = (n % 128) + 128; n = math.floor(n / 128) end
  o[#o + 1] = n
end
local function pbInt(o, f, n) if n and n > 0 then pbVar(o, f * 8); pbVar(o, n) end end
local function pbMsg(o, f, b)
  pbVar(o, f * 8 + 2); pbVar(o, #b)
  for i = 1, #b do o[#o + 1] = b[i] end
end

local function zlibStored(data)
  local out, n, pos = { 0x78, 0x01 }, #data, 1
  repeat
    local len = math.min(65535, n - pos + 1)
    out[#out + 1] = (pos + len > n) and 1 or 0          -- BFINAL + BTYPE=00 (stored)
    out[#out + 1] = len % 256; out[#out + 1] = math.floor(len / 256)
    local nlen = 65535 - len
    out[#out + 1] = nlen % 256; out[#out + 1] = math.floor(nlen / 256)
    for i = pos, pos + len - 1 do out[#out + 1] = data[i] end
    pos = pos + len
  until pos > n
  local a, b = 1, 0                                      -- Adler-32, big-endian
  for i = 1, n do a = (a + data[i]) % 65521; b = (b + a) % 65521 end
  out[#out + 1] = math.floor(b / 256); out[#out + 1] = b % 256
  out[#out + 1] = math.floor(a / 256); out[#out + 1] = a % 256
  return out
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(bytes)
  local out, n = {}, #bytes
  for i = 1, n, 3 do
    local b1, b2, b3 = bytes[i], bytes[i + 1], bytes[i + 2]
    local v = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)
    local c1, c2 = math.floor(v / 262144) % 64, math.floor(v / 4096) % 64
    local c3, c4 = math.floor(v / 64) % 64, v % 64
    out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1) ..
      (b2 and B64:sub(c3 + 1, c3 + 1) or "=") .. (b3 and B64:sub(c4 + 1, c4 + 1) or "=")
  end
  return table.concat(out)
end
PR._b64, PR._zlib = base64, zlibStored -- exposed for /difu debug

function PR.SimURL()
  local bySlot = {}
  for _, sl in ipairs(PR.SLOTS) do bySlot[sl.k] = sl end
  local eq = {}
  for _, k in ipairs(PR.WS_ORDER) do
    local sl, it = bySlot[k], {}
    if sl and not PR.char.off[k] then
      local o = PR.Selected(sl)
      if o then pbInt(it, 1, o.id) end
      if PR.useEnchants and sl.ench and sl.ench.ws then pbInt(it, 3, sl.ench.ws) end
    end
    pbMsg(eq, 1, it)
  end
  local pl = {}; pbInt(pl, 54, 2); pbMsg(pl, 3, eq)        -- player: class Warrior, equipment
  local set = {}; pbInt(set, 15, 2); pbMsg(set, 3, pl)      -- settings: player
  return (PR.IsFury() and PR.SIM_URL_FURY or PR.SIM_URL) .. "?i=g#" .. base64(zlibStored(set))
end

-- ---------------------------------------------------------------------------
-- Import / export (same format as the web guide)
-- PR1;f=A;s=head:226869,...;h=id,id;d=step,step;k=step,step;x=slot,slot
-- ---------------------------------------------------------------------------
function PR.Export()
  PR.ComputeAuto()
  local sel, have, done, skip, off, later = {}, {}, {}, {}, {}, {}
  for _, sl in ipairs(PR.SLOTS) do
    local o = PR.Selected(sl)
    sel[#sel + 1] = sl.k .. ":" .. o.id
    for _, opt in ipairs(PR.OptsFor(sl)) do
      if PR.Has(opt.id) then have[#have + 1] = tostring(opt.id) end
    end
    if PR.char.off[sl.k] then off[#off + 1] = sl.k end
  end
  for _, n in ipairs(PR.NODES) do
    local s = PR.Status(n.id)
    if s == "done" then done[#done + 1] = n.id elseif s == "skipped" then skip[#skip + 1] = n.id
    elseif s == "later" then later[#later + 1] = n.id end
  end
  return table.concat({ "PR1", "p=" .. PR.spec, "f=" .. PR.faction, "s=" .. table.concat(sel, ","), "h=" .. table.concat(have, ","),
    "d=" .. table.concat(done, ","), "k=" .. table.concat(skip, ","), "l=" .. table.concat(later, ","), "x=" .. table.concat(off, ","),
    "t=" .. string.format("a%d,d%d,s%d,t%d,c%d", PR.Ranks().anticip, PR.Ranks().deflect, PR.Ranks().shieldSpec, PR.Ranks().tough, PR.Ranks().cruelty or 0) }, ";")
end

function PR.Import(str)
  str = (str or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if str:sub(1, 4) ~= "PR1;" then return false end
  local p = {}
  for kv in str:gmatch("[^;]+") do
    local k, v = kv:match("^(%a)=(.*)$")
    if k then p[k] = v end
  end
  local function split(v)
    local out = {}
    for x in (v or ""):gmatch("[^,]+") do out[#out + 1] = x end
    return out
  end
  if p.p == "prot" or p.p == "fury" then PR.ApplySpec(p.p) end
  local c = PR.char
  for _, e in ipairs(split(p.s)) do
    local k, id = e:match("^(%w+):(%d+)$")
    if k then c.sel[k] = tonumber(id) end
  end
  wipe(c.have); for _, id in ipairs(split(p.h)) do c.have[tonumber(id)] = true end
  wipe(c.steps)
  for _, id in ipairs(split(p.d)) do if PR.NODE[id] then c.steps[id] = "done" end end
  for _, id in ipairs(split(p.k)) do if PR.NODE[id] then c.steps[id] = "skipped" end end
  for _, id in ipairs(split(p.l)) do if PR.NODE[id] then c.steps[id] = "later" end end
  wipe(c.off); for _, k in ipairs(split(p.x)) do c.off[k] = true end
  return true
end

-- ---------------------------------------------------------------------------
-- Init and events
-- ---------------------------------------------------------------------------
local function charKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

function PR.Init()
  DifusBisProRouteDB = DifusBisProRouteDB or {}
  local db = DifusBisProRouteDB
  db.chars = db.chars or {}
  if not db.lang then db.lang = (GetLocale():sub(1, 2) == "es") and "es" or "en" end
  PR.db = db
  PR.lang = db.lang
  PR.faction = (UnitFactionGroup("player") == "Horde") and "H" or "A"
  local c = db.chars[charKey()] or {}
  db.chars[charKey()] = c
  c.sel = c.sel or {}; c.have = c.have or {}; c.steps = c.steps or {}; c.off = c.off or {}
  c.bank = c.bank or {}; c.turnedIn = c.turnedIn or {}; c.presets = c.presets or {}
  c.showDone = (c.showDone == nil) and true or c.showDone
  PR.char = c
  if not c.selBySpec then c.selBySpec = { prot = c.sel } end
  PR.ApplySpec(c.spec or "prot")
  local _, class = UnitClass("player")
  if class ~= "WARRIOR" then print("|cffc69b6dDifu'sBisProRoute|r: " .. PR.T("notWarrior")) end
end

local function scanBank()
  if not PR.char then return end
  for id in pairs(PR.ITEM) do
    local inBank = (GetItemCount(id, true) or 0) - (GetItemCount(id) or 0)
    PR.char.bank[id] = inBank > 0 or nil
  end
  for _, id in ipairs(PR.VALOR) do
    local inBank = (GetItemCount(id, true) or 0) - (GetItemCount(id) or 0)
    PR.char.bank[id] = inBank > 0 or nil
  end
end

local pending = false
function PR.Refresh(announce)
  if pending then return end
  pending = true
  C_Timer.After(0.3, function()
    pending = false
    if not PR.char then return end
    xpcall(PR.DoRefresh, PR.Err, announce)
  end)
end

-- cheap, coalesced UI repaint (no auto-detection, no route recompute)
local repaintPending = false
function PR.Repaint()
  if repaintPending then return end
  repaintPending = true
  C_Timer.After(0.5, function()
    repaintPending = false
    if PR.char and PR.UI and PR.UI.frame and PR.UI.frame:IsShown() and PR.UI.Update then xpcall(PR.UI.Update, PR.Err) end
  end)
end

-- ask the server for every guide item a few at a time after login, so tooltips are instant later
function PR.PrewarmItems()
  local req = (C_Item and C_Item.RequestLoadItemDataByID) or nil
  if not req then return end
  local ids = {}
  for id in pairs(PR.ITEM) do ids[#ids + 1] = id end
  local i = 0
  local function step()
    for _ = 1, 8 do
      i = i + 1
      local id = ids[i]
      if not id then return end
      if not GetItemInfo(id) then pcall(req, id) end
    end
    C_Timer.After(0.2, step)
  end
  C_Timer.After(3, step)
end

function PR.DoRefresh(announce)
    local oldRanks = PR.liveRanks
    PR.liveRanks = PR.ReadTalents()
    PR.baseCache = nil
    local function rk(r) return r and (r.anticip .. "," .. r.deflect .. "," .. r.shieldSpec .. "," .. r.tough .. "," .. (r.cruelty or 0)) or "" end
    if rk(oldRanks) ~= rk(PR.liveRanks) then PR.InvalidateOpt() end
    if not PR.liveRanks and (PR.talentTries or 0) < 10 then
      PR.talentTries = (PR.talentTries or 0) + 1
      C_Timer.After(2, function() PR.Refresh(false) end)
    end
    local before = PR.auto or {}
    PR.ComputeAuto()
    PR.ComputeRoute()
    if announce then
      for id in pairs(PR.auto) do
        if not before[id] and PR.route.need[id] then
          print("|cffc69b6dDifu'sBisProRoute|r: " .. string.format(PR.T("autoDone"), PR.tx(PR.NODE[id].title)))
        end
      end
    end
    if PR.UI and PR.UI.Update then PR.UI.Update() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "PLAYER_LOGIN" then
    PR.Init()
    for _, e in ipairs({ "QUEST_TURNED_IN", "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "BANKFRAME_OPENED",
      "PLAYERBANKSLOTS_CHANGED", "UPDATE_FACTION", "SKILL_LINES_CHANGED", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "GET_ITEM_INFO_RECEIVED", "QUEST_LOG_UPDATE" }) do
      pcall(ev.RegisterEvent, ev, e)
    end
    -- only the player's stats, not every unit around you
    if ev.RegisterUnitEvent then pcall(ev.RegisterUnitEvent, ev, "UNIT_STATS", "player") else pcall(ev.RegisterEvent, ev, "UNIT_STATS") end
    PR.PrewarmItems()
    if PR.UI and PR.UI.Build then PR.UI.Build() end
    PR.Refresh(false)
    return
  end
  -- item data arriving from the server only changes names/icons: repaint, don't recompute everything
  if event == "GET_ITEM_INFO_RECEIVED" then
    if arg1 and PR.ITEM[arg1] then PR.Repaint() end
    return
  end
  if event == "UNIT_STATS" then
    if arg1 ~= "player" then return end
    PR.baseCache = nil; PR.Repaint(); return
  end
  if event == "QUEST_TURNED_IN" and arg1 then PR.char.turnedIn[arg1] = true end
  if event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then scanBank() end
  PR.Refresh(event ~= "GET_ITEM_INFO_RECEIVED" and event ~= "QUEST_LOG_UPDATE")
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
SLASH_DIFUSBISPROROUTE1 = "/difu"
SlashCmdList.DIFUSBISPROROUTE = function(msg)
  msg = (msg or ""):lower()
  local cmd, arg = msg:match("^(%S*)%s*(.-)$")
  if not PR.char then return end
  if cmd == "" then PR.UI.Toggle()
  elseif cmd == "export" then PR.UI.ShowIO("export")
  elseif cmd == "import" then PR.UI.ShowIO("import")
  elseif cmd == "sim" then PR.UI.ShowIO("sim")
  elseif cmd == "web" then PR.UI.ShowIO("web")
  elseif cmd == "lang" and (arg == "es" or arg == "en") then PR.db.lang = arg; PR.lang = arg; PR.UI.Relabel(); PR.Refresh(false)
  elseif cmd == "scale" and tonumber(arg) then
    local v = math.max(0.6, math.min(1.4, tonumber(arg)))
    PR.db.scale = v; if PR.UI.frame then PR.UI.frame:SetScale(v) end
  elseif cmd == "reset" then
    wipe(PR.char.sel); wipe(PR.char.have); wipe(PR.char.steps); wipe(PR.char.off)
    print("|cffc69b6dDifu'sBisProRoute|r: " .. PR.T("reset")); PR.Refresh(false)
  elseif cmd == "talentos" or cmd == "talents" then xpcall(PR.DumpTalents, PR.Err); PR.InvalidateOpt(); PR.Refresh(false)
  elseif cmd == "spec" and (arg == "prot" or arg == "fury") then PR.ApplySpec(arg); if PR.UI.Relabel then PR.UI.Relabel() end; PR.Refresh(false)
  elseif cmd == "debug" then
    PR.ComputeAuto()
    print("|cffc69b6dDifu'sBisProRoute|r debug — " .. PR.faction .. ", " .. PR.lang)
    for _, n in ipairs(PR.NODES) do
      if PR.AUTO[n.id] then
        print(string.format("  %s: %s", n.id, PR.auto[n.id] and "|cff1eff00OK|r" or "|cff888888-|r"))
      end
    end
    print("  art: " .. tostring(PR.UI.artSource))
    print("  " .. string.format(PR.T("valor"), PR.ValorCount()) .. " | " .. string.format(PR.T("reals"), PR.CountReals()))
  else print("|cffc69b6dDifu'sBisProRoute|r: " .. PR.T("help")) end
end
