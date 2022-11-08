CustomBehaviorActionEntry scenario_monitor_action;

void scenario_monitor_action_init()
{
	scenario_monitor_action = new CustomBehaviorActionEntry("ScenarioMonitor");
	scenario_monitor_action.set_function("OnStart", action_start);
	scenario_monitor_action.set_function("Update", action_update);
	//scenario_monitor_action.set_function("InitialContainedAction", action_containedaction);
}

static BehaviorAction action_containedaction(CustomBehaviorAction action, INextBot bot, int entity)
{
	BehaviorAction next_action = seek_and_destroy_action.create();
	return next_action;
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	return result.Continue();
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	return result.Continue();
}