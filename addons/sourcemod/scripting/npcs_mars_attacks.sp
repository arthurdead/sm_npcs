#include <sourcemod>
#include <datamaps>
#include <nextbot>
#include <popspawner>
#include <animhelpers>
#include <sm_npcs>
#include <teammanager>
#include <rulestools>

CustomBehaviorActionEntry main_action;

#include "npcs_mars_attacks/martian/npc.sp"

static bool late_loaded;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	late_loaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	mars_attacks_martian_init();
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

	mars_attacks_martian_precache(entity);

	RemoveEntity(entity);
}

public void OnPluginEnd()
{
	remove_entities_of_classname("npc_mars_attacks_*");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "npc_mars_attacks_martian") != -1) {
		mars_attacks_martian_created(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	if(StrContains(classname, "npc_mars_attacks_martian") != -1) {
		mars_attacks_martian_destroyed(entity);
	}
}