static void handle_weapon_fire(IIntentionCustom intention, INextBot bot, int entity, int victim, float sight_pos[3])
{
	float next_attack = intention.get_data("next_attack");
	if(next_attack < GetGameTime()) {
		next_attack = GetGameTime() + 1.0;
		intention.set_data("next_attack", next_attack);

		bot.BodyInterface.StartActivity(ACT_MELEE_ATTACK1, ACTIVITY_TRANSITORY);
	}
}

BehaviorAction fortified_drone_behavior(IIntentionCustom intention, INextBot bot, int entity)
{
	intention.set_function("handle_weapon_fire", handle_weapon_fire);

	intention.set_data("next_attack", GetGameTime());

	intention.set_data("melee_only", 1);

	CustomBehaviorAction action = main_action.create();
	return action;
}