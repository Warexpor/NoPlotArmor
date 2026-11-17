module NoPlotArmorCries

// NoPlotArmor finisher voice (0.2.1-dev). Finishers run the victim through a
// workspot that otherwise leaves them silent: no hit lands during the grab,
// so no hit reaction ever voices, and the workspot suppresses native
// reactions. Cry once on death in a finisher workspot, voiced by the victim's
// own voiceset (Judy sounds like Judy). Downed-but-alive loop cries are NOT
// here: they live in the standalone DownedCries mod. Gated on the NPA master
// switch like every other hook in this mod.

@addMethod(NPCPuppet)
private final func NPA_CryBark() -> Void {
  // hit_reaction_heavy is the game's own pain voice event: referenced by game
  // data and used by vanilla hit reactions. Resolves inside the victim's own
  // voiceset.
  GameObject.PlayVoiceOver(this, n"hit_reaction_heavy", n"NoPlotArmor:Cries");
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  // Bark BEFORE the chain: the rest of the death pipeline (native teardown
  // included) runs inside wrappedMethod, and a dead puppet may no longer be
  // able to voice by the time it returns.
  if IsDefined(this) && this.IsAttached() && !this.IsCharacterChildren() && !this.IsRagdolling()
    && this.HasWorkspotTag(n"FinisherWorkspot") && NPAControl.Enabled(this.GetGame()) {
    FTLog(s"[NoPlotArmor] finisher cry for \(TDBID.ToStringDEBUG(this.GetRecordID())) \(EntityID.ToDebugString(this.GetEntityID()))");
    this.NPA_CryBark();
  }
  return wrappedMethod(evt);
}
