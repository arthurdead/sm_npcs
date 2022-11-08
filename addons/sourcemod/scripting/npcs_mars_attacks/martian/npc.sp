int tf2_shooting_star_muzzle = -1;

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
	npc_health_cvar = CreateConVar("sk_mars_attacks_martian_health", "1000");

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
	PrecacheModel("models/arthurdead/mars_attacks/martian/martian.mdl");
	PrecacheModel("models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl");

	PrecacheScriptSound("Weapon_ShootingStar.SingleCharged");

	//AddModelToDownloadsTable("models/arthurdead/mars_attacks/martian/martian.mdl");

	SetEntityModel(entity, "models/workshop/weapons/c_models/c_invasion_sniperrifle/c_invasion_sniperrifle.mdl");

	tf2_shooting_star_muzzle = AnimatingLookupAttachment(entity, "muzzle");

	SetEntityModel(entity, "models/arthurdead/mars_attacks/martian/martian.mdl");

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

	//npc_hull_debug(bot, body, locomotion, entity);

	if(entity_is_alive(entity)) {
		handle_playbackrate(entity, locomotion, body);
		handle_move_xy(entity, npc_move_x, npc_move_y, locomotion);

		if(!locomotion.OnGround ||
			locomotion.DidJustJump) {
			body.StartActivity(ACT_JUMP);
		} else {
			float ground_speed = locomotion.GroundSpeed;
			if(ground_speed > 0.01) {
				if(locomotion.Running) {
					body.StartActivity(ACT_RUN);
				} else {
					body.StartActivity(ACT_WALK);
				}
			} else {
				if(body.IsActualPosture(CROUCH)) {
					body.StartActivity(ACT_CROUCHIDLE);
				} else {
					body.StartActivity(ACT_IDLE_AIM_RIFLE_STIMULATED);
				}
			}
		}
	}

	return Plugin_Continue;
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

static void martian_get_skins(int entity, int &body = 0, int &head = 0, int &helmet = 0)
{
	int skin = GetEntProp(entity, Prop_Send, "m_nSkin");

	int goo_head_start = (martian_body_num * martian_helmet_num);
	if(skin >= goo_head_start) {
		skin -= goo_head_start;
		head = martian_head_goo;
	} else {
		head = martian_head_default;
	}

	for(int i = 0; i < martian_helmet_num; ++i) {
		int helmet_end = ((i+1) * martian_body_num);
		if(skin <= helmet_end) {
			skin -= helmet_end;
			helmet = i;
			break;
		}
	}

	body = -skin;
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

	return skin;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/arthurdead/mars_attacks/martian/martian.mdl");
	SetEntityModelScale(entity, 1.0);
	SetEntProp(entity, Prop_Data, "m_bloodColor", DONT_BLEED);
	SetEntPropString(entity, Prop_Data, "m_iName", "Martian");

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, 100.0, 200.0);
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