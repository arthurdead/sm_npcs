#include <sourcemod>
#include <moreinfected>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <dhooks>

#include "base/shared.sp"

//#include "re_npcs/classic_zombies.sp"
#include "re_npcs/tyrant.sp"

public void OnPluginStart()
{
	base_npc_init();

	//classiczombie_init();
	tyrant_init();

	RegConsoleCmd("testre", cmd);
}

public void OnMapStart()
{
	moreinfected_data data;
	re_tyrant_precache(data);
}

Action cmd(int client, int args)
{
	float end[3];
	end[0] = 1842.788208;
	end[1] = 2050.267578;
	end[2] = 68.982697;

	if(client != 0) {
		float origin[3];
		GetClientEyePosition(client, origin);

		float angles[3];
		GetClientEyeAngles(client, angles);

		Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntity, client);

		TR_GetEndPosition(end, trace);

		//int ent = TR_GetEntityIndex(trace);
		//PrintToServer("%i", ent);

		delete trace;
	}

	int entity = create_base_npc("npc_re_tyrant", 3);
	TeleportEntity(entity, end);

	ServerCommand("nb_debug_filter");
	ServerCommand("nb_debug_filter %i", entity);
	
	return Plugin_Handled;
}

public void OnGameFrame()
{
	int door = -1;
	int client = 1;

	if(door == -1 || !IsClientInGame(client)) {
		return;
	}

	float center[3];
	GetDoorCenter(door, center);

	float offset[3];
	offset = center;
	GetOffsetToDoor(client, door, offset, 100.0);

	float mins[3];
	GetEntPropVector(door, Prop_Data, "m_vecMins", mins);

	float maxs[3];
	GetEntPropVector(door, Prop_Data, "m_vecMaxs", maxs);

	float ang[3];
	GetEntPropVector(door, Prop_Data, "m_angAbsRotation", ang);

	DrawHull(center, ang);
	DrawHull(offset, ang);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "npc_re_classiczombie")) {
		//SDKHook(entity, SDKHook_Spawn, classiczombie_spawn);
	} else if(StrEqual(classname, "npc_re_tyrant")) {
		SDKHook(entity, SDKHook_Spawn, tyrant_spawn);
	}
}

public void OnPluginEnd()
{
	remove_all_entities("npc_re_classiczombie");
	remove_all_entities("npc_re_tyrant");
}