CustomBehaviorActionEntry dead_action;

void dead_action_init()
{
	dead_action = new CustomBehaviorActionEntry("Dead");
	dead_action.set_function("OnStart", action_start);
	dead_action.set_function("OnAnimationActivityComplete", action_animcomplete);
}

static bool can_ragdoll(int entity)
{
	return (AnimatingSelectWeightedSequence(entity, ACT_DIERAGDOLL) != -1);
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	IBody body = bot.BodyInterface;

	CTakeDamageInfo dmginfo;
	action.get_data_array("m_dmgInfo", dmginfo, sizeof(CTakeDamageInfo));

	int attacker = dmginfo.m_hInflictor;
	if(attacker == -1) {
		attacker = dmginfo.m_hAttacker;
	}

	NavRelativeDirType dir = DirectionBetweenEntities(entity, attacker);

	bool play_anim = false;

	switch(dir) {
		case FORWARD: {
			if(body.StartActivity(ACT_DIE_FRONTSIDE, ACTIVITY_UNINTERRUPTIBLE)) {
				play_anim = true;
			}
		}
		case RIGHT: {
			if(body.StartActivity(ACT_DIE_LEFTSIDE, ACTIVITY_UNINTERRUPTIBLE)) {
				play_anim = true;
			}
		}
		case LEFT: {
			if(body.StartActivity(ACT_DIE_RIGHTSIDE, ACTIVITY_UNINTERRUPTIBLE)) {
				play_anim = true;
			}
		}
		case BACKWARD: {
			if(body.StartActivity(ACT_DIE_BACKSIDE, ACTIVITY_UNINTERRUPTIBLE)) {
				play_anim = true;
			}
		}
	}

	if(!play_anim) {
		if(body.StartActivity(ACT_DIESIMPLE, ACTIVITY_UNINTERRUPTIBLE)) {
			play_anim = true;
		}
	}

	if(play_anim) {
		make_npc_decoration(bot, entity);
		return result.Continue();
	} else {
		if(can_ragdoll(entity)) {
			CombatCharacterEventKilled(entity, dmginfo);
		} else {
			RequestFrame(frame_remove_npc, EntIndexToEntRef(entity));
		}
		return result.TryDone(RESULT_CRITICAL);
	}
}

static void make_npc_decoration(INextBot bot, int entity)
{
	IBodyCustom body_custom = view_as<IBodyCustom>(bot.BodyInterface);
	body_custom.SolidMask = (CONTENTS_SOLID|CONTENTS_WINDOW|CONTENTS_GRATE);
	body_custom.CollisionGroup = COLLISION_GROUP_NONE;

	int flags = GetEntityFlags(entity);
	flags |= FL_NOTARGET;
	flags &= ~FL_NPC;
	SetEntityFlags(entity, flags);

	SetEntityMoveType(entity, MOVETYPE_NONE);

	SetEntityCollisionGroup(entity, COLLISION_GROUP_NONE);

	SetEntProp(entity, Prop_Send, "m_nSolidType", SOLID_NONE);

	SetEntProp(entity, Prop_Data, "m_takedamage", DAMAGE_NO);

	SetEntProp(entity, Prop_Data, "m_iHealth", 0);

	SetEntProp(entity, Prop_Data, "m_lifeState", LIFE_DEAD);

	int solidflags = GetEntProp(entity, Prop_Send, "m_usSolidFlags");
	solidflags |= FSOLID_NOT_SOLID;
	SetEntProp(entity, Prop_Send, "m_usSolidFlags", solidflags);
}

static BehaviorResultType action_animcomplete(CustomBehaviorAction action, INextBot bot, int entity, Activity act, BehaviorResult result)
{
	CTakeDamageInfo dmginfo;
	action.get_data_array("m_dmgInfo", dmginfo, sizeof(CTakeDamageInfo));

	if(can_ragdoll(entity)) {
		CombatCharacterEventKilled(entity, dmginfo);
	} else {
		float time = sm_npcs_dead_decoration_time.FloatValue;
		if(time <= 0.0) {
			RequestFrame(frame_remove_npc, EntIndexToEntRef(entity));
		} else {
			CreateTimer(time, timer_remove_npc, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
		}
	}

	return result.TryDone(RESULT_CRITICAL);
}