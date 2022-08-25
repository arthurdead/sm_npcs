BehaviorActionEntry hans_volter_melee_action;

void hans_volter_melee_action_init()
{
	hans_volter_melee_action = new BehaviorActionEntry("HansVolterMelee");
	hans_volter_melee_action.set_function("OnStart", hans_volter_melee_start);
	hans_volter_melee_action.set_function("Update", hans_volter_melee_update);
}

static BehaviorResultType hans_volter_melee_start(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	INextBot bot = INextBot(entity);
	bot.LocomotionInterface.Stop();

	BaseAnimating anim = BaseAnimating(entity);
	anim.ResetSequence(hans_volter_melee_anim);

	return BEHAVIOR_CONTINUE;
}

static BehaviorResultType hans_volter_melee_update(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished") != 0) {
		return BEHAVIOR_DONE;
	}

	return BEHAVIOR_CONTINUE;
}