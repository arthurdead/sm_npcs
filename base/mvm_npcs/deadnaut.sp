#define DEADNAUT_CLASS_MODELS_DONT_BONEMERGE

#if defined DEADNAUT_CLASS_MODELS_DONT_BONEMERGE
	#define DEADNAUT_ANIM_MODEL "models/deadnaut/deadnaut_heavy_anim.mdl"
#else
	#define DEADNAUT_ANIM_MODEL "models/deadnaut/animation/deadnaut_animation.mdl"
#endif

enum DeadnautState
{
	Deadnaut_Spawning,
	Deadnaut_Dying,
	Deadnaut_Default,
	Deadnaut_Falling,
	Deadnaut_Landing,
};

int deadnaut_anim_Stance = -1;
int deadnaut_anim_Walk = -1;
int deadnaut_anim_Run = -1;
int deadnaut_anim_Run2 = -1;
int deadnaut_anim_Run_urgent = -1;
int deadnaut_anim_StandUp = -1;
int deadnaut_anim_Flinch = -1;
int deadnaut_anim_Brace = -1;
int deadnaut_anim_FistSlam = -1;
int deadnaut_anim_Kick = -1;
int deadnaut_anim_Smash = -1;
int deadnaut_anim_Land = -1;

ConVar deadnaut_health = null;

void deadnaut_init()
{
	CustomEntityFactory factory = register_nextbot_factory("npc_deadnaut");
	CustomSendtable sendtable = sendtable_from_nextbot_factory(factory);
	sendtable.override_with("CTFBaseBoss");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);
#if !defined DEADNAUT_CLASS_MODELS_DONT_BONEMERGE
	datamap.add_prop("m_hBody", custom_prop_int);
#endif
	datamap.add_prop("m_iClass", custom_prop_int);

	deadnaut_health = CreateConVar("deadnaut_health", "100");

	CustomPopulationSpawner spawner = register_popspawner("Deadnaut");
	spawner.Parse = DeadnautPopParse;
	spawner.Spawn = DeadnautPopSpawn;
	spawner.GetClass = base_npc_pop_getclass;
	spawner.GetClassIcon = base_npc_pop_getclassicon;
	spawner.GetHealth = base_npc_pop_get_health;
	spawner.IsMiniBoss = base_npc_pop_isminiboss;
	spawner.HasAttribute = base_npc_pop_hasattribute;
}

void deadnaut_precache(int entity, BaseAnimating anim)
{
#if !defined DEADNAUT_CLASS_MODELS_DONT_BONEMERGE
	PrecacheModel("models/deadnaut/deadnaut_demoman.mdl");
	PrecacheModel("models/deadnaut/deadnaut_engineer.mdl");
	PrecacheModel("models/deadnaut/deadnaut_heavy.mdl");
	PrecacheModel("models/deadnaut/deadnaut_pyro.mdl");
	PrecacheModel("models/deadnaut/deadnaut_sniper.mdl");
	PrecacheModel("models/deadnaut/deadnaut_soldier.mdl");
	PrecacheModel("models/deadnaut/deadnaut_spy.mdl");
#endif

	PrecacheModel("models/deadnaut/deadnaut_heavy_anim.mdl");
	PrecacheModel("models/deadnaut/animation/deadnaut_animation.mdl");

	SetEntityModel(entity, DEADNAUT_ANIM_MODEL);

	deadnaut_anim_Stance = anim.LookupSequence("Stance");
	deadnaut_anim_Walk = anim.LookupSequence("Walk");
	deadnaut_anim_Run = anim.LookupSequence("Run");
	deadnaut_anim_Run2 = anim.LookupSequence("Run2");
	deadnaut_anim_Run_urgent = anim.LookupSequence("Run_urgent");
	deadnaut_anim_StandUp = anim.LookupSequence("StandUp");
	deadnaut_anim_Flinch = anim.LookupSequence("Flinch");
	deadnaut_anim_Brace = anim.LookupSequence("Brace");
	deadnaut_anim_FistSlam = anim.LookupSequence("FistSlam");
	deadnaut_anim_Kick = anim.LookupSequence("Kick");
	deadnaut_anim_Smash = anim.LookupSequence("Smash");
	deadnaut_anim_Land = anim.LookupSequence("Land");
}

int CreateDeadnaut(TFTeam team = TFTeam_Blue, TFClassType class = TFClass_Unknown)
{
	int entity = CreateEntityByName("npc_deadnaut");
	SetEntProp(entity, Prop_Data, "m_iClass", class);
	DispatchSpawn(entity);
	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", team);
	ActivateEntity(entity);
	return entity;
}

bool DeadnautPopParse(CustomPopulationSpawner spawner, KeyValues data)
{
	base_npc_pop_parse(spawner, data, deadnaut_health.IntValue, false);
	return true;
}

bool DeadnautPopSpawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	TFClassType class = spawner.get_data("Class");

	int entity = CreateDeadnaut(TFTeam_Blue, class);

	base_npc_pop_spawn(spawner, entity);

	TeleportEntity(entity, pos);

	if(result != null) {
		result.Push(entity);
	}

	return true;
}

void OnDeadnautSpawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);

	TFTeam team = GetEntityTFTeam(entity);
	if(team == TFTeam_Blue) {
		SetEntityModel(entity, DEADNAUT_ANIM_MODEL);

	#if !defined DEADNAUT_CLASS_MODELS_DONT_BONEMERGE
		TFClassType class = GetEntCustomProp(entity, "m_iClass");
		char model[PLATFORM_MAX_PATH];
		switch(class) {
			case TFClass_Heavy: { strcopy(model, sizeof(model), "models/player/deadnaut_heavy.mdl"); }
			case TFClass_Engineer: { strcopy(model, sizeof(model), "models/deadnaut/deadnaut_engineer.mdl"); }
			case TFClass_Soldier: { strcopy(model, sizeof(model), "models/deadnaut/deadnaut_soldier.mdl"); }
			case TFClass_DemoMan: { strcopy(model, sizeof(model), "models/deadnaut/deadnaut_demoman.mdl"); }
			case TFClass_Spy: { strcopy(model, sizeof(model), "models/deadnaut/deadnaut_spy.mdl"); }
			case TFClass_Sniper: { strcopy(model, sizeof(model), "models/deadnaut/deadnaut_sniper.mdl"); }
			case TFClass_Pyro: { strcopy(model, sizeof(model), "models/deadnaut/deadnaut_pyro.mdl"); }
		}

		if(!StrEqual(model, "")) {
			int body = CreateEntityByName("prop_dynamic_override");
			DispatchKeyValue(body, "model", model);
			DispatchSpawn(body);

			SetEntPropFloat(body, Prop_Send, "m_flPlaybackRate", 1.0);

			SetVariantString("!activator");
			AcceptEntityInput(body, "SetParent", entity);

			//EF_BONEMERGE_FASTCULL
			SetEntProp(body, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES);
			SetEntProp(entity, Prop_Send, "m_fEffects", EF_NODRAW|EF_NOSHADOW|EF_NORECEIVESHADOW);

			SetEntProp(entity, Prop_Data, "m_hBody", body);
		}
	#endif
	} else {
		SetEntityModel(entity, team == TFTeam_Red ? "models/deadnaut/animation/deadnaut_animation.mdl" : "models/deadnaut/deadnaut_heavy_anim.mdl");

		SetEntProp(entity, Prop_Data, "m_iClass", TFClass_Unknown);
	}

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", deadnaut_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", deadnaut_health.IntValue);
	}

	SetEntProp(entity, Prop_Data, "m_nState", Deadnaut_Spawning);

	//INextBot bot = INextBot(entity);
	//NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

	//locomotion.DeathDropHeight = 99999999999.0;
	//locomotion.MaxJumpHeight = 0.0;
	//locomotion.StepHeight = 50.0;

	base_npc_set_hull(entity, 80.0, 200.0);
}

void OnDeadnautThink(int entity)
{
	base_npc_think(entity);

	DeadnautState state = GetEntProp(entity, Prop_Data, "m_nState");
	INextBot bot = INextBot(entity);
	NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

	BaseAnimating anim = BaseAnimating(entity);

	if(state != Deadnaut_Dying && state != Deadnaut_Spawning) {
		if(!locomotion.OnGround) {
			if(state != Deadnaut_Falling) {
				SetEntProp(entity, Prop_Data, "m_nState", Deadnaut_Falling);
				return;
			}
		} else if(locomotion.OnGround && state == Deadnaut_Falling) {
			SetEntProp(entity, Prop_Send, "m_nSequence", -1);
			SetEntPropFloat(entity, Prop_Send, "m_flCycle", 0.0);
			SetEntPropFloat(entity, Prop_Data, "m_flAnimTime", GetGameTime());
			anim.ResetSequenceInfo();
			SetEntProp(entity, Prop_Data, "m_nState", Deadnaut_Landing);
			return;
		} else {
			if(GetEntProp(entity, Prop_Data, "m_lifeState") == LIFE_DYING) {
				SetEntProp(entity, Prop_Data, "m_nState", Deadnaut_Dying);
				return;
			}
		}
	}

	TFClassType class = GetEntProp(entity, Prop_Data, "m_iClass");

	switch(state) {
		case Deadnaut_Landing: {
			anim.ResetSequence(deadnaut_anim_Land);

			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				SetEntProp(entity, Prop_Data, "m_nState", Deadnaut_Default);
			}
		}
		case Deadnaut_Falling: {
			SetEntProp(entity, Prop_Send, "m_nSequence", deadnaut_anim_Land);
			SetEntPropFloat(entity, Prop_Send, "m_flCycle", 0.0);
			SetEntPropFloat(entity, Prop_Data, "m_flAnimTime", GetGameTime());
			return;
		}
		case Deadnaut_Dying: {
			anim.ResetSequence(deadnaut_anim_Brace);

			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				RequestFrame(FrameRemoveEntity, entity);
			}
		}
		case Deadnaut_Spawning: {
			anim.ResetSequence(deadnaut_anim_StandUp);

			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				SetEntProp(entity, Prop_Data, "m_nState", Deadnaut_Default);
			}
		}
		case Deadnaut_Default: {
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

				baseline_cost_flags cost_flags = cost_flags_none;
				switch(class) {
					case TFClass_Spy: { cost_flags |= cost_flags_discrete; }
					case TFClass_Scout: { cost_flags |= cost_flags_safest; }
					default: { cost_flags |= cost_flags_mod; }
				}

				if(target != -1) {
					path.ComputeEntity(bot, target, baseline_path_cost, cost_flags);
					SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
				} else {
					float pos[3];
					if(FindBombSite(pos)) {
						path.ComputeVector(bot, pos, baseline_path_cost, cost_flags);
						SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
					}
				}
			}

			float m_flGroundSpeed = 999.0;

			int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");
			if(sequence == deadnaut_anim_Walk) {
				m_flGroundSpeed = 95.0;
			} else if(sequence == deadnaut_anim_Run) {
				m_flGroundSpeed = 150.0;
			} else if(sequence == deadnaut_anim_Run2) {
				m_flGroundSpeed = 150.0;
			} else if(sequence == deadnaut_anim_Run_urgent) {
				m_flGroundSpeed = 200.0;
			}

			sequence = deadnaut_anim_Stance;

			float speed = locomotion.GroundSpeed;
			if(speed > 1.0) {
				switch(class) {
					case TFClass_Scout: { sequence = deadnaut_anim_Run_urgent; }
					case TFClass_Heavy: { sequence = deadnaut_anim_Walk; }
					default: { sequence = deadnaut_anim_Run; }
				}
			}

			anim.ResetSequence(sequence);

			locomotion.RunSpeed = m_flGroundSpeed;
			locomotion.WalkSpeed = m_flGroundSpeed;

			path.Update(bot);
		}
	}

	anim.StudioFrameAdvance();
}

void DeadnautRemoveAll()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_deadnaut")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
}