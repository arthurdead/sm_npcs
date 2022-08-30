#define TEAM_UNASSIGNED 0
#define TF_TEAM_PVE_INVADERS 3
#define TF_TEAM_PVE_INVADERS_GIANTS 4
#define TF_TEAM_HALLOWEEN 5

#define DAMAGE_NO 0
#define DAMAGE_YES 2
#define LIFE_ALIVE 0

#define EFL_KILLME (1 << 0)

#define EF_NODRAW 0x020
#define EF_BONEMERGE 0x001
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_PARENT_ANIMATES 0x200

#define MELEE_RANGE 55.0
float MELEE_MINS[3] = {-24.0, -24.0, -82.0};
float MELEE_MAXS[3] = {24.0, 24.0, 82.0};

#define RANGED_RANGE 1000.0

stock float GetVectorLength2D(const float vec[3])
{
	return (vec[0] * vec[0] + vec[1] * vec[1]);
}

stock float UTIL_VecToYaw( const float vec[3] )
{
	if (vec[0] == 0.0 && vec[0] == 0.0)
		return 0.0;
	
	float yaw = ArcTangent2( vec[1], vec[0] );

	yaw = RadToDeg(yaw);

	if (yaw < 0.0)
		yaw += 360.0;

	return yaw;
}

stock float UTIL_VecToPitch( const float vec[3] )
{
	if (vec[1] == 0.0 && vec[0] == 0.0)
	{
		if (vec[2] < 0.0)
			return 180.0;
		else
			return -180.0;
	}

	float dist = GetVectorLength2D(vec);
	float pitch = ArcTangent2( -vec[2], dist );

	pitch = RadToDeg(pitch);

	return pitch;
}

stock float UTIL_AngleDiff( float destAngle, float srcAngle )
{
	float delta;

	delta = ((destAngle - srcAngle) / (360.0));
	if ( destAngle > srcAngle )
	{
		if ( delta >= 180.0 )
			delta -= 360.0;
	}
	else
	{
		if ( delta <= -180.0 )
			delta += 360.0;
	}
	return delta;
}

stock float UTIL_Approach( float target, float value, float speed )
{
	float delta = target - value;

	if ( delta > speed )
		value += speed;
	else if ( delta < -speed )
		value -= speed;
	else 
		value = target;

	return value;
}

stock float get_player_class_speed(int client)
{
	TFClassType class = TF2_GetPlayerClass(client);
	TFPlayerClassData data = TFPlayerClassData.Get(class);
	return data.GetFloat("m_flMaxSpeed");
}

stock int get_player_count()
{
	int players = 0;

	for(int i = 1; i <= MaxClients; ++i) {
		if(!IsClientInGame(i)) {
			continue;
		}

		if(IsClientSourceTV(i) ||
			IsClientReplay(i)) {
			continue;
		}

		++players;
	}

	return players;
}

stock int create_bonemerge_model(int owner, const char[] model, const char[] attach)
{
	int merge = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(merge, "model", model);
	DispatchSpawn(merge);
	SetEntityOwner(merge, owner);
	SetVariantString("!activator");
	AcceptEntityInput(merge, "SetParent", owner);
	int effects = GetEntProp(merge, Prop_Send, "m_fEffects");
	effects |= EF_BONEMERGE|EF_BONEMERGE_FASTCULL|EF_PARENT_ANIMATES;
	SetEntProp(merge, Prop_Send, "m_fEffects", effects);
	SetVariantString(attach)
	AcceptEntityInput(merge, "SetParentAttachment");
	return merge;
}

stock void flying_npc_spawn(INextBot bot, int entity, int health, const float hull[3], float altitude, float acceleration)
{
	shared_npc_spawn(bot, entity, health, hull, altitude, acceleration, true);
}

stock void ground_npc_spawn(INextBot bot, int entity, int health, const float hull[3], float walk_speed, float run_speed)
{
	shared_npc_spawn(bot, entity, health, hull, walk_speed, run_speed, false);
}

static MRESReturn npc_loc_collide(ILocomotion locomotion, int other, bool &result)
{
	if(EntityIsCombatCharacter(other)) {
		result = false;
		return MRES_Supercede;
	}

	return MRES_Ignored;
}

stock Action tankhealthbar_think(int entity, const char[] context)
{
	float health = float(GetEntProp(entity, Prop_Data, "m_iHealth"));
	float maxhealth = float(GetEntProp(entity, Prop_Data, "m_iMaxHealth"));
	SetEntPropFloat(entity, Prop_Send, "m_lastHealthPercentage", (health / maxhealth));
	SetEntityNextThink(entity, GetGameTime() + 0.1, context);
	return Plugin_Continue;
}

static void shared_npc_spawn(INextBot bot, int entity, int health, const float hull[3], float walk_speed, float run_speed, bool fly = false)
{
	AnyLocomotion custom_locomotion = bot.AllocateLocomotion(fly);
	if(fly) {
		custom_locomotion.MaxJumpHeight = walk_speed;
		custom_locomotion.DeathDropHeight = 9999999.0;
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

	set_npc_hull(body_custom, entity, hull);

	SetEntProp(entity, Prop_Data, "m_iHealth", health);
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);

	int initialteam = GetEntProp(entity, Prop_Data, "m_iInitialTeamNum");
	if(initialteam == TEAM_UNASSIGNED) {
		if(GameRules_GetProp("m_bPlayingMannVsMachine")) {
			SetEntProp(entity, Prop_Send, "m_iTeamNum", TF_TEAM_PVE_INVADERS);
		} else {
			SetEntProp(entity, Prop_Send, "m_iTeamNum", TF_TEAM_HALLOWEEN);
		}
	} else {
		SetEntProp(entity, Prop_Send, "m_iTeamNum", initialteam);
	}

	if(GetEntProp(entity, Prop_Send, "m_iTeamNum") == TF_TEAM_PVE_INVADERS && GameRules_GetProp("m_bPlayingMannVsMachine")) {
		//TODO!!!!! move this elsewhere
		custom_locomotion.set_function("ShouldCollideWith", npc_loc_collide);
	}

	char classname[64];
	GetEntityClassname(entity, classname, sizeof(classname));

	int idx = StrContains(classname, "_robothealthbar");
	if(idx != -1) {
		classname[idx] = '\0';

		SetEntProp(entity, Prop_Send, "m_eType", 2);
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

#define npc_healthbar_robot (view_as<entity_healthbar_t>(view_as<int>(entity_healthbar_last)+0))
#define npc_healthbar_tank  (view_as<entity_healthbar_t>(view_as<int>(entity_healthbar_last)+1))

stock bool base_npc_pop_attrs(CustomPopulationSpawner spawner, AttributeType attr, int num)
{
	if(expr_pop_attribute(spawner, attr, num)) {
		return true;
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

stock int base_npc_pop_health(CustomPopulationSpawner spawner, int num, int health)
{
	int health_override = expr_pop_health(spawner, num);
	if(health_override > 0) {
		return health_override;
	}

	return health;
}

stock bool base_npc_pop_parse(CustomPopulationSpawner spawner, KeyValues data)
{
	if(!expr_pop_parse(spawner, data)) {
		return false;
	}

	char healthbar_str[7];
	data.GetString("HealthBar", healthbar_str, sizeof(healthbar_str));
	if(StrEqual(healthbar_str, "Robot")) {
		spawner.set_data("healthbar", npc_healthbar_robot);
	} else if(StrEqual(healthbar_str, "Tank")) {
		spawner.set_data("healthbar", npc_healthbar_tank);
	}

	if(!modifier_spawner_parse(spawner, data)) {
		return false;
	}

	return true;
}

stock bool npc_pop_spawn_single(const char[] classname, CustomPopulationSpawner spawner, const float pos[3], ArrayList result)
{
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
	SetEntProp(entity, Prop_Send, "m_iTeamNum", TF_TEAM_PVE_INVADERS);

	if(result) {
		result.Push(entity);
	}

	return shared_npc_pop_spawn(spawner, pos, result);
}

static bool shared_npc_pop_spawn(CustomPopulationSpawner spawner, const float pos[3], ArrayList result)
{
	if(!expr_pop_spawn(spawner, pos, result)) {
		return false;
	}

	if(!modifier_spawner_spawn(spawner, pos, result)) {
		return false;
	}

	return true;
}

stock void frame_remove_npc(int entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity == -1) {
		return;
	}

	RemoveEntity(entity);
}

stock Action timer_remove_npc(Handle timer, int entity)
{
	entity = EntRefToEntIndex(entity);
	if(entity == -1) {
		return Plugin_Continue;
	}

	RemoveEntity(entity);
	return Plugin_Continue;
}

void set_npc_hull(IBodyCustom body_custom, int entity, const float hull[3])
{
	float mins[3];
	float maxs[3];

	if(IsNullVector(hull)) {
		GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
	} else {
		mins[0] = -hull[0];
		mins[1] = -hull[1];
		mins[2] = 0.0;
		SetEntPropVector(entity, Prop_Send, "m_vecMins", mins);

		maxs[0] = hull[0];
		maxs[1] = hull[1];
		maxs[2] = hull[2];
		SetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
	}

	float width = 0.0;
	if(-mins[1] > maxs[1]) {
		width = -mins[1];
	} else {
		width = maxs[1];
	}

	float height = maxs[2];

	#define TF2_MAGIC_HULL_HEIGHT 135.0

	if(height > TF2_MAGIC_HULL_HEIGHT) {
		height = TF2_MAGIC_HULL_HEIGHT;
	}

	body_custom.HullWidth = width;

	body_custom.CrouchHullHeight = height;
	body_custom.StandHullHeight = height;
	body_custom.LieHullHeight = height;
}

static bool trace_filter_entity(int entity, int mask, any data)
{
	return entity != data;
}

typedef enum_attach_func_t = function void (const float pos[3], int attacker, int victim, any data);

static bool enumerate_attachment_func(int entity, DataPack enum_data)
{
	INextBot bot = INextBot(entity);
	if(bot != INextBot_Null) {
		return false;
	}

	enum_data.Reset();

	int attacker = enum_data.ReadCell();
	if(entity == attacker) {
		return false;
	}

	Function func = enum_data.ReadFunction();

	float pos[3];
	enum_data.ReadCellArray(pos, 3);

	any data = enum_data.ReadCell();

	Call_StartFunction(null, func);
	Call_PushArray(pos, 3);
	Call_PushCell(attacker);
	Call_PushCell(entity);
	Call_PushCell(data);
	Call_Finish();

	return false;
}

stock void enumerate_attachment(int entity, const char[] attach_name, const float hull[3], enum_attach_func_t func, any data = 0)
{
	int attach_idx = AnimatingLookupAttachment(entity, attach_name);

	float pos[3];
	AnimatingGetAttachment(entity, attach_idx, pos);

	float radius = hull[1];

	float mins[3];
	mins[0] = -hull[0];
	mins[1] = -hull[1];
	mins[2] = 0.0;

	float maxs[3];
	maxs[0] = hull[0];
	maxs[1] = hull[1];
	maxs[2] = hull[2];

	//NDebugOverlay_Box(pos, mins, maxs, 255, 0, 0, 255, 1.0);

	NDebugOverlay_Sphere1(pos, radius, 255, 0, 0, false, 1.0);

	DataPack enum_data = new DataPack();
	enum_data.WriteCell(entity);
	enum_data.WriteFunction(func);
	enum_data.WriteCellArray(pos, 3);
	enum_data.WriteCell(data);
	TR_EnumerateEntitiesSphere(pos, radius, PARTITION_SOLID_EDICTS, enumerate_attachment_func, enum_data);
	delete enum_data;
}

void npc_resolve_collisions(int entity)
{
	float npc_pos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", npc_pos);

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
			!IsPlayerAlive(i)) {
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

		Handle trace = TR_TraceHullFilterEx(plr_new_pos, plr_new_pos, ply_mins, ply_maxs, MASK_PLAYERSOLID, trace_filter_entity, i);
		bool hit = TR_DidHit(trace);
		delete trace;

		if(hit) {
			float tmp_pos[3];
			tmp_pos[0] = plr_new_pos[0];
			tmp_pos[1] = plr_new_pos[1];
			tmp_pos[2] = plr_new_pos[2] + 32.0;
			trace = TR_TraceHullFilterEx(tmp_pos, plr_new_pos, ply_mins, ply_maxs, MASK_PLAYERSOLID, trace_filter_entity, i);
			bool solid = TR_StartSolid(trace);

			if(solid) {
				//TakeDamage
				delete trace;
				continue;
			} else {
				TR_GetEndPosition(plr_new_pos, trace);
			}

			delete trace;
		}

		EntitySetAbsOrigin(i, plr_new_pos);
	}
}

stock void handle_playbackrate(int entity, ILocomotion locomotion, IBody body)
{
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
}

stock void handle_move_yaw(int entity, int pose, ILocomotion locomotion)
{
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
}

stock void npc_hull_debug(INextBot bot, IBody body, ILocomotion locomotion, int entity)
{
	if(bot.IsDebugging(NEXTBOT_LOCOMOTION)) {
		float pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);

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
}

stock void remove_entities_of_classname(const char[] classname)
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, classname)) != -1) {
		RemoveEntity(entity);
	}
}