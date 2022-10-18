#include "scenario.sp"
#include "tactical.sp"

void monitor_action_init()
{
	tactical_monitor_action_init();
	scenario_monitor_action_init();
}