BehaviorActionEntry play_anim_action;

void play_anim_action_init()
{
	play_anim_action = new BehaviorActionEntry("PlayAnim");
	play_anim_action.set_function("OnStart", play_anim_start);
	play_anim_action.set_function("OnAnimationActivityComplete", play_anim_complete);
	play_anim_action.set_function("OnAnimationActivityInterrupted", play_anim_interrupted);
}

static BehaviorResultType play_anim_complete(BehaviorAction action, INextBot bot, int entity, int ground, BehaviorResult result)
{
	BehaviorActionEntry next_entry = action.get_data("next_action_entry");
	BehaviorAction next_action = next_entry.create();

	if(action.has_function("setup_next_action")) {
		Function func = action.get_function("setup_next_action");
		Call_StartFunction(null, func);
		Call_PushCell(next_action);
		Call_Finish();
	}

	result.action = next_action;
	result.set_reason("anim complete");
	result.priority = RESULT_TRY;
	return BEHAVIOR_CHANGE_TO;
}

static BehaviorResultType play_anim_interrupted(BehaviorAction action, INextBot bot, int entity, int ground, BehaviorResult result)
{
	result.priority = RESULT_TRY;
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType play_anim_start(BehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	IBody body = bot.BodyInterface;

	Activity act = action.get_data("activity");
	ActivityType flags = NO_ACTIVITY_FLAGS;
	if(action.has_data("activity_flags")) {
		flags = action.get_data("activity_flags");
	}

	body.StartActivity(act, flags);

	return BEHAVIOR_CONTINUE;
}