ConVar tyrant_health = null;

BehaviorActionEntry tyrant_wander = null;
BehaviorActionEntry tyrant_chase = null;
BehaviorActionEntry tyrant_attack = null;

void tyrant_init()
{
	CustomEntityFactory factory = register_infected_factory("npc_re_tyrant");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);
	datamap.add_prop("m_flLastStep", custom_prop_time);

	tyrant_health = CreateConVar("re_tyrant_health", "100");

	tyrant_wander = new BehaviorActionEntry("tyrant_wander");
	tyrant_wander.set_function("Update", TyrantWanderUpdate);
	tyrant_wander.set_function("OnStart", TyrantWanderStart);
	tyrant_wander.set_function("OnEnd", TyrantWanderEnd);

	tyrant_chase = new BehaviorActionEntry("tyrant_chase");
	tyrant_chase.set_function("Update", TyrantChaseUpdate);
	tyrant_chase.set_function("OnStart", TyrantChaseStart);
	tyrant_chase.set_function("OnEnd", TyrantChaseEnd);

	tyrant_attack = new BehaviorActionEntry("tyrant_attack");
	tyrant_attack.set_function("Update", TyrantAttackUpdate);
	tyrant_attack.set_function("OnStart", TyrantAttackStart);
}

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

BehaviorResultType TyrantChaseStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("path", new ChasePath(LEAD_SUBJECT));
	return BEHAVIOR_CONTINUE;
}

void TyrantChaseEnd(BehaviorAction action, int entity, BehaviorAction next)
{
	ChasePath path = action.get_data("path");
	delete path;
}

BehaviorResultType TyrantAttackStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	int sequence = action.get_data("sequence");
	view_as<BaseAnimating>(entity).ResetSequenceEx(sequence);
	INextBot bot = INextBot(entity);
	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);
	locomotion.RunSpeed = 0.0;
	locomotion.WalkSpeed = 0.0;
	action.set_data("hit", false);
	return BEHAVIOR_CONTINUE;
}

bool TyrantEnumKockback(int entity, DataPack data)
{
	if(entity >= 1 && entity <= MaxClients) {
		if(L4D2_IsSurvivorBusy(entity)) {
			return true;
		}

		BehaviorAction action = data.ReadCell();

		int type = data.ReadCell();

		int attacker = data.ReadCell();

		float ang[3];
		data.ReadFloatArray(ang, sizeof(ang));

		float dir[3];
		GetAngleVectors(ang, dir, NULL_VECTOR, NULL_VECTOR);
		if(type == 20) {
			ScaleVector(dir, 400.0);
			SDKHooks_TakeDamage(entity, attacker, attacker, 5.0, DMG_CRUSH|DMG_CLUB);
		} else if(type == 21) {
			ScaleVector(dir, 100.0);
			SDKHooks_TakeDamage(entity, attacker, attacker, 5.0, DMG_CRUSH|DMG_CLUB);
		}
		L4D2_CTerrorPlayer_Fling(entity, entity, dir);
		SetEntProp(entity, Prop_Send, "m_knockdownReason", 0);
		action.set_data("hit", true);
	}
	return true;
}

void DoTyrantAttack(BehaviorAction action, INextBot bot, int entity, float pos[3], float ang[3], int type)
{
	EmitSoundToAll(tyrantswing[GetRandomInt(0, sizeof(tyrantswing)-1)], entity);

	IBody body = bot.BodyInterface;

	float mins[3];
	body.GetHullMins(mins);
	float maxs[3];
	body.GetHullMaxs(maxs);

	float end[3];
	end[0] = pos[0];
	end[1] = pos[1];
	end[2] = pos[2];

	if(type == 20) {
		VectorAddRotatedOffset(ang, end, view_as<float>({50.0, 0.0, 0.0}));
	} else if(type == 21) {
		VectorAddRotatedOffset(ang, end, view_as<float>({100.0, 0.0, 0.0}));
	}

	DataPack data = new DataPack();
	data.WriteCell(action);
	data.WriteCell(type);
	data.WriteCell(entity);
	data.WriteFloatArray(ang, sizeof(ang));
	data.Reset();
	if(type == 20) {
		TR_EnumerateEntitiesHull(pos, end, mins, maxs, PARTITION_SOLID_EDICTS, TyrantEnumKockback, data);
	} else if(type == 21) {
		TR_EnumerateEntitiesHull(pos, end, mins, maxs, PARTITION_SOLID_EDICTS, TyrantEnumKockback, data);
	}
	delete data;
}

BehaviorResultType TyrantAttackUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
		result.set_reason("sequence done");
		return BEHAVIOR_DONE;
	}

	INextBot bot = INextBot(entity);

	BaseAnimating anim = BaseAnimating(entity);

	int sequence = action.get_data("sequence");

	float pos[3];
	float ang[3];
	if(anim.GetIntervalMovement(_, pos, ang)) {
		bot.LocomotionInterface.DriveTo(pos);
		SetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);
	}

	float cycle = GetEntPropFloat(entity, Prop_Send, "m_flCycle");

	if(sequence == 20 && cycle >= 0.11 && cycle <= 0.12) {
		DoTyrantAttack(action, bot, entity, pos, ang, sequence);
	} else if(sequence == 21 && cycle >= 0.57 && cycle <= 0.65) {
		DoTyrantAttack(action, bot, entity, pos, ang, sequence);
	}

	if(sequence == 20 && action.get_data("hit") && cycle >= 0.4) {
		result.set_reason("target knocked");
		return BEHAVIOR_DONE;
	}

	return BEHAVIOR_CONTINUE;
}

void TyrantWalking(INextBot bot, int entity, bool chase = false)
{
	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);

	int sequence = 1;
	float speed = locomotion.GroundSpeed;
	if(speed > 0.0) {
		sequence = chase ? 3 : 3;

		if(GetEntPropFloat(entity, Prop_Data, "m_flLastStep") <= GetGameTime()) {
			EmitSoundToAll(tyrantstep[GetRandomInt(0, sizeof(tyrantstep)-1)], entity);
			SetEntPropFloat(entity, Prop_Data, "m_flLastStep", GetGameTime() + 0.1);
		}
	}

	BaseAnimating anim = BaseAnimating(entity);
	anim.ResetSequenceEx(sequence);

	float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed == 0.0) {
		m_flGroundSpeed = 0.1;
	}

	locomotion.RunSpeed = m_flGroundSpeed;
	locomotion.WalkSpeed = m_flGroundSpeed;
}

BehaviorResultType TyrantChaseUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	int target = EntRefToEntIndex(action.get_data("target"));
	if(target == -1 || !IsPlayerAlive(target)) {
		result.set_reason("target lost");
		return BEHAVIOR_DONE;
	}

	INextBot bot = INextBot(entity);

	IVision vision = bot.VisionInterface;

	float range = bot.GetRangeToEntity(target);
	if(range <= 70.0) {
		if(vision.IsInFieldOfViewEntity(target)) {
			result.action = tyrant_attack.create();
			result.action.set_data("sequence", 21);
			result.set_reason("target close");
			return BEHAVIOR_SUSPEND_FOR;
		}
	} else if(range <= 100.0) {
		if(vision.IsLookingAtEntity(target)) {
			result.action = tyrant_attack.create();
			result.action.set_data("sequence", 20);
			result.set_reason("target close");
			return BEHAVIOR_SUSPEND_FOR;
		}
	}

	ChasePath path = action.get_data("path");
	path.Update(bot, target, baseline_path_cost, cost_flags_mod|cost_flags_onlywalk);

	TyrantWalking(bot, entity, true);

	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantWanderStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("path", new PathFollower());
	action.set_data("repathtime", 0.0);
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantWanderUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	INextBot bot = INextBot(entity);
	IVision vision = bot.VisionInterface;

	int target = vision.GetPrimaryRecognizedThreat();
	if(target != -1) {
		result.action = tyrant_chase.create();
		result.action.set_data("target", EntIndexToEntRef(target));
		result.set_reason("found target");
		return BEHAVIOR_SUSPEND_FOR;
	}

	PathFollower path = action.get_data("path");

	if(action.get_data("repathtime") <= GetGameTime()) {
		int count = CNavMesh.GetNavAreaCount();
		int idx = GetRandomInt(0, count-1);
		CNavArea area = CNavMesh.GetNavAreaByID(idx);

		if(area != CNavArea_Null) {
			float vec[3];
			area.GetRandomPoint(vec);

			path.ComputeVector(bot, vec, baseline_path_cost, cost_flags_mod|cost_flags_onlywalk);
		}

		action.set_data("repathtime", GetGameTime() + GetRandomFloat(10.0, 20.0));
	}

	path.Update(bot);

	TyrantWalking(bot, entity);

	return BEHAVIOR_CONTINUE;
}

void TyrantWanderEnd(BehaviorAction action, int entity, BehaviorAction next)
{
	PathFollower path = action.get_data("path");
	delete path;
}

BehaviorAction tyrant_behavior(int entity)
{
	return tyrant_wander.create();
}

void tyrant_spawn(int entity)
{
	INextBot bot = INextBot(entity);

	IIntentionCustom inte = bot.AllocateCustomIntention(tyrant_behavior);
	base_npc_spawn(entity, inte);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);
	SetEntityModel(entity, "models/roach/redc/ety1.mdl");
	base_npc_set_hull(entity, 25.0, 100.0);

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", tyrant_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", tyrant_health.IntValue);
	}

	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);
	locomotion.MaxJumpHeight = 18.0;
}

void tyrant_think(int entity)
{
	INextBot bot = INextBot(entity);
	base_npc_think(entity, bot);

	BaseAnimating anim = BaseAnimating(entity);
	anim.StudioFrameAdvance();
}

void tyrant_removeall()
{
	int entity = -1;
	while((entity = FindEntityByClassname(entity, "npc_re_tyrant")) != -1) {
		RemoveEntity(entity);
	}
}