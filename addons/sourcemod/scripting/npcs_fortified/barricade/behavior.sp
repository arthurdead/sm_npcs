static void handle_die(IIntentionCustom intention, INextBot bot, int entity, bool start)
{
	int shield = GetEntPropEnt(entity, Prop_Data, "m_hShieldEntity");
	if(shield != -1) {
		RemoveEntity(shield);
		SetEntPropEnt(entity, Prop_Data, "m_hShieldEntity", -1);
	}
}

BehaviorAction fortified_barricade_behavior(IIntentionCustom intention, INextBot bot, int entity)
{
	intention.set_function("handle_die", handle_die);

	intention.set_data("melee_only", 1);

	CustomBehaviorAction action = main_action.create();
	return action;
}