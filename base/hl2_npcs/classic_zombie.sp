enum ClassicZombieState
{
	ClassicZombie_Spawning,
	ClassicZombie_Dying,
	ClassicZombie_Default,
};

ConVar classiczombie_health = null;

void classiczombie_init()
{
	CustomEntityFactory factory = register_nextbot_factory("npc_classiczombie");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);

	classiczombie_health = CreateConVar("classiczombie_health", "100");

	CustomPopulationSpawner spawner = register_popspawner("ClassicZombie");
	spawner.Parse = ClassicZombiePopParse;
	spawner.Spawn = ClassicZombiePopSpawn;
	spawner.GetClass = base_npc_pop_getclass;
	spawner.GetClassIcon = base_npc_pop_getclassicon;
	spawner.GetHealth = base_npc_pop_get_health;
	spawner.IsMiniBoss = base_npc_pop_isminiboss;
	spawner.HasAttribute = base_npc_pop_hasattribute;
}

bool ClassicZombiePopParse(CustomPopulationSpawner spawner, KeyValues data)
{
	base_npc_pop_parse(spawner, data, classiczombie_health.IntValue, true);
	return true;
}

bool ClassicZombiePopSpawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	int entity = create_base_npc("npc_classiczombie", TFTeam_Blue);

	base_npc_pop_spawn(spawner, entity);

	TeleportEntity(entity, pos);

	if(result != null) {
		result.Push(entity);
	}

	return true;
}

void classiczombie_precache(int entity, BaseAnimating anim)
{
	PrecacheModel("models/zombie/classic.mdl");

	SetEntityModel(entity, "models/zombie/classic.mdl");
}

void ClassicZombieRemoveAll()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_classiczombie")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
}

void OnClassicZombieSpawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);

	SetEntityModel(entity, "models/zombie/classic.mdl");

	base_npc_set_hull(entity, 150.0, 250.0);

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", classiczombie_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", classiczombie_health.IntValue);
	}

	SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Spawning);
}

void OnClassicZombieThink(int entity)
{
	base_npc_think(entity);

	ClassicZombieState state = GetEntProp(entity, Prop_Data, "m_nState");

	if(GetEntProp(entity, Prop_Data, "m_lifeState") == LIFE_DYING) {
		state = ClassicZombie_Dying;
	}

	INextBot bot = INextBot(entity);
	BaseAnimating anim = BaseAnimating(entity);

	anim.StudioFrameAdvance();

	switch(state) {
		case ClassicZombie_Dying: {
			RequestFrame(FrameRemoveEntity, entity);
		}
		case ClassicZombie_Spawning: {
			SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Default);
		}
		case ClassicZombie_Default: {
			NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

			PathFollower path = GetEntProp(entity, Prop_Data, "m_pPathFollower");

			if(GetEntPropFloat(entity, Prop_Data, "m_flRepathTime") <= GetGameTime()) {
				int target = -1;

				IVision vision = bot.VisionInterface;
				CKnownEntity threat = vision.GetPrimaryKnownThreat(false);
				if(threat != CKnownEntity_Null) {
					target = threat.Entity;
				} else {
					target = FindFurthestEscortTarget();
				}

				if(target != -1) {
					path.ComputeEntity(bot, target, baseline_path_cost, cost_flags_mod);
					SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
				} else {
					float pos[3];
					if(FindBombSite(pos)) {
						path.ComputeVector(bot, pos, baseline_path_cost, cost_flags_mod);
						SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
					}
				}
			}

			int sequence = anim.SelectWeightedSequence(ACT_WALK);
			float speed = locomotion.GroundSpeed;
			if(speed > 1.0) {
				sequence = anim.SelectWeightedSequence(ACT_WALK);
			}

			PrintToServer("%i, %i", ACT_WALK, sequence);
			anim.ResetSequence(sequence);

			float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");

			locomotion.RunSpeed = m_flGroundSpeed;
			locomotion.WalkSpeed = m_flGroundSpeed;

			path.Update(bot);
		}
	}
}