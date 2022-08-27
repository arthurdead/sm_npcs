#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <animhelpers>
#include <datamaps>
#include <nextbot>
#include <proxysend>
#include <stocksoup/tf/monster_resource>
#include <popspawner>
#include <tf2>
#include <tf2_stocks>
#include <listen>
#include <clsobj_hack>
#include <bit>
#include <modifier_spawner>
#include <expression_parser>
#include <wpnhack>
#include <loadsoundscript>

TFMonsterResource monster_resource;

ConVar npc_deathnotice_eventtime;

#include "sm_npcs_shared.sp"

#include "behavior/shared/shared.sp"
#include "behavior/melee/basic_melee.sp"
#include "behavior/range/basic_range.sp"
#include "behavior/anim/play_anim.sp"

#include "kf2_npcs/kf2_npcs.sp"
#include "hl2_npcs/hl2_npcs.sp"

static ConVar nav_authorative;
static ConVar path_expensive_optimize;

static bool late_load;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	late_load = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	basic_melee_action_init();
	basic_range_action_init();
	play_anim_action_init();

	kf2_npcs_init();
	hl2_npcs_init();

	nav_authorative = FindConVar("nav_authorative");
	path_expensive_optimize = FindConVar("path_expensive_optimize");

	npc_deathnotice_eventtime = FindConVar("npc_deathnotice_eventtime");

	if(late_load) {
		int entity = -1;
		char classname[64];
		while((entity = FindEntityByClassname(entity, "*")) != -1) {
			GetEntityClassname(entity, classname, sizeof(classname));
			OnEntityCreated(entity, classname);
		}
	}
}

public void OnConfigsExecuted()
{
	nav_authorative.BoolValue = false;
	path_expensive_optimize.BoolValue = false;

	FindConVar("ai_show_hull_attacks").BoolValue = true;

	//InsertServerCommand("nb_debug BEHAVIOR");
	ServerExecute();
}

public void OnMapStart()
{
	int entity = CreateEntityByName("prop_dynamic_override");

	kf2_npcs_precache(entity);
	hl2_npcs_precache(entity);

	RemoveEntity(entity);

	monster_resource = TFMonsterResource.GetEntity(true);
	monster_resource.Hide();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	kf2_npcs_entity_created(entity, classname);
	hl2_npcs_entity_created(entity, classname);
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	kf2_npcs_entity_destroyed(entity, classname);
	hl2_npcs_entity_destroyed(entity, classname);
}

public void OnPluginEnd()
{
	kf2_npcs_plugin_end();
	hl2_npcs_plugin_end();
}