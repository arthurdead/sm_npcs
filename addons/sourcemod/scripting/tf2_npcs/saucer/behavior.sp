static void handle_fire(CustomBehaviorAction action, int entity, int victim)
{
	float attack_time = action.get_data("attack_time");
	if(attack_time < GetGameTime()) {
		float my_pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", my_pos);

		float victim_pos[3];
		EntityWorldSpaceCenter(victim, victim_pos);

		

		action.set_data("attack_time", GetGameTime() + 0.5);
	}
}

BehaviorAction tf2_saucer_behavior(int entity)
{
	CustomBehaviorAction action = basic_range_action.create();
	action.set_function("handle_fire", handle_fire);
	return action;
}