#if defined __sm_npcs_inc
	#endinput
#endif
#define __sm_npcs_inc

#if !defined REQUIRE_PLUGIN
	#define __SMNPC_PL_OPTIONAL
#endif

#if !defined REQUIRE_EXTENSIONS
	#define __SMNPC_EXT_OPTIONAL
#endif

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <popspawner>

#if !defined __SMNPC_PL_OPTIONAL
	#define REQUIRE_PLUGIN
#endif

#if !defined __SMNPC_EXT_OPTIONAL
	#define REQUIRE_EXTENSIONS
#endif

#include <datamaps>
#include <nextbot>

#define DAMAGE_NO 0
#define DAMAGE_YES 2
#define DAMAGE_EVENTS_ONLY 1
#define LIFE_DEAD 2
#define LIFE_ALIVE 0

#define EFL_KILLME (1 << 0)

#define EF_NODRAW 0x020
#define EF_BONEMERGE 0x001
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_PARENT_ANIMATES 0x200

#define SOLID_NONE 0
#define FSOLID_NOT_SOLID 0x0004
#define COLLISION_GROUP_NONE 0

enum
{
	DONT_BLEED = -1,
	BLOOD_COLOR_RED = 0,
	BLOOD_COLOR_YELLOW,
	BLOOD_COLOR_GREEN,
	BLOOD_COLOR_MECH,
};

native int base_npc_pop_health_impl(CustomPopulationSpawner spawner, int num, int health);
native bool base_npc_pop_attrs_impl(CustomPopulationSpawner spawner, AttributeType attr, int num);
native bool base_npc_pop_parse_impl(CustomPopulationSpawner spawner, KeyValues data);

stock int base_npc_pop_health(CustomPopulationSpawner spawner, int num, int health)
{ return base_npc_pop_health_impl(spawner, num, health); }
stock bool base_npc_pop_attrs(CustomPopulationSpawner spawner, AttributeType attr, int num)
{ return base_npc_pop_attrs_impl(spawner, attr, num); }
stock bool base_npc_pop_parse(CustomPopulationSpawner spawner, KeyValues data)
{ return base_npc_pop_parse_impl(spawner, data); }

native bool npc_pop_spawn_single(const char[] classname, CustomPopulationSpawner spawner, const float pos[3], ArrayList result);

native void ground_npc_spawn(INextBot bot, int entity, int health, float walk_speed, float run_speed);
native void flying_npc_spawn(INextBot bot, int entity, int health, float altitude, float acceleration);

native void weapon_fired(int entity);

native void TE_SetupBloodSprite2Ex(const float pos[3], const float dir[3], const int color[4], int Size);

stock void TE_SetupBloodSprite2(const float pos[3], const float dir[3], int color, int Size)
{
	int rgba[4];

	switch(color) {
		case DONT_BLEED: return;
		case BLOOD_COLOR_RED: {
			rgba[0] = 75;
		}
		case BLOOD_COLOR_YELLOW: {
			rgba[0] = 195;
			rgba[1] = 195;
		}
		case BLOOD_COLOR_MECH: {
			rgba[0] = 20;
			rgba[1] = 20;
			rgba[2] = 20;
		}
		case BLOOD_COLOR_GREEN: {
			rgba[0] = 195;
			rgba[1] = 195;
		}
	}

	rgba[3] = 255;

	TE_SetupBloodSprite2Ex(pos, dir, rgba, Size);
}

native void npc_resolve_collisions(INextBot bot, int entity);
native void handle_playbackrate(int entity, ILocomotion locomotion, IBody body);
native void handle_move_yaw(int entity, int pose, ILocomotion locomotion);
native void handle_move_xy(int entity, int xpose, int ypose, ILocomotion locomotion);

native void npc_hull_debug(INextBot bot, IBody body, ILocomotion locomotion, int entity);

native int find_particle(const char[] name);

stock void SetEntityModelScale(int entity, float scale)
{
	float vec[3];
	vec[0] = scale;
	SetVariantVector3D(vec);
	AcceptEntityInput(entity, "SetModelScale");
}

stock int create_attach_model(int owner, const char[] model, const char[] attach)
{
	int merge = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(merge, "model", model);
	DispatchSpawn(merge);
	SetEntityOwner(merge, owner);
	SetVariantString("!activator");
	AcceptEntityInput(merge, "SetParent", owner);
	int effects = GetEntProp(merge, Prop_Send, "m_fEffects");
	effects |= EF_PARENT_ANIMATES;
	SetEntProp(merge, Prop_Send, "m_fEffects", effects);
	SetVariantString(attach)
	AcceptEntityInput(merge, "SetParentAttachment");
	return merge;
}

stock int create_bonemerge_model(int owner, const char[] model, const char[] attach)
{
	int merge = create_attach_model(owner, model, attach);
	int effects = GetEntProp(merge, Prop_Send, "m_fEffects");
	effects |= EF_BONEMERGE|EF_BONEMERGE_FASTCULL|EF_PARENT_ANIMATES;
	SetEntProp(merge, Prop_Send, "m_fEffects", effects);
	return merge;
}

stock bool entity_is_alive(int entity)
{
	if(GetEntProp(entity, Prop_Data, "m_iEFlags") & EFL_KILLME) {
		return false;
	}

	if(GetEntProp(entity, Prop_Data, "m_lifeState") != LIFE_ALIVE) {
		return false;
	}

	if(GetEntProp(entity, Prop_Data, "m_iHealth") <= 0) {
		return false;
	}

	return true;
}

stock bool entity_is_invunerable(int victim)
{
	if(victim >= 1 && victim <= MaxClients) {
		if(TF2_IsPlayerInCondition(victim, TFCond_Ubercharged) ||
			TF2_IsPlayerInCondition(victim, TFCond_UberchargedHidden) ||
			TF2_IsPlayerInCondition(victim, TFCond_UberchargedCanteen) ||
			TF2_IsPlayerInCondition(victim, TFCond_UberchargedOnTakeDamage)) {
			return true;
		}
	}

	if(GetEntProp(victim, Prop_Data, "m_takedamage") != DAMAGE_YES) {
		return true;
	}

	return false;
}

stock bool entity_is_damageable(int victim, bool ignore_uber)
{
	if(!entity_is_alive(victim)) {
		return false;
	}

	if(GetEntityFlags(victim) & FL_NOTARGET) {
		return false;
	}

	if(victim >= 1 && victim <= MaxClients) {
		if(!IsPlayerAlive(victim) ||
			GetClientTeam(victim) < 2 ||
			TF2_GetPlayerClass(victim) == TFClass_Unknown) {
			return false;
		}

		if(TF2_IsPlayerInCondition(victim, TFCond_HalloweenGhostMode)) {
			return false;
		}
	}

	if(!ignore_uber) {
		if(entity_is_invunerable(victim)) {
			return false;
		}
	}

	return true;
}

//BasicMelee.handle_swing
typedef handle_swing_func_t = function void (int entity);

//BasicMelee.handle_idle
typedef handle_idle_func_t = function void (int entity);

//*.handle_die
typedef handle_die_func_t = function bool (int entity);

//BasicRange.handle_fire
typedef handle_fire_func_t = function void (CustomBehaviorAction action, INextBot bot, int entity, int victim, const float sight_pos[3]);

//PlayAnim.setup_next_action
typedef setup_next_action_func_t = function void (CustomBehaviorAction action);

native CustomBehaviorActionEntry get_behavior_action(const char[] name);

forward void basic_behaviors_created();

typedef npc_datamap_init_func_t = function void (CustomDatamap datamap);

stock void create_npc_factories(const char[] classname, const char[] name, npc_datamap_init_func_t dtm_func)
{
	char tmp_classname[64];
	strcopy(tmp_classname, sizeof(tmp_classname), classname);
	int len = strlen(classname);

	CustomDatamap datamap = register_nextbot_factory(tmp_classname, name);
	if(dtm_func != INVALID_FUNCTION) {
		Call_StartFunction(null, dtm_func);
		Call_PushCell(datamap);
		Call_Finish();
	}

	tmp_classname[len] = '\0';
	StrCat(tmp_classname, sizeof(tmp_classname), "_robothealthbar");
	datamap = register_robot_nextbot_factory(tmp_classname, name);
	if(dtm_func != INVALID_FUNCTION) {
		Call_StartFunction(null, dtm_func);
		Call_PushCell(datamap);
		Call_Finish();
	}

	tmp_classname[len] = '\0';
	StrCat(tmp_classname, sizeof(tmp_classname), "_tankhealthbar");
	datamap = register_tankboss_nextbot_factory(tmp_classname, name);
	if(dtm_func != INVALID_FUNCTION) {
		Call_StartFunction(null, dtm_func);
		Call_PushCell(datamap);
		Call_Finish();
	}
}

stock void remove_entities_of_classname(const char[] classname)
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, classname)) != -1) {
		RemoveEntity(entity);
	}
}

public SharedPlugin __pl_sm_npcs =
{
	name = "sm_npcs",
	file = "sm_npcs.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_sm_npcs_SetNTVOptional()
{
	
}
#endif
