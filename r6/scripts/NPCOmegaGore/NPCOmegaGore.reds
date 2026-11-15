module NPCOmegaGore

// Keep other systems' protection sources intact; remove only our own override
// when the entity leaves the world. Its actual runtime behavior is diagnostic.
@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  let godSys = GameInstance.GetGodModeSystem(this.GetGame());
  godSys.EnableOverride(this.GetEntityID(), gameGodModeType.Mortal, n"NPCOmegaGore");
  // Spawned copies and ambient NPCs are often protected only by the Default
  // source. Quest- or scene-owned sources are left intact: removing those
  // would break quests in ways a respawn cannot fix.
  godSys.RemoveGodMode(this.GetEntityID(), gameGodModeType.Immortal, n"Default");
  godSys.RemoveGodMode(this.GetEntityID(), gameGodModeType.Invulnerable, n"Default");
  return result;
}

@wrapMethod(NPCPuppet)
protected cb func OnPreUninitialize(evt: ref<entPreUninitializeEvent>) -> Bool {
  GameInstance.GetGodModeSystem(this.GetGame()).DisableOverride(this.GetEntityID(), n"NPCOmegaGore");
  return wrappedMethod(evt);
}

// Early attack-creation flags: the engine decides projectile collision before
// DamageSystem.PreProcess runs. Adding FriendlyFire here (instead of only in
// PreProcess) is the plausible fix for shots passing through friendly NPCs.
// Vanilla EffectPreAction_PreAttack only sets FriendlyFire for special
// WithFriendlyFire effects, and DamageSystem.ModifyHitFlagsForPlayer removes it.
// Keep the late re-add below as a safety net for the post-collision pipeline.
@wrapMethod(AttackData)
public final func PreAttack() {
  wrappedMethod();
  if IsDefined(this.GetInstigator()) && this.GetInstigator().IsPlayer() {
    this.AddFlag(hitFlag.FriendlyFire, n"NPCOmegaGore");
    this.AddFlag(hitFlag.IgnoreImmortalityModes, n"NPCOmegaGore");
    this.AddFlag(hitFlag.IgnoreStatPoolCustomLimit, n"NPCOmegaGore");
    // Fire-path telemetry: proves whether script preactions run for a given
    // weapon. Throttled to 3 logs per player session.
    let player = this.GetInstigator() as PlayerPuppet;
    if IsDefined(player) && player.npgPreAttackLogs < 3 {
      player.npgPreAttackLogs += 1;
      FTLog(s"[NPCOmegaGore] PreAttack attack=\(EnumInt(this.GetAttackType())) friendly=\(this.HasFlag(hitFlag.FriendlyFire)) n=\(player.npgPreAttackLogs)");
    }
  }
}

@addField(PlayerPuppet)
public let npgPreAttackLogs: Int32;
@addField(PlayerPuppet)
public let npgFlagLogs: Int32;

@wrapMethod(DamageSystem)
private final func PreProcess(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Bool {
  if IsDefined(hitEvent) && IsDefined(hitEvent.target as NPCPuppet) && IsDefined(hitEvent.attackData) {
    hitEvent.attackData.AddFlag(hitFlag.IgnoreImmortalityModes, n"NPCOmegaGore");
    hitEvent.attackData.AddFlag(hitFlag.IgnoreStatPoolCustomLimit, n"NPCOmegaGore");
  }
  let result = wrappedMethod(hitEvent, cache);
  if !IsDefined(hitEvent) { return result; }
  let npc = hitEvent.target as NPCPuppet;
  if IsDefined(npc) && IsDefined(hitEvent.attackData) && IsDefined(hitEvent.attackData.GetInstigator()) && hitEvent.attackData.GetInstigator().IsPlayer() {
    let dmg = hitEvent.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health);
    let hp = GameInstance.GetStatPoolsSystem(npc.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health);
    npc.NPCOmegaGore_RecordHit(result, hitEvent.attackData, dmg, hp, hitEvent.projectionPipeline);
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
    if IsDefined(player) && player.npgFlagLogs < 3 {
      player.npgFlagLogs += 1;
      FTLog(s"[NPCOmegaGore] HitFlagsIn attack=\(atk) friendlyIn=\(incoming) n=\(player.npgFlagLogs)");
    };
    if IsDefined(hitEvent) && IsDefined(hitEvent.target as NPCPuppet) && IsDefined(hitEvent.attackData) {
      hitEvent.attackData.AddFlag(hitFlag.FriendlyFire, n"NPCOmegaGore");
    }
  }
}

@wrapMethod(HitReactionComponent)
protected final func CanDieCondition(opt doNotCheckAttackData: Bool) -> Bool {
  if IsDefined(this.m_ownerNPC) { return true; }
  return wrappedMethod(doNotCheckAttackData);
}

@addMethod(NPCPuppet)
public final func NPCOmegaGore_Describe() -> String {
  let id = this.GetEntityID();
  let god = GameInstance.GetGodModeSystem(this.GetGame());
  let hp = GameInstance.GetStatPoolsSystem(this.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(id), gamedataStatPoolType.Health);
  let invStat = GameInstance.GetStatsSystem(this.GetGame()).GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.IsInvulnerable);
  let immSrc = god.GetGodModeSources(id, gameGodModeType.Immortal);
  let invSrc = god.GetGodModeSources(id, gameGodModeType.Invulnerable);
  return s"record=\(TDBID.ToStringDEBUG(this.GetRecordID())) entity=\(EntityID.ToDebugString(id)) hp%=\(hp) immortal=\(god.HasGodMode(id, gameGodModeType.Immortal)) immSrcN=\(ArraySize(immSrc)) invulnerable=\(god.HasGodMode(id, gameGodModeType.Invulnerable)) invSrcN=\(ArraySize(invSrc)) invulnerableStat=\(invStat) boss=\(this.IsBoss()) defeat=\(this.IsDefeatMechanicActive()) dead=\(this.IsDead()) defeated=\(ScriptedPuppet.IsDefeated(this)) aboutDie=\(this.IsAboutToDie()) aboutDef=\(this.IsAboutToBeDefeated()) crowd=\(this.IsCrowd()) dismemberment=\(IsDefined(this.GetDismembermentComponent())) onHits=\(this.npgOnHitCount) hits=\(this.npgHitCount) hitInfo=[\(this.npgLastHit)] goreChecks=\(this.npgGoreCount) goreInfo=[\(this.npgLastGore)] deaths=\(this.npgDeathCount) deathInfo=[\(this.npgLastDeath)]";
}

// The player's friendly-target flag drives weapon-safe and attack checks.
// Suppress that flag so the player can aim at friendly NPCs; other safe-zone
// and scene restrictions still apply independently.
@wrapMethod(PlayerPuppet)
public final func IsAimingAtFriendly() -> Bool {
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
private let npgHitCount: Int32;
@addField(NPCPuppet)
private let npgOnHitCount: Int32;
@addField(NPCPuppet)
private let npgLastHit: String;
@addField(NPCPuppet)
private let npgGoreCount: Int32;
@addField(NPCPuppet)
private let npgLastGore: String;
@addField(NPCPuppet)
private let npgDeathCount: Int32;
@addField(NPCPuppet)
private let npgLastDeath: String;

@addMethod(NPCPuppet)
public final func NPCOmegaGore_RecordHit(accepted: Bool, data: ref<AttackData>, dmg: Float, hp: Float, proj: Bool) -> Void {
  this.npgHitCount += 1;
  this.npgLastHit = s"preprocess=\(accepted) proj=\(proj) dmg=\(dmg) hp=\(hp) attack=\(EnumInt(data.GetAttackType())) friendly=\(data.HasFlag(hitFlag.FriendlyFire)) friendlyIgnored=\(data.HasFlag(hitFlag.FriendlyFireIgnored)) immortalTgt=\(data.HasFlag(hitFlag.ImmortalTarget)) noDamage=\(data.HasFlag(hitFlag.DealNoDamage)) nonlethal=\(data.HasFlag(hitFlag.Nonlethal))";
}

@addMethod(NPCPuppet)
public final func NPCOmegaGore_RecordOnHit() -> Void {
  this.npgOnHitCount += 1;
}

@wrapMethod(GameObject)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
  let npc = this as NPCPuppet;
  if IsDefined(npc) && IsDefined(evt) && IsDefined(evt.attackData) && IsDefined(evt.attackData.GetInstigator()) && evt.attackData.GetInstigator().IsPlayer() {
    npc.NPCOmegaGore_RecordOnHit();
  }
  return wrappedMethod(evt);
}

@addMethod(NPCPuppet)
public final func NPCOmegaGore_RecordGore(info: String) -> Void {
  this.npgGoreCount += 1;
  this.npgLastGore = info;
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  this.npgDeathCount += 1;
  this.npgLastDeath = s"dead=\(this.IsDead()) defeated=\(ScriptedPuppet.IsDefeated(this))";
  return wrappedMethod(evt);
}

@wrapMethod(HitReactionComponent)
protected final func DismembermentConditions() -> Bool {
  let result = wrappedMethod();
  if IsDefined(this.m_ownerNPC) && IsDefined(this.m_attackData) && IsDefined(this.m_attackData.GetInstigator()) && this.m_attackData.GetInstigator().IsPlayer() {
    let shape = this.GetHitShapeUserData();
    if IsDefined(shape) {
      this.m_ownerNPC.NPCOmegaGore_RecordGore(s"allowed=\(result) zone=\(EnumInt(HitShapeUserDataBase.GetHitReactionZone(shape))) part=\(EnumInt(HitShapeUserDataBase.GetDismembermentBodyPart(shape))) material=\(EnumInt(shape.GetShapeType())) alive=\(this.m_isAlive) dying=\(this.m_ownerNPC.IsAboutToDie()) defeated=\(ScriptedPuppet.IsDefeated(this.m_ownerNPC)) force=\(this.m_attackData.HasFlag(hitFlag.ForceDismember))");
    } else {
      this.m_ownerNPC.NPCOmegaGore_RecordGore("missing hit shape");
    }
  }
  return result;
}
