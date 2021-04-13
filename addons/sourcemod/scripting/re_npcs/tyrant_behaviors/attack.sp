BehaviorActionEntry tyrant_attack = null;

void tyrant_attack_init()
{
	tyrant_attack = new BehaviorActionEntry("tyrant_attack");
	tyrant_attack.set_function("Update", TyrantAttackUpdate);
	tyrant_attack.set_function("OnStart", TyrantAttackStart);
}

BehaviorResultType TyrantAttackStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("hit", false);
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantAttackUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	BaseAnimating anim = BaseAnimating(entity);

	int sequence = action.get_data("sequence");
	anim.ResetSequenceEx(sequence);

	INextBot bot = INextBot(entity);

	float pos[3];
	float ang[3];
	if(AutoMovement(entity, pos, ang, 0.5, bot)) {
		result.set_reason("sequence done");
		return BEHAVIOR_DONE;
	}

	float cycle = GetEntPropFloat(entity, Prop_Send, "m_flCycle");

	if(sequence == 20 && cycle >= 0.10 && cycle <= 0.15) {
		DoTyrantAttack(action, bot, entity, pos, ang, sequence);
	} else if(sequence == 21 && cycle >= 0.57 && cycle <= 0.65) {
		DoTyrantAttack(action, bot, entity, pos, ang, sequence);
	}

	if(sequence == 20 && action.get_data("hit") && cycle >= 0.4) {
		result.set_reason("target knocked");
		return BEHAVIOR_DONE;
	}

	return BEHAVIOR_CONTINUE;
}