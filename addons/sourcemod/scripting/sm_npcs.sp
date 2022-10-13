#include <sourcemod>
#include <sdktools>
#include <teammanager>
#include <rulestools>
#include <datamaps>
#include <nextbot>
#include <animhelpers>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <clsobj_hack>
#include <popspawner>
#define REQUIRE_PLUGIN
#define REQUIRE_EXTENSIONS

#undef REQUIRE_PLUGIN
#include <expr_pop>
#include <modifier_spawner>
#include <listen>
#define REQUIRE_PLUGIN

#include <sm_npcs>

#define npc_healthbar_robot (view_as<entity_healthbar_t>(view_as<int>(entity_healthbar_last)+0))
#define npc_healthbar_tank  (view_as<entity_healthbar_t>(view_as<int>(entity_healthbar_last)+1))

static bool expr_pop_loaded;
static bool clsobj_hack_loaded;
static bool modifier_spawner_loaded;
static bool popspawner_loaded;
static bool listen_loaded;

stock bool can_spawn_here(int mask, const float mins[3], float maxs[3], const float pos[3])
{
	TR_TraceHull(pos, pos, mins, maxs, mask);
	return TR_GetFraction() == 1.0;
}

stock float GetVectorLength2D(const float vec[3])
{
	return (vec[0] * vec[0] + vec[1] * vec[1]);
}

stock void frame_remove_npc(int entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity == -1) {
		return;
	}

	RemoveEntity(entity);
}

stock float get_player_class_speed(int client)
{
	if(clsobj_hack_loaded) {
		TFClassType class = TF2_GetPlayerClass(client);
		TFPlayerClassData data = TFPlayerClassData.Get(class);
		return data.GetFloat("m_flMaxSpeed");
	} else {
		return GetEntPropFloat(client, Prop_Send, "m_flMaxSpeed");
	}
}

#define MELEE_RANGE 70.0
#define RANGED_RANGE 1000.0

static ParticleEffectNames = INVALID_STRING_TABLE;

ConVar sm_npcs_debug_pathing;

#include "sm_npcs/behavior/shared/shared.sp"
#include "sm_npcs/behavior/melee/basic_melee.sp"
#include "sm_npcs/behavior/range/basic_range.sp"
#include "sm_npcs/behavior/anim/play_anim.sp"

static GlobalForward fwd_behaviors_created;

public void OnPluginStart()
{
	sm_npcs_debug_pathing = CreateConVar("sm_npcs_debug_pathing", "0");

	basic_melee_action_init();
	basic_range_action_init();
	play_anim_action_init();
}

public void OnAllPluginsLoaded()
{
	expr_pop_loaded = LibraryExists("expr_pop");
	clsobj_hack_loaded = LibraryExists("clsobj_hack");
	modifier_spawner_loaded = LibraryExists("modifier_spawner");
	popspawner_loaded = LibraryExists("popspawner");
	listen_loaded = LibraryExists("listen");

	if(fwd_behaviors_created.FunctionCount > 0) {
		Call_StartForward(fwd_behaviors_created);
		Call_Finish();
	}
}

static int g_sModelIndexBloodSpray = -1;
static int g_sModelIndexBloodDrop = -1;

public void OnMapStart()
{
	ParticleEffectNames = FindStringTable("ParticleEffectNames");

	g_sModelIndexBloodSpray = PrecacheModel("sprites/bloodspray.vmt");
	g_sModelIndexBloodDrop = PrecacheModel("sprites/blood.vmt");
}

static any native_TE_SetupBloodSprite2Ex(Handle plugin, int params)
{
	float pos[3];
	GetNativeArray(1, pos, 3);

	float dir[3];
	GetNativeArray(2, dir, 3);

	int color[4];
	GetNativeArray(3, color, 4);

	int Size = GetNativeCell(4);

	TE_SetupBloodSprite(pos, dir, color, Size, g_sModelIndexBloodSpray, g_sModelIndexBloodDrop);

	return 0;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	fwd_behaviors_created = new GlobalForward("basic_behaviors_created", ET_Ignore);

	CreateNative("base_npc_pop_health_impl", native_base_npc_pop_health);
	CreateNative("base_npc_pop_attrs_impl", native_base_npc_pop_attrs);
	CreateNative("base_npc_pop_parse_impl", native_base_npc_pop_parse);

	CreateNative("npc_pop_spawn_single", native_npc_pop_spawn_single);
	CreateNative("ground_npc_spawn", native_ground_npc_spawn);
	CreateNative("flying_npc_spawn", native_flying_npc_spawn);
	CreateNative("npc_resolve_collisions", native_npc_resolve_collisions);
	CreateNative("handle_playbackrate", native_handle_playbackrate);
	CreateNative("handle_move_yaw", native_handle_move_yaw);
	CreateNative("npc_hull_debug", native_npc_hull_debug);
	CreateNative("get_behavior_action", native_get_behavior_action);
	CreateNative("find_particle", native_find_particle);
	CreateNative("TE_SetupBloodSprite2Ex", native_TE_SetupBloodSprite2Ex);

	RegPluginLibrary("sm_npcs");

	return APLRes_Success;
}

static any native_get_behavior_action(Handle plugin, int params)
{
	int len;
	GetNativeStringLength(1, len);
	char[] name = new char[++len];
	GetNativeString(1, name, len);

	if(StrEqual(name, "BasicMelee")) {
		return basic_melee_action;
	} else if(StrEqual(name, "BasicRange")) {
		return basic_range_action;
	} else if(StrEqual(name, "PlayAnim")) {
		return play_anim_action;
	}

	return 0;
}

static any native_find_particle(Handle plugin, int params)
{
	int len;
	GetNativeStringLength(1, len);
	char[] name = new char[++len];
	GetNativeString(1, name, len);

	return FindStringIndex(ParticleEffectNames, name);
}

static any native_base_npc_pop_health(Handle plugin, int params)
{
	if(!popspawner_loaded) {
		return 0;
	}

	CustomPopulationSpawner spawner = GetNativeCell(1);
	int num = GetNativeCell(2);
	int health = GetNativeCell(3);

	if(expr_pop_loaded) {
		int health_override = expr_pop_health(spawner, num);
		if(health_override > 0) {
			return health_override;
		}
	}

	return health;
}

static any native_npc_pop_spawn_single(Handle plugin, int params)
{
	if(!popspawner_loaded) {
		return false;
	}

	int len;
	GetNativeStringLength(1, len);
	char[] classname = new char[++len];
	GetNativeString(1, classname, len);

	CustomPopulationSpawner spawner = GetNativeCell(2);

	float pos[3];
	GetNativeArray(3, pos, 3);

	ArrayList result = GetNativeCell(4);

	char tmp_classname[64];
	strcopy(tmp_classname, sizeof(tmp_classname), classname);

	entity_healthbar_t healthbar = entity_healthbar_none;
	if(spawner.has_data("healthbar")) {
		healthbar = spawner.get_data("healthbar");
	}

	switch(healthbar) {
		case npc_healthbar_robot: StrCat(tmp_classname, sizeof(tmp_classname), "_robothealthbar");
		case npc_healthbar_tank: StrCat(tmp_classname, sizeof(tmp_classname), "_tankhealthbar");
	}

	int entity = CreateEntityByName(tmp_classname);
	TeleportEntity(entity, pos);
	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", TF_TEAM_PVE_INVADERS);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeamManager_SetEntityTeam(entity, TF_TEAM_PVE_INVADERS, false);

	if(result) {
		result.Push(entity);
	}

	if(expr_pop_loaded) {
		if(!expr_pop_spawn(spawner, pos, result)) {
			return false;
		}
	}

	if(modifier_spawner_loaded) {
		if(!modifier_spawner_spawn(spawner, pos, result)) {
			return false;
		}
	}

	return true;
}

static any native_base_npc_pop_attrs(Handle plugin, int params)
{
	if(!popspawner_loaded) {
		return false;
	}

	CustomPopulationSpawner spawner = GetNativeCell(1);
	AttributeType attr = GetNativeCell(2);
	int num = GetNativeCell(3);

	if(expr_pop_loaded) {
		if(expr_pop_attribute(spawner, attr, num)) {
			return true;
		}
	}

	AttributeType flags = NPC_POP_FLAGS;

	entity_healthbar_t healthbar = entity_healthbar_none;
	if(spawner.has_data("healthbar")) {
		healthbar = spawner.get_data("healthbar");
	}

	if(healthbar == npc_healthbar_tank) {
		flags |= MINIBOSS;
	}

	return !!(flags & attr);
}

static any native_base_npc_pop_parse(Handle plugin, int params)
{
	if(!popspawner_loaded) {
		return false;
	}

	CustomPopulationSpawner spawner = GetNativeCell(1);
	KeyValues data = GetNativeCell(2);

	if(expr_pop_loaded) {
		if(!expr_pop_parse(spawner, data)) {
			return false;
		}
	}

	char healthbar_str[7];
	data.GetString("HealthBar", healthbar_str, sizeof(healthbar_str));
	if(StrEqual(healthbar_str, "Robot")) {
		spawner.set_data("healthbar", npc_healthbar_robot);
	} else if(StrEqual(healthbar_str, "Tank")) {
		spawner.set_data("healthbar", npc_healthbar_tank);
	}

	if(modifier_spawner_loaded) {
		if(!modifier_spawner_parse(spawner, data)) {
			return false;
		}
	}

	return true;
}

static any native_ground_npc_spawn(Handle plugin, int params)
{
	INextBot bot = GetNativeCell(1);
	int entity = GetNativeCell(2);
	int health = GetNativeCell(3);

	float walk_speed = GetNativeCell(4);
	float run_speed = GetNativeCell(5);

	shared_npc_spawn(bot, entity, health, walk_speed, run_speed, false);
	return 0;
}

static any native_flying_npc_spawn(Handle plugin, int params)
{
	INextBot bot = GetNativeCell(1);
	int entity = GetNativeCell(2);
	int health = GetNativeCell(3);

	float altitude = GetNativeCell(4);
	float acceleration = GetNativeCell(5);

	shared_npc_spawn(bot, entity, health, altitude, acceleration, true);
	return 0;
}

static any native_handle_move_yaw(Handle plugin, int params)
{
	int entity = GetNativeCell(1);
	int pose = GetNativeCell(2);
	ILocomotion locomotion = GetNativeCell(3);

	float ang[3];
	GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);

	float fwd[3];
	float right[3];
	GetAngleVectors(ang, fwd, right, NULL_VECTOR);
	NegateVector(right);

	float velocity[3];
	locomotion.GetVelocity(velocity);

	float x = GetVectorDotProduct(right, velocity);
	float y = GetVectorDotProduct(fwd, velocity);
	float yaw = RadToDeg(ArcTangent2(x, y));

	AnimatingSetPoseParameter(entity, pose, yaw);
	return 0;
}

static any native_handle_playbackrate(Handle plugin, int params)
{
	int entity = GetNativeCell(1);
	ILocomotion locomotion = GetNativeCell(2);
	IBody body = GetNativeCell(3);

	IBodyCustom body_custom = view_as<IBodyCustom>(body);

	float playback_rate = 1.0;

	if(locomotion.OnGround) {
		float ground_speed = locomotion.GroundSpeed;

		float anim_speed = 0.0;
		if(ground_speed > 0.1) {
			if(locomotion.Running) {
				if(body_custom.has_data("run_anim_speed")) {
					anim_speed = body_custom.get_data("run_anim_speed");
				}
			} else {
				if(body_custom.has_data("walk_anim_speed")) {
					anim_speed = body_custom.get_data("walk_anim_speed");
				}
			}
		}

		if(ground_speed > 0.1 && anim_speed > 0.1) {
			playback_rate = (ground_speed / anim_speed);
		}
	}

	if(playback_rate > 2.0) {
		//playback_rate = 2.0;
	}

	if(playback_rate < -4.0) {
		playback_rate = -4.0;
	} else if(playback_rate > 12.0) {
		playback_rate = 12.0;
	}

	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", playback_rate);
	return 0;
}

static bool trace_filter_entity(int entity, int mask, any data)
{
	return entity != data;
}

static any native_npc_hull_debug(Handle plugin, int params)
{
	if(!listen_loaded) {
		return 0;
	}

	INextBot bot = GetNativeCell(1);
	IBody body = GetNativeCell(2);
	ILocomotion locomotion = GetNativeCell(3);
	int entity = GetNativeCell(4);

	if(bot.IsDebugging(NEXTBOT_LOCOMOTION)) {
		float pos[3];
		bot.GetPosition(pos);

		float ang[3];
		GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);

		float mins[3];
		body.GetHullMins(mins);
		float maxs[3];
		body.GetHullMaxs(maxs);

		NDebugOverlay_BoxAngles(pos, mins, maxs, ang, 255, 0, 0, 255, NDEBUG_PERSIST_TILL_NEXT_SERVER);

		GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
		GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

		NDebugOverlay_BoxAngles(pos, mins, maxs, ang, 0, 255, 0, 255, NDEBUG_PERSIST_TILL_NEXT_SERVER);

		float end[3];
		end[0] = pos[0];
		end[1] = pos[1];
		end[2] = pos[2];
		end[2] += locomotion.StepHeight;

		NDebugOverlay_Line(pos, end, 0, 0, 255, false, NDEBUG_PERSIST_TILL_NEXT_SERVER);

		end[0] = pos[0];
		end[1] = pos[1];
		end[2] = pos[2];
		end[1] -= body.HullWidth;
		end[2] += maxs[2] / 2.0;

		NDebugOverlay_Line(pos, end, 0, 0, 255, false, NDEBUG_PERSIST_TILL_NEXT_SERVER);

		end[0] = pos[0];
		end[1] = pos[1];
		end[2] = pos[2];
		end[2] += body.HullHeight;

		NDebugOverlay_Line(pos, end, 0, 0, 255, false, NDEBUG_PERSIST_TILL_NEXT_SERVER);
	}

	return 0;
}

static any native_npc_resolve_collisions(Handle plugin, int params)
{
	INextBot bot = GetNativeCell(1);
	int entity = GetNativeCell(2);

	float npc_pos[3];
	bot.GetPosition(npc_pos);

	float npc_mins[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMins", npc_mins);

	float npc_maxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", npc_maxs);

	float npc_global_maxs[3];
	AddVectors(npc_pos, npc_maxs, npc_global_maxs);

	float npc_global_mins[3];
	AddVectors(npc_pos, npc_mins, npc_global_mins);

	float npc_center[3];
	EntityWorldSpaceCenter(entity, npc_center);

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i) ||
			!IsPlayerAlive(i) ||
			IsClientSourceTV(i) ||
			IsClientReplay(i) ||
			GetClientTeam(i) < 2 ||
			TF2_GetPlayerClass(i) == TFClass_Unknown) {
			continue;
		}

		float ply_pos[3];
		GetClientAbsOrigin(i, ply_pos);

		float ply_mins[3];
		GetEntPropVector(i, Prop_Data, "m_vecMins", ply_mins);

		float ply_maxs[3];
		GetEntPropVector(i, Prop_Data, "m_vecMaxs", ply_maxs);

		float plr_global_maxs[3];
		AddVectors(ply_pos, ply_maxs, plr_global_maxs);

		float plr_global_mins[3];
		AddVectors(ply_pos, ply_mins, plr_global_mins);

		if(plr_global_mins[0] > npc_global_maxs[0] ||
			plr_global_maxs[0] < npc_global_mins[0] ||
			plr_global_mins[1] > npc_global_maxs[1] ||
			plr_global_maxs[1] < npc_global_mins[1] ||
			plr_global_mins[2] > npc_global_maxs[2] ||
			plr_global_maxs[2] < npc_global_mins[2]) {
			continue;
		}

		float plr_center[3];
		EntityWorldSpaceCenter(i, plr_center);

		float to_plr[3];
		SubtractVectors(plr_center, npc_center, to_plr);

		float overlap[3];

		float signX = 0.0;
		float signY = 0.0;
		float signZ = 0.0;

		if(to_plr[0] >= 0.0) {
			overlap[0] = npc_global_maxs[0] - plr_global_mins[0];
			signX = 1.0;
		} else {
			overlap[0] = plr_global_maxs[0] - npc_global_mins[0];
			signX = -1.0;
		}

		if(to_plr[1] >= 0.0) {
			overlap[1] = npc_global_maxs[1] - plr_global_mins[1];
			signY = 1.0;
		} else {
			overlap[1] = plr_global_maxs[1] - npc_global_mins[1];
			signY = -1.0;
		}

		if(to_plr[2] >= 0.0) {
			overlap[2] = npc_global_maxs[2] - plr_global_mins[2];
			signZ = 1.0;
		} else {
			overlap[2] = 99999.9;
			signZ = -1.0;
		}

		float bloat = 5.0;

		float plr_new_pos[3];
		plr_new_pos[0] = ply_pos[0];
		plr_new_pos[1] = ply_pos[1];
		plr_new_pos[2] = ply_pos[2];

		if(overlap[0] < overlap[1]) {
			if(overlap[0] < overlap[2]) {
				plr_new_pos[0] += signX * (overlap[0] + bloat);
			} else {
				plr_new_pos[2] += signZ * (overlap[2] + bloat);
			}
		} else if(overlap[2] < overlap[1]) {
			plr_new_pos[2] += signZ * (overlap[2] + bloat);
		} else {
			plr_new_pos[1] += signY * (overlap[1] + bloat);
		}

		TR_TraceHullFilter(plr_new_pos, plr_new_pos, ply_mins, ply_maxs, MASK_PLAYERSOLID, trace_filter_entity, i);
		bool hit = TR_DidHit();

		if(hit) {
			float tmp_pos[3];
			tmp_pos[0] = plr_new_pos[0];
			tmp_pos[1] = plr_new_pos[1];
			tmp_pos[2] = plr_new_pos[2] + 32.0;
			TR_TraceHullFilter(tmp_pos, plr_new_pos, ply_mins, ply_maxs, MASK_PLAYERSOLID, trace_filter_entity, i);
			bool solid = TR_StartSolid();

			if(solid) {
				//TakeDamage
				continue;
			} else {
				TR_GetEndPosition(plr_new_pos);
			}
		}

		EntitySetAbsOrigin(i, plr_new_pos);
	}

	return 0;
}

static MRESReturn npc_loc_collide(ILocomotion locomotion, int other, bool &result)
{
	if(EntityIsCombatCharacter(other)) {
		result = false;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

static Action tankhealthbar_think(int entity, const char[] context)
{
	float health = float(GetEntProp(entity, Prop_Data, "m_iHealth"));
	float maxhealth = float(GetEntProp(entity, Prop_Data, "m_iMaxHealth"));
	SetEntPropFloat(entity, Prop_Send, "m_lastHealthPercentage", (health / maxhealth));
	SetEntityNextThink(entity, GetGameTime() + 0.1, context);
	return Plugin_Continue;
}

static void shared_npc_spawn(INextBot bot, int entity, int health, float walk_speed, float run_speed, bool fly)
{
	AnyLocomotion custom_locomotion = bot.AllocateLocomotion(fly);
	if(fly) {
		custom_locomotion.MaxJumpHeight = walk_speed;
		custom_locomotion.DeathDropHeight = 9999999.0;
		custom_locomotion.TraversableSlopeLimit = 9999999.0;
		custom_locomotion.StepHeight = walk_speed;
		custom_locomotion.WalkSpeed = run_speed;
		custom_locomotion.RunSpeed = run_speed;
		custom_locomotion.DesiredAltitude = walk_speed;
		custom_locomotion.Acceleration = run_speed;
	} else {
		custom_locomotion.MaxJumpHeight = 180.0;
		custom_locomotion.DeathDropHeight = 200.0;
		custom_locomotion.StepHeight = STEP_HEIGHT;
		custom_locomotion.WalkSpeed = walk_speed;
		custom_locomotion.RunSpeed = run_speed;
	}

	bot.AllocateCustomVision();

	IBodyCustom body_custom = bot.AllocateCustomBody();
	body_custom.set_data("walk_anim_speed", walk_speed);
	body_custom.set_data("run_anim_speed", run_speed);

	set_npc_hull(body_custom, entity);

	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_NO);

		SetEntProp(entity, Prop_Data, "m_iHealth", 99999);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", 99999);
	} else if(health < 0) {
		SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_EVENTS_ONLY);

		SetEntProp(entity, Prop_Data, "m_iHealth", -health);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", -health);
	} else {
		SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_YES);

		SetEntProp(entity, Prop_Data, "m_iHealth", health);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
	}

	int initialteam = GetEntProp(entity, Prop_Data, "m_iInitialTeamNum");
	if(initialteam == TEAM_UNASSIGNED) {
		if(IsMannVsMachineMode()) {
			TeamManager_SetEntityTeam(entity, TF_TEAM_PVE_INVADERS, false);
		} else {
			TeamManager_SetEntityTeam(entity, TF_TEAM_HALLOWEEN, false);
		}
	} else {
		TeamManager_SetEntityTeam(entity, initialteam, false);
	}

	int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
	if((team == TF_TEAM_PVE_INVADERS || team == TF_TEAM_PVE_INVADERS_GIANTS) && IsMannVsMachineMode()) {
		//TODO!!!!! move this elsewhere
		custom_locomotion.set_function("ShouldCollideWith", npc_loc_collide);
	}

	int solidmask = MASK_NPCSOLID;

	switch(team) {
		case TF_TEAM_RED: {
			solidmask |= CONTENTS_BLUETEAM;
		}
		case TF_TEAM_BLUE: {
			solidmask |= CONTENTS_REDTEAM;
		}
	}

	body_custom.SolidMask = solidmask;

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	int idx = StrContains(classname, "_robothealthbar");
	if(idx != -1) {
		classname[idx] = '\0';

		//2 == -35.0
		//1 == -30.0
		//0 == -10.0

		if(fly) {
			SetEntProp(entity, Prop_Send, "m_eType", 0);
		} else {
			SetEntProp(entity, Prop_Send, "m_eType", 2);
		}
	} else {
		idx = StrContains(classname, "_tankhealthbar");
		if(idx != -1) {
			classname[idx] = '\0';

			HookEntityContextThink(entity, tankhealthbar_think, "ThinkTankHealthbar");
			SetEntityNextThink(entity, GetGameTime() + 0.1, "ThinkTankHealthbar");
		}
	}

	SetEntPropString(entity, Prop_Data, "m_iClassname", classname);
}

void set_npc_hull(IBodyCustom body_custom, int entity)
{
	float mins[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);

	float maxs[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);

	float width = maxs[1] > mins[1] ? maxs[1] : mins[1];
	float height = maxs[2];

	width += 1.0;
	height += 1.0;

	body_custom.HullWidth = width;

	body_custom.CrouchHullHeight = height;
	body_custom.StandHullHeight = height;
	body_custom.LieHullHeight = height;
}
