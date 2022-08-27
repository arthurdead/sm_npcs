static void handle_idle(int entity)
{
	if(GetEntPropFloat(entity, Prop_Data, "m_flIdleDelay") < GetGameTime()) {
		EmitGameSoundToAll("NPC_Antlion.Idle", entity);
		SetEntPropFloat(entity, Prop_Data, "m_flIdleDelay", GetGameTime() + 4.0);
	}
}

static void setup_next_action(BehaviorAction action)
{
	action.set_function("handle_idle", handle_idle);
}

static BehaviorResultType antlion_burrow_start(BehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	return play_anim_start(action, bot, entity, prior, result);
}

BehaviorAction hl2_antlion_behavior(int entity)
{
	BehaviorAction action = play_anim_action.create();
	action.set_data("activity", ACT_ANTLION_BURROW_OUT);
	action.set_data("next_action_entry", basic_melee_action);
	action.set_function("setup_next_action", setup_next_action);
	action.set_function("OnStart", antlion_burrow_start);
	return action;
}