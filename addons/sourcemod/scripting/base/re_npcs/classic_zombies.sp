ConVar classiczombie_health = null;

enum classiczombie_state
{
	classiczombie_spawning,
	classiczombie_dying,
	classiczombie_default,
	classiczombie_attacking,
	classiczombie_facingtarget,
};

static const char classiczombie_models[][PLATFORM_MAX_PATH] = {
	"models/re1/re1zombie_male1.mdl",
	"models/re1/re1zombie_male2.mdl",
	"models/re1/re1zombie_male3.mdl",
	"models/re2/re2zombie_male.mdl",
	"models/re2/re2zombie_officer.mdl",
	"models/re2/re2zombie_patient.mdl",
	"models/re2/re2zombie_female.mdl",
	"models/re2/re2zombie_doctor.mdl",
	"models/re3/re3zombie_suit.mdl",
	"models/re3/re3ubcs_zombie.mdl",
	"models/re3/re3zombie_girl.mdl",
};

int g_nAttackAnim = 34;

void classiczombie_init()
{
	CustomEntityFactory factory = register_infected_factory("npc_re_classiczombie");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);
	datamap.add_prop("m_flRecalcWalkAnim", custom_prop_time);
	datamap.add_prop("m_nWalkAnim", custom_prop_int);
	datamap.add_prop("m_flRecalcIdleAnim", custom_prop_time);
	datamap.add_prop("m_nIdleAnim", custom_prop_int);

	classiczombie_health = CreateConVar("re_classiczombie_health", "100");
}

#if defined GAME_L4D2
public void re_classiczombie_precache(moreinfected_data data)
{
	for(int i = 0; i < sizeof(classiczombie_models); ++i) {
		PrecacheModel(classiczombie_models[i]);
	}

	g_nAttackAnim = 34;
}

public int re_classiczombie_spawn_common(int entity, Address area, float pos[3], infected_directive directive, moreinfected_data data)
{
	RemoveEntity(entity);

	entity = create_base_npc("npc_re_classiczombie", 3);

	TeleportEntity(entity, pos);

	return entity;
}
#endif

void classiczombie_think(int entity)
{
	INextBot bot = INextBot(entity);

	base_npc_think(entity, bot);

	classiczombie_state state = view_as<classiczombie_state>(GetEntProp(entity, Prop_Data, "m_nState"));

	BaseAnimating anim = BaseAnimating(entity);

	anim.StudioFrameAdvance();

	switch(state) {
		case classiczombie_spawning: {
			SetEntProp(entity, Prop_Data, "m_nState", classiczombie_default);
		}
		case classiczombie_dying: {
			RequestFrame(FrameRemoveEntity, entity);
		}
		case classiczombie_attacking: {
			if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
				SetEntProp(entity, Prop_Data, "m_nState", classiczombie_default);
			}
		}
		case classiczombie_facingtarget: {
			int target = GetEntPropEnt(entity, Prop_Data, "m_hTarget");
			if(target != -1) {
				float target_pos[3];
				GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);

				ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);
				locomotion.FaceTowards(target_pos);

				IVision vision = bot.VisionInterface;
				if(vision.IsInFieldOfViewEntity(target)) {
					anim.ResetSequenceEx(g_nAttackAnim);
					SetEntProp(entity, Prop_Data, "m_nState", classiczombie_attacking);
				}
			} else {
				SetEntProp(entity, Prop_Data, "m_nState", classiczombie_default);
			}
		}
		case classiczombie_default: {
			ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);

			IVision vision = bot.VisionInterface;

			int target = vision.GetPrimaryRecognizedThreat();
			if(target == -1) {
				target = GetEntPropEnt(entity, Prop_Data, "m_hTarget");
			} else {
				SetEntPropEnt(entity, Prop_Data, "m_hTarget", target);
			}

			ChasePath path = get_npc_path(entity);

			if(target != -1) {
				float target_pos[3];
				GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);

				float my_pos[3];
				GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", my_pos);

				float distance = GetVectorDistance(my_pos, target_pos);
				if(distance <= 50.0) {
					int sequence = GetEntProp(entity, Prop_Data, "m_nIdleAnim");
					anim.ResetSequenceEx(sequence);
					SetEntProp(entity, Prop_Data, "m_nState", classiczombie_facingtarget);
					locomotion.RunSpeed = 0.0;
					locomotion.WalkSpeed = 0.0;
					return;
				}
			}

			if(GetEntPropFloat(entity, Prop_Data, "m_flRecalcWalkAnim") <= GetGameTime()) {
				int sequence = anim.SelectWeightedSequenceEx(ACT_WALK);
				SetEntProp(entity, Prop_Data, "m_nWalkAnim", sequence);
				SetEntPropFloat(entity, Prop_Data, "m_flRecalcWalkAnim", GetGameTime() + GetRandomFloat(5.0, 20.0));
			}

			if(GetEntPropFloat(entity, Prop_Data, "m_flRecalcIdleAnim") <= GetGameTime()) {
				int sequence = anim.SelectWeightedSequenceEx(ACT_IDLE);
				SetEntProp(entity, Prop_Data, "m_nIdleAnim", sequence);
				SetEntPropFloat(entity, Prop_Data, "m_flRecalcIdleAnim", GetGameTime() + GetRandomFloat(5.0, 20.0));
			}

			int sequence = GetEntProp(entity, Prop_Data, "m_nIdleAnim");
			float speed = locomotion.GroundSpeed;
			if(speed > 0.0) {
				sequence = GetEntProp(entity, Prop_Data, "m_nWalkAnim");
			}

			anim.ResetSequenceEx(sequence);

			float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
			if(m_flGroundSpeed == 0.0) {
				m_flGroundSpeed = 0.1;
			}

			locomotion.RunSpeed = m_flGroundSpeed;
			locomotion.WalkSpeed = m_flGroundSpeed;

			if(target != -1) {
				path.Update(bot, target, baseline_path_cost, cost_flags_mod|cost_flags_onlywalk);
			} else {
				view_as<PathFollower>(path).Update(bot);
			}
		}
	}
}

void classiczombie_spawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);

	SetEntityModel(entity, classiczombie_models[GetRandomInt(0, sizeof(classiczombie_models)-1)]);

	base_npc_set_hull(entity, 20.0, 70.0);

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", classiczombie_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", classiczombie_health.IntValue);
	}

	SetEntProp(entity, Prop_Data, "m_nState", classiczombie_spawning);

	INextBot bot = INextBot(entity);

	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);

	locomotion.MaxJumpHeight = 18.0;
}

void classiczombie_removeall()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_re_classiczombie")) != -1) {
		base_npc_deleted(entity);
		RemoveEntity(entity);
	}
}