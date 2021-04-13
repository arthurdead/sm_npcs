#include <datamaps>
#include <animhelpers>
#include <nextbot>

#define LIFE_DYING 1

#define BLOOD_COLOR_RED 0
#define BLOOD_COLOR_YELLOW 1
#define BLOOD_COLOR_GREEN 2
#define BLOOD_COLOR_MECH 3

#define HIDEHUD_BONUS_PROGRESS (1 << 11)

ConVar base_npc_path_lookahead_range = null;

stock void base_npc_init()
{
#if defined GAME_TF2
	base_npc_path_lookahead_range = FindConVar("tf_bot_path_lookahead_range");
#elseif defined GAME_L4D2
	base_npc_path_lookahead_range = FindConVar("z_jockey_lookahead");
#endif
}

stock ChasePath base_npc_create_chase(int entity)
{
#if defined GAME_L4D2
	InfectedChasePath path = new InfectedChasePath(LEAD_SUBJECT);
#elseif defined GAME_TF2
	DirectChasePath path = new DirectChasePath(LEAD_SUBJECT);
#endif
	path.MinLookAheadDistance = base_npc_path_lookahead_range.FloatValue * GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
	return path;
}

stock PathFollower base_npc_create_follower(int entity)
{
#if defined GAME_L4D2
	PathFollower path = new PathFollower();
#elseif defined GAME_TF2
	CTFPathFollower path = new CTFPathFollower();
#endif
	path.MinLookAheadDistance = base_npc_path_lookahead_range.FloatValue * GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
	return path;
}

stock bool base_npc_climbuptoledge(GameLocomotionCustom locomotion, float goal[3], float fwd[3], int obstacle)
{
	return false;
}

stock void base_npc_spawn(int entity, IIntentionCustom inte = IIntentionCustom_Null)
{
	INextBot bot = INextBot(entity);

	INextBotCustom custom = bot.MakeCustom();
#if defined GAME_L4D2
	custom.AllowedToClimb = false;
#endif

	GameLocomotionCustom locomotion = bot.AllocateCustomLocomotion();
	locomotion.set_function("ClimbUpToLedge", base_npc_climbuptoledge);

	bot.AllocateCustomBody();
	bot.AllocateCustomVision();

	SDKHook(entity, SDKHook_Think, base_npc_think);
}

stock int create_base_npc(const char[] classname, int team = 0)
{
	int entity = CreateEntityByName(classname);
	SetEntProp(entity, Prop_Data, "m_iTeamNum", team);
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", team);
	ActivateEntity(entity);
	return entity;
}

stock void base_npc_set_hull(int entity, float width, float height)
{
	float m_flModelScale = GetEntPropFloat(entity, Prop_Send, "m_flModelScale");

	float HullWidth = width * m_flModelScale;
	float HullHeight = height * m_flModelScale;

	float hullMins[3];
	hullMins[0] = -HullWidth;
	hullMins[1] = hullMins[0];
	hullMins[2] = 0.0;

	float hullMaxs[3];
	hullMaxs[0] = HullWidth;
	hullMaxs[1] = hullMaxs[0];
	hullMaxs[2] = HullHeight;

	INextBot bot = INextBot(entity);
	IBodyCustom body = view_as<IBodyCustom>(bot.BodyInterface);

	body.HullWidth = HullWidth;
	body.HullHeight = HullHeight;

	SetEntPropVector(entity, Prop_Send, "m_vecMins", hullMins);
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", hullMaxs);

	hullMins[0] = -HullWidth/2.0;
	hullMins[1] = hullMins[0];

	hullMaxs[0] = HullWidth/2.0;
	hullMaxs[1] = hullMaxs[0];

	body.SetHullMins(hullMins);
	body.SetHullMaxs(hullMaxs);
}

stock bool TraceEntityFilter_DontHitEntity(int entity, int mask, any data)
{
	return entity != data;
}

stock void base_npc_resolve_collisions(int entity)
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
	view_as<BaseEntity>(entity).WorldSpaceCenter(npc_center);

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
		view_as<BaseEntity>(i).WorldSpaceCenter(plr_center);

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

		Handle trace = TR_TraceHullFilterEx(plr_new_pos, plr_new_pos, ply_mins, ply_maxs, MASK_PLAYERSOLID, TraceEntityFilter_DontHitEntity, i);
		bool hit = TR_DidHit(trace);
		delete trace;

		if(hit) {
			float tmp_pos[3];
			tmp_pos[0] = plr_new_pos[0];
			tmp_pos[1] = plr_new_pos[1];
			tmp_pos[2] = plr_new_pos[2] + 32.0;
			trace = TR_TraceHullFilterEx(tmp_pos, plr_new_pos, ply_mins, ply_maxs, MASK_PLAYERSOLID, TraceEntityFilter_DontHitEntity, i);
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

		view_as<BaseEntity>(i).SetAbsOrigin(plr_new_pos);
	}
}

stock void base_npc_think(int entity)
{
	BaseAnimating anim = BaseAnimating(entity);
	anim.StudioFrameAdvance();

	base_npc_resolve_collisions(entity);

	INextBot bot = INextBot(entity);

	if(bot.IsDebugging(NEXTBOT_LOCOMOTION)) {
		float pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);

		float ang[3];
		GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);

		IBody body = bot.BodyInterface;

		float mins[3];
		body.GetHullMins(mins);
		float maxs[3];
		body.GetHullMaxs(maxs);

		DrawHull(pos, ang, mins, maxs, {255, 0, 0, 255});

		GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
		GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

		DrawHull(pos, ang, mins, maxs, {0, 255, 0, 255});
	}
}

#if defined GAME_TF2
stock void TypeToClassname(TFClassType type, char[] str, int len)
{
	switch(type) {
		case TFClass_Heavy: { strcopy(str, len, "heavy"); }
		case TFClass_Scout: { strcopy(str, len, "scout"); }
		case TFClass_Pyro: { strcopy(str, len, "pyro"); }
		case TFClass_Medic: { strcopy(str, len, "medic"); }
		case TFClass_Spy: { strcopy(str, len, "spy"); }
		case TFClass_Engineer: { strcopy(str, len, "engineer"); }
		case TFClass_Sniper: { strcopy(str, len, "sniper"); }
		case TFClass_Soldier: { strcopy(str, len, "soldier"); }
		case TFClass_DemoMan: { strcopy(str, len, "demo"); }
	}
}

#if defined popspawner_included
stock void base_npc_pop_parse(CustomPopulationSpawner spawner, KeyValues data, int defhealth, bool defminiboss = false)
{
	int health = data.GetNum("Health", defhealth);
	float scale = data.GetFloat("ModelScale", 1.0);
	bool miniboss = view_as<bool>(data.GetNum("MiniBoss", view_as<int>(defminiboss)));

	char classname[32];
	data.GetString("Class", classname, sizeof(classname));

	TFClassType class = TFClass_Unknown;
	if(!StrEqual(classname, "")) {
		class = TF2_GetClass(classname);
	}

	spawner.set_data("Class", class);
	spawner.set_data("Health", health);
	spawner.set_data("Scale", scale);
	spawner.set_data("MiniBoss", miniboss);
}

stock bool base_npc_pop_isminiboss(CustomPopulationSpawner spawner, int num)
{
	return spawner.get_data("MiniBoss");
}

stock bool base_npc_pop_getclassicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	TFClassType class = spawner.get_data("Class");
	if(class == TFClass_Unknown) {
		strcopy(str, len, "Tank");
	} else {
		TypeToClassname(class, str, len);
	}
	return true;
}

stock int base_npc_pop_getclass(CustomPopulationSpawner spawner, int num)
{
	return spawner.get_data("Class");
}

stock bool base_npc_pop_hasattribute(CustomPopulationSpawner spawner, AttributeType attr, int num)
{
	if(attr & (IGNORE_FLAG|IS_NPC|REMOVE_ON_DEATH)) {
		return true;
	}

	if(spawner.get_data("MiniBoss")) {
		if(attr & MINIBOSS) {
			return true;
		}
	}

	return false;
}

stock void base_npc_pop_spawn(CustomPopulationSpawner spawner, int entity)
{
	int health = spawner.get_data("Health");
	float scale = spawner.get_data("Scale");

	SetEntProp(entity, Prop_Data, "m_iHealth", health);
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", scale);
}

stock int base_npc_pop_get_health(CustomPopulationSpawner spawner, int num)
{
	return spawner.get_data("Health");
}
#endif

stock bool FindBombSite(float pos[3])
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "func_capturezone")) != -1) {
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);
		return true;
	}
	return false;
}

stock int FindFurthestTank()
{
	return -1;
}

stock int FindFurthestBulltank()
{
	return -1;
}

stock int FindFurthestBombPlayer()
{
	for(int i = 1; i <= MaxClients; ++i) {
		if(IsClientInGame(i)) {
			if(GetClientTFTeam(i) == TFTeam_Blue) {
				
			}
		}
	}

	return -1;
}

stock int FindFurthestEscortTarget()
{
	int entity = FindFurthestTank();
	if(entity == -1) {
		entity = FindFurthestBulltank();
	}
	if(entity == -1) {
		entity = FindFurthestBombPlayer();
	}
	return entity;
}
#endif

stock void FrameRemoveEntity(int entity)
{
	RemoveEntity(entity);
}

stock void GetDoorCenter(int entity, float center[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", center);

	float ang[3];
	GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);

	float maxs[3];
	GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

	float offset[3];
	offset[0] = 0.0;
	offset[1] = -(maxs[1]/2.0) + 3.0;
	offset[2] = -maxs[2] + 7.0;

	int master = GetEntPropEnt(entity, Prop_Data, "m_hMaster");
	if(master != -1) {
		offset[1] -= maxs[1]/2.0 + 3.0;
	}

	VectorAddRotatedOffset(ang, center, offset);
}

stock void OpenDoorAwayFrom(int door, int entity)
{
	int master = GetEntPropEnt(door, Prop_Data, "m_hMaster");
	if(master != -1) {
		SetVariantString("!activator")
		AcceptEntityInput(master, "OpenAwayFrom", entity);
	} else {
		SetVariantString("!activator")
		AcceptEntityInput(door, "OpenAwayFrom", entity);
	}
}

stock void GetOffsetToDoor(int entity, int door, float pos[3], float range)
{
	float mypos[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", mypos);

	NavRelativeDirType dir = DirectionBetweenEntityVector(door, mypos);

	PrintToServer("%i", dir);

	float offset[3];
	if(dir == FORWARD) {
		offset[0] = range;
	} else if(dir == BACKWARD || dir == LEFT) {
		offset[0] = -range;
	}

	float ang[3];
	GetEntPropVector(door, Prop_Data, "m_angAbsRotation", ang);

	VectorAddRotatedOffset(ang, pos, offset);
}

stock void remove_all_entities(const char[] classname)
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, classname)) != -1) {
		RemoveEntity(entity);
	}
}

stock bool AutoMovement(int entity, float pos[3], float ang[3], float scale = 1.0, INextBot bot = INextBot_Null)
{
	if(bot == INextBot_Null) {
		bot = INextBot(entity);
	}

	GameLocomotionCustom locomotion = view_as<GameLocomotionCustom>(bot.LocomotionInterface);
	locomotion.RunSpeed = 0.0;
	locomotion.WalkSpeed = 0.0;

	bool finished = false;
	if(view_as<BaseAnimating>(entity).GetSequenceMovement(finished, pos, ang)) {
		float origin[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
		ScaleVector(pos, scale);
		AddVectors(origin, pos, pos);
		locomotion.DriveTo(pos);
		float rot[3];
		GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", rot);
		AddVectors(rot, ang, ang);
		SetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);
	}

	return finished;
}

stock void VectorAddRotatedOffset(const float angle[3], float buffer[3], const float offset[3])
{
	float vecForward[3]; float vecLeft[3]; float vecUp[3];
	GetAngleVectors(angle, vecForward, vecLeft, vecUp);

	ScaleVector(vecForward, offset[0]);
	ScaleVector(vecLeft, offset[1]);
	ScaleVector(vecUp, offset[2]);

	float vecAdd[3];
	AddVectors(vecAdd, vecForward, vecAdd);
	AddVectors(vecAdd, vecLeft, vecAdd);
	AddVectors(vecAdd, vecUp, vecAdd);

	AddVectors(buffer, vecAdd, buffer);
}

#if defined GAME_L4D2
stock bool L4D2_IsSurvivorBusy(int client)
{
	return GetEntityFlags(client) & FL_FROZEN || 
		GetEntProp(client, Prop_Send, "m_iHideHUD") & ~HIDEHUD_BONUS_PROGRESS || 
		GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0 || 
		//GetEntProp(client, Prop_Send, "m_knockdownReason") > 0 || 
		GetEntPropFloat(client, Prop_Send, "m_staggerDist") > 0.0 || 
		GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 || 
		GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0;
}
#endif

int g_iLaserBeamIndex = -1;
float drawlifetime = 0.1;

stock void DrawHull(const float origin[3], const float angles[3]=NULL_VECTOR, const float mins[3]={-16.0, -16.0, 0.0}, const float maxs[3]={16.0, 16.0, 72.0}, int drawcolor[4] = {255, 0, 0, 255})
{
	if(g_iLaserBeamIndex == -1)
	{
		g_iLaserBeamIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	}

	float corners[8][3];
	
	for (int i = 0; i < 3; i++)
	{
		corners[0][i] = mins[i];
	}
	
	corners[1][0] = maxs[0];
	corners[1][1] = mins[1];
	corners[1][2] = mins[2];
	
	corners[2][0] = maxs[0];
	corners[2][1] = maxs[1];
	corners[2][2] = mins[2];
	
	corners[3][0] = mins[0];
	corners[3][1] = maxs[1];
	corners[3][2] = mins[2];
	
	corners[4][0] = mins[0];
	corners[4][1] = mins[1];
	corners[4][2] = maxs[2];
	
	corners[5][0] = maxs[0];
	corners[5][1] = mins[1];
	corners[5][2] = maxs[2];
	
	for (int i = 0; i < 3; i++)
	{
		corners[6][i] = maxs[i];
	}
	
	corners[7][0] = mins[0];
	corners[7][1] = maxs[1];
	corners[7][2] = maxs[2];

	for(int i = 0; i < sizeof(corners); i++)
	{
		float rad[3];
		rad[0] = DegToRad(angles[2]);
		rad[1] = DegToRad(angles[0]);
		rad[2] = DegToRad(angles[1]);

		float cosAlpha = Cosine(rad[0]);
		float sinAlpha = Sine(rad[0]);
		float cosBeta = Cosine(rad[1]);
		float sinBeta = Sine(rad[1]);
		float cosGamma = Cosine(rad[2]);
		float sinGamma = Sine(rad[2]);

		float x = corners[i][0], y = corners[i][1], z = corners[i][2];
		float newX, newY, newZ;
		newY = cosAlpha*y - sinAlpha*z;
		newZ = cosAlpha*z + sinAlpha*y;
		y = newY;
		z = newZ;

		newX = cosBeta*x + sinBeta*z;
		newZ = cosBeta*z - sinBeta*x;
		x = newX;
		z = newZ;

		newX = cosGamma*x - sinGamma*y;
		newY = cosGamma*y + sinGamma*x;
		x = newX;
		y = newY;
		
		corners[i][0] = x;
		corners[i][1] = y;
		corners[i][2] = z;
	}

	for(int i = 0; i < sizeof(corners); i++)
	{
		AddVectors(origin, corners[i], corners[i]);
	}

	for(int i = 0; i < 4; i++)
	{
		int j = ( i == 3 ? 0 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], g_iLaserBeamIndex, g_iLaserBeamIndex, 0, 120, drawlifetime, 1.0, 1.0, 2, 1.0, drawcolor, 0);
		TE_SendToAll();
	}

	for(int i = 4; i < 8; i++)
	{
		int j = ( i == 7 ? 4 : i+1 );
		TE_SetupBeamPoints(corners[i], corners[j], g_iLaserBeamIndex, g_iLaserBeamIndex, 0, 120, drawlifetime, 1.0, 1.0, 2, 1.0, drawcolor, 0);
		TE_SendToAll();
	}

	for(int i = 0; i < 4; i++)
	{
		TE_SetupBeamPoints(corners[i], corners[i+4], g_iLaserBeamIndex, g_iLaserBeamIndex, 0, 120, drawlifetime, 1.0, 1.0, 2, 1.0, drawcolor, 0);
		TE_SendToAll();
	}
}