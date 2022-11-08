CustomBehaviorActionEntry taunt_action;

void taunt_action_init()
{
	taunt_action = new CustomBehaviorActionEntry("Taunt");
	taunt_action.set_function("OnStart", action_start);
	taunt_action.set_function("Update", action_update);
	taunt_action.set_function("OnAnimationActivityComplete", action_animcomplete);
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("m_tauntTimer", GetGameTime() + GetRandomFloat(0.0, 1.0));
	action.set_data("m_tauntEndTimer", 0.0);
	action.set_data("m_didTaunt", 0);

	action.set_data("taunt_done", 0);
	action.set_data("taunt_started", 0);

	return result.Continue();
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	IBody body = bot.BodyInterface;
	IBodyCustom body_custom = view_as<IBodyCustom>(body);

	float tauntTimer = action.get_data("m_tauntTimer");
	if(tauntTimer <= GetGameTime()) {
		bool didTaunt = action.get_data("m_didTaunt");
		if(didTaunt) {
			float tauntEndTimer = action.get_data("m_tauntEndTimer");
			if(tauntEndTimer <= GetGameTime()) {
				body_custom.ResetActivityFlags();
				return result.Done("Taunt timed-out");
			}

			bool done = action.get_data("taunt_done");
			if(done) {
				return result.Done("Taunt finished");
			}
		} else {
			bool started = body.StartActivity(ACT_VICTORY_DANCE, ACTIVITY_UNINTERRUPTIBLE|MOTION_CONTROLLED_XY);
			action.set_data("taunt_started", started);

			action.set_data("m_tauntEndTimer", GetGameTime() + GetRandomFloat(3.0, 5.0));
			action.set_data("m_didTaunt", 1);
		}
	}

	return result.Continue();
}

static BehaviorResultType action_animcomplete(CustomBehaviorAction action, INextBot bot, int entity, Activity act, BehaviorResult result)
{
	bool started = action.get_data("taunt_started");
	if(started && act == ACT_VICTORY_DANCE) {
		action.set_data("taunt_done", 1);

		IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
		body_custom.ResetActivityFlags();
	}

	return result.TryContinue();
}