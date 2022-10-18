#include <sourcemod>
#include <datamaps>
#include <nextbot>
#include <popspawner>
#include <animhelpers>
#include <sm_npcs>

CustomBehaviorActionEntry main_action;

#include "npcs_fortified/drone/npc.sp"
#include "npcs_fortified/distruptor/npc.sp"
#include "npcs_fortified/barricade/npc.sp"

static bool late_loaded;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	late_loaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	fortified_drone_init();
	fortified_distruptor_init();
	fortified_barricade_init();
}

public void OnAllPluginsLoaded()
{
	if(late_loaded) {
		basic_behaviors_created();
	}
}

public void basic_behaviors_created()
{
	main_action = get_behavior_action("Main");
}

public void OnMapStart()
{
	int entity = CreateEntityByName("prop_dynamic_override");

	fortified_drone_precache(entity);
	fortified_distruptor_precache(entity);
	fortified_barricade_precache(entity);

	RemoveEntity(entity);
}

public void OnPluginEnd()
{
	remove_entities_of_classname("npc_fortified_*");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "npc_fortified_drone") != -1) {
		fortified_drone_created(entity);
	} else if(StrContains(classname, "npc_fortified_distruptor") != -1) {
		fortified_distruptor_created(entity);
	} else if(StrContains(classname, "npc_fortified_barricade") != -1) {
		fortified_barricade_created(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	
}