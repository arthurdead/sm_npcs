int tf2_cow_mangler_muzzle = -1;

ConVar sk_tfi_alien_commando_dmg;

#include "behavior.sp"

static int npc_move_y = -1;
static int npc_move_x = -1;

static int npc_body_yaw = -1;
static int npc_body_pitch = -1;

static ConVar npc_health_cvar;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_hWeaponModel", custom_prop_ehandle);
}

void tfi_alien_commando_init()
{
	npc_health_cvar = CreateConVar("sk_tfi_alien_health", "125");
	sk_tfi_alien_commando_dmg = CreateConVar("sk_tfi_alien_commando_dmg", "50");

	create_npc_factories("npc_tfi_alien_commando", "TFIAlienCommando", npc_datamap_init);

	CustomPopulationSpawnerEntry spawner = register_popspawner("TFIAlienCommando");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "tfi_alien_commando");
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
	return npc_pop_spawn_single("npc_tfi_alien_commando", spawner, pos, result);
}

void tfi_alien_commando_precache(int entity)
{
	PrecacheModel("models/arthurdead/tf_invasion_game/alien_commando/alien_commando.mdl");
	PrecacheModel("models/workshop/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl");

	//AddModelToDownloadsTable("models/arthurdead/tf_invasion_game/alien_commando/alien_commando.mdl");

	SetEntityModel(entity, "models/arthurdead/tf_invasion_game/alien_commando/alien_commando.mdl");

	npc_move_x = AnimatingLookupPoseParameter(entity, "move_x");
	npc_move_y = AnimatingLookupPoseParameter(entity, "move_y");

	npc_body_yaw = AnimatingLookupPoseParameter(entity, "body_yaw");
	npc_body_pitch = AnimatingLookupPoseParameter(entity, "body_pitch");

	SetEntityModel(entity, "models/workshop/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl");

	tf2_cow_mangler_muzzle = AnimatingLookupAttachment(entity, "muzzle");
}

void tfi_alien_commando_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, npc_spawn);
}

static Action npc_think(int entity)
{
	INextBot bot = INextBot(entity);
	ILocomotion locomotion = bot.LocomotionInterface;
	IBody body = bot.BodyInterface;
	IBodyCustom body_custom = view_as<IBodyCustom>(body);

	//npc_hull_debug(bot, body, locomotion, entity);

	if(entity_is_alive(entity)) {
		handle_playbackrate(entity, locomotion, body);
		handle_move_xy(entity, npc_move_x, npc_move_y, locomotion);
		handle_aim_xy(entity, npc_body_yaw, npc_body_pitch, body_custom);

		if(!locomotion.OnGround ||
			locomotion.DidJustJump) {
			body.StartActivity(ACT_HOP);
		} else {
			float ground_speed = locomotion.GroundSpeed;
			if(ground_speed > 0.1) {
				body.StartActivity(ACT_RUN);
			} else {
				if(body.IsActualPosture(CROUCH)) {
					body.StartActivity(ACT_CROUCHIDLE);
				} else {
					body.StartActivity(ACT_IDLE);
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

static int skin = 0;

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/arthurdead/tf_invasion_game/alien_commando/alien_commando.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", DONT_BLEED);
	SetEntPropString(entity, Prop_Data, "m_iName", "Alien Commando");

	SetEntProp(entity, Prop_Send, "m_nSkin", GetURandomInt() % 3);
	SetEntProp(entity, Prop_Send, "m_nBody", GetURandomInt() % 2);

	SetEntProp(entity, Prop_Send, "m_nSkin", skin++);
	SetEntProp(entity, Prop_Send, "m_nBody", 0);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, 175.0, 175.0);
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(tfi_alien_commando_behavior, "TFIAlienCommandoBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.HeadAsAngles = false;

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);

	int weapon = create_attach_model(entity, "models/workshop/weapons/c_models/c_drg_cowmangler/c_drg_cowmangler.mdl", "0");
	SetEntPropVector(weapon, Prop_Send, "m_angRotation", view_as<float>({-90.0, -90.0, 0.0}));
	SetEntPropVector(weapon, Prop_Send, "m_vecOrigin", view_as<float>({0.0, 0.0, 20.0}));
	SetEntProp(weapon, Prop_Send, "m_nSkin", 1);
	SetEntPropEnt(entity, Prop_Data, "m_hWeaponModel", weapon);
}

void tfi_alien_commando_destroyed(int entity)
{
	int weapon = GetEntPropEnt(entity, Prop_Data, "m_hWeaponModel");
	if(weapon != -1) {
		RemoveEntity(weapon);
	}
}