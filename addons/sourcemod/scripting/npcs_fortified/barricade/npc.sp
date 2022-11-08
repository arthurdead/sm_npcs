#include "behavior.sp"

static ConVar npc_health_cvar;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_hShieldEntity", custom_prop_ehandle);
}

void fortified_barricade_init()
{
	npc_health_cvar = CreateConVar("sk_fortified_drone_health", "1000");

	create_npc_factories("npc_fortified_barricade", "FortifiedBarricade", npc_datamap_init);

	CustomPopulationSpawnerEntry spawner = register_popspawner("FortifiedBarricade");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "fortified_barricade");
	return true;
}

static TFClassType npc_pop_class(CustomPopulationSpawner spawner, int num)
{
	return TFClass_Scout;
}

static int npc_pop_health(CustomPopulationSpawner spawner, int num)
{
	return base_npc_pop_health(spawner, num, npc_health_cvar.IntValue);
}

static bool npc_pop_spawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	return npc_pop_spawn_single("npc_fortified_barricade", spawner, pos, result);
}

void fortified_barricade_precache(int entity)
{
	PrecacheModel("models/arthurdead/fortified/mob/barricade/barricade.mdl");
	PrecacheModel("models/props_mvm/mvm_player_shield.mdl");

	//AddModelToDownloadsTable("models/arthurdead/fortified/mob/barricade/barricade.mdl");
}

void fortified_barricade_created(int entity)
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

	int shield = GetEntPropEnt(entity, Prop_Data, "m_hShieldEntity");

	if(entity_is_alive(entity)) {
		handle_playbackrate(entity, locomotion, body);

		body_custom.HeadAsAngles = (shield != -1);
		body_custom.ViewAsHead = (shield != -1);

		if(shield != -1) {
			body_custom.StartActivity(ACT_SHIELD_UP_IDLE);
		} else {
			if(!locomotion.OnGround ||
				locomotion.DidJustJump) {
				body.StartActivity(ACT_IDLE);
			} else {
				float ground_speed = locomotion.GroundSpeed;
				if(ground_speed > 0.1) {
					body.StartActivity(ACT_WALK);
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
	TE_SetupBloodSprite2(info.m_vecDamagePosition, dir, BLOOD_COLOR_MECH, 5);
	TE_SendToAll();

	return Plugin_Continue;
}

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/arthurdead/fortified/mob/barricade/barricade.mdl");
	SetEntityModelScale(entity, 1.0);
	SetEntProp(entity, Prop_Data, "m_bloodColor", DONT_BLEED);
	SetEntPropString(entity, Prop_Data, "m_iName", "Barricade");

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, 150.0, 150.0);
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(fortified_barricade_behavior, "FortifiedBarricadeBehavior");

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);

	return;

	int shield = create_attach_entity(entity, "entity_medigun_shield", NULL_STRING);
	SetEntityNextThink(shield, TIME_NEVER_THINK, "CTFMedigunShield_ShieldThink");
	SetEntPropVector(shield, Prop_Send, "m_angRotation", view_as<float>({0.0, 0.0, 0.0}));
	SetEntPropVector(shield, Prop_Send, "m_vecOrigin", view_as<float>({145.0, 0.0, 0.0}));
	SetEntProp(shield, Prop_Send, "m_nSkin", 1);
	SetEntPropEnt(entity, Prop_Data, "m_hShieldEntity", shield);
}

void fortified_barricade_destroyed(int entity)
{
	int shield = GetEntPropEnt(entity, Prop_Data, "m_hShieldEntity");
	if(shield != -1) {
		RemoveEntity(shield);
	}
}