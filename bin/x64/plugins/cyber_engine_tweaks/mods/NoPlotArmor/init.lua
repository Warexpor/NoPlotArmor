local MOD_VERSION = "0.2.1"
local MOD_NAME = "No Plot Armor"
local LOG_PREFIX = "[NoPlotArmor] "
local SPAWN_TAG = "NoPlotArmor_Spawn"
local LEGACY_TAGS = { "NoPlotArmor_Spawn", "NPCOmegaGore_Spawn", "OmegaNPC_Spawn" }

local open = false
local record = "Character.Judy"
local query = ""
local status = "Load a save, choose a record, then spawn."
local pending = {}
local diagnosticTimer = 0
local lastDiagnostic = nil
local catalog = require("catalog")
local showAll = false
local page = 1
local pageSize = 15
-- Main and notable recurring characters; the complete catalog remains optional.
local featured = {}
for _, id in ipairs({
  "Character.Judy", "Character.Panam", "Character.Jackie", "Character.Sobchak", "Character.Kerry",
  "Character.Rogue", "Character.Takemura", "Character.Victor_Vector", "Character.Misty", "Character.Evelyn",
  "Character.Maiko", "Character.Claire", "Character.Alt", "Character.Tbug", "Character.Smasher",
  "Character.Elizabeth_Peralez", "Character.Jefferson_Peralez", "Character.Padre", "Character.reggie",
  "Character.wakako_okada", "Character.muamar_reyes", "Character.mr_hands", "Character.reed", "Character.songbird",
  "Character.myers", "Character.kurtz", "Character.alex", "Character.bella", "Character.theo",
  "Character.paco", "Character.Lizzy_Wizzy", "Character.Lizzy_Wizzy_ep1", "Character.q203_mr_x",
  "Character.Dex_bodyguard", "Character.Santiago", "Character.Fingers", "Character.sq026_woodman",
  "Character.Ozob", "Character.Wilson", "Character.sq021_joss", "Character.sq023_joshua",
  "Character.q101_spider_murphy", "Character.Tom", "Character.sq024_dominic", "Character.mq303_lina",
  "Character.sq017_blue_moon", "Character.sq017_red_menace", "Character.sq017_purple_force",
  "Character.Hanako", "Character.Yorinobu", "Character.Saburo", "Character.Michiko"
}) do featured[id] = true end
local fireAuthApplied = false
local hitFlagsFlipped = false
local retaliationEnabled = false
local modEnabled = true
local verboseLogging = false
local ownedFireSafe = false
local ownedFireFriendly = false
local neutralTimer = 0

local function saveRetaliationSetting()
  local ok, err = pcall(function()
    local file = assert(io.open("retaliation.txt", "w"))
    file:write(retaliationEnabled and "1" or "0")
    file:close()
  end)
  if not ok then print(LOG_PREFIX .. "Could not save retaliation setting: " .. tostring(err)) end
end

local function saveMasterSetting()
  local ok, err = pcall(function()
    local file = assert(io.open("enabled.txt", "w"))
    file:write(modEnabled and "1" or "0")
    file:close()
  end)
  if not ok then print(LOG_PREFIX .. "Could not save master setting: " .. tostring(err)) end
end

local function saveVerboseSetting()
  pcall(function()
    local file = assert(io.open("verbose.txt", "w"))
    file:write(verboseLogging and "1" or "0")
    file:close()
  end)
end

local function spawn()
  if not modEnabled then status = "Enable No Plot Armor before spawning."; return end
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
    spec.tags = { SPAWN_TAG }
    local id = Game.GetDynamicEntitySystem():CreateEntity(spec)
    if not id then error("CreateEntity returned no entity ID") end
    pending[#pending + 1] = { id = id, elapsed = 0, name = record }
    return "Requested " .. record .. "; waiting for entity."
  end)
  status = ok and result or ("Spawn failed: " .. tostring(result))
  print(LOG_PREFIX .. status)
end

local function clear()
  local ok, result = pcall(function()
    local system = Game.GetDynamicEntitySystem()
    local count = 0
    for _, tag in ipairs(LEGACY_TAGS) do
      local ids = system:GetTaggedIDs(tag)
      for _, id in ipairs(ids) do system:DeleteEntity(id); count = count + 1 end
    end
    pending = {}
    return "Removed " .. count .. " spawned copies (all tags)."
  end)
  status = ok and result or ("Cleanup failed: " .. tostring(result))
  print(LOG_PREFIX .. status)
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
  print(LOG_PREFIX .. "WEAPON " .. status)
end

local function inspectTarget()
  local ok, result = pcall(function()
    local p = Game.GetPlayer()
    if not p then return "Load a save first." end
    local target = Game.GetTargetingSystem():GetLookAtObject(p, false, false)
    if not target then return "Look at an NPC first." end
    if not target:IsNPC() then return "Target is not an NPC." end
    return target:NoPlotArmor_Describe()
  end)
  status = ok and tostring(result) or ("Inspection failed: " .. tostring(result))
  print(LOG_PREFIX .. "INSPECT " .. status)
end

registerForEvent("onInit", function()
  local okMaster, master = pcall(function()
    local f = io.open("enabled.txt", "r")
    if not f then return true end
    local value = f:read("*a"); f:close()
    return value:match("^%s*0%s*$") == nil
  end)
  if okMaster then modEnabled = master end
  local ok, value = pcall(function()
    local file = io.open("retaliation.txt", "r")
    if not file then return false end
    local content = file:read("*a")
    file:close()
    return content:match("^%s*1%s*$") ~= nil
  end)
  if ok then retaliationEnabled = value end
  local okV, verbose = pcall(function()
    local file = io.open("verbose.txt", "r")
    if not file then return false end
    local content = file:read("*a")
    file:close()
    return content:match("^%s*1%s*$") ~= nil
  end)
  if okV then verboseLogging = verbose end
  print(LOG_PREFIX .. "v" .. MOD_VERSION .. " loaded. Use the CET overlay to spawn or inspect.")
end)
registerForEvent("onOverlayOpen", function() open = true end)
registerForEvent("onOverlayClose", function() open = false end)
registerForEvent("onUpdate", function(dt)
  pcall(function()
    local player = Game.GetPlayer()
    if player then
      player:NPA_SetEnabled(modEnabled)
      player:NPA_SetRetaliationEnabled(modEnabled and retaliationEnabled)
      if modEnabled then
        local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
        player:NPA_UpdateShotTarget(target or player, dt)
      end
    end
  end)
  -- Authorize the player's own fire path: covers any native check that reads
  -- these statuses instead of (or in addition to) the attack flags.
  if modEnabled and not fireAuthApplied then
    pcall(function()
      local p = Game.GetPlayer()
      if p then
        ownedFireSafe = not StatusEffectSystem.ObjectHasStatusEffect(p, "BaseStatusEffect.IgnoreWeaponSafe")
        ownedFireFriendly = not StatusEffectSystem.ObjectHasStatusEffect(p, "BaseStatusEffect.DoNotBlockShootingOnFriendlyFire")
        if ownedFireSafe then StatusEffectHelper.ApplyStatusEffect(p, "BaseStatusEffect.IgnoreWeaponSafe") end
        if ownedFireFriendly then StatusEffectHelper.ApplyStatusEffect(p, "BaseStatusEffect.DoNotBlockShootingOnFriendlyFire") end
        fireAuthApplied = true
        if verboseLogging then print(LOG_PREFIX .. "Fire authorization statuses applied to player.") end
      end
    end)
  end
  -- The REDscript startup tweak supplies the bullet record flag. It stays
  -- loaded while toggling; do not mutate the shared record at runtime.
  if not hitFlagsFlipped then hitFlagsFlipped = true end
  if not modEnabled and fireAuthApplied then
    pcall(function()
      local p = Game.GetPlayer()
      if not p then return end
      if ownedFireSafe then StatusEffectHelper.RemoveStatusEffect(p, "BaseStatusEffect.IgnoreWeaponSafe") end
      if ownedFireFriendly then StatusEffectHelper.RemoveStatusEffect(p, "BaseStatusEffect.DoNotBlockShootingOnFriendlyFire") end
      fireAuthApplied = false; ownedFireSafe = false; ownedFireFriendly = false
    end)
  end
  if verboseLogging then
    diagnosticTimer = diagnosticTimer + dt
    if diagnosticTimer >= 0.5 then
      diagnosticTimer = 0
      local ok, description = pcall(function()
        local player = Game.GetPlayer()
        if not player then return nil end
        local target = Game.GetTargetingSystem():GetLookAtObject(player, false, false)
        if not target or not target:IsNPC() then return nil end
        return tostring(target:NoPlotArmor_Describe())
      end)
      if not ok then
        if lastDiagnostic ~= "error:" .. tostring(description) then
          print(LOG_PREFIX .. "Target diagnostic failed: " .. tostring(description))
        end
        lastDiagnostic = "error:" .. tostring(description)
      elseif description ~= lastDiagnostic then
        if description then print(LOG_PREFIX .. "TARGET " .. description) end
        lastDiagnostic = description
      end
    end
  end
  -- Only spawner-created entities are managed; ordinary enemies keep their AI.
  -- Repeat while disabled so a spawned hostile cannot reacquire hostility after a hit.
  neutralTimer = neutralTimer + dt
  if modEnabled and not retaliationEnabled and neutralTimer >= 0.25 then
    neutralTimer = 0
    local ok, err = pcall(function()
      local player = Game.GetPlayer()
      if not player then return end
      local system = Game.GetDynamicEntitySystem()
      for _, tag in ipairs(LEGACY_TAGS) do
        for _, id in ipairs(system:GetTaggedIDs(tag)) do
          local npc = Game.FindEntityByID(id)
          if npc and npc:IsNPC() then npc:NPA_NeutralizeSpawn(player) end
        end
      end
    end)
    if not ok then print(LOG_PREFIX .. "Spawn neutrality failed: " .. tostring(err)) end
  end
  for i = #pending, 1, -1 do
    local item = pending[i]
    item.elapsed = item.elapsed + dt
    local ok, entity = pcall(Game.FindEntityByID, item.id)
    if ok and entity then
      if not item.reported then
        status = "Spawned " .. item.name .. ". Appearance and behavior depend on the record."
        print(LOG_PREFIX .. status)
        item.reported = true
      end
      if modEnabled and not retaliationEnabled then
        local player = Game.GetPlayer()
        if player then pcall(function() entity:NPA_NeutralizeSpawn(player) end) end
      end
      if not modEnabled then
        table.remove(pending, i)
      elseif item.elapsed >= 1.0 then
        local adjusted, ready = pcall(function() return entity:NPA_AdjustSpawnHealth() end)
        if adjusted and ready then
          table.remove(pending, i)
        elseif item.elapsed > 10 then
          print(LOG_PREFIX .. "Spawn health adjustment did not complete: " .. tostring(ready))
          table.remove(pending, i)
        end
      end
    elseif item.elapsed > 10 then
      status = "Spawn timed out for " .. item.name .. "; record may require special assets."
      print(LOG_PREFIX .. status)
      table.remove(pending, i)
    end
  end
end)
registerForEvent("onDraw", function()
  if not open then return end
  if ImGui.Begin(MOD_NAME .. " v" .. MOD_VERSION) then
    local master, masterChanged = ImGui.Checkbox("Enable " .. MOD_NAME, modEnabled)
    if masterChanged then modEnabled = master; saveMasterSetting() end
    ImGui.TextWrapped("Lets you damage story NPCs. Spawns are copies. Killing quest NPCs can break quests — use a manual save.")
    local enabled, changed = ImGui.Checkbox("NPCs retaliate when hit", retaliationEnabled)
    if changed then retaliationEnabled = enabled; saveRetaliationSetting() end
    local verbose, verboseChanged = ImGui.Checkbox("Verbose logging (for bug reports)", verboseLogging)
    if verboseChanged then verboseLogging = verbose; saveVerboseSetting() end
    record = ImGui.InputText("Character record", record, 160)
    if ImGui.Button("Spawn record") then spawn() end
    ImGui.SameLine()
    if ImGui.Button("Remove spawned copies") then clear() end
    if ImGui.Button("Inspect NPC in crosshairs") then inspectTarget() end
    if ImGui.Button("Log current weapon attack") then logWeaponAttack() end
    ImGui.TextWrapped(status)
    ImGui.Separator()
    local all, allChanged = ImGui.Checkbox("Show all characters", showAll)
    if allChanged then showAll = all; page = 1 end
    local newQuery = ImGui.InputText("Search names or records", query, 100)
    if newQuery ~= query then query = newQuery; page = 1 end
    local needle = string.lower(query)
    local matches = {}
    for _, entry in ipairs(catalog) do
      if (showAll or featured[entry[2]]) and
         (needle == "" or string.find(string.lower(entry[1] .. " " .. entry[2]), needle, 1, true)) then
        matches[#matches + 1] = entry
      end
    end
    local pages = math.max(1, math.ceil(#matches / pageSize))
    page = math.min(page, pages)
    if ImGui.Button("Previous page") then page = math.max(1, page - 1) end
    ImGui.SameLine()
    if ImGui.Button("Next page") then page = math.min(pages, page + 1) end
    ImGui.SameLine()
    ImGui.Text("Page " .. page .. " / " .. pages .. " (" .. #matches .. " characters)")
    for i = (page - 1) * pageSize + 1, math.min(page * pageSize, #matches) do
      local entry = matches[i]
      if ImGui.Button(entry[1] .. "##" .. entry[2]) then record = entry[2] end
    end
    ImGui.Separator()
    ImGui.Text(MOD_NAME .. " v" .. MOD_VERSION)
  end
  ImGui.End()
end)
