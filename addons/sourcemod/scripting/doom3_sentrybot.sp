#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <clsobj_hack>
#include <datamaps>
#include <animhelpers>
#include <nextbot>

#include "base/shared.sp"

#define COLLISION_GROUP_DEBRIS 1

CObjectInfoCustom g_SentryBoyInfo = null;
DynamicHook GetConstructionMultiplierDetour = null;
FireBulletsInfo_t g_SentryShotInfo;
ConVar obj_sentrybot_health = null;
ConVar obj_sentrybot_damage = null;
bool bWantsSentryBot[MAXPLAYERS+1] = {false, ...};

void obj_sentrybot_health_changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int value = StringToInt(newValue);

	if(g_SentryBoyInfo != null) {
		g_SentryBoyInfo.SetInt("m_nBaseHealth", value);
	}
}

void obj_sentrybot_damage_changed(ConVar convar, const char[] oldValue, const char[] newValue)
{
	float value = StringToFloat(newValue);

	g_SentryShotInfo.m_flDamage = value;
}

public void OnPluginStart()
{
	base_npc_init();

	GameData gamedata = new GameData("doom3_sentrybot");

	GetConstructionMultiplierDetour = DynamicHook.FromConf(gamedata, "CBaseObject::GetConstructionMultiplier");

	delete gamedata;

	CustomEntityFactory factory = register_baseobject_factory("obj_doom3_sentrybot");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);
	datamap.add_prop("m_flLastStep", custom_prop_float);
	datamap.add_prop("m_hTarget", custom_prop_int);
	datamap.add_prop("m_flLastLookAround", custom_prop_float);
	datamap.add_prop("m_flLastScan", custom_prop_float);
	datamap.add_prop("m_vecLookAround", custom_prop_vector);
	datamap.add_prop("m_vecWalkTo", custom_prop_vector);
	datamap.add_prop("m_bWalkingTo", custom_prop_bool);

	obj_sentrybot_health = CreateConVar("obj_sentrybot_health", "150");
	obj_sentrybot_health.AddChangeHook(obj_sentrybot_health_changed);

	obj_sentrybot_damage = CreateConVar("obj_sentrybot_damage", "16.0");
	obj_sentrybot_damage.AddChangeHook(obj_sentrybot_damage_changed);

	g_SentryBoyInfo = CObjectInfoCustom.CloneByName("OBJ_SENTRYGUN");
	g_SentryBoyInfo.SetString("m_pObjectName", "OBJ_DOOM3_SENTRYBOT");
	g_SentryBoyInfo.SetString("m_pClassName", "obj_doom3_sentrybot");
	g_SentryBoyInfo.SetInt("m_MaxUpgradeLevel", 1);
	g_SentryBoyInfo.SetInt("m_nBaseHealth", obj_sentrybot_health.IntValue);

	HookEvent("player_builtobject", player_builtobject);
	HookEvent("object_destroyed", object_destroyed);
	HookEvent("object_detonated", object_destroyed);

	g_SentryShotInfo.m_bPrimaryAttack = true;
	g_SentryShotInfo.m_iAmmoType = TF_AMMO_PRIMARY;
	g_SentryShotInfo.m_flDamage = obj_sentrybot_damage.FloatValue;
	g_SentryShotInfo.m_iTracerFreq = 1;
	g_SentryShotInfo.m_iShots = 1;
	g_SentryShotInfo.m_flDamageForceScale = 1.0;

	//RegAdminCmd("sm_sentrybot", sm_sentrybot, ADMFLAG_GENERIC);
	RegConsoleCmd("sm_sentrybot", sm_sentrybot);
}

Action sm_sentrybot(int client, int args)
{
	if(client == 0) {
		ReplyToCommand(client, "[SM] you must be ingame to use this comamnd.");
		return Plugin_Handled;
	}

	bWantsSentryBot[client] = !bWantsSentryBot[client];

	if(bWantsSentryBot[client]) {
		ReplyToCommand(client, "[SM] sentrybot enabled.");

		int builder = GetBuilderOfType(client, view_as<int>(TFObject_Sentry));
		if(builder) {
			BuilderSetAsBuildable(builder, view_as<int>(TFObject_Sentry), false);
			BuilderSetAsBuildable(builder, g_SentryBoyInfo.Index, true);
		}

		int entity = -1;
		while((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1) {
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder") == client) {
				RemoveEntity(entity);
			}
		}
	} else {
		ReplyToCommand(client, "[SM] sentrybot disabled.");

		int builder = GetBuilderOfType(client, g_SentryBoyInfo.Index);
		if(builder) {
			BuilderSetAsBuildable(builder, g_SentryBoyInfo.Index, false);
			BuilderSetAsBuildable(builder, view_as<int>(TFObject_Sentry), true);
		}

		int entity = -1;
		while((entity = FindEntityByClassname(entity, "obj_doom3_sentrybot")) != -1) {
			if(GetEntPropEnt(entity, Prop_Send, "m_hBuilder") == client) {
				RemoveEntity(entity);
			}
		}
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	bWantsSentryBot[client] = false;
}

public Action ClassCanBuildObject(int client, int class, int type, bool &can)
{
	if(class != view_as<int>(TFClass_Engineer)) {
		return Plugin_Continue;
	}

	if(bWantsSentryBot[client]) {
		if(g_SentryBoyInfo != null && type == g_SentryBoyInfo.Index) {
			can = true;
			return Plugin_Changed;
		} else if(type == view_as<int>(TFObject_Sentry)) {
			can = false;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

static const char stepsounds[4][PLATFORM_MAX_PATH] =
{
	"cpt_doom3/sentrybot/sentry_sstep_01.wav",
	"cpt_doom3/sentrybot/sentry_sstep_02.wav",
	"cpt_doom3/sentrybot/sentry_sstep_03.wav",
	"cpt_doom3/sentrybot/sentry_sstep_04.wav",
};

static const char firesounds[5][PLATFORM_MAX_PATH] =
{
	"cpt_doom3/sentrybot/sentry_fire_01.wav",
	"cpt_doom3/sentrybot/sentry_fire_02.wav",
	"cpt_doom3/sentrybot/sentry_fire_03.wav",
	"cpt_doom3/sentrybot/sentry_fire_04.wav",
	"cpt_doom3/sentrybot/sentry_fire_05.wav",
};

static const char painsounds[4][PLATFORM_MAX_PATH] =
{
	"cpt_doom3/sentrybot/sentry_pain_01.wav",
	"cpt_doom3/sentrybot/sentry_pain_02.wav",
	"cpt_doom3/sentrybot/sentry_pain_03.wav",
	"cpt_doom3/sentrybot/sentry_pain_04.wav",
};

int g_nMuzzle = -1;

public void OnMapStart()
{
	int entity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(entity, "model", "models/error.mdl");
	DispatchSpawn(entity);

	BaseAnimating anim = BaseAnimating(entity);

	PrecacheModel("models/cpthazama/doom3/sentrybot.mdl");

	SetEntityModel(entity, "models/cpthazama/doom3/sentrybot.mdl");

	g_nMuzzle = anim.LookupAttachment("muzzle");

	g_SentryBoyInfo.SetFloat("m_flBuildTime", anim.SequenceDuration("unfold") * 1.8);

	RemoveEntity(entity);

	PrecacheSound("cpt_doom3/sentrybot/sentry_destroyed_01.wav");
	PrecacheSound("cpt_doom3/sentrybot/sentry_activate_01.wav");
	PrecacheSound("cpt_doom3/sentrybot/sentry_shutdown_01.wav");
	PrecacheSound("cpt_doom3/sentrybot/sentry_fight_enemy_02.wav");
	for(int i = 0; i < sizeof(stepsounds); ++i) {
		PrecacheSound(stepsounds[i]);
	}
	for(int i = 0; i < sizeof(firesounds); ++i) {
		PrecacheSound(firesounds[i]);
	}
	for(int i = 0; i < sizeof(painsounds); ++i) {
		PrecacheSound(painsounds[i]);
	}
}

void SentryBotSpawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_iHealth", obj_sentrybot_health.IntValue);
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", obj_sentrybot_health.IntValue);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);

	SetEntityModel(entity, "models/cpthazama/doom3/sentrybot.mdl");

	base_npc_set_hull(entity, 20.0, 40.0);

	INextBot bot = INextBot(entity);
	NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

	locomotion.DeathDropHeight = 18.0;
	locomotion.MaxJumpHeight = 18.0;

	SDKUnhook(entity, SDKHook_SpawnPost, SentryBotSpawn);
	SDKHook(entity, SDKHook_SpawnPost, SentryBotCarried);

	SentryBotCarried(entity);

	//int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");
	//SDKHook(builder, SDKHook_OnTakeDamage);
}

void SentryBotCarried(int entity)
{
	EmitSoundToAll("cpt_doom3/sentrybot/sentry_shutdown_01.wav", entity);
}

stock void CreateAmmoPack(int entity, float origin[3])
{
	static ConVar tf_obj_gib_velocity_min = null;
	if(tf_obj_gib_velocity_min == null) {
		tf_obj_gib_velocity_min = FindConVar("tf_obj_gib_velocity_min");
	}
	static ConVar tf_obj_gib_velocity_max = null;
	if(tf_obj_gib_velocity_max == null) {
		tf_obj_gib_velocity_max = FindConVar("tf_obj_gib_velocity_max");
	}
	static ConVar tf_obj_gib_maxspeed = null;
	if(tf_obj_gib_maxspeed == null) {
		tf_obj_gib_maxspeed = FindConVar("tf_obj_gib_maxspeed");
	}

	int metal = g_SentryBoyInfo.GetInt("m_iMetalToDropInGibs");
	if(metal == 0) {
		int cost = g_SentryBoyInfo.GetInt("m_Cost");
		float reduced = float(cost) * 0.5;
		PrintToServer("%i, %f", cost, reduced);
		metal = RoundToFloor(reduced);
		PrintToServer("%i", metal);
	}

	int ammo = CreateEntityByName("tf_ammo_pack");

	static int m_bObjGibOffset = -1;
	if(m_bObjGibOffset == -1) {
		m_bObjGibOffset = FindDataMapInfo(ammo, "m_pConstraint") + 4;
	}

	static int m_iAmmoOffset = -1;
	if(m_iAmmoOffset == -1) {
		m_iAmmoOffset = m_bObjGibOffset + 1;
	}

	PrintToServer("%i, %i", m_bObjGibOffset, m_iAmmoOffset);

	int team = GetEntProp(entity, Prop_Data, "m_iTeamNum");

	SetEntityModel(ammo, "models/items/ammopack_medium.mdl");
	SetEntProp(ammo, Prop_Data, "m_iHealth", 900);
	SetEntProp(ammo, Prop_Send, "m_nSkin", team == 2 ? 0 : 1);
	DispatchSpawn(ammo);
	SetEntProp(ammo, Prop_Send, "m_CollisionGroup", COLLISION_GROUP_DEBRIS);
	SetEntProp(ammo, Prop_Data, "m_takedamage", DAMAGE_YES);
	int finaloffset = m_iAmmoOffset + (TF_AMMO_METAL * 4);
	PrintToServer("%i, %i", finaloffset, metal);
	SetEntData(ammo, finaloffset, metal);

	float vel[3];
	vel[0] = GetRandomFloat(-0.5, 0.5);
	vel[1] = GetRandomFloat(-0.5, 0.5);
	vel[2] = GetRandomFloat(0.75, 1.25);
	ScaleVector(vel, GetRandomFloat(tf_obj_gib_velocity_min.FloatValue, tf_obj_gib_velocity_max.FloatValue));
	float speed = GetVectorLength(vel);
	if(speed > tf_obj_gib_maxspeed.FloatValue) {
		ScaleVector(vel, speed / tf_obj_gib_maxspeed.FloatValue);
	}
	TeleportEntity(ammo, origin, _, vel);
}

Action object_destroyed(Event event, const char[] name, bool dontBroadcast)
{
	int type = event.GetInt("objecttype");

	if(type == g_SentryBoyInfo.Index) {
		int entity = event.GetInt("index");

		EmitSoundToAll("cpt_doom3/sentrybot/sentry_destroyed_01.wav", entity);

		float origin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);

		CreateAmmoPack(entity, origin);
	}

	return Plugin_Continue;
}

Action player_builtobject(Event event, const char[] name, bool dontBroadcast)
{
	int type = event.GetInt("object");

	if(type == g_SentryBoyInfo.Index) {
		int entity = event.GetInt("index");
		EmitSoundToAll("cpt_doom3/sentrybot/sentry_activate_01.wav", entity);
	}

	return Plugin_Continue;
}

bool TraceEntityFilter_DontHitEntityOrBuilder(int entity, int mask, int data)
{
	int builder = GetEntPropEnt(data, Prop_Send, "m_hBuilder");
	return entity != data && entity != builder;
}

void SentryBotThink(int entity, const char[] context, any data)
{
	INextBot bot = INextBot(entity);

	SetEntityNextThinkContext(entity, GetGameTime() + 0.05);

	BaseAnimatingOverlay anim = BaseAnimatingOverlay(entity);

	anim.StudioFrameAdvance();

	if(GetEntProp(entity, Prop_Send, "m_bBuilding")) {
		int sequence = anim.SelectWeightedSequenceEx(ACT_STAND);
		anim.ResetSequenceEx(sequence);
		return;
	}

	if(GetEntProp(entity, Prop_Send, "m_bPlacing")) {
		int sequence = anim.SelectWeightedSequenceEx(ACT_CROUCHIDLE);
		anim.ResetSequenceEx(sequence);
		return;
	}

	if(GetEntProp(entity, Prop_Send, "m_bCarried") ||
		GetEntProp(entity, Prop_Send, "m_bPlasmaDisable") ||
		GetEntProp(entity, Prop_Send, "m_bDisabled") ||
		GetEntProp(entity, Prop_Send, "m_bCarryDeploy")) {
		return;
	}

	if(!bot.DoThink(entity)) {
		return;
	}

	base_npc_think(entity);

	int builder = GetEntPropEnt(entity, Prop_Send, "m_hBuilder");

	bool m_bPlayerControlled = false;

	int weapon = GetEntPropEnt(builder, Prop_Send, "m_hActiveWeapon");
	if(weapon != -1) {
		int m_iItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

		switch(m_iItemDefinitionIndex) {
			case 140, 1086, 30668:
			{ m_bPlayerControlled = true; }
		}
	}

	int target = builder;

	ChasePath path = get_npc_path(entity);
	NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

	bool facingtarget = false;
	CKnownEntity threat = CKnownEntity_Null;

	if(!m_bPlayerControlled) {
		IVision vision = bot.VisionInterface;

		threat = vision.GetPrimaryKnownThreat(false);

		if(threat == CKnownEntity_Null) {
			for(int i = 1; i <= MaxClients; ++i) {
				if(!IsClientInGame(i) ||
					!IsPlayerAlive(i) ||
					GetClientTeam(i) == GetEntProp(entity, Prop_Send, "m_iTeamNum")) {
					continue;
				}

				if(TF2_IsPlayerInCondition(i, TFCond_Disguised) ||
					TF2_IsPlayerInCondition(i, TFCond_Cloaked)) {
					continue;
				}

				if(!vision.IsAbleToSeeEntity(i, DISREGARD_FOV)) {
					continue;
				}

				if(bot.IsRangeLessThanEntity(i, 1100.0)) {
					vision.AddKnownEntity(i);
				}
			}

			threat = vision.GetPrimaryKnownThreat(false);
		}

		if(threat != CKnownEntity_Null) {
			target = threat.Entity;

			if(threat.IsVisibleInFOVNow()) {
				facingtarget = true;

				float target_pos[3];
				GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);

				locomotion.FaceTowards(target_pos);

				if(!anim.IsPlayingGestureEx(ACT_RANGE_ATTACK1)) {
					anim.AddGestureEx1(ACT_RANGE_ATTACK1);
				}

				if(GetEntPropFloat(entity, Prop_Send, "m_flNextAttack") <= GetGameTime()) {
					anim.GetAttachmentEx(g_nMuzzle, g_SentryShotInfo.m_vecSrc, NULL_VECTOR);

					float target_center[3];
					vision.IsLineOfSightClearToEntity(target, target_center);

					SubtractVectors(target_center, g_SentryShotInfo.m_vecSrc, g_SentryShotInfo.m_vecDirShooting);

					g_SentryShotInfo.m_flDistance = GetVectorLength(g_SentryShotInfo.m_vecDirShooting) + 100.0;

					g_SentryShotInfo.m_vecSpread[0] = 0.0;
					g_SentryShotInfo.m_vecSpread[1] = 0.0;
					g_SentryShotInfo.m_vecSpread[2] = 0.0;

					g_SentryShotInfo.m_pAttacker = builder;
					anim.FireBullets(g_SentryShotInfo);
					SetEntPropFloat(entity, Prop_Send, "m_flNextAttack", GetGameTime() + 0.1);

					EmitSoundToAll(firesounds[GetRandomInt(0, sizeof(firesounds)-1)], entity);
				}
			}
		}

		if(!facingtarget && bot.GetRangeToEntity(target) <= 100.0) {
			facingtarget = true;
		}
	} else {
		facingtarget = true;

		bool attacking = !!(GetClientButtons(builder) & IN_ATTACK);
		bool moving = !!(GetClientButtons(builder) & IN_ATTACK2);

		if(attacking || moving) {
			float target_pos[3];
			GetClientEyePosition(builder, target_pos);

			float ang[3];
			GetClientEyeAngles(builder, ang);

			Handle trace = TR_TraceRayFilterEx(target_pos, ang, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntityOrBuilder, entity);

			TR_GetEndPosition(target_pos, trace);

			delete trace;

			if(moving) {
				SetEntProp(entity, Prop_Data, "m_bWalkingTo", 1);
				SetEntPropVector(entity, Prop_Data, "m_vecWalkTo", target_pos);
			}

			IVision vision = bot.VisionInterface;

			if(attacking && vision.IsInFieldOfViewVector(target_pos)) {
				if(!anim.IsPlayingGestureEx(ACT_RANGE_ATTACK1)) {
					anim.AddGestureEx1(ACT_RANGE_ATTACK1);
				}

				if(GetEntPropFloat(entity, Prop_Send, "m_flNextAttack") <= GetGameTime()) {
					anim.GetAttachmentEx(g_nMuzzle, g_SentryShotInfo.m_vecSrc, NULL_VECTOR);

					SubtractVectors(target_pos, g_SentryShotInfo.m_vecSrc, g_SentryShotInfo.m_vecDirShooting);

					g_SentryShotInfo.m_flDistance = GetVectorLength(g_SentryShotInfo.m_vecDirShooting) + 100.0;

					g_SentryShotInfo.m_vecSpread[0] = 0.02618;
					g_SentryShotInfo.m_vecSpread[1] = 0.02618;
					g_SentryShotInfo.m_vecSpread[2] = 0.02618;

					g_SentryShotInfo.m_pAttacker = builder;
					anim.FireBullets(g_SentryShotInfo);
					SetEntPropFloat(entity, Prop_Send, "m_flNextAttack", GetGameTime() + 0.1);

					EmitSoundToAll(firesounds[GetRandomInt(0, sizeof(firesounds)-1)], entity);
				}
			}
		}
	}

	int sequence = anim.SelectWeightedSequenceEx(ACT_IDLE);

	float speed = locomotion.GroundSpeed;
	if(speed > 1.0) {
		if(GetEntPropFloat(entity, Prop_Data, "m_flLastStep") <= GetGameTime()) {
			EmitSoundToAll(stepsounds[GetRandomInt(0, sizeof(stepsounds)-1)], entity);
			SetEntPropFloat(entity, Prop_Data, "m_flLastStep", GetGameTime() + 0.1);
		}

		if(threat == CKnownEntity_Null && !m_bPlayerControlled) {
			sequence = anim.SelectWeightedSequenceEx(ACT_WALK);
		} else {
			sequence = anim.SelectWeightedSequenceEx(ACT_WALK_AIM);
		}
	} else if(threat == CKnownEntity_Null) {
		if(facingtarget && !GetEntProp(entity, Prop_Data, "m_bWalkingTo")) {
			float target_pos[3];
			GetEntPropVector(entity, Prop_Data, "m_vecLookAround", target_pos);

			if(GetEntPropFloat(entity, Prop_Data, "m_flLastLookAround") <= GetGameTime()) {
				GetClientEyePosition(builder, target_pos);

				float ang[3];
				GetClientEyeAngles(builder, ang);

				Handle trace = TR_TraceRayFilterEx(target_pos, ang, MASK_SOLID, RayType_Infinite, TraceEntityFilter_DontHitEntityOrBuilder, entity);

				TR_GetEndPosition(target_pos, trace);

				delete trace;

				SetEntPropVector(entity, Prop_Data, "m_vecLookAround", target_pos);
				SetEntPropFloat(entity, Prop_Data, "m_flLastLookAround", GetGameTime() + 0.5);
			}

			locomotion.FaceTowards(target_pos);
		}
	}

	anim.ResetSequenceEx(sequence);

	float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed == 0.0) {
		m_flGroundSpeed = 999.0;
	}

	locomotion.RunSpeed = m_flGroundSpeed;
	locomotion.WalkSpeed = m_flGroundSpeed;

	if(m_bPlayerControlled) {
		if(GetEntProp(entity, Prop_Data, "m_bWalkingTo")) {
			if(GetEntPropFloat(entity, Prop_Data, "m_flRepathTime") <= GetGameTime()) {
				float pos[3];
				GetEntPropVector(entity, Prop_Data, "m_vecWalkTo", pos);
				path.ComputeVector(bot, pos, baseline_path_cost, cost_flags_mod|cost_flags_safest|cost_flags_discrete);
				SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
			}

			view_as<PathFollower>(path).Update(bot);

			if(path.IsAtGoal(bot)) {
				SetEntProp(entity, Prop_Data, "m_bWalkingTo", 0);
			}
		}
	} else if(!facingtarget) {
		path.Update(bot, target, baseline_path_cost, cost_flags_mod|cost_flags_safest|cost_flags_discrete);
	}
}

MRESReturn GetConstructionMultiplierPost(int pThis, DHookReturn hReturn)
{
	view_as<float>(hReturn.Value) *= 2.0;
	return MRES_Supercede;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "obj_doom3_sentrybot")) {
		SetEntProp(entity, Prop_Send, "m_iObjectType", g_SentryBoyInfo.Index);
		SetEntProp(entity, Prop_Send, "m_fObjectFlags", 0x04);

		SDKHook(entity, SDKHook_SpawnPost, SentryBotSpawn);

		GetConstructionMultiplierDetour.HookEntity(Hook_Post, entity, GetConstructionMultiplierPost);

		SetEntityContextThink(entity, SentryBotThink, GetGameTime() + 0.05, "SentrybotContext");

		MakeEntityNextBot(entity);
	}
}

public void OnEntityDestroyed(int entity)
{
	if(entity == -1) {
		return;
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));
	if(StrEqual(classname, "obj_doom3_sentrybot")) {
		base_npc_deleted(entity);
	}
}

void SentryBotRemoveAll()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "obj_doom3_sentrybot")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
}

public void OnPluginEnd()
{
	SentryBotRemoveAll();
}