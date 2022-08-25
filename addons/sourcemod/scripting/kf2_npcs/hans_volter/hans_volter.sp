int hans_volter_walk_anim = -1;
int hans_volter_idle_anim = -1;

int hans_volter_walk_akimbo_anim = -1;
int hans_volter_idle_akimbo_anim = -1;

int hans_volter_melee_anim = -1;

#include "behavior.sp"

void hans_volter_init()
{
	CustomDatamap datamap = register_nextbot_factory("npc_hans_volter", "HansVolter");
	datamap.add_prop("m_bAkimbo", custom_prop_bool);
	datamap.add_prop("m_flLastAkimbo", custom_prop_time);
	datamap.add_prop("m_hAkimboGun1", custom_prop_ehandle);
	datamap.add_prop("m_hAkimboGun2", custom_prop_ehandle);

	hans_volter_behavior_init();
}

void hans_volter_precache(int entity, BaseAnimating anim)
{
	PrecacheModel("models/linux55/kf2/zeds/hans_volter.mdl");
	PrecacheModel("models/weapons/w_smg1.mdl");

	SetEntityModel(entity, "models/linux55/kf2/zeds/hans_volter.mdl");

	hans_volter_walk_anim = anim.LookupSequence("walk");
	hans_volter_idle_anim = anim.LookupSequence("idle2");

	hans_volter_walk_akimbo_anim = anim.LookupSequence("walk2");
	hans_volter_idle_akimbo_anim = anim.LookupSequence("idle");

	hans_volter_melee_anim = anim.LookupSequence("attack1");
}

void hans_volter_destroyed(int entity)
{
	int gun1 = GetEntPropEnt(entity, Prop_Data, "m_hAkimboGun1");
	if(gun1 != -1) {
		RemoveEntity(gun1);
	}

	int gun2 = GetEntPropEnt(entity, Prop_Data, "m_hAkimboGun2");
	if(gun2 != -1) {
		RemoveEntity(gun2);
	}
}

void hans_volter_created(int entity)
{
	SDKHook(entity, SDKHook_SpawnPost, hans_volter_spawn);
	SDKHook(entity, SDKHook_ThinkPost, hans_volter_think);
}

static void hans_volter_spawn(int entity)
{
	SetEntityModel(entity, "models/linux55/kf2/zeds/hans_volter.mdl");

	int health = 1;
	switch(get_player_count()) {
		case 0,1: health = 8013;
		case 2: health = 14022;
		case 3: health = 20032;
		case 4: health = 26042;
		case 5: health = 32052;
		case 6: health = 38061;
		default: health = 38061;
	}

	INextBot bot = INextBot(entity);

	health = 100;

	shared_npc_spawn(bot, entity, health, view_as<float>({22.0, 23.0, 170.0}), 100.0, 260.0);

	bot.AllocateCustomIntention(hans_volter_behavior, "HansVolterBehavior");
}

static void hans_volter_think(int entity)
{
	INextBot bot = INextBot(entity);

	shared_npc_think(bot, entity);

	BaseAnimating anim = BaseAnimating(entity);
	anim.StudioFrameAdvance();

	monster_resource.LinkHealth(entity);

	//SetEntPropFloat(entity, Prop_Send, "m_lastHealthPercentage", 0.5);
}