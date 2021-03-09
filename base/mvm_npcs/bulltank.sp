enum BulltankState
{
	Bulltank_Spawning,
	Bulltank_Dying,
	Bulltank_Default,
	Bulltank_Firing,
};

int bulltank_anim_Stand = -1;
int bulltank_anim_Walk = -1;
int bulltank_anim_Walk2 = -1;
int bulltank_anim_Run = -1;
int bulltank_anim_Run2 = -1;
int bulltank_anim_RunStop = -1;
int bulltank_anim_ShellUp = -1;
int bulltank_anim_Shell2 = -1;
int bulltank_anim_Shell = -1;

ConVar bulltank_health = null;

void bulltank_init()
{
	CustomEntityFactory factory = register_nextbot_factory("npc_bulltank");
	CustomSendtable sendtable = sendtable_from_nextbot_factory(factory);
	sendtable.override_with("CTFTankBoss");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);

	bulltank_health = CreateConVar("bulltank_health", "100");

	CustomPopulationSpawner spawner = register_popspawner("Bulltank");
	spawner.Parse = BulltankPopParse;
	spawner.Spawn = BulltankPopSpawn;
	spawner.GetClass = base_npc_pop_getclass;
	spawner.GetClassIcon = base_npc_pop_getclassicon;
	spawner.GetHealth = base_npc_pop_get_health;
	spawner.IsMiniBoss = base_npc_pop_isminiboss;
	spawner.HasAttribute = base_npc_pop_hasattribute;
}

void bulltank_precache(int entity, BaseAnimating anim)
{
	PrecacheModel("models/bulltank/bulltank_sequences.mdl");

	SetEntityModel(entity, "models/bulltank/bulltank_sequences.mdl");

	bulltank_anim_Stand = anim.LookupSequence("Stand");
	bulltank_anim_Walk = anim.LookupSequence("Walk");
	bulltank_anim_Walk2 = anim.LookupSequence("Walk2");
	bulltank_anim_Run = anim.LookupSequence("Run");
	bulltank_anim_Run2 = anim.LookupSequence("Run2");
	bulltank_anim_RunStop = anim.LookupSequence("RunStop");
	bulltank_anim_ShellUp = anim.LookupSequence("ShellUp");
	bulltank_anim_Shell2 = anim.LookupSequence("Shell2");
	bulltank_anim_Shell = anim.LookupSequence("Shell");
}

bool BulltankPopParse(CustomPopulationSpawner spawner, KeyValues data)
{
	base_npc_pop_parse(spawner, data, bulltank_health.IntValue, true);
	return true;
}

bool BulltankPopSpawn(CustomPopulationSpawner spawner, float pos[3], ArrayList result)
{
	int entity = create_base_npc("npc_bulltank", TFTeam_Blue);

	base_npc_pop_spawn(spawner, entity);

	TeleportEntity(entity, pos);

	if(result != null) {
		result.Push(entity);
	}

	return true;
}

void OnBulltankSpawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_iInitialTeamNum", TFTeam_Blue);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", TFTeam_Blue);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_MECH);

	SetEntityModel(entity, "models/bulltank/bulltank_sequences.mdl");

	base_npc_set_hull(entity, 150.0, 250.0);

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", bulltank_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", bulltank_health.IntValue);
	}

	SetEntProp(entity, Prop_Data, "m_nState", Bulltank_Spawning);
}

void OnBulltankThink(int entity)
{
	base_npc_think(entity);

	BulltankState state = GetEntProp(entity, Prop_Data, "m_nState");

	if(GetEntProp(entity, Prop_Data, "m_lifeState") == LIFE_DYING) {
		state = Bulltank_Dying;
	}

	INextBot bot = INextBot(entity);
	BaseAnimating anim = BaseAnimating(entity);

	anim.StudioFrameAdvance();

	switch(state) {
		case Bulltank_Firing: {
			anim.ResetSequence(bulltank_anim_Shell);

			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				SetEntProp(entity, Prop_Data, "m_nState", Bulltank_Default);
			}
		}
		case Bulltank_Dying: {
			anim.ResetSequence(bulltank_anim_Shell2);

			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				RequestFrame(FrameRemoveEntity, entity);
			}
		}
		case Bulltank_Spawning: {
			anim.ResetSequence(bulltank_anim_ShellUp);

			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				SetEntProp(entity, Prop_Data, "m_nState", Bulltank_Default);
			}
		}
		case Bulltank_Default: {
			NextBotGoundLocomotionCustom locomotion = view_as<NextBotGoundLocomotionCustom>(bot.LocomotionInterface);

			PathFollower path = GetEntProp(entity, Prop_Data, "m_pPathFollower");

			if(GetEntPropFloat(entity, Prop_Data, "m_flRepathTime") <= GetGameTime()) {
				float pos[3];
				if(FindBombSite(pos)) {
					path.ComputeVector(bot, pos, baseline_path_cost, cost_flags_safest|cost_flags_discrete);
				}
				SetEntPropFloat(entity, Prop_Data, "m_flRepathTime", GetGameTime() + 0.5);
			}

			float m_flGroundSpeed = 999.0;

			int sequence = GetEntProp(entity, Prop_Send, "m_nSequence");
			if(sequence == bulltank_anim_Walk) {
				m_flGroundSpeed = 70.0;
			} else if(sequence == bulltank_anim_Walk2) {
				m_flGroundSpeed = 95.0;
			} else if(sequence == bulltank_anim_Run) {
				m_flGroundSpeed = 200.0;
			} else if(sequence == bulltank_anim_Run2) {
				m_flGroundSpeed = 150.0;
			}

			sequence = bulltank_anim_Stand;

			float speed = locomotion.GroundSpeed;
			if(speed > 1.0) {
				sequence = bulltank_anim_Walk;
			}

			anim.ResetSequence(sequence);

			locomotion.RunSpeed = m_flGroundSpeed;
			locomotion.WalkSpeed = m_flGroundSpeed;

			path.Update(bot);
		}
	}
}

void BulltankRemoveAll()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_bulltank")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
}