enum ClassicZombieState
{
	ClassicZombie_Spawning,
	ClassicZombie_Dying,
	ClassicZombie_Default,
	ClassicZombie_Attacking,
	ClassicZombie_FacingTarget,
};

ConVar classiczombie_health = null;

Activity ACT_ZOM_RELEASECRAB = ACT_INVALID;

void classiczombie_init()
{
	CustomEntityFactory factory = register_nextbot_factory("npc_classiczombie");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);
	datamap.add_prop("m_flRecalcWalkAnim", custom_prop_float);
	datamap.add_prop("m_nWalkAnim", custom_prop_int);

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

	ACT_ZOM_RELEASECRAB = anim.LookupActivity("ACT_ZOM_RELEASECRAB");
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

	base_npc_set_hull(entity, 20.0, 70.0);

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", classiczombie_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", classiczombie_health.IntValue);
	}

	static char spawnanims[][] =
	{
		"slumprise_a",
		"slumprise_a2",
		"slumprise_a_attack",
		"slumprise_b",
	};

	BaseAnimating anim = BaseAnimating(entity);

	int i = GetRandomInt(0, sizeof(spawnanims)-1);
	int sequence = anim.LookupSequence(spawnanims[i]);

	if(ACT_ZOM_RELEASECRAB == ACT_INVALID) {
		ACT_ZOM_RELEASECRAB = anim.LookupActivity("ACT_ZOM_RELEASECRAB");
	}

	anim.ResetSequence(sequence);
	SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Spawning);

	INextBot bot = INextBot(entity);
	NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

	locomotion.DeathDropHeight = 10.0;
	locomotion.MaxJumpHeight = 0.0;
}

void OnClassicZombieThink(int entity)
{
	base_npc_think(entity);

	ClassicZombieState state = GetEntProp(entity, Prop_Data, "m_nState");

	BaseAnimating anim = BaseAnimating(entity);

	if(state != ClassicZombie_Dying) {
		if(GetEntProp(entity, Prop_Data, "m_lifeState") == LIFE_DYING) {
			int sequence = anim.SelectWeightedSequence(ACT_ZOM_RELEASECRAB);
			anim.ResetSequence(sequence);
			SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Dying);
			return;
		}
	}

	INextBot bot = INextBot(entity);

	switch(state) {
		case ClassicZombie_FacingTarget: {
			int target = EntRefToEntIndex(GetEntProp(entity, Prop_Data, "m_hTarget"));
			if(IsValidEntity(target)) {
				float target_pos[3];
				GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);

				NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);
				locomotion.FaceTowards(target_pos);

				IVision vision = bot.VisionInterface;
				if(vision.IsInFieldOfViewEntity(target)) {
					int sequence = anim.SelectWeightedSequence(ACT_MELEE_ATTACK1);
					anim.ResetSequence(sequence);
					SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Attacking);
				}
			} else {
				SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Default);
			}
		}
		case ClassicZombie_Attacking: {
			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Default);
			}
		}
		case ClassicZombie_Dying: {
			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				RequestFrame(FrameRemoveEntity, entity);
			}
		}
		case ClassicZombie_Spawning: {
			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_Default);
			}
		}
		case ClassicZombie_Default: {
			NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

			PathFollower path = GetEntProp(entity, Prop_Data, "m_pPathFollower");

			int target = EntRefToEntIndex(GetEntProp(entity, Prop_Data, "m_hTarget"));
			if(IsValidEntity(target)) {
				float target_pos[3];
				GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);

				float my_pos[3];
				GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", my_pos);

				float distance = GetVectorDistance(my_pos, target_pos);
				if(distance <= 50.0) {
					int sequence = anim.SelectWeightedSequence(ACT_IDLE);
					anim.ResetSequence(sequence);
					SetEntProp(entity, Prop_Data, "m_nState", ClassicZombie_FacingTarget);
					return;
				}
			}

			if(GetEntPropFloat(entity, Prop_Data, "m_flRepathTime") <= GetGameTime()) {
				target = -1;

				IVision vision = bot.VisionInterface;
				CKnownEntity threat = vision.GetPrimaryKnownThreat(false);
				if(threat != CKnownEntity_Null) {
					target = threat.Entity;
				}

				if(target != -1) {
					path.ComputeEntity(bot, target, baseline_path_cost, cost_flags_mod);
					SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
					SetEntProp(entity, Prop_Data, "m_hTarget", EntIndexToEntRef(target));
				} else {
					SetEntProp(entity, Prop_Data, "m_hTarget", -1);
					float pos[3];
					if(FindBombSite(pos)) {
						path.ComputeVector(bot, pos, baseline_path_cost, cost_flags_mod);
						SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
					}
				}
			}

			if(GetEntPropFloat(entity, Prop_Data, "m_flRecalcWalkAnim") <= GetGameTime()) {
				SetEntProp(entity, Prop_Data, "m_nWalkAnim", anim.SelectWeightedSequence(ACT_WALK));
				SetEntPropFloat(entity, Prop_Data, "m_flRecalcWalkAnim", GetGameTime() + GetRandomFloat(1.0, 3.0));
			}

			int sequence = anim.SelectWeightedSequence(ACT_IDLE);
			float speed = locomotion.GroundSpeed;
			if(speed > 1.0) {
				sequence = GetEntProp(entity, Prop_Data, "m_nWalkAnim");
			}

			anim.ResetSequence(sequence);

			float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
			if(m_flGroundSpeed == 0.0) {
				m_flGroundSpeed = 999.0;
			}

			locomotion.RunSpeed = m_flGroundSpeed;
			locomotion.WalkSpeed = m_flGroundSpeed;

			path.Update(bot);
		}
	}

	anim.StudioFrameAdvance();
}