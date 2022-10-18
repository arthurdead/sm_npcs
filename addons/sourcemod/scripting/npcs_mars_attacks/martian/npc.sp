#include "behavior.sp"

static ConVar npc_health_cvar;

static int npc_move_x = -1;
static int npc_move_y = -1;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_hWeaponModel", custom_prop_ehandle);
}

void mars_attacks_martian_init()
{
	npc_health_cvar = CreateConVar("sk_mars_attack_martian_health", "1000");

	create_npc_factories("npc_mars_attacks_martian", "MarsAttacksMartian", npc_datamap_init);

	CustomPopulationSpawnerEntry spawner = register_popspawner("MarsAttacksMartian");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "mars_attacks_martian");
	return true;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Soldier;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health_cvar.IntValue);
}

static bool npc_pop_spawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	return npc_pop_spawn_single("npc_mars_attacks_martian", spawner, pos, result);
}

void mars_attacks_martian_precache(int entity)
{
	PrecacheModel("models/mars_attacks/martian/martian.mdl");

	//AddModelToDownloadsTable("models/mars_attacks/martian/martian.mdl");

	PrecacheModel("models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl");

	SetEntityModel(entity, "models/mars_attacks/martian/martian.mdl");

	npc_move_x = AnimatingLookupPoseParameter(entity, "move_x");
	npc_move_y = AnimatingLookupPoseParameter(entity, "move_y");
}

void mars_attacks_martian_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, npc_spawn);
}

static Action npc_think(int entity)
{
	INextBot bot = INextBot(entity);
	ILocomotion locomotion = bot.LocomotionInterface;
	IBody body = bot.BodyInterface;

	npc_hull_debug(bot, body, locomotion, entity);

	npc_resolve_collisions(bot, entity);

	handle_playbackrate(entity, locomotion, body);

	handle_move_xy(entity, npc_move_x, npc_move_y, locomotion);

	float ground_speed = locomotion.GroundSpeed;
	if(ground_speed > 0.1) {
		if(locomotion.Running) {
			body.StartActivity(ACT_RUN, NO_ACTIVITY_FLAGS);
		} else {
			body.StartActivity(ACT_WALK_AIM_RIFLE_STIMULATED, NO_ACTIVITY_FLAGS);
		}
	} else {
		body.StartActivity(ACT_IDLE_AIM_RIFLE_STIMULATED, NO_ACTIVITY_FLAGS);
	}

	return Plugin_Continue;
}

static Activity npc_translate_act(IBodyCustom body, Activity act)
{
	switch(act) {
		case ACT_JUMP: {
			return ACT_INVALID;
		}

		case ACT_IDLE_AGITATED: {
			switch(GetURandomInt() % 3) {
				case 0: return ACT_IDLE_AIM_RIFLE_STIMULATED;
				case 1: return ACT_IDLE_AGITATED;
			}
		}
		case ACT_IDLE_STIMULATED: {
			switch(GetURandomInt() % 4) {
				case 0: return ACT_IDLE_AIM_RIFLE_STIMULATED;
				case 1: return ACT_IDLE_STIMULATED;
				case 2: return ACT_IDLE_STIMULATED;
			}
		}
		case ACT_IDLE_RELAXED: {
			return ACT_IDLE_RELAXED;
		}

		case ACT_RUN_AGITATED: {
			return ACT_RUN;
		}
		case ACT_RUN_STIMULATED: {
			return ACT_RUN;
		}
		case ACT_RUN_RELAXED: {
			return ACT_RUN;
		}

		case ACT_WALK_AGITATED: {
			return ACT_WALK_AIM_RIFLE_STIMULATED;
		}
		case ACT_WALK_STIMULATED: {
			return ACT_WALK_AIM_RIFLE_STIMULATED;
		}
		case ACT_WALK_RELAXED: {
			return ACT_WALK_AIM_RIFLE_STIMULATED;
		}
	}

	return act;
}

static Action npc_takedmg(int entity, CTakeDamageInfo info, int &result)
{
	float dir[3];
	TE_SetupBloodSprite2(info.m_vecDamagePosition, dir, BLOOD_COLOR_GREEN, 5);
	TE_SendToAll();

	return Plugin_Continue;
}

enum
{
	martian_body_default,
	martian_body_red,
	martian_body_red2,
	martian_body_blue,
	martian_body_blue2,
	martian_body_skeleton,
	martian_body_num,
};

enum
{
	martian_head_default,
	martian_head_goo,
	martian_head_num,
};

enum
{
	martian_helmet_default,
	martian_helmet_shattered,
	martian_helmet_exploded,
	martian_helmet_splattered,
	martian_helmet_num,
}

static int calc_martian_skin(int body, int head, int helmet)
{
	int skin = 0;

	switch(body) {
		case martian_body_default: {
			skin += 0;
		}
		case martian_body_red: {
			skin += 1;
		}
		case martian_body_red2: {
			skin += 2;
		}
		case martian_body_blue: {
			skin += 3;
		}
		case martian_body_blue2: {
			skin += 4;
		}
		case martian_body_skeleton: {
			skin += 5;
		}
	}

	switch(head) {
		case martian_head_default: {
			skin += (0 * (martian_body_num * martian_helmet_num));
		}
		case martian_head_goo: {
			skin += (1 * (martian_body_num * martian_helmet_num));
		}
	}

	switch(helmet) {
		case martian_helmet_default: {
			skin += (martian_body_num * 0);
		}
		case martian_helmet_shattered: {
			skin += (martian_body_num * 1);
		}
		case martian_helmet_exploded: {
			skin += (martian_body_num * 2);
		}
		case martian_helmet_splattered: {
			skin += (martian_body_num * 3);
		}
	}

	PrintToServer("%i", skin);

	return skin;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/mars_attacks/martian/martian.mdl");
	SetEntityModelScale(entity, 1.0);
	SetEntProp(entity, Prop_Data, "m_bloodColor", DONT_BLEED);
	SetEntPropString(entity, Prop_Data, "m_iName", "Martian");

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, 100.0, 250.0);
	HookEntityThink(entity, npc_think);

	bool mvm = IsMannVsMachineMode();

	int body = martian_body_default;

	int team = GetEntProp(entity, Prop_Send, "m_iTeamNum");
	switch(team) {
		case TF_TEAM_RED: {
			body = martian_body_red2;
		}
		case TF_TEAM_BLUE: {
			if(mvm) {
				body = martian_body_default;
			} else {
				body = martian_body_blue2;
			}
		}
		case TF_TEAM_PVE_INVADERS_GIANTS: {
			body = martian_body_default;
		}
		case TEAM_UNASSIGNED: {
			body = martian_body_default;
		}
		case TF_TEAM_HALLOWEEN: {
			body = martian_body_default;
		}
	}

	int skin = calc_martian_skin(body, martian_head_default, martian_helmet_default);
	SetEntProp(entity, Prop_Send, "m_nSkin", skin);

	bot.AllocateCustomIntention(mars_attacks_martian_behavior, "MarsAttacksMartianBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.set_function("TranslateActivity", npc_translate_act);

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);

	int weapon = create_attach_model(entity, "models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl", "weapon_bone");
	SetEntityModelScale(weapon, 0.7);
	SetEntPropVector(weapon, Prop_Send, "m_angRotation", view_as<float>({90.0, -90.0, 0.0}));
	SetEntPropVector(weapon, Prop_Send, "m_vecOrigin", view_as<float>({1.0, 2.0, -10.0}));
	SetEntProp(weapon, Prop_Send, "m_nSkin", 0);
	SetEntPropEnt(entity, Prop_Data, "m_hWeaponModel", weapon);
}

void mars_attacks_martian_destroyed(int entity)
{
	int weapon = GetEntPropEnt(entity, Prop_Data, "m_hWeaponModel");
	if(weapon != -1) {
		RemoveEntity(weapon);
	}
}