#include <sourcemod>
#include <datamaps>
#include <nextbot>
#include <popspawner>
#include <animhelpers>
#include <sm_npcs>

CustomBehaviorActionEntry main_action;

#include "npcs_tf2_invasion_update/saucer/npc.sp"

static bool late_loaded;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	late_loaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	tf2_saucer_init();
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

	tf2_saucer_precache(entity);

	RemoveEntity(entity);
}

public void OnPluginEnd()
{
	remove_entities_of_classname("npc_tf2_*");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "npc_tf2_saucer") != -1) {
		tf2_saucer_created(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	if(StrContains(classname, "npc_tf2_saucer") != -1) {
		tf2_saucer_destroyed(entity);
	}
}