#include "behaviors/melee.sp"
#include "behaviors/main.sp"

void hans_volter_behavior_init()
{
	hans_volter_main_action_init();
	hans_volter_melee_action_init();
}

BehaviorAction hans_volter_behavior(int entity)
{
	return hans_volter_main_action.create();
}