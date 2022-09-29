static char idle_sounds[][] = {
	"NPC_BaseZombie.Moan1",
	"NPC_BaseZombie.Moan2",
	"NPC_BaseZombie.Moan3",
	"NPC_BaseZombie.Moan4",
};

static void handle_idle(int entity)
{
	if(GetEntPropFloat(entity, Prop_Data, "m_flNextMoanSound") < GetGameTime()) {
		EmitGameSoundToAll(idle_sounds[GetURandomInt() % sizeof(idle_sounds)], entity);
		SetEntPropFloat(entity, Prop_Data, "m_flNextMoanSound", GetGameTime() + GetRandomFloat(10.0, 20.0));
	}
}

static void handle_die(int entity)
{
	EmitGameSoundToAll("Zombie.Die", entity);
}

static void handle_swing(int entity)
{
	EmitGameSoundToAll("Zombie.Attack", entity);
}

BehaviorAction hl2_zombie_behavior(int entity)
{
	CustomBehaviorAction action = basic_melee_action.create();
	action.set_function("handle_idle", handle_idle);
	//action.set_function("handle_die", handle_die);
	action.set_function("handle_swing", handle_swing);
	return action;
}