static void handle_weapon_fire(IIntentionCustom intention, INextBot bot, int entity, int victim, float sight_pos[3])
{
	SetVariantInt(999999);
	AcceptEntityInput(victim, "RemoveHealth");

	float next_attack = GetEntPropFloat(entity, Prop_Send, "m_flNextAttack");
	if(next_attack <= GetGameTime()) {
		next_attack = GetGameTime() + 2.0;
		SetEntPropFloat(entity, Prop_Send, "m_flNextAttack", next_attack);
	}
}

BehaviorAction psychonauts_gmen_behavior(IIntentionCustom intention, INextBot bot, int entity)
{
	intention.set_function("handle_weapon_fire", handle_weapon_fire);

	intention.set_data("sap_only", 1);
	intention.set_data("melee_only", 1);

	CustomBehaviorAction action = main_action.create();
	return action;
}