BehaviorActionEntry hans_volter_main_action;

void hans_volter_main_action_init()
{
	hans_volter_main_action = new BehaviorActionEntry("HansVolterMain");
	hans_volter_main_action.set_function("OnStart", hans_volter_main_start);
	hans_volter_main_action.set_function("Update", hans_volter_main_update);
	hans_volter_main_action.set_function("OnEnd", hans_volter_main_end);
	hans_volter_main_action.set_function("OnStuck", hans_volter_main_stuck);
}

static BehaviorResultType hans_volter_main_stuck(BehaviorAction action, int entity, BehaviorResult result)
{
	ChasePath path = action.get_data("path");

	if(path.CurrentGoal != Segment_Null) {
		float pos[3];
		path.CurrentGoal.GetPosition(pos);
		TeleportEntity(entity, pos);
	}

	result.priority = RESULT_TRY;
	return BEHAVIOR_CONTINUE;
}

static BehaviorResultType hans_volter_main_start(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	ChasePath path = new ChasePath(LEAD_SUBJECT);
	action.set_data("path", path);

	INextBot bot = INextBot(entity);
	bot.LocomotionInterface.Walk();

	return BEHAVIOR_CONTINUE;
}

static int hans_volter_create_gun(int entity, const char[] attach)
{
	int gun = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(gun, "model", "models/weapons/w_smg1.mdl");
	DispatchSpawn(gun);

	SetVariantString("!activator");
	AcceptEntityInput(gun, "SetParent", entity);

	SetVariantString(attach);
	AcceptEntityInput(gun, "SetParentAttachment", entity);

	return gun;
}

static void hans_volter_set_akimbo(int entity, bool akimbo)
{
	int gun1 = GetEntPropEnt(entity, Prop_Data, "m_hAkimboGun1");
	if(gun1 != -1) {
		RemoveEntity(gun1);
	}

	int gun2 = GetEntPropEnt(entity, Prop_Data, "m_hAkimboGun2");
	if(gun2 != -1) {
		RemoveEntity(gun2);
	}

	if(akimbo) {
		gun1 = hans_volter_create_gun(entity, "Right_Weapon");
		SetEntPropEnt(entity, Prop_Data, "m_hAkimboGun1", gun1);

		gun2 = hans_volter_create_gun(entity, "Left_Weapon");
		SetEntPropVector(gun2, Prop_Send, "m_vecOrigin", view_as<float>({-72.50, -81.56, 4.53}));
		SetEntPropEnt(entity, Prop_Data, "m_hAkimboGun2", gun2);
	} else {
		SetEntPropEnt(entity, Prop_Data, "m_hAkimboGun1", -1);
		SetEntPropEnt(entity, Prop_Data, "m_hAkimboGun2", -1);
	}

	SetEntProp(entity, Prop_Data, "m_bAkimbo", akimbo);
}

static BehaviorResultType hans_volter_main_update(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	ChasePath path = action.get_data("path");

	int target = 1;

	INextBot bot = INextBot(entity);

	ILocomotion locomotion = bot.LocomotionInterface;

	bool akimbo = GetEntProp(entity, Prop_Data, "m_bAkimbo") != 0;

	if(GetEntProp(entity, Prop_Data, "m_iHealth") <= 3000) {
		if(GetEntPropFloat(entity, Prop_Data, "m_flLastAkimbo") < GetGameTime()) {
			akimbo = !akimbo;
			hans_volter_set_akimbo(entity, akimbo);
			SetEntPropFloat(entity, Prop_Data, "m_flLastAkimbo", GetGameTime() + 70.0);
		}
	}

	if(bot.IsRangeLessThanEntity(target, 60.0)) {
		result.action = hans_volter_melee_action.create();
		return BEHAVIOR_SUSPEND_FOR;
	}

	path.Update(bot, target, baseline_path_cost, cost_flags_mod|cost_flags_fastest);

	BaseAnimating anim = BaseAnimating(entity);

	if(locomotion.AttemptingToMove) {
		anim.ResetSequence(akimbo ? hans_volter_walk_akimbo_anim : hans_volter_walk_anim);
	} else {
		anim.ResetSequence(akimbo ? hans_volter_idle_akimbo_anim : hans_volter_idle_anim);
	}

	IVision vision = bot.VisionInterface;

	if(akimbo) {
		float spot[3];
		if(vision.IsLineOfSightClearToEntity(target, spot)) {
			locomotion.FaceTowards(spot);
		}
	}

	return BEHAVIOR_CONTINUE;
}

static void hans_volter_main_end(BehaviorAction action, int entity, BehaviorAction next)
{
	ChasePath path = action.get_data("path");
	delete path;
}