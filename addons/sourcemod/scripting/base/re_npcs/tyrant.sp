ConVar tyrant_health = null;

BehaviorActionEntry tyrant_idle = null;
BehaviorActionEntry tyrant_chase = null;
BehaviorActionEntry action_play_sequence = null;

void tyrant_init()
{
	CustomEntityFactory factory = register_infected_factory("npc_re_tyrant");
	CustomDatamap datamap = CustomDatamap.from_factory(factory);
	base_npc_init_datamaps(datamap);

	tyrant_health = CreateConVar("re_tyrant_health", "100");

	tyrant_idle = new BehaviorActionEntry("tyrant_idle");
	tyrant_idle.set_function("Update", TyrantIdleUpdate);
	tyrant_idle.set_function("OnStart", TyrantIdleStart);
	tyrant_idle.set_function("OnResume", TyrantIdleStart);

	tyrant_chase = new BehaviorActionEntry("tyrant_chase");
	tyrant_chase.set_function("Update", TyrantChaseUpdate);
	tyrant_chase.set_function("OnStart", TyrantChaseStart);
	tyrant_chase.set_function("OnEnd", TyrantChaseEnd);
	tyrant_chase.set_function("OnResume", TyrantChaseResume);

	action_play_sequence = new BehaviorActionEntry("action_play_sequence");
	action_play_sequence.set_function("Update", PlaySequenceUpdate);
	action_play_sequence.set_function("OnStart", PlaySequenceStart);
}

#if defined GAME_L4D2
public void re_tyrant_precache(infected_class class, char data[MAX_DATA_LENGTH])
{
	PrecacheModel("models/roach/redc/ety1.mdl");
}

public int re_tyrant_spawn(int entity, Address area, float pos[3], infected_directive directive, infected_class class, char data[MAX_DATA_LENGTH])
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
	return TyrantChaseResume(action, entity, prior, result);
}

BehaviorResultType TyrantChaseResume(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	view_as<BaseAnimating>(entity).ResetSequenceEx(3);
	return BEHAVIOR_CONTINUE;
}

void TyrantChaseEnd(BehaviorAction action, int entity, BehaviorAction next)
{
	ChasePath path = action.get_data("path");
	delete path;
}

BehaviorResultType PlaySequenceStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	int sequence = action.get_data("sequence");
	view_as<BaseAnimating>(entity).ResetSequenceEx(sequence);
	INextBot bot = INextBot(entity);
	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);
	locomotion.RunSpeed = 0.0;
	locomotion.WalkSpeed = 0.0;
	return BEHAVIOR_CONTINUE;
}

void VectorAddRotatedOffset(const float angle[3], float buffer[3], const float offset[3])
{
	float vecForward[3]; float vecLeft[3]; float vecUp[3];
	GetAngleVectors(angle, vecForward, vecLeft, vecUp);

	ScaleVector(vecForward, offset[0]);
	ScaleVector(vecLeft, offset[1]);
	ScaleVector(vecUp, offset[2]);

	float vecAdd[3];
	AddVectors(vecAdd, vecForward, vecAdd);
	AddVectors(vecAdd, vecLeft, vecAdd);
	AddVectors(vecAdd, vecUp, vecAdd);

	AddVectors(buffer, vecAdd, buffer);
}

bool enumpunch(int entity, any data)
{
	if(entity >= 1 && entity <= MaxClients) {
		float dir[3];
		L4D2_CTerrorPlayer_Fling(entity, entity, dir);
	}

	return true;
}

BehaviorResultType PlaySequenceUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	if(GetEntProp(entity, Prop_Data, "m_bSequenceFinished")) {
		result.set_reason("sequence done");
		return BEHAVIOR_DONE;
	}

	INextBot bot = INextBot(entity);

	BaseAnimating anim = BaseAnimating(entity);

	float pos[3];
	float ang[3];
	bool finished = false;
	if(anim.GetIntervalMovement(finished, pos, ang)) {
		bot.LocomotionInterface.DriveTo(pos);

		IBody body = bot.BodyInterface;

		float mins[3];
		body.GetHullMins(mins);
		float maxs[3];
		body.GetHullMaxs(maxs);

		float end[3];
		end[0] = pos[0];
		end[1] = pos[1];
		end[2] = pos[2];

		float offset[3];
		offset[0] += 100.0;
		VectorAddRotatedOffset(ang, end, offset);

		DrawHull(pos, ang, mins, maxs, {255, 0, 0, 255});
		DrawHull(end, ang, mins, maxs, {0, 255, 0, 255});

		TR_EnumerateEntitiesHull(pos, end, mins, maxs, MASK_NPCSOLID, enumpunch, entity);
	}

	if(finished) {
		result.set_reason("sequence done");
		return BEHAVIOR_DONE;
	}

	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantChaseUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	int target = EntRefToEntIndex(action.get_data("target"));
	if(target == -1) {
		result.set_reason("target lost");
		return BEHAVIOR_DONE;
	}

	INextBot bot = INextBot(entity);

	IVision vision = bot.VisionInterface;

	float range = bot.GetRangeToEntity(target);

	if(range <= 50.0) {
		if(vision.IsInFieldOfViewEntity(target)) {
			result.action = action_play_sequence.create();
			result.action.set_data("sequence", 21);
			result.set_reason("target close");
			return BEHAVIOR_SUSPEND_FOR;
		}
	} else if(range <= 100.0) {
		if(vision.IsLookingAtEntity(target)) {
			result.action = action_play_sequence.create();
			result.action.set_data("sequence", 20);
			result.set_reason("target close");
			return BEHAVIOR_SUSPEND_FOR;
		}
	}

	ChasePath path = action.get_data("path");
	path.Update(bot, target, baseline_path_cost, cost_flags_mod|cost_flags_onlywalk);

	ZombieBotLocomotionCustom locomotion = view_as<ZombieBotLocomotionCustom>(bot.LocomotionInterface);

	int sequence = 1;
	float speed = locomotion.GroundSpeed;
	if(speed > 0.0) {
		sequence = 3;
	}

	BaseAnimating anim = BaseAnimating(entity);
	anim.ResetSequenceEx(sequence);

	float m_flGroundSpeed = GetEntPropFloat(entity, Prop_Data, "m_flGroundSpeed");
	if(m_flGroundSpeed == 0.0) {
		m_flGroundSpeed = 0.1;
	}

	locomotion.RunSpeed = m_flGroundSpeed;
	locomotion.WalkSpeed = m_flGroundSpeed;

	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantIdleStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	view_as<BaseAnimating>(entity).ResetSequenceEx(1);
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantIdleUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
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

	return BEHAVIOR_CONTINUE;
}

BehaviorAction tyrant_behavior(int entity)
{
	return tyrant_idle.create();
}

void tyrant_spawn(int entity)
{
	base_npc_spawn(entity);

	SetEntProp(entity, Prop_Data, "m_bloodColor", BLOOD_COLOR_RED);

	SetEntityModel(entity, "models/roach/redc/ety1.mdl");

	base_npc_set_hull(entity, 30.0, 100.0);

	int health = GetEntProp(entity, Prop_Data, "m_iHealth");
	if(health == 0) {
		SetEntProp(entity, Prop_Data, "m_iHealth", tyrant_health.IntValue);
		SetEntProp(entity, Prop_Data, "m_iMaxHealth", tyrant_health.IntValue);
	}

	INextBot bot = INextBot(entity);

	bot.AllocateCustomIntention(tyrant_behavior);

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