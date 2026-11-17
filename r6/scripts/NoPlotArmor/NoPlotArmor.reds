module NoPlotArmor

// No Plot Armor v0.2.0 — killable story NPCs, wound injection, story spawner kept.
public static func NPA_Version() -> String { return "0.2.0"; }


// Track loaded NPCs so the master switch can remove our own protection changes.
public class NPAControl extends ScriptableService {
  private let disabled: Bool;
  private let lock: RWLock;
  private let npcs: array<wref<NPCPuppet>>;

  public static func Get(game: GameInstance) -> ref<NPAControl> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"NoPlotArmor.NPAControl") as NPAControl;
  }
  public static func Enabled(game: GameInstance) -> Bool {
    let control = NPAControl.Get(game);
    if !IsDefined(control) { return true; }
    return control.IsEnabled();
  }
  public final func IsEnabled() -> Bool {
    RWLock.AcquireShared(this.lock);
    let value = !this.disabled;
    RWLock.ReleaseShared(this.lock);
    return value;
  }
  public final func Register(npc: wref<NPCPuppet>) -> Void {
    RWLock.Acquire(this.lock);
    let i = 0;
    while i < ArraySize(this.npcs) {
      if !IsDefined(this.npcs[i]) { ArrayErase(this.npcs, i); } else {
        if Equals(this.npcs[i], npc) {
          if !this.disabled { npc.NPA_ApplyProtection(); }
          RWLock.Release(this.lock);
          return;
        }
        i += 1;
      }
    }
    ArrayPush(this.npcs, npc);
    if !this.disabled { npc.NPA_ApplyProtection(); }
    RWLock.Release(this.lock);
  }
  public final func SetEnabled(enabled: Bool) -> Void {
    RWLock.Acquire(this.lock);
    if Equals(this.disabled, !enabled) { RWLock.Release(this.lock); return; }
    this.disabled = !enabled;
    let i = 0;
    while i < ArraySize(this.npcs) {
      let npc = this.npcs[i];
      if !IsDefined(npc) { ArrayErase(this.npcs, i); } else {
        if enabled { npc.NPA_ApplyProtection(); } else { npc.NPA_RemoveProtection(); }
        i += 1;
      }
    }
    RWLock.Release(this.lock);
  }
  public final func RefreshTarget(npc: wref<NPCPuppet>) -> Void {
    RWLock.Acquire(this.lock);
    if !this.disabled && IsDefined(npc) {
      // Some quest actors already exist when the service becomes available.
      // Adopt them here even if their OnGameAttached registration was missed.
      let found = false;
      let i = 0;
      while i < ArraySize(this.npcs) {
        if !IsDefined(this.npcs[i]) { ArrayErase(this.npcs, i); } else {
          if Equals(this.npcs[i], npc) { found = true; }
          i += 1;
        }
      }
      if !found { ArrayPush(this.npcs, npc); }
      if !npc.npaProtectionApplied { npc.NPA_ApplyProtection(); } else { npc.NPA_RefreshProtection(); }
    }
    RWLock.Release(this.lock);
  }
  public final func Unregister(npc: wref<NPCPuppet>) -> Void {
    RWLock.Acquire(this.lock);
    npc.NPA_RemoveProtection();
    let i = 0;
    while i < ArraySize(this.npcs) {
      if !IsDefined(this.npcs[i]) || Equals(this.npcs[i], npc) { ArrayErase(this.npcs, i); } else { i += 1; }
    }
    RWLock.Release(this.lock);
  }
}

@addField(NPCPuppet)
public let npaProtectionApplied: Bool;
@addField(NPCPuppet)
private let npaReportedImmortalFailure: Bool;
@addField(NPCPuppet)
private let npaReportedInvulnerableFailure: Bool;
@addField(NPCPuppet)
private let npaRemovedImmortalSources: array<CName>;
@addField(NPCPuppet)
private let npaRemovedInvulnerableSources: array<CName>;
@addField(NPCPuppet)
private let npaRemovedImmortalOverrides: array<CName>;
@addField(NPCPuppet)
private let npaRemovedInvulnerableOverrides: array<CName>;

@addMethod(NPCPuppet)
public final func NPA_ApplyProtection() -> Void {
  if this.npaProtectionApplied { return; }
  let god = GameInstance.GetGodModeSystem(this.GetGame());
  let id = this.GetEntityID();
  god.EnableOverride(id, gameGodModeType.Mortal, n"NoPlotArmor");
  this.npaProtectionApplied = true;
  this.NPA_RefreshProtection();
}
// Quest scenes can add protection after attachment. Remember each source we
// actually removed so the master switch can restore it while the NPC exists.
@addMethod(NPCPuppet)
public final func NPA_RefreshProtection() -> Void {
  let god = GameInstance.GetGodModeSystem(this.GetGame());
  let id = this.GetEntityID();
  let sources = god.GetGodModeSources(id, gameGodModeType.Immortal);
  let i = 0;
  while i < ArraySize(sources) {
    if god.RemoveGodMode(id, gameGodModeType.Immortal, sources[i]) {
      if !ArrayContains(this.npaRemovedImmortalSources, sources[i]) { ArrayPush(this.npaRemovedImmortalSources, sources[i]); }
      FTLog(s"[NoPlotArmor] Removed late immortal source \(sources[i]) from \(TDBID.ToStringDEBUG(this.GetRecordID()))");
    } else if NotEquals(sources[i], n"NoPlotArmor") && god.DisableOverride(id, sources[i]) {
      if !ArrayContains(this.npaRemovedImmortalOverrides, sources[i]) { ArrayPush(this.npaRemovedImmortalOverrides, sources[i]); }
      FTLog(s"[NoPlotArmor] Disabled immortal override \(sources[i]) from \(TDBID.ToStringDEBUG(this.GetRecordID()))");
    } else if !this.npaReportedImmortalFailure {
      this.npaReportedImmortalFailure = true;
      FTLog(s"[NoPlotArmor] FAILED to remove immortal source or override \(sources[i]) from \(TDBID.ToStringDEBUG(this.GetRecordID()))");
    }
    i += 1;
  }
  sources = god.GetGodModeSources(id, gameGodModeType.Invulnerable);
  i = 0;
  while i < ArraySize(sources) {
    if god.RemoveGodMode(id, gameGodModeType.Invulnerable, sources[i]) {
      if !ArrayContains(this.npaRemovedInvulnerableSources, sources[i]) { ArrayPush(this.npaRemovedInvulnerableSources, sources[i]); }
      FTLog(s"[NoPlotArmor] Removed late invulnerable source \(sources[i]) from \(TDBID.ToStringDEBUG(this.GetRecordID()))");
    } else if NotEquals(sources[i], n"NoPlotArmor") && god.DisableOverride(id, sources[i]) {
      if !ArrayContains(this.npaRemovedInvulnerableOverrides, sources[i]) { ArrayPush(this.npaRemovedInvulnerableOverrides, sources[i]); }
      FTLog(s"[NoPlotArmor] Disabled invulnerable override \(sources[i]) from \(TDBID.ToStringDEBUG(this.GetRecordID()))");
    } else if !this.npaReportedInvulnerableFailure {
      this.npaReportedInvulnerableFailure = true;
      FTLog(s"[NoPlotArmor] FAILED to remove invulnerable source or override \(sources[i]) from \(TDBID.ToStringDEBUG(this.GetRecordID()))");
    }
    i += 1;
  }
}
@addMethod(NPCPuppet)
public final func NPA_RemoveProtection() -> Void {
  if !this.npaProtectionApplied { return; }
  let god = GameInstance.GetGodModeSystem(this.GetGame());
  let id = this.GetEntityID();
  god.DisableOverride(id, n"NoPlotArmor");
  let i = 0;
  while i < ArraySize(this.npaRemovedImmortalSources) {
    god.AddGodMode(id, gameGodModeType.Immortal, this.npaRemovedImmortalSources[i]); i += 1;
  }
  i = 0;
  while i < ArraySize(this.npaRemovedInvulnerableSources) {
    god.AddGodMode(id, gameGodModeType.Invulnerable, this.npaRemovedInvulnerableSources[i]); i += 1;
  }
  i = 0;
  while i < ArraySize(this.npaRemovedImmortalOverrides) {
    god.EnableOverride(id, gameGodModeType.Immortal, this.npaRemovedImmortalOverrides[i]); i += 1;
  }
  i = 0;
  while i < ArraySize(this.npaRemovedInvulnerableOverrides) {
    god.EnableOverride(id, gameGodModeType.Invulnerable, this.npaRemovedInvulnerableOverrides[i]); i += 1;
  }
  ArrayClear(this.npaRemovedImmortalOverrides);
  ArrayClear(this.npaRemovedInvulnerableOverrides);
  ArrayClear(this.npaRemovedImmortalSources);
  ArrayClear(this.npaRemovedInvulnerableSources);
  this.npaProtectionApplied = false;
}

@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  let control = NPAControl.Get(this.GetGame());
  if IsDefined(control) { control.Register(this); }
  return result;
}
@wrapMethod(NPCPuppet)
protected cb func OnPreUninitialize(evt: ref<entPreUninitializeEvent>) -> Bool {
  let control = NPAControl.Get(this.GetGame());
  if IsDefined(control) { control.Unregister(this); } else { this.NPA_RemoveProtection(); }
  return wrappedMethod(evt);
}
@addMethod(PlayerPuppet)
public final func NPA_SetEnabled(enabled: Bool) -> Void {
  let control = NPAControl.Get(this.GetGame());
  if IsDefined(control) { control.SetEnabled(enabled); }
  if !enabled { this.NPA_RestoreShotTarget(); this.npaRetaliationEnabled = false; }
}

// Early attack-creation flags: the engine decides projectile collision before
// DamageSystem.PreProcess runs. Adding FriendlyFire here (instead of only in
// PreProcess) is the plausible fix for shots passing through friendly NPCs.
// Vanilla EffectPreAction_PreAttack only sets FriendlyFire for special
// WithFriendlyFire effects, and DamageSystem.ModifyHitFlagsForPlayer removes it.
// Keep the late re-add below as a safety net for the post-collision pipeline.
// Diagnostic throttles live on the player and persist in the save, so a plain
// counter stays exhausted forever after the first session. Instead the budget
// refreshes whenever two minutes of game time pass without logging.
@addField(PlayerPuppet)
public let npaLastLogAt: Float;

@addMethod(PlayerPuppet)
public final func NPA_LogRefresh() -> Void {
  let now = EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGame()).GetSimTime());
  if now < this.npaLastLogAt || now - this.npaLastLogAt > 120.0 {
    this.npaPreAttackLogs = 0;
    this.npaFlagLogs = 0;
    this.npaLastLogAt = now;
  }
}

@wrapMethod(AttackData)
public final func PreAttack() {
  wrappedMethod();
  if IsDefined(this.GetInstigator()) && this.GetInstigator().IsPlayer() && NPAControl.Enabled(this.GetInstigator().GetGame()) {
    this.AddFlag(hitFlag.FriendlyFire, n"NoPlotArmor");
    this.AddFlag(hitFlag.IgnoreImmortalityModes, n"NoPlotArmor");
    this.AddFlag(hitFlag.IgnoreStatPoolCustomLimit, n"NoPlotArmor");
    // Fire-path telemetry: proves whether script preactions run for a given
    // weapon. Throttled: 3 logs per 2 minutes of game time.
    let player = this.GetInstigator() as PlayerPuppet;
    if IsDefined(player) {
      player.NPA_LogRefresh();
      if player.npaPreAttackLogs < 3 {
        player.npaPreAttackLogs += 1;
        FTLog(s"[NoPlotArmor] PreAttack attack=\(EnumInt(this.GetAttackType())) friendly=\(this.HasFlag(hitFlag.FriendlyFire)) n=\(player.npaPreAttackLogs)");
      }
    }
  }
}

@addField(PlayerPuppet)
public let npaPreAttackLogs: Int32;
@addField(PlayerPuppet)
public let npaFlagLogs: Int32;

@addField(PlayerPuppet)
public let npaRetaliationEnabled: Bool;

@addMethod(PlayerPuppet)
public final func NPA_SetRetaliationEnabled(enabled: Bool) -> Void {
  this.npaRetaliationEnabled = enabled;
}

// Friendly targets are filtered before a bullet produces a hit event. Temporarily
// change only the player/target agent relationship while a ranged weapon is
// trained on that NPC; our earlier in-game test showed this permits real hits.
// These are explicit pair overrides, not changes to the NPC's faction group.
@addField(PlayerPuppet)
private let npaShotTarget: wref<NPCPuppet>;
@addField(PlayerPuppet)
private let npaShotPlayerAttitude: EAIAttitude;
@addField(PlayerPuppet)
private let npaShotTargetAttitude: EAIAttitude;
@addField(PlayerPuppet)
private let npaShotReleaseDelay: Float;

@addMethod(PlayerPuppet)
private final func NPA_RestoreShotTarget() -> Void {
  let npc = this.npaShotTarget;
  if IsDefined(npc) && IsDefined(this.GetAttitudeAgent()) && IsDefined(npc.GetAttitudeAgent()) {
    let playerAgent = this.GetAttitudeAgent();
    let npcAgent = npc.GetAttitudeAgent();
    // Do not overwrite a real retaliation or another system's later change.
    if Equals(playerAgent.GetAttitudeTowards(npcAgent), EAIAttitude.AIA_Neutral) && Equals(npcAgent.GetAttitudeTowards(playerAgent), EAIAttitude.AIA_Neutral) {
      playerAgent.SetAttitudeTowards(npcAgent, this.npaShotPlayerAttitude);
      npcAgent.SetAttitudeTowards(playerAgent, this.npaShotTargetAttitude);
    }
  }
  this.npaShotTarget = null;
  this.npaShotReleaseDelay = 0.0;
}

@addMethod(PlayerPuppet)
public final func NPA_UpdateShotTarget(candidate: wref<GameObject>, dt: Float) -> Void {
  let npc = candidate as NPCPuppet;
  if !IsDefined(npc) || npc.IsDead() {
    npc = null;
  }
  if IsDefined(npc) {
    let control = NPAControl.Get(this.GetGame());
    if IsDefined(control) { control.RefreshTarget(npc); }
  }
  if IsDefined(this.npaShotTarget) {
    if Equals(this.npaShotTarget, npc) {
      this.npaShotReleaseDelay = 0.35;
      return;
    }
    // Keep the previous override briefly if the crosshair is between targets,
    // but switch immediately when another NPC is acquired.
    if !IsDefined(npc) {
      this.npaShotReleaseDelay -= dt;
      if this.npaShotReleaseDelay > 0.0 { return; }
    }
    this.NPA_RestoreShotTarget();
  }
  if !IsDefined(npc) || !IsDefined(this.GetAttitudeAgent()) || !IsDefined(npc.GetAttitudeAgent()) { return; }
  let playerAgent = this.GetAttitudeAgent();
  let npcAgent = npc.GetAttitudeAgent();
  let playerAttitude = playerAgent.GetAttitudeTowards(npcAgent);
  let npcAttitude = npcAgent.GetAttitudeTowards(playerAgent);
  if Equals(playerAttitude, EAIAttitude.AIA_Hostile) || Equals(npcAttitude, EAIAttitude.AIA_Hostile) { return; }
  if NotEquals(playerAttitude, EAIAttitude.AIA_Friendly) && NotEquals(npcAttitude, EAIAttitude.AIA_Friendly) { return; }
  this.npaShotTarget = npc;
  this.npaShotPlayerAttitude = playerAttitude;
  this.npaShotTargetAttitude = npcAttitude;
  this.npaShotReleaseDelay = 0.35;
  playerAgent.SetAttitudeTowards(npcAgent, EAIAttitude.AIA_Neutral);
  npcAgent.SetAttitudeTowards(playerAgent, EAIAttitude.AIA_Neutral);
}

@wrapMethod(DamageSystem)
private final func PreProcess(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Bool {
  if IsDefined(hitEvent) && IsDefined(hitEvent.target as NPCPuppet) && NPAControl.Enabled(hitEvent.target.GetGame()) && IsDefined(hitEvent.attackData) {
    hitEvent.attackData.AddFlag(hitFlag.IgnoreImmortalityModes, n"NoPlotArmor");
    hitEvent.attackData.AddFlag(hitFlag.IgnoreStatPoolCustomLimit, n"NoPlotArmor");
  }
  let result = wrappedMethod(hitEvent, cache);
  if !IsDefined(hitEvent) { return result; }
  let npc = hitEvent.target as NPCPuppet;
  if IsDefined(npc) && IsDefined(hitEvent.attackData) && IsDefined(hitEvent.attackData.GetInstigator()) && hitEvent.attackData.GetInstigator().IsPlayer() {
    let dmg = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    let hp = GameInstance.GetStatPoolsSystem(npc.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health);
    npc.NoPlotArmor_RecordHit(result, hitEvent.attackData, dmg, hp, hitEvent.projectionPipeline);
  }
  return result;
}

// The vanilla function removes the player's original friendly-fire flag.
// Add ours afterward so it survives the quick-exit check.
@wrapMethod(DamageSystem)
private final func ModifyHitFlagsForPlayer(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Void {
  // Capture the incoming flag state before vanilla strips it. Throttled.
  let incoming = false;
  let atk = -1;
  let inst = IsDefined(hitEvent) && IsDefined(hitEvent.attackData) ? hitEvent.attackData.GetInstigator() : null;
  if IsDefined(inst) && inst.IsPlayer() {
    incoming = hitEvent.attackData.HasFlag(hitFlag.FriendlyFire);
    atk = EnumInt(hitEvent.attackData.GetAttackType());
  }
  wrappedMethod(hitEvent, cache);
  if IsDefined(inst) && inst.IsPlayer() {
    let player = inst as PlayerPuppet;
    if IsDefined(player) {
      player.NPA_LogRefresh();
      if player.npaFlagLogs < 3 {
        player.npaFlagLogs += 1;
      // Identify the exact weapon + attack records behind this shot. Previews
      // carry them too, so even a non-colliding shot reveals its records.
      let wStr = "none";
      let aStr = "none";
      let w = hitEvent.attackData.GetWeapon();
      if IsDefined(w) {
        wStr = TDBID.ToStringDEBUG(ItemID.GetTDBID(w.GetItemID()));
      }
      let attackDef = hitEvent.attackData.GetAttackDefinition();
      if IsDefined(attackDef) {
        aStr = TDBID.ToStringDEBUG(attackDef.GetRecord().GetID());
      }
      FTLog(s"[NoPlotArmor] HitFlagsIn attack=\(atk) friendlyIn=\(incoming) weapon=\(wStr) attackRec=\(aStr) n=\(player.npaFlagLogs)");
    };
    if IsDefined(hitEvent) && IsDefined(hitEvent.target as NPCPuppet) && NPAControl.Enabled(hitEvent.target.GetGame()) && IsDefined(hitEvent.attackData) {
      hitEvent.attackData.AddFlag(hitFlag.FriendlyFire, n"NoPlotArmor");
    }
  }
  }
}

@wrapMethod(HitReactionComponent)
protected final func CanDieCondition(opt doNotCheckAttackData: Bool) -> Bool {
  // Preserve the game's nonlethal and fist-fight rules. The killability
  // override is intended for lethal attacks, not to turn knockout hits lethal.
  if IsDefined(this.m_ownerNPC) && IsDefined(this.m_attackData) && !doNotCheckAttackData {
    if this.m_attackData.HasFlag(hitFlag.Nonlethal)
      || StatusEffectSystem.ObjectHasStatusEffect(this.m_ownerNPC, t"GameplayRestriction.FistFight")
      || (IsDefined(this.m_attackData.GetInstigator())
        && StatusEffectSystem.ObjectHasStatusEffect(this.m_attackData.GetInstigator(), t"GameplayRestriction.FistFight")) {
      return wrappedMethod(doNotCheckAttackData);
    }
  }
  if IsDefined(this.m_ownerNPC) && NPAControl.Enabled(this.m_ownerNPC.GetGame()) { return true; }
  return wrappedMethod(doNotCheckAttackData);
}

// Called only for the spawner's tagged entities, never quest-owned originals.
@addMethod(NPCPuppet)
public final func NPA_NeutralizeSpawn(player: wref<PlayerPuppet>) -> Void {
  if !IsDefined(player) || this.IsDead() { return; }
  GameObject.ChangeAttitudeToNeutral(this, player);
  GameObject.ChangeAttitudeToNeutral(player, this);
}

@addField(NPCPuppet)
private let npaSpawnHealthAdjusted: Bool;

// Cap unusually large health pools on non-boss spawned copies only.
@addMethod(NPCPuppet)
public final func NPA_AdjustSpawnHealth() -> Bool {
  if this.npaSpawnHealthAdjusted { return true; }
  if this.IsBoss() { this.npaSpawnHealthAdjusted = true; return true; }
  let id = Cast<StatsObjectID>(this.GetEntityID());
  let pools = GameInstance.GetStatPoolsSystem(this.GetGame());
  let stats = GameInstance.GetStatsSystem(this.GetGame());
  let maxHealth = pools.GetStatPoolMaxPointValue(id, gamedataStatPoolType.Health);
  let statHealth = stats.GetStatValue(id, gamedataStatType.Health);
  if maxHealth <= 0.0 || statHealth <= 0.0 { return false; }
  if maxHealth > 1000.0 {
    let mod = RPGManager.CreateStatModifier(gamedataStatType.Health, gameStatModifierType.Multiplier, 1000.0 / maxHealth);
    if !stats.AddModifier(id, mod) { return false; }
    FTLog(s"[NoPlotArmor] spawn health adjustment applied: record=\(TDBID.ToStringDEBUG(this.GetRecordID())) priorMax=\(maxHealth) priorStat=\(statHealth) multiplier=\(1000.0 / maxHealth)");
  }
  this.npaSpawnHealthAdjusted = true;
  return true;
}

@addMethod(NPCPuppet)
public final func NoPlotArmor_Describe() -> String {
  let id = this.GetEntityID();
  let god = GameInstance.GetGodModeSystem(this.GetGame());
  let hp = GameInstance.GetStatPoolsSystem(this.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(id), gamedataStatPoolType.Health);
  let invStat = GameInstance.GetStatsSystem(this.GetGame()).GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.IsInvulnerable);
  let immSrc = god.GetGodModeSources(id, gameGodModeType.Immortal);
  let invSrc = god.GetGodModeSources(id, gameGodModeType.Invulnerable);
  let component = this.GetDismembermentComponent();
  let limbs: DismemberedLimbCount;
  if IsDefined(component) { limbs = component.GetDismemberedLimbCount(); }
  let spawned = this.HasTag(n"NoPlotArmor_Spawn") || this.HasTag(n"NPCOmegaGore_Spawn") || this.HasTag(n"OmegaNPC_Spawn");
  return s"record=\(TDBID.ToStringDEBUG(this.GetRecordID())) entity=\(EntityID.ToDebugString(id)) spawned=\(spawned) appearance=\(this.GetCurrentAppearanceName()) hp%=\(hp) immortal=\(god.HasGodMode(id, gameGodModeType.Immortal)) immSrcN=\(ArraySize(immSrc)) invulnerable=\(god.HasGodMode(id, gameGodModeType.Invulnerable)) invSrcN=\(ArraySize(invSrc)) invulnerableStat=\(invStat) boss=\(this.IsBoss()) defeat=\(this.IsDefeatMechanicActive()) dead=\(this.IsDead()) defeated=\(ScriptedPuppet.IsDefeated(this)) aboutDie=\(this.IsAboutToDie()) aboutDef=\(this.IsAboutToBeDefeated()) crowd=\(this.IsCrowd()) dismemberment=\(IsDefined(component)) fleshLimbs=\(limbs.fleshDismemberments) cyberLimbs=\(limbs.cyberDismemberments) onHits=\(this.npaOnHitCount) hits=\(this.npaHitCount) hitInfo=[\(this.npaLastHit)] goreChecks=\(this.npaGoreCount) goreInfo=[\(this.npaLastGore)] deaths=\(this.npaDeathCount) deathInfo=[\(this.npaLastDeath)]";
}

// The player's friendly-target flag drives weapon-safe and attack checks.
// Suppress that flag so the player can aim at friendly NPCs; other safe-zone
// and scene restrictions still apply independently.
@wrapMethod(PlayerPuppet)
public final func IsAimingAtFriendly() -> Bool {
  if !NPAControl.Enabled(this.GetGame()) { return wrappedMethod(); }
  return false;
}

// These counters are observed by the CET target sampler. onHits increments when
// the engine delivers a collision hit to the NPC (GameObject.OnHit), hits
// increments when the hit reaches DamageSystem.PreProcess, goreChecks when
// dismemberment conditions are evaluated. hitInfo proj=true means a UI damage
// preview, not a real hit: the projection pipeline evaluates PreProcess
// without dealing damage. onHits>0 with hits==0 means
// collision works but the damage pipeline rejects the hit; both zero during
// live fire means shots are still rejected before collision.
@addField(NPCPuppet)
private let npaHitCount: Int32;
@addField(NPCPuppet)
private let npaOnHitCount: Int32;
@addField(NPCPuppet)
private let npaLastHit: String;
@addField(NPCPuppet)
private let npaGoreCount: Int32;
@addField(NPCPuppet)
private let npaLastGore: String;
@addField(NPCPuppet)
private let npaDeathCount: Int32;
@addField(NPCPuppet)
private let npaLastDeath: String;

@addMethod(NPCPuppet)
public final func NoPlotArmor_RecordHit(accepted: Bool, data: ref<AttackData>, dmg: Float, hp: Float, proj: Bool) -> Void {
  this.npaHitCount += 1;
  this.npaLastHit = s"preprocess=\(accepted) proj=\(proj) dmg=\(dmg) hp=\(hp) attack=\(EnumInt(data.GetAttackType())) friendly=\(data.HasFlag(hitFlag.FriendlyFire)) friendlyIgnored=\(data.HasFlag(hitFlag.FriendlyFireIgnored)) immortalTgt=\(data.HasFlag(hitFlag.ImmortalTarget)) noDamage=\(data.HasFlag(hitFlag.DealNoDamage)) nonlethal=\(data.HasFlag(hitFlag.Nonlethal))";
}

@addMethod(NPCPuppet)
public final func NoPlotArmor_RecordOnHit() -> Void {
  this.npaOnHitCount += 1;
}

public class NPARetaliationEvent extends Event {
  public let player: wref<PlayerPuppet>;
}
@addMethod(NPCPuppet)
protected cb func OnNPARetaliationEvent(evt: ref<NPARetaliationEvent>) -> Bool {
  let player = evt.player;
  if !IsDefined(player) || !NPAControl.Enabled(this.GetGame()) || !player.npaRetaliationEnabled || this.IsDead() { return false; }
  let wasHostile = Equals(GameObject.GetAttitudeBetween(this, player), EAIAttitude.AIA_Hostile);
  if !wasHostile { GameObject.ChangeAttitudeToHostile(this, player); }
  // A hostile attitude alone does not register the player as an AI threat.
    let tracker: wref<TargetTrackingExtension>;
    if TargetTrackingExtension.Get(this, tracker) {
      tracker.AddThreat(player, true, player.GetWorldPosition(), 1.0, -1.0, false);
    }
    // A quest workspot can prevent this actor reacting at all. Keep vehicle,
    // finisher and synchronized animation transitions under their own control.
    if !VehicleComponent.IsMountedToVehicle(this.GetGame(), this)
      && !this.HasWorkspotTag(n"FinisherWorkspot")
      && !StatusEffectSystem.ObjectHasStatusEffect(this, t"WorkspotStatus.SyncAnimation")
      && !StatusEffectSystem.ObjectHasStatusEffect(this, t"WorkspotStatus.Death") {
      let workspots = GameInstance.GetWorkspotSystem(this.GetGame());
      if workspots.IsActorInWorkspot(this) { workspots.StopNpcInWorkspot(this); }
    }
  if !wasHostile { FTLog(s"[NoPlotArmor] Retaliation requested for \(TDBID.ToStringDEBUG(this.GetRecordID())) tracker=\(IsDefined(tracker))"); }
  return false;
}
@wrapMethod(GameObject)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
  let npc = this as NPCPuppet;
  if IsDefined(npc) && IsDefined(evt) && IsDefined(evt.attackData) && IsDefined(evt.attackData.GetInstigator()) && evt.attackData.GetInstigator().IsPlayer() {
    npc.NoPlotArmor_RecordOnHit();
    let player = evt.attackData.GetInstigator() as PlayerPuppet;
    if IsDefined(player) && NPAControl.Enabled(player.GetGame()) && player.npaRetaliationEnabled && !npc.IsDead() {
      let request = new NPARetaliationEvent();
      request.player = player;
      npc.QueueEvent(request);
    }
  }
  return wrappedMethod(evt);
}

@addMethod(NPCPuppet)
public final func NoPlotArmor_RecordGore(info: String) -> Void {
  this.npaGoreCount += 1;
  this.npaLastGore = info;
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  this.npaDeathCount += 1;
  this.npaLastDeath = s"dead=\(this.IsDead()) defeated=\(ScriptedPuppet.IsDefeated(this))";
  return wrappedMethod(evt);
}

// TweakDB fix attempt for living-friendly bullet collision: the runtime
// FriendlyFire flag is set from creation yet bullets still ghost friendlies,
// and no attack record uses the WithFriendlyFire effector. The remaining
// record-level lever is the attack's own HitFlags. This flips FriendlyFire
// onto the shared hitscan record at boot (runtime only, reverts if removed).
public class NPAAttackFlagTweak extends ScriptableTweak {
  protected cb func OnApply() -> Void {
    let id = t"Attacks.Bullet_GameEffect";
    let rec = TweakDBInterface.GetAttackRecord(id);
    if !IsDefined(rec) {
      FTLog("[NoPlotArmor] attack record missing");
      return;
    }
    let cur = rec.HitFlags();
    let i = 0;
    while i < ArraySize(cur) {
      if Equals(cur[i], "FriendlyFire") {
        FTLog("[NoPlotArmor] FriendlyFire already present on Bullet_GameEffect");
        return;
      }
      i += 1;
    }
    ArrayPush(cur, "FriendlyFire");
    if TweakDBManager.SetFlat(id + t".hitFlags", cur) && TweakDBManager.UpdateRecord(id) {
      FTLog("[NoPlotArmor] FriendlyFire added to Bullet_GameEffect");
    } else {
      FTLog("[NoPlotArmor] FAILED to set hitFlags flat on Bullet_GameEffect");
    }
  }
}

// Hit reaction initializes its thresholds before the spawn health modifier is
// applied. Rescale its cached thresholds once for the adjusted spawned copy.
@addField(HitReactionComponent)
private let npaScaledHealthThresholds: Bool;
@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  if !this.npaScaledHealthThresholds && IsDefined(this.m_ownerNPC)
    && NPAControl.Enabled(this.m_ownerNPC.GetGame())
    && (this.m_ownerNPC.HasTag(n"NoPlotArmor_Spawn") || this.m_ownerNPC.HasTag(n"NPCOmegaGore_Spawn") || this.m_ownerNPC.HasTag(n"OmegaNPC_Spawn")) && this.m_totalHealth > 0.0 {
    let id = Cast<StatsObjectID>(this.m_ownerNPC.GetEntityID());
    let maxHealth = GameInstance.GetStatPoolsSystem(this.m_ownerNPC.GetGame()).GetStatPoolMaxPointValue(id, gamedataStatPoolType.Health);
    if maxHealth > 0.0 && maxHealth < this.m_totalHealth * 0.9 {
      let ratio = maxHealth / this.m_totalHealth;
      let i = 0;
      while i < ArraySize(this.m_woundedBodyPartDamageThreshold) {
        this.m_woundedBodyPartDamageThreshold[i] *= ratio; i += 1;
      }
      i = 0;
      while i < ArraySize(this.m_dismembermentBodyPartDamageThreshold) {
        this.m_dismembermentBodyPartDamageThreshold[i] *= ratio; i += 1;
      }
      this.m_totalHealth = maxHealth;
      this.npaScaledHealthThresholds = true;
      FTLog(s"[NoPlotArmor] Rescaled spawned NPC gore thresholds by \(ratio)");
    }
  }
  wrappedMethod();
}

@wrapMethod(HitReactionComponent)
protected final func DismembermentConditions() -> Bool {
  let result = wrappedMethod();
  if IsDefined(this.m_ownerNPC) && IsDefined(this.m_attackData) && IsDefined(this.m_attackData.GetInstigator()) && this.m_attackData.GetInstigator().IsPlayer() {
    let shape = this.GetHitShapeUserData();
    if IsDefined(shape) {
      let zone = HitShapeUserDataBase.GetHitReactionZone(shape);
      let index = EnumInt(zone);
      let woundDamage: Float = -1.0;
      let dismemberDamage: Float = -1.0;
      if index >= 0 && index < ArraySize(this.m_bodyPartWoundCumulatedDamages) { woundDamage = this.m_bodyPartWoundCumulatedDamages[index]; }
      if index >= 0 && index < ArraySize(this.m_bodyPartDismemberCumulatedDamages) { dismemberDamage = this.m_bodyPartDismemberCumulatedDamages[index]; }
      // Panam's story record can have no usable native corpse threshold.
      // Preserve the native living-limb branch; allow only sufficiently damaged
      // corpse regions on the copy spawned by this mod, never a living NPC.
      if !result && NPAControl.Enabled(this.m_ownerNPC.GetGame()) && Equals(this.m_ownerNPC.GetRecordID(), t"Character.Panam")
        && (this.m_ownerNPC.HasTag(n"NoPlotArmor_Spawn") || this.m_ownerNPC.HasTag(n"NPCOmegaGore_Spawn") || this.m_ownerNPC.HasTag(n"OmegaNPC_Spawn"))
        && this.m_ownerNPC.IsDead()
        && !this.m_attackData.HasFlag(hitFlag.Nonlethal)
        && IsDefined(this.m_ownerNPC.GetDismembermentComponent())
        && index >= 0 && index < ArraySize(this.m_bodyPartDismemberCumulatedDamages)
        && NotEquals(zone, EHitReactionZone.Special)
        && this.GetOwnerTotalHealth() > 0.0
        && dismemberDamage >= this.GetOwnerTotalHealth() * 0.10 {
        result = true;
      }
      this.m_ownerNPC.NoPlotArmor_RecordGore(s"allowed=\(result) zone=\(index) part=\(EnumInt(HitShapeUserDataBase.GetDismembermentBodyPart(shape))) material=\(EnumInt(shape.GetShapeType())) alive=\(this.m_isAlive) dying=\(this.m_ownerNPC.IsAboutToDie()) defeated=\(ScriptedPuppet.IsDefeated(this.m_ownerNPC)) force=\(this.m_attackData.HasFlag(hitFlag.ForceDismember)) woundDamage=\(woundDamage) dismemberDamage=\(dismemberDamage) totalHealth=\(this.GetOwnerTotalHealth()) human=\(this.m_ownerNPC.IsHuman()) cover=\(this.m_inCover) workspot=\(this.m_inWorkspot)");
    } else {
      this.m_ownerNPC.NoPlotArmor_RecordGore("missing hit shape");
    }
  }
  return result;
}

// Story-appearance wound donors. Same technique as Collateral Damage's
// WoundInject: the donor's wound resources are captured on its own
// Resource/Load and assigned into whichever .app loads for the target path
// (vanilla or a body-mod override). Nothing is constructed; a target file that
// already has wounds is left alone, so other dismemberment mods win.
// Local donors use the game's Tyger Claw wound resources for the matching
// body type and map the wound config to the names in each target appearance.
public class NPAWoundDonor extends IScriptable {
  private let token: ref<ResourceToken>;
  private let captured: Bool;
  private let wounds: array<ref<entdismembermentWoundResource>>;
  private let effects: array<ref<entdismembermentEffectResource>>;
  private let config: entdismembermentWoundsConfigSet;
  private let name: String;
  private let reported: Bool;

  public static func Create(target: ResRef, donor: ResRef, name: String) -> ref<NPAWoundDonor> {
    let self = new NPAWoundDonor();
    self.name = name;
    let callbacks = GameInstance.GetCallbackSystem();
    callbacks.RegisterCallback(n"Resource/Load", self, n"OnDonorLoad").AddTarget(ResourceTarget.Path(donor));
    callbacks.RegisterCallback(n"Resource/Load", self, n"OnAppLoad").AddTarget(ResourceTarget.Path(target));
    self.token = GameInstance.GetResourceDepot().LoadResource(donor);
    return self;
  }

  private cb func OnDonorLoad(event: ref<ResourceEvent>) {
    let donor = event.GetResource() as appearanceAppearanceResource;
    if !IsDefined(donor) || ArraySize(donor.Wounds) == 0 { return; }
    this.wounds = donor.Wounds;
    this.effects = donor.DismEffects;
    this.config = donor.DismWoundConfig;
    this.captured = true;
  }

  private cb func OnAppLoad(event: ref<ResourceEvent>) {
    let app = event.GetResource() as appearanceAppearanceResource;
    if !IsDefined(app) || ArraySize(app.Wounds) > 0 { return; }
    if !this.captured {
      if !this.reported {
        this.reported = true;
        FTLog(s"[NoPlotArmor] wound donor not ready for \(this.name)");
      }
      return;
    }
    app.Wounds = this.wounds;
    app.DismEffects = this.effects;
    app.DismWoundConfig = this.config;
    if !this.reported {
      this.reported = true;
      FTLog(s"[NoPlotArmor] wound data injected for \(this.name)");
    }
  }
}

public class NPAWoundInjector extends ScriptableService {
  private let donors: array<ref<NPAWoundDonor>>;

  private func Add(target: ResRef, donor: ResRef, name: String) {
    ArrayPush(this.donors, NPAWoundDonor.Create(target, donor, name));
  }

  private cb func OnLoad() {
    this.Add(r"base\\characters\\appearances\\main_npc\\judy.app", r"noplotarmor\\wound_donors\\judy.app", "judy");
    this.Add(r"base\\characters\\appearances\\main_npc\\celebrity_chrome.app", r"noplotarmor\\wound_donors\\celebrity_chrome.app", "celebrity_chrome");
    this.Add(r"base\\characters\\appearances\\main_npc\\panam.app", r"noplotarmor\\wound_donors\\panam.app", "panam");
    this.Add(r"base\\characters\\appearances\\main_npc\\rogue.app", r"noplotarmor\\wound_donors\\rogue.app", "rogue");
    this.Add(r"base\\characters\\appearances\\main_npc\\evelyn.app", r"noplotarmor\\wound_donors\\evelyn.app", "evelyn");
    this.Add(r"base\\characters\\appearances\\main_npc\\misty.app", r"noplotarmor\\wound_donors\\misty.app", "misty");
    this.Add(r"base\\characters\\appearances\\main_npc\\clair.app", r"noplotarmor\\wound_donors\\clair.app", "clair");
    this.Add(r"base\\characters\\appearances\\main_npc\\meredith_stout.app", r"noplotarmor\\wound_donors\\meredith_stout.app", "meredith_stout");
    this.Add(r"base\\characters\\appearances\\main_npc\\elizabeth_peralez.app", r"noplotarmor\\wound_donors\\elizabeth_peralez.app", "elizabeth_peralez");
    this.Add(r"base\\characters\\appearances\\main_npc\\jackie_welles.app", r"noplotarmor\\wound_donors\\jackie_welles.app", "jackie_welles");
    this.Add(r"base\\characters\\appearances\\main_npc\\goro_takemura.app", r"noplotarmor\\wound_donors\\goro_takemura.app", "goro_takemura");
    this.Add(r"base\\characters\\appearances\\main_npc\\river_ward.app", r"noplotarmor\\wound_donors\\river_ward.app", "river_ward");
    this.Add(r"base\\characters\\appearances\\main_npc\\kerry_eurodyne.app", r"noplotarmor\\wound_donors\\kerry_eurodyne.app", "kerry_eurodyne");
    this.Add(r"base\\characters\\appearances\\main_npc\\victor_vektor.app", r"noplotarmor\\wound_donors\\victor_vektor.app", "victor_vektor");
    this.Add(r"base\\characters\\appearances\\main_npc\\dex.app", r"noplotarmor\\wound_donors\\dex.app", "dex");
    this.Add(r"base\\characters\\appearances\\main_npc\\saul.app", r"noplotarmor\\wound_donors\\saul.app", "saul");
    this.Add(r"base\\characters\\appearances\\main_npc\\jefferson_peralez.app", r"noplotarmor\\wound_donors\\jefferson_peralez.app", "jefferson_peralez");
    this.Add(r"base\\characters\\appearances\\main_npc\\bodyguard_dex.app", r"noplotarmor\\wound_donors\\bodyguard_dex.app", "bodyguard_dex");
    this.Add(r"base\\characters\\appearances\\main_npc\\8ug8ear.app", r"noplotarmor\\wound_donors\\8ug8ear.app", "8ug8ear");
    this.Add(r"base\\characters\\appearances\\main_npc\\alt.app", r"noplotarmor\\wound_donors\\alt.app", "alt");
    this.Add(r"base\\characters\\appearances\\main_npc\\capitan_reyes.app", r"noplotarmor\\wound_donors\\capitan_reyes.app", "capitan_reyes");
    this.Add(r"base\\characters\\appearances\\main_npc\\dakota_smith.app", r"noplotarmor\\wound_donors\\dakota_smith.app", "dakota_smith");
    this.Add(r"base\\characters\\appearances\\main_npc\\dino.app", r"noplotarmor\\wound_donors\\dino.app", "dino");
    this.Add(r"base\\characters\\appearances\\main_npc\\fingers.app", r"noplotarmor\\wound_donors\\fingers.app", "fingers");
    this.Add(r"base\\characters\\appearances\\main_npc\\josh_kavorkin.app", r"noplotarmor\\wound_donors\\josh_kavorkin.app", "josh_kavorkin");
    this.Add(r"base\\characters\\appearances\\main_npc\\joshua_stephenson.app", r"noplotarmor\\wound_donors\\joshua_stephenson.app", "joshua_stephenson");
    this.Add(r"base\\characters\\appearances\\main_npc\\peter_sampson.app", r"noplotarmor\\wound_donors\\peter_sampson.app", "peter_sampson");
    this.Add(r"base\\characters\\appearances\\main_npc\\psycho.app", r"noplotarmor\\wound_donors\\psycho.app", "psycho");
    this.Add(r"base\\characters\\appearances\\main_npc\\sandra_dorset.app", r"noplotarmor\\wound_donors\\sandra_dorset.app", "sandra_dorset");
    this.Add(r"base\\characters\\appearances\\main_npc\\santiago.app", r"noplotarmor\\wound_donors\\santiago.app", "santiago");
    this.Add(r"base\\characters\\appearances\\main_npc\\sebastian_perez.app", r"noplotarmor\\wound_donors\\sebastian_perez.app", "sebastian_perez");
    this.Add(r"base\\characters\\appearances\\main_npc\\steve.app", r"noplotarmor\\wound_donors\\steve.app", "steve");
    this.Add(r"base\\characters\\appearances\\main_npc\\t_bug.app", r"noplotarmor\\wound_donors\\t_bug.app", "t_bug");
    this.Add(r"base\\characters\\appearances\\main_npc\\thompson.app", r"noplotarmor\\wound_donors\\thompson.app", "thompson");
    this.Add(r"base\\characters\\appearances\\main_npc\\us_cracks_band.app", r"noplotarmor\\wound_donors\\us_cracks_band.app", "us_cracks_band");
    this.Add(r"base\\characters\\appearances\\main_npc\\wakako_okada.app", r"noplotarmor\\wound_donors\\wakako_okada.app", "wakako_okada");
    this.Add(r"base\\characters\\appearances\\main_npc\\weldon_holt.app", r"noplotarmor\\wound_donors\\weldon_holt.app", "weldon_holt");
    this.Add(r"base\\characters\\appearances\\main_npc\\weyland.app", r"noplotarmor\\wound_donors\\weyland.app", "weyland");
    this.Add(r"base\\characters\\appearances\\main_npc\\wilson.app", r"noplotarmor\\wound_donors\\wilson.app", "wilson");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\alex.app", r"noplotarmor\\wound_donors\\alex.app", "alex");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\bella.app", r"noplotarmor\\wound_donors\\bella.app", "bella");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\kurt.app", r"noplotarmor\\wound_donors\\kurt.app", "kurt");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\lizzy_wizzy.app", r"noplotarmor\\wound_donors\\lizzy_wizzy.app", "lizzy_wizzy");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\mr_hands.app", r"noplotarmor\\wound_donors\\mr_hands.app", "mr_hands");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\president_myers.app", r"noplotarmor\\wound_donors\\president_myers.app", "president_myers");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\reed.app", r"noplotarmor\\wound_donors\\reed.app", "reed");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\songbird.app", r"noplotarmor\\wound_donors\\songbird.app", "songbird");
    this.Add(r"ep1\\characters\\appearances\\main_npc\\theo.app", r"noplotarmor\\wound_donors\\theo.app", "theo");
  }
}
