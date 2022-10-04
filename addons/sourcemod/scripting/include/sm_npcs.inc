#if defined __sm_npcs_inc
	#endinput
#endif
#define __sm_npcs_inc

#include <datamaps>
#include <popspawner>
#include <nextbot>

#define DAMAGE_NO 0
#define DAMAGE_YES 2
#define LIFE_ALIVE 0

#define EFL_KILLME (1 << 0)

#define EF_NODRAW 0x020
#define EF_BONEMERGE 0x001
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_PARENT_ANIMATES 0x200

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

native void ground_npc_spawn(INextBot bot, int entity, int health, const float hull[3], float walk_speed, float run_speed);
native void flying_npc_spawn(INextBot bot, int entity, int health, const float hull[3], float altitude, float acceleration);

native void npc_resolve_collisions(int entity);
native void handle_playbackrate(int entity, ILocomotion locomotion, IBody body);
native void handle_move_yaw(int entity, int pose, ILocomotion locomotion);

native int find_particle(const char[] name);

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

//BasicMelee.handle_swing
typedef handle_swing_func_t = function void (int entity);

//BasicMelee.handle_idle
typedef handle_idle_func_t = function void (int entity);

//*.handle_die
typedef handle_die_func_t = function bool (int entity);

//BasicRange.handle_fire
typedef handle_fire_func_t = function void (CustomBehaviorAction action, int entity, int victim, const float sight_pos[3]);

//PlayAnim.setup_next_action
typedef setup_next_action_func_t = function void (CustomBehaviorAction action);

native CustomBehaviorActionEntry get_behavior_action(const char[] name);

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
