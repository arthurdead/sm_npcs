#include <sourcemod>
#include <datamaps>
#include <nextbot>
#include <popspawner>
#include <animhelpers>
#include <sm_npcs>

CustomBehaviorActionEntry basic_range_action;

#include "npcs_tf2_invasion/alien_commando/npc.sp"

public void OnPluginStart()
{
	tf2i_alien_commando_init();
}

public void OnAllPluginsLoaded()
{
	basic_range_action = get_behavior_action("BasicRange");
}

public void OnMapStart()
{
	int entity = CreateEntityByName("prop_dynamic_override");

	tf2i_alien_commando_precache(entity);

	RemoveEntity(entity);
}

public void OnPluginEnd()
{
	remove_entities_of_classname("npc_tf2i_alien_commando*");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "npc_tf2i_alien_commando") != -1) {
		tf2i_alien_commando_created(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	if(StrContains(classname, "npc_tf2i_alien_commando") != -1) {
		tf2i_alien_commando_destroyed(entity);
	}
}