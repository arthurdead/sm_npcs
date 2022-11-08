CustomBehaviorActionEntry dead_action;

void dead_action_init()
{
	dead_action = new CustomBehaviorActionEntry("Dead");
	dead_action.set_function("OnStart", action_start);
	dead_action.set_function("Update", action_update);
	dead_action.set_function("OnAnimationActivityComplete", action_animcomplete);
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	IBody body = bot.BodyInterface;

	SetEntPropFloat(entity, Prop_Send, "m_flPlaybackRate", 1.0);

	if(!action.has_data("was_ragdoll")) {
		bool play_anim = action.get_data("play_anim");
		if(play_anim) {
			Activity death_activity = action.get_data("death_activity");
			if(death_activity != ACT_INVALID) {
				body.StartActivity(death_activity, ACTIVITY_UNINTERRUPTIBLE);
			}
		}
	}

	if(action.has_data("should_rag")) {
		float ragdoll_time = action.get_data("ragdoll_time");
		if(ragdoll_time <= GetGameTime()) {
			if(!action.has_data("was_ragdoll")) {
				CTakeDamageInfo dmginfo;
				action.get_data_array("m_dmgInfo", dmginfo, sizeof(CTakeDamageInfo));
				CombatCharacterEventKilled(entity, dmginfo);
				action.set_data("was_ragdoll", 1)
			}
		}
	} else if(action.has_data("should_remove")) {
		float remove_time = action.get_data("remove_time");
		if(remove_time <= GetGameTime()) {
			RequestFrame(frame_remove_npc, EntIndexToEntRef(entity));
			return result.Done();
		}
	}

	return result.Continue();
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	IBody body = bot.BodyInterface;

	bool can_rag = (AnimatingSelectWeightedSequence(entity, ACT_DIERAGDOLL) != -1);
	action.set_data("can_ragdoll", can_rag);

	bool play_anim = false;

	Activity death_activity = CombatCharacterGetDeathActivity(entity);
	if(death_activity != ACT_INVALID) {
		if(body.SelectAnimationSequence(death_activity) != -1) {
			play_anim = true;
		}
	}

	if(play_anim) {
		action.set_data("death_activity", death_activity);
	} else {
		action.set_data("death_activity", ACT_INVALID);
	}

	action.set_data("play_anim", play_anim);

	if(HasEntProp(entity, Prop_Send, "m_iDeathPose")) {
		int lastHitGroup = GetEntProp(entity, Prop_Data, "m_LastHitGroup");

		CTakeDamageInfo dmginfo;
		action.get_data_array("m_dmgInfo", dmginfo, sizeof(CTakeDamageInfo));

		int frame = 0;
		death_activity = ACT_INVALID;
		SelectDeathPoseActivityAndFrame(entity, dmginfo, lastHitGroup, death_activity, frame);

		int sequence = -1;

		if(death_activity != ACT_INVALID) {
			sequence = body.SelectAnimationSequence(death_activity);
		}

		SetEntProp(entity, Prop_Send, "m_iDeathPose", sequence);
		SetEntProp(entity, Prop_Send, "m_iDeathFrame", frame);
	}

	IIntentionCustom intention_custom = view_as<IIntentionCustom>(bot.IntentionInterface);

	Handle pl;
	Function func = intention_custom.get_function("handle_die", pl);
	if(func != INVALID_FUNCTION && pl != null) {
		Call_StartFunction(pl, func);
		Call_PushCell(intention_custom);
		Call_PushCell(bot);
		Call_PushCell(entity);
		Call_PushCell(true);
		Call_Finish();
	}

	if(play_anim) {
		float time = sm_npcs_dead_decoration_time.FloatValue;
		if(time <= 0.0) {
			RequestFrame(frame_remove_npc, EntIndexToEntRef(entity));
			return result.Done();
		} else {
			action.set_data("remove_time", GetGameTime() + time);
			action.set_data("should_remove", 1);
		}
	} else {
		if(can_rag) {
			action.set_data("ragdoll_time", GetGameTime() + 0.1);
			action.set_data("should_rag", 1);
		} else {
			RequestFrame(frame_remove_npc, EntIndexToEntRef(entity));
			return result.Done();
		}
	}

	return result.Continue();
}

static void make_npc_decoration(INextBot bot, int entity)
{
	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.HeadAsAngles = false;

	AnyLocomotion locomotion_custom = view_as<AnyLocomotion>(bot.LocomotionInterface);
	locomotion_custom.ResolvePlayerCollisions = false;

	int flags = GetEntityFlags(entity);
	flags |= (FL_NOTARGET|FL_DONTTOUCH);
	flags &= ~FL_NPC;
	SetEntityFlags(entity, flags);

	SetEntityMoveType(entity, MOVETYPE_NONE);

	SetEntityCollisionGroup(entity, COLLISION_GROUP_NONE);

	EntitySetSolid(entity, SOLID_NONE);

	SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_NO);

	SetEntProp(entity, Prop_Data, "m_iHealth", 0);

	SetEntProp(entity, Prop_Data, "m_lifeState", LIFE_DEAD);

	EntityAddSolidFlags(entity, FSOLID_NOT_SOLID);
}

static BehaviorResultType action_animcomplete(CustomBehaviorAction action, INextBot bot, int entity, Activity act, BehaviorResult result)
{
	bool play_anim = action.get_data("play_anim");
	if(!play_anim) {
		return result.TryContinue();
	}

	Activity death_activity = action.get_data("death_activity");
	if(death_activity == ACT_INVALID || act != death_activity) {
		return result.TryContinue();
	}

	IIntentionCustom intention_custom = view_as<IIntentionCustom>(bot.IntentionInterface);

	Handle pl;
	Function func = intention_custom.get_function("handle_die", pl);
	if(func != INVALID_FUNCTION && pl != null) {
		Call_StartFunction(pl, func);
		Call_PushCell(intention_custom);
		Call_PushCell(bot);
		Call_PushCell(entity);
		Call_PushCell(false);
		Call_Finish();
	}

	bool can_rag = action.get_data("can_ragdoll");
	if(can_rag) {
		if(!action.has_data("should_rag")) {
			action.set_data("ragdoll_time", GetGameTime() + 0.1);
			action.set_data("should_rag", 1);
		}
	} else {
		if(!action.has_data("was_decorated")) {
			make_npc_decoration(bot, entity);
			action.set_data("was_decorated", 1);
		}
	}

	return result.TryContinue();
}