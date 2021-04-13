static const char tyrantstep[2][PLATFORM_MAX_PATH] =
{
	"roach/reuc_redc/tyrant_step1.mp3",
	"roach/reuc_redc/tyrant_step2.mp3",
};

static const char tyrantswing[2][PLATFORM_MAX_PATH] =
{
	"roach/reuc_redc/tyrant_swing1.mp3",
	"roach/reuc_redc/tyrant_swing2.mp3",
};

BehaviorActionEntry tyrant_kickdoor = null;
BehaviorActionEntry tyrant_chase = null;

#include "tyrant_behaviors/shared.sp"
#include "tyrant_behaviors/attack.sp"
#include "tyrant_behaviors/chase.sp"
#include "tyrant_behaviors/kickdoor.sp"
#include "tyrant_behaviors/wander.sp"
#include "tyrant_behaviors/exec.sp"

ConVar tyrant_health = null;

void tyrant_init()
{
	CustomSendtable table = null;
	CustomEntityFactory factory = register_infected_nextbot_factory("npc_re_tyrant", table, ZombieClass_Tank);
	table.set_name("DT_ReTyrant");
	table.set_network_name("CReTyrant");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	datamap.set_name("CReTyrant");
	datamap.add_prop("m_flLastStep", custom_prop_time);
	
	tyrant_health = CreateConVar("re_tyrant_health", "100000");

	tyrant_exec_init();
	tyrant_attack_init();
	tyrant_chase_init();
	tyrant_wander_init();
	tyrant_kickdoor_init();
}

#if defined GAME_L4D2
public void re_tyrant_precache(moreinfected_data data)
{
	PrecacheModel("models/roach/redc/ety1.mdl");

	for(int i = 0; i < sizeof(tyrantstep); ++i) {
		PrecacheSound(tyrantstep[i]);
	}

	for(int i = 0; i < sizeof(tyrantswing); ++i) {
		PrecacheSound(tyrantswing[i]);
	}
}

public int re_tyrant_spawn_special(int entity, Address area, float pos[3], float ang[3], ZombieClassType type, moreinfected_data data)
{
	RemoveEntity(entity);

	entity = create_base_npc("npc_re_tyrant", 3);

	TeleportEntity(entity, pos);

	return entity;
}
#endif

BehaviorAction tyrant_behavior(int entity)
{
	BehaviorAction action = tyrant_exec.create();
	//BehaviorAction action = tyrant_kickdoor.create();
	//action.set_data("entity", EntIndexToEntRef(357));
	return action;
}

void tyrant_spawn(int entity)
{
	INextBot bot = INextBot(entity);

	IIntentionCustom inte = bot.AllocateCustomIntention(tyrant_behavior, "TyrantBehavior");
	base_npc_spawn(entity, inte);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);
	SetEntityModel(entity, "models/roach/redc/ety1.mdl");
	SetEntProp(entity, Prop_Send, "m_Gender", 1);
	base_npc_set_hull(entity, 25.0, 100.0);

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", tyrant_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", tyrant_health.IntValue);
	}

	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);
	locomotion.StepHeight = 26.0;
	locomotion.MaxJumpHeight = 26.0;
}