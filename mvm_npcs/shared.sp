void FrameRemoveEntity(int entity)
{
	RemoveEntity(entity);
}

bool FindBombSite(float pos[3])
{
	pos[0] = -943.550476;
	pos[1] = 1629.567871;
	pos[2] = -105.126297;
	return true;
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
			if(GetClientTeam(i) == 3) {
				return i;
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

Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	INextBot bot = INextBot(victim);
	IVision vision = bot.VisionInterface;
	vision.AddKnownEntity(attacker);

	return Plugin_Continue;
}

void mvm_npcs_precache()
{
	int entity = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(entity, "model", "models/error.mdl");
	DispatchSpawn(entity);

	BaseAnimating anim = BaseAnimating(entity);

	bulltank_precache(entity, anim);
	deadnaut_precache(entity, anim);

	RemoveEntity(entity);
}

void mvm_npcs_init()
{
	base_npc_init();
	bulltank_init();
	deadnaut_init();
}