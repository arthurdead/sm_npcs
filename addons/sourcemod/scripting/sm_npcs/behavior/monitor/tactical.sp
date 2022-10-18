CustomBehaviorActionEntry tactical_monitor_action;

void tactical_monitor_action_init()
{
	tactical_monitor_action = new CustomBehaviorActionEntry("TacticalMonitor");
	tactical_monitor_action.set_function("OnStart", action_start);
	tactical_monitor_action.set_function("Update", action_update);
	tactical_monitor_action.set_function("InitialContainedAction", action_containedaction);
}

static BehaviorAction action_containedaction(CustomBehaviorAction action, INextBot bot, int entity)
{
	BehaviorAction next_action = scenario_monitor_action.create();
	return next_action;
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("m_maintainTimer", 0.0);

	return result.Continue();
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	IIntention intention = bot.IntentionInterface;

	QueryResultType shouldRetreat = intention.ShouldRetreat(bot);
	if(shouldRetreat == ANSWER_YES) {
		BehaviorAction next_action = retreat_to_cover_action.create();
		return result.SuspendFor(next_action, "Backing off");
	}

	EntityNPCInfo npcinfo;
	get_npc_info(entity, npcinfo);

	bool isAvailable = (intention.ShouldHurry(bot) != ANSWER_YES);
	float maintainTimer = action.get_data("m_maintainTimer");
	if(isAvailable && maintainTimer < GetGameTime()) {
		maintainTimer = GetRandomFloat(0.3, 0.5);
		action.set_data("m_maintainTimer", maintainTimer);

		int enemy_sentry = npcinfo.get_enemy_sentry();
		if(enemy_sentry != -1) {
			//BehaviorAction next_action = destroy_enemy_sentry_action.create();
			//return result.SuspendFor(next_action, "Going after an enemy sentry to destroy it");
		}
	}

	IVision vision = bot.VisionInterface;

	npcinfo.update_delayed_threat_notices(vision);

	return result.Continue();
}