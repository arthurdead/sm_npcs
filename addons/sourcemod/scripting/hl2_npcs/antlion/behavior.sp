BehaviorAction hl2_antlion_behavior(int entity)
{
	BehaviorAction spawn = play_anim_action.create();
	spawn.set_data("activity", ACT_ANTLION_BURROW_OUT);
	spawn.set_data("next_action_entry", basic_melee_action);
	return spawn;
}