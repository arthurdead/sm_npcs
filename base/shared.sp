#define EF_BONEMERGE 0x001
#define EF_BONEMERGE_FASTCULL 0x080
#define EF_PARENT_ANIMATES 0x200
#define EF_NODRAW 0x020
#define EF_NOSHADOW 0x010
#define EF_NORECEIVESHADOW 0x040

#define COLLISION_GROUP_NPC 9
#define LIFE_ALIVE 0
#define LIFE_DYING 1

#define FSOLID_NOT_STANDABLE 0x0010

#define USE_ROTATION_EXPANDED_BOUNDS 5
#define SOLID_VPHYSICS 6
#define SOLID_BBOX 2
#define SOLID_CUSTOM 5

#define BLOOD_COLOR_RED 0
#define BLOOD_COLOR_YELLOW 1
#define BLOOD_COLOR_GREEN 2
#define BLOOD_COLOR_MECH 3
#define	DAMAGE_YES 2

#define EFL_DIRTY_SURROUNDING_COLLISION_BOUNDS (1 << 14)
#define EFL_DIRTY_SPATIAL_PARTITION (1 << 15)
#define EFL_DONTWALKON (1 << 26)

ConVar tf_bot_path_lookahead_range = null;
ConVar base_npc_draw_hull = null;

void base_npc_init()
{
	tf_bot_path_lookahead_range = FindConVar("tf_bot_path_lookahead_range");
	base_npc_draw_hull = CreateConVar("base_npc_draw_hull", "1");
}

void base_npc_init_datamaps(CustomDatamap datamap)
{
	datamap.add_prop("m_pPathFollower", custom_prop_int);
	datamap.add_prop("m_flRepathTime", custom_prop_float);
	datamap.add_prop("m_nState", custom_prop_int);
	datamap.add_prop("m_hTarget", custom_prop_int);
}

void base_npc_spawn(int entity)
{
	SetEntProp(entity, Prop_Data, "m_lifeState", LIFE_ALIVE);
	SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_YES);

	INextBot bot = INextBot(entity);
	bot.AllocateCustomBody();
	bot.AllocateCustomLocomotion();

	SetEntProp(entity, Prop_Send, "m_nSolidType", SOLID_BBOX);

	int flags = GetEdictFlags(entity);
	flags |= FL_EDICT_DIRTY_PVS_INFORMATION;
	SetEdictFlags(entity, flags);

	SetEntityMoveType(entity, MOVETYPE_CUSTOM);

	//setting any of these while the entity is in the MVM spawn zone makes it disapper very weird
	/*
	SetEntProp(entity, Prop_Send, "m_nSurroundType", USE_ROTATION_EXPANDED_BOUNDS);

	flags = GetEntProp(entity, Prop_Data, "m_iEFlags");
	flags |= EFL_DIRTY_SURROUNDING_COLLISION_BOUNDS|EFL_DIRTY_SPATIAL_PARTITION;
	SetEntProp(entity, Prop_Data, "m_iEFlags", flags);

	flags = GetEntProp(entity, Prop_Send, "m_usSolidFlags");
	flags |= FSOLID_NOT_STANDABLE;
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", flags);
	*/

	PathFollower path = new PathFollower();
	path.MinLookAheadDistance = tf_bot_path_lookahead_range.FloatValue * GetEntPropFloat(entity, Prop_Send, "m_flModelScale");
	SetEntProp(entity, Prop_Data, "m_pPathFollower", path);
}

void base_npc_deleted(int entity)
{
	PathFollower path = GetEntProp(entity, Prop_Data, "m_pPathFollower");
	if(path != null) {
		delete path;
	}
	SetEntProp(entity, Prop_Data, "m_pPathFollower", 0);
}

int create_base_npc(const char[] classname, TFTeam team = TFTeam_Unassigned)
{
	int entity = CreateEntityByName(classname);
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", team);
	ActivateEntity(entity);
	return entity;
}

void base_npc_set_hull(int entity, float width, float height)
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

	body.SetHullMins(hullMins);
	body.SetHullMaxs(hullMaxs);
	body.HullWidth = HullWidth;
	body.HullHeight = HullHeight;

	SetEntPropVector(entity, Prop_Send, "m_vecMins", hullMins);
	SetEntPropVector(entity, Prop_Send, "m_vecMaxs", hullMaxs);
}

void base_npc_think(int entity)
{
	

	if(base_npc_draw_hull.BoolValue) {
		float pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);

		float ang[3];
		GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);

		INextBot bot = INextBot(entity);
		IBody body = bot.BodyInterface;

		float HullWidth = body.HullWidth;
		float HullHeight = body.HullHeight;

		float hullMins[3];
		hullMins[0] = -HullWidth;
		hullMins[1] = hullMins[0];
		hullMins[2] = 0.0;

		float hullMaxs[3];
		hullMaxs[0] = HullWidth;
		hullMaxs[1] = hullMaxs[0];
		hullMaxs[2] = HullHeight;

		DrawHull(pos, ang, hullMins, hullMaxs);
	}
}

void TypeToClassname(TFClassType type, char[] str, int len)
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

void base_npc_pop_parse(CustomPopulationSpawner spawner, KeyValues data, int defhealth, bool defminiboss = false)
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

bool base_npc_pop_isminiboss(CustomPopulationSpawner spawner, int num)
{
	return spawner.get_data("MiniBoss");
}

bool base_npc_pop_getclassicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	TFClassType class = spawner.get_data("Class");
	if(class == TFClass_Unknown) {
		strcopy(str, len, "Tank");
	} else {
		TypeToClassname(class, str, len);
	}
	return true;
}

int base_npc_pop_getclass(CustomPopulationSpawner spawner, int num)
{
	return spawner.get_data("Class");
}

bool base_npc_pop_hasattribute(CustomPopulationSpawner spawner, AttributeType attr, int num)
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

void base_npc_pop_spawn(CustomPopulationSpawner spawner, int entity)
{
	int health = spawner.get_data("Health");
	float scale = spawner.get_data("Scale");

	SetEntProp(entity, Prop_Data, "m_iHealth", health);
	SetEntProp(entity, Prop_Data, "m_iMaxHealth", health);
	SetEntPropFloat(entity, Prop_Send, "m_flModelScale", scale);
}

int base_npc_pop_get_health(CustomPopulationSpawner spawner, int num)
{
	return spawner.get_data("Health");
}

TFTeam GetEntityTFTeam(int entity)
{
	return view_as<TFTeam>(GetEntProp(entity, Prop_Data, "m_iTeamNum"));
}

TFTeam GetClientTFTeam(int client)
{
	return view_as<TFTeam>(GetClientTeam(client));
}

void FrameRemoveEntity(int entity)
{
	RemoveEntity(entity);
}

bool FindBombSite(float pos[3])
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "func_capturezone")) != -1) {
		GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", pos);
		return true;
	}
	return false;
}

int FindFurthestTank()
{
	return -1;
}

int FindFurthestBulltank()
{
	return -1;
}

int FindFurthestBombPlayer()
{
	for(int i = 1; i <= MaxClients; ++i) {
		if(IsClientInGame(i)) {
			if(GetClientTFTeam(i) == TFTeam_Blue) {
				
			}
		}
	}

	return -1;
}

int FindFurthestEscortTarget()
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

int g_iLaserBeamIndex = -1;
float drawlifetime = 0.1;
int drawcolor[4] = {255, 0, 0, 255};

void DrawHull(const float origin[3], const float angles[3]=NULL_VECTOR, const float mins[3]={-16.0, -16.0, 0.0}, const float maxs[3]={16.0, 16.0, 72.0})
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