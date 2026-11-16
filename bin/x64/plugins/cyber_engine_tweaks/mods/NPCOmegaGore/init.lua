local open = false
local record = "Character.Judy"
local query = ""
local status = "Load a save, choose a record, then spawn."
local pending = {}
local diagnosticTimer = 0
local lastDiagnostic = nil
local catalog = require("catalog")
local fireAuthApplied = false
local hitFlagsFlipped = false

local function spawn()
  local player = Game.GetPlayer()
  if not player then status = "Load a save first."; return end
  local ok, result = pcall(function()
    if not record:match("^Character%.[%w_]+$") then error("Enter a Character.* record") end
    if not TweakDB:GetRecord(record) then error("Character record not found: " .. record) end
    local p, f = player:GetWorldPosition(), player:GetWorldForward()
    local length = math.sqrt(f.x * f.x + f.y * f.y)
    if length < 0.001 then error("Could not determine player direction") end
    local forward = Vector4.new(f.x / length, f.y / length, 0, 0)
    local spec = DynamicEntitySpec.new()
    spec.recordID = TweakDBID.new(record)
    spec.position = Vector4.new(p.x + forward.x * 2, p.y + forward.y * 2, p.z, 1)
    spec.orientation = EulerAngles.ToQuat(EulerAngles.new(0, 0, Vector4.ToRotation(forward).yaw))
    spec.alwaysSpawned = true
    spec.tags = { "NPCOmegaGore_Spawn" }
    local id = Game.GetDynamicEntitySystem():CreateEntity(spec)
    if not id then error("CreateEntity returned no entity ID") end
    pending[#pending + 1] = { id = id, elapsed = 0, name = record }
    return "Requested " .. record .. "; waiting for entity."
  end)
  status = ok and result or ("Spawn failed: " .. tostring(result))
  print("[NPCOmegaGore] " .. status)
end

local function clear()
  local ok, result = pcall(function()
    local system = Game.GetDynamicEntitySystem()
    local count = 0
    for _, tag in ipairs({ "NPCOmegaGore_Spawn", "OmegaNPC_Spawn" }) do
      local ids = system:GetTaggedIDs(tag)
      for _, id in ipairs(ids) do system:DeleteEntity(id); count = count + 1 end
    end
    pending = {}
    return "Removed " .. count .. " spawned entities (both NPCOmegaGore and legacy OmegaNPC tags)."
  end)
  status = ok and result or ("Cleanup failed: " .. tostring(result))
end

local function logWeaponAttack()
  local ok, result = pcall(function()
    local p = Game.GetPlayer()
    if not p then return "Load a save first." end
    local out = {}
    local function add(s) out[#out + 1] = tostring(s) end
    local okW, weapon = pcall(function() return ScriptedPuppet.GetWeaponRight(p) end)
    if not okW or not weapon then return "No active weapon (fists?) " .. tostring(weapon) end
    add("weapon=" .. tostring(weapon:GetClassName()))
    local okA, attack = pcall(function() return weapon:GetCurrentAttack() end)
    if not okA or not attack then return table.concat(out, " ") .. " no-current-attack " .. tostring(attack) end
    local okR, rec = pcall(function() return attack:GetRecord() end)
    if not okR or not rec then return table.concat(out, " ") .. " no-attack-record" end
    add("attack=" .. tostring(rec:GetID()))
    local okH, flags = pcall(function() return rec:HitFlags() end)
    if okH and flags then
      local names = {}
      for _, f in ipairs(flags) do names[#names + 1] = tostring(f) end
      add("hitflags=[" .. table.concat(names, ",") .. "]")
    else
      add("hitflags=?")
    end
    local okT, atype = pcall(function() return rec:AttackType() end)
    if okT and atype then
      local okTT, ttype = pcall(function() return atype:Type() end)
      if okTT then add("type=" .. tostring(ttype)) end
    end
    return table.concat(out, " ")
  end)
  status = ok and tostring(result) or ("Weapon log failed: " .. tostring(result))
  print("[NPCOmegaGore] WEAPON " .. status)
end

local function inspectTarget()
  local ok, result = pcall(function()
    local p = Game.GetPlayer()
    if not p then return "Load a save first." end
    local target = Game.GetTargetingSystem():GetLookAtObject(p, false, false)
    if not target then return "Look at an NPC first." end
    if not target:IsNPC() then return "Target is not an NPC." end
    return target:NPCOmegaGore_Describe()
  end)
  status = ok and tostring(result) or ("Inspection failed: " .. tostring(result))
  print("[NPCOmegaGore] INSPECT " .. status)
end

registerForEvent("onInit", function()
  print("[NPCOmegaGore] Diagnostics active: target changes and health/protection changes are sampled twice per second.")
end)
registerForEvent("onOverlayOpen", function() open = true end)
registerForEvent("onOverlayClose", function() open = false end)
registerForEvent("onUpdate", function(dt)
  -- Authorize the player's own fire path: covers any native check that reads
  -- these statuses instead of (or in addition to) the attack flags.
  if not fireAuthApplied then
    pcall(function()
      local p = Game.GetPlayer()
      if p then
        StatusEffectHelper.ApplyStatusEffect(p, "BaseStatusEffect.IgnoreWeaponSafe")
        StatusEffectHelper.ApplyStatusEffect(p, "BaseStatusEffect.DoNotBlockShootingOnFriendlyFire")
        fireAuthApplied = true
        print("[NPCOmegaGore] Fire authorization statuses applied to player.")
      end
    end)
  end
  -- Record-level fix (backup for the REDscript ScriptableTweak): the native
  -- bullet path reads the attack record's own HitFlags, where per-shot
  -- runtime flags never reach. Runs at boot, no save needed.
  if not hitFlagsFlipped then
    pcall(function()
      local rec = "Attacks.Bullet_GameEffect"
      local r = TweakDB:GetRecord(rec)
      if not r then print("[NPCOmegaGore] TweakDB record missing: " .. rec); return end
      local flags = {}
      local okH, cur = pcall(function() return r:HitFlags() end)
      if okH and cur then
        for _, f in ipairs(cur) do flags[#flags + 1] = tostring(f) end
      else
        local okF, flat = pcall(function() return TweakDB:GetFlat(rec .. ".hitFlags") end)
        if okF and type(flat) == "table" then
          for _, f in ipairs(flat) do flags[#flags + 1] = tostring(f) end
        end
      end
      for _, f in ipairs(flags) do
        if f == "FriendlyFire" then print("[NPCOmegaGore] record HitFlags already set"); hitFlagsFlipped = true; return end
      end
      flags[#flags + 1] = "FriendlyFire"
      local okS = pcall(function() TweakDB:SetFlat(rec .. ".hitFlags", flags) end)
      local okU, resU = pcall(function() return TweakDB:UpdateRecord(rec) end)
      print("[NPCOmegaGore] record flip set=" .. tostring(okS) .. " update=" .. tostring(okU) .. ":" .. tostring(resU))
      local okV, verify = pcall(function() return TweakDB:GetRecord(rec):HitFlags() end)
      if okV and verify then
        local names = {}
        for _, f in ipairs(verify) do names[#names + 1] = tostring(f) end
        print("[NPCOmegaGore] record verify HitFlags=[" .. table.concat(names, ",") .. "]")
      end
      hitFlagsFlipped = true
    end)
  end
  diagnosticTimer = diagnosticTimer + dt
  if diagnosticTimer >= 0.5 then
    diagnosticTimer = 0
    local ok, description = pcall(function()
      local player = Game.GetPlayer()
      if not player then return nil end
      local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
      if not target or not target:IsNPC() then return nil end
      return tostring(target:NPCOmegaGore_Describe())
    end)
    if not ok then
      if lastDiagnostic ~= "error:" .. tostring(description) then
        print("[NPCOmegaGore] Target diagnostic failed: " .. tostring(description))
      end
      lastDiagnostic = "error:" .. tostring(description)
    elseif description ~= lastDiagnostic then
      if description then print("[NPCOmegaGore] TARGET " .. description) end
      lastDiagnostic = description
    end
  end
  for i = #pending, 1, -1 do
    local item = pending[i]
    item.elapsed = item.elapsed + dt
    local ok, entity = pcall(Game.FindEntityByID, item.id)
    if ok and entity then
      status = "Spawned " .. item.name .. ". Appearance and behavior depend on the record."
      print("[NPCOmegaGore] " .. status)
      table.remove(pending, i)
    elseif item.elapsed > 10 then
      status = "Spawn timed out for " .. item.name .. "; record may require special assets."
      print("[NPCOmegaGore] " .. status)
      table.remove(pending, i)
    end
  end
end)
registerForEvent("onDraw", function()
  if not open then return end
  if ImGui.Begin("NPCOmegaGore") then
    ImGui.TextWrapped("Spawns are copies. Some records need specific quest or DLC assets.")
    record = ImGui.InputText("Character record", record, 160)
    if ImGui.Button("Spawn record") then spawn() end
    ImGui.SameLine()
    if ImGui.Button("Remove spawned copies") then clear() end
    if ImGui.Button("Inspect NPC in crosshairs") then inspectTarget() end
    if ImGui.Button("Log current weapon attack") then logWeaponAttack() end
    ImGui.TextWrapped(status)
    ImGui.Separator()
    query = ImGui.InputText("Search names or records", query, 100)
    local needle = string.lower(query)
    local shown, matches = 0, 0
    for _, entry in ipairs(catalog) do
      if needle == "" or string.find(string.lower(entry[1] .. " " .. entry[2]), needle, 1, true) then
        matches = matches + 1
        if shown < 30 then
          if ImGui.Button(entry[1] .. "##" .. entry[2]) then record = entry[2] end
          shown = shown + 1
        end
      end
    end
    ImGui.Text("Showing " .. shown .. " of " .. matches .. " matches; search to narrow.")
  end
  ImGui.End()
end)
