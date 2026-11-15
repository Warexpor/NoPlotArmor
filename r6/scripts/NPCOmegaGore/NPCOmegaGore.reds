module NPCOmegaGore

// Keep other systems' protection sources intact; remove only our own override
// when the entity leaves the world. Its actual runtime behavior is diagnostic.
@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let result = wrappedMethod();
  GameInstance.GetGodModeSystem(this.GetGame()).EnableOverride(this.GetEntityID(), gameGodModeType.Mortal, n"NPCOmegaGore");
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
  }
}

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
    npc.NPCOmegaGore_RecordHit(result, hitEvent.attackData);
  }
  return result;
}

// The vanilla function removes the player's original friendly-fire flag.
// Add ours afterward so it survives the quick-exit check.
@wrapMethod(DamageSystem)
private final func ModifyHitFlagsForPlayer(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Void {
  wrappedMethod(hitEvent, cache);
  if IsDefined(hitEvent) && IsDefined(hitEvent.target as NPCPuppet) && IsDefined(hitEvent.attackData)
    && IsDefined(hitEvent.attackData.GetInstigator()) && hitEvent.attackData.GetInstigator().IsPlayer() {
    hitEvent.attackData.AddFlag(hitFlag.FriendlyFire, n"NPCOmegaGore");
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
  return s"record=\(TDBID.ToStringDEBUG(this.GetRecordID())) entity=\(EntityID.ToDebugString(id)) hp%=\(hp) immortal=\(god.HasGodMode(id, gameGodModeType.Immortal)) invulnerable=\(god.HasGodMode(id, gameGodModeType.Invulnerable)) invulnerableStat=\(invStat) boss=\(this.IsBoss()) defeat=\(this.IsDefeatMechanicActive()) crowd=\(this.IsCrowd()) dismemberment=\(IsDefined(this.GetDismembermentComponent())) onHits=\(this.npgOnHitCount) hits=\(this.npgHitCount) hitInfo=[\(this.npgLastHit)] goreChecks=\(this.npgGoreCount) goreInfo=[\(this.npgLastGore)]";
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
// dismemberment conditions are evaluated. onHits>0 with hits==0 means
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

@addMethod(NPCPuppet)
public final func NPCOmegaGore_RecordHit(accepted: Bool, data: ref<AttackData>) -> Void {
  this.npgHitCount += 1;
  this.npgLastHit = s"preprocess=\(accepted) attack=\(EnumInt(data.GetAttackType())) friendly=\(data.HasFlag(hitFlag.FriendlyFire)) friendlyIgnored=\(data.HasFlag(hitFlag.FriendlyFireIgnored)) noDamage=\(data.HasFlag(hitFlag.DealNoDamage)) nonlethal=\(data.HasFlag(hitFlag.Nonlethal))";
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
