#include "behavior.sp"

static ConVar npc_health_cvar;

static int npc_walk_anim = -1;

static void npc_datamap_init(CustomDatamap datamap)
{
	datamap.add_prop("m_flCloakFactor", custom_prop_float);
}

void tfi_alien_commando_init()
{
	npc_health_cvar = CreateConVar("sk_psychonauts_gmen_health", "125");

	create_npc_factories("npc_psychonauts_gmen", "PsychonautsGmen", npc_datamap_init);

	CustomPopulationSpawnerEntry spawner = register_popspawner("PsychonautsGmen");
	spawner.Parse = base_npc_pop_parse;
	spawner.Spawn = npc_pop_spawn;
	spawner.GetClass = npc_pop_class;
	spawner.HasAttribute = base_npc_pop_attrs;
	spawner.GetHealth = npc_pop_health;
	spawner.GetClassIcon = npc_pop_classicon;
}

static bool npc_pop_classicon(CustomPopulationSpawner spawner, int num, char[] str, int len)
{
	strcopy(str, len, "psychonauts_gmen");
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
	return npc_pop_spawn_single("npc_psychonauts_gmen", spawner, pos, result);
}

void psychonauts_gmen_precache(int entity)
{
	PrecacheModel("models/arthurdead/psychonauts/gmen/gmen.mdl");

	//AddModelToDownloadsTable("models/arthurdead/psychonauts/gmen/gmen.mdl");

	SetEntityModel(entity, "models/arthurdead/psychonauts/gmen/gmen.mdl");

	npc_walk_anim = AnimatingLookupSequence(entity, "Sneaky");
}

void psychonauts_gmen_created(int entity)
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

		float m_flCloakFactor = GetEntPropFloat(entity, Prop_Data, "m_flCloakFactor");

		body_custom.StartSequence(npc_walk_anim, ACT_WALK);

		float m_flNextAttack = GetEntPropFloat(entity, Prop_Send, "m_flNextAttack");

		if(m_flNextAttack > GetGameTime()) {
			if(m_flCloakFactor > 0.0) {
				m_flCloakFactor -= 0.01;
			}
		} else {
			if(m_flCloakFactor < 0.9) {
				m_flCloakFactor += 0.01;
			}
		}

		SetEntPropFloat(entity, Prop_Data, "m_flCloakFactor", m_flCloakFactor);

		char str[10];
		FormatEx(str, sizeof(str), "%f", m_flCloakFactor);

		set_material_var(entity, "models/arthurdead/psychonauts/gmen/gmen", "$cloakfactor", str);
	} else {
		SetEntPropFloat(entity, Prop_Data, "m_flCloakFactor", 0.0);
		set_material_var(entity, "models/arthurdead/psychonauts/gmen/gmen", "$cloakfactor", "0.0");
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

static void npc_spawn(int entity)
{
	SetEntityModel(entity, "models/arthurdead/psychonauts/gmen/gmen.mdl");
	SetEntProp(entity, Prop_Data, "m_bloodColor", DONT_BLEED);
	SetEntPropString(entity, Prop_Data, "m_iName", "GMen");

	SetEntPropFloat(entity, Prop_Data, "m_flCloakFactor", 0.9);

	INextBot bot = INextBot(entity);
	ground_npc_spawn(bot, entity, npc_health_cvar.IntValue, 50.0, 50.0);
	HookEntityThink(entity, npc_think);

	bot.AllocateCustomIntention(psychonauts_gmen_behavior, "PsychonautsGmenBehavior");

	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.HeadAsAngles = false;

	HookEntityOnTakeDamageAlive(entity, npc_takedmg, true);
}

void psychonauts_gmen_destroyed(int entity)
{
	
}