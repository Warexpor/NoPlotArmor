module NoPlotArmorCries

// NoPlotArmor downed-cries + finisher voice (ported from DownedCries 0.1.0-dev).
// Downed NPCs replay the game's own hit_reaction_heavy pain voice on a
// cooldown while defeated, wounded or dismembered-but-alive; finisher kills
// cry once in the victim's own voiceset. No audio files; every voice set
// works. Children excluded, ragdolling puppets skipped. Gated on the NPA
// master switch like every other hook in this mod.

public abstract class NPACriesTuning {
  public static func MinDelay() -> Float = 6.0
  public static func MaxDelay() -> Float = 11.0
  public static func MaxCries() -> Int32 = 12
  public static func MaxTicks() -> Int32 = 180
}

public abstract class NPACries {
  public static func BasicFilter(npc: ref<NPCPuppet>) -> Bool {
    if !IsDefined(npc) || !npc.IsAttached() || !ScriptedPuppet.IsAlive(npc) { return false; }
    if npc.IsCharacterChildren() { return false; }
    return true;
  }

  public static func Eligible(npc: ref<NPCPuppet>) -> Bool {
    if !NPACries.BasicFilter(npc) { return false; }
    if !NPAControl.Enabled(npc.GetGame()) { return false; }
    // A ragdolling puppet cannot emit voice; also pauses cries during a
    // defeated tumble.
    if npc.IsRagdolling() { return false; }
    if ScriptedPuppet.IsDefeated(npc) { return true; }
    if StatusEffectSystem.ObjectHasStatusEffectOfType(npc, gamedataStatusEffectType.Wounded) { return true; }
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedArmLeft") { return true; }
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedArmRight") { return true; }
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegLeft") { return true; }
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DismemberedLegRight") { return true; }
    return false;
  }
}

public class NPACriesTick extends Event {
  public let gen: Int32;
}

@addField(NPCPuppet)
private let npaCryGen: Int32;
@addField(NPCPuppet)
private let npaCryTicks: Int32;
@addField(NPCPuppet)
private let npaCryCries: Int32;
@addField(NPCPuppet)
private let npaCryNextAt: Float;
@addField(NPCPuppet)
private let npaCryStarted: Bool;
@addField(NPCPuppet)
private let npaCryWasEligible: Bool;

@addMethod(NPCPuppet)
private final func NPA_CryNow() -> Float {
  return EngineTime.ToFloat(GameInstance.GetTimeSystem(this.GetGame()).GetSimTime());
}

@addMethod(NPCPuppet)
public final func NPA_CryEnsureLoop() -> Void {
  if !NPACries.BasicFilter(this) { return; }
  if !NPAControl.Enabled(this.GetGame()) { return; }
  // A fresh hit refreshes a running loop instead of stacking a second one.
  if this.npaCryStarted {
    this.npaCryTicks = 0;
    return;
  }
  this.npaCryStarted = true;
  this.npaCryGen += 1;
  this.npaCryTicks = 0;
  this.npaCryCries = 0;
  this.npaCryWasEligible = false;
  this.npaCryNextAt = this.NPA_CryNow();
  FTLog(s"[NoPlotArmor] cries started for \(TDBID.ToStringDEBUG(this.GetRecordID())) \(EntityID.ToDebugString(this.GetEntityID()))");
  let tick = new NPACriesTick();
  tick.gen = this.npaCryGen;
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, tick, 1.0, false);
}

@addMethod(NPCPuppet)
private final func NPA_CryBark() -> Void {
  // hit_reaction_heavy is the game's own pain voice event: referenced by game
  // data and used by vanilla hit reactions. Resolves inside the victim's own
  // voiceset, so Judy sounds like Judy.
  GameObject.PlayVoiceOver(this, n"hit_reaction_heavy", n"NoPlotArmor:Cries");
}

@addMethod(NPCPuppet)
protected cb func OnNPACriesTick(evt: ref<NPACriesTick>) -> Bool {
  if !IsDefined(evt) || evt.gen != this.npaCryGen || !this.npaCryStarted { return false; }
  this.npaCryTicks += 1;
  if !NPACries.BasicFilter(this) || !NPAControl.Enabled(this.GetGame()) || this.npaCryCries >= NPACriesTuning.MaxCries() || this.npaCryTicks > NPACriesTuning.MaxTicks() {
    this.npaCryStarted = false;
    return false;
  }
  let eligible = NPACries.Eligible(this);
  // Cry promptly on the downing transition instead of waiting out the
  // cooldown from an earlier hit.
  if eligible && !this.npaCryWasEligible {
    this.npaCryNextAt = this.NPA_CryNow();
  }
  this.npaCryWasEligible = eligible;
  if eligible && this.NPA_CryNow() >= this.npaCryNextAt {
    if this.npaCryCries == 0 {
      FTLog(s"[NoPlotArmor] first cry for \(TDBID.ToStringDEBUG(this.GetRecordID())) \(EntityID.ToDebugString(this.GetEntityID()))");
    }
    this.NPA_CryBark();
    this.npaCryCries += 1;
    this.npaCryNextAt = this.NPA_CryNow() + RandRangeF(NPACriesTuning.MinDelay(), NPACriesTuning.MaxDelay());
  }
  let tick = new NPACriesTick();
  tick.gen = this.npaCryGen;
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, tick, 1.0, false);
  return true;
}

@wrapMethod(NPCPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if ScriptedPuppet.IsAlive(this) { this.NPA_CryEnsureLoop(); }
  return result;
}

@wrapMethod(NPCPuppet)
protected func OnIncapacitated() -> Void {
  wrappedMethod();
  this.NPA_CryEnsureLoop();
}

// Finishers run the victim through a workspot that otherwise leaves them
// silent: no hit lands during the grab, so the loop above never starts, and
// the workspot suppresses native reactions. Cry once on death in a finisher
// workspot, voiced by the victim's own voiceset.
@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  // Bark BEFORE the chain: the rest of the death pipeline (native teardown
  // included) runs inside wrappedMethod, and a dead puppet may no longer be
  // able to voice by the time it returns.
  // Note: BasicFilter requires the puppet alive, which is false by the time
  // OnDeath runs, so check attachment/age directly here.
  if IsDefined(this) && this.IsAttached() && !this.IsCharacterChildren() && !this.IsRagdolling()
    && this.HasWorkspotTag(n"FinisherWorkspot") && NPAControl.Enabled(this.GetGame()) {
    FTLog(s"[NoPlotArmor] finisher cry for \(TDBID.ToStringDEBUG(this.GetRecordID())) \(EntityID.ToDebugString(this.GetEntityID()))");
    this.NPA_CryBark();
  }
  return wrappedMethod(evt);
}
