module NoPlotArmor

// NoPlotArmor finisher voice (0.2.1-dev). Same module as the rest of the mod:
// cross-module class references do not resolve (RedRequire flags them).
// Finishers run the victim through a workspot that otherwise leaves them
// silent. This hooks the finisher's own game-effect event: the victim is
// alive and voiced at that moment, so the cry comes out in their own
// voiceset (Judy sounds like Judy). Barking later, at OnDeath, proved
// unreliable — the workspot teardown can already have muted them by then,
// leaving only the generic finisher audio. Downed-but-alive loop cries are
// NOT here: they live in the standalone DownedCries mod. Gated on the NPA
// master switch like every other hook in this mod.

@addMethod(NPCPuppet)
private final func NPA_CryBark() -> Void {
  // hit_reaction_heavy is the game's own pain voice event: referenced by game
  // data and used by vanilla hit reactions. Resolves inside the victim's own
  // voiceset.
  GameObject.PlayVoiceOver(this, n"hit_reaction_heavy", n"NoPlotArmor:Cries");
}

@wrapMethod(FinisherAttackEvents)
public final func PlayFinisherGameEffect(const targetPuppet: ref<GameObject>, instigator: ref<GameObject>, const hasFromFront: Bool, const hasFromBack: Bool) -> Bool {
  let npc = targetPuppet as NPCPuppet;
  if IsDefined(npc) && npc.IsAttached() && !npc.IsCharacterChildren() && !npc.IsRagdolling()
    && NPAControl.Enabled(targetPuppet.GetGame()) {
    FTLog(s"[NoPlotArmor] finisher cry for \(TDBID.ToStringDEBUG(npc.GetRecordID())) \(EntityID.ToDebugString(npc.GetEntityID()))");
    npc.NPA_CryBark();
  }
  return wrappedMethod(targetPuppet, instigator, hasFromFront, hasFromBack);
}
