CustomBehaviorActionEntry play_anim_action;

void play_anim_action_init()
{
	play_anim_action = new CustomBehaviorActionEntry("PlayAnim");
	play_anim_action.set_function("OnStart", play_anim_start);
	play_anim_action.set_function("OnAnimationActivityComplete", play_anim_complete);
	play_anim_action.set_function("OnAnimationActivityInterrupted", play_anim_interrupted);
}

static BehaviorResultType play_anim_complete(CustomBehaviorAction action, INextBot bot, int entity, int ground, BehaviorResult result)
{
	CustomBehaviorActionEntry next_entry = action.get_data("next_action_entry");
	CustomBehaviorAction next_action = next_entry.create();

	Handle pl;
	Function func = action.get_function("setup_next_action", pl);
	if(func != INVALID_FUNCTION && pl != null) {
		Call_StartFunction(pl, func);
		Call_PushCell(next_action);
		Call_Finish();
	}

	return result.TryChangeTo(next_action, _, "anim complete");
}

static BehaviorResultType play_anim_interrupted(CustomBehaviorAction action, INextBot bot, int entity, int ground, BehaviorResult result)
{
	return result.TryContinue();
}

BehaviorResultType play_anim_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	IBody body = bot.BodyInterface;

	Activity act = action.get_data("activity");
	ActivityType flags = NO_ACTIVITY_FLAGS;
	if(action.has_data("activity_flags")) {
		flags = action.get_data("activity_flags");
	}

	body.StartActivity(act, flags);

	return result.Continue();
}