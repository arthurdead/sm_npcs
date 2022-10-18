CustomBehaviorActionEntry main_action;

void main_action_init()
{
	main_action = new CustomBehaviorActionEntry("Main");
	main_action.set_function("OnStart", action_start);
	main_action.set_function("Update", action_update);
	main_action.set_function("OnKilled", action_killed);
	main_action.set_function("OnInjured", action_injured);
	main_action.set_function("OnOtherKilled", action_other_killed);
	main_action.set_function("OnContact", action_contact);
	main_action.set_function("InitialContainedAction", action_containedaction);
	main_action.set_function("SelectTargetPoint", action_targetpoint);
	main_action.set_function("IsPositionAllowed", action_posallowed);
	main_action.set_function("ShouldAttack", action_attack);
	main_action.set_function("ShouldHurry", action_hurry);
	main_action.set_function("ShouldRetreat", action_retreat);
	main_action.set_function("SelectMoreDangerousThreat", action_treat);
}

static bool is_immediate_threat(INextBot bot, int entity, CKnownEntity threat)
{
	int threat_entity = threat.Entity;

	if(TeamManager_AreEntitiesFriends(entity, threat_entity)) {
		return false;
	}

	if(!entity_is_alive(threat_entity)) {
		return false;
	}

	if(!threat.VisibleRecently) {
		return false;
	}

	if(!bot.IsLineOfFireClearEnt(threat_entity)) {
		return false;
	}

	int threat_player = (threat_entity >= 1 && threat_entity <= MaxClients) ? threat_entity : -1;

	float to[3];
	threat.GetLastKnownPosition(to);

	float from[3];
	bot.GetPosition(from);

	SubtractVectors(from, to, to);
	float threatRange = NormalizeVector(to, to);

	const float nearbyRange = 500.0;
	if(threatRange < nearbyRange) {
		return true;
	}

	//TODO!!!!
#if 0
	if(bot.IsThreatFiringAtMe(threat_entity)) {
		return true;
	}
#endif

	if(threat_player == -1) {
		int sentry = -1;

		if(EntityIsBaseObject(threat_entity)) {
			if(view_as<TFObjectType>(GetEntProp(threat_entity, Prop_Send, "m_iObjectType")) == TFObject_Sentry) {
				sentry = threat_entity;
			}
		}

		if(sentry != -1) {
			
		}

		return false;
	}

	TFClassType threat_class = TF2_GetPlayerClass(threat_player);

	switch(threat_class) {
		case TFClass_Sniper: {
			float eyeang[3];
			GetClientEyeAngles(threat_player, eyeang);

			float sniperForward[3];
			GetAngleVectors(eyeang, sniperForward, NULL_VECTOR, NULL_VECTOR);

			if(GetVectorDotProduct(to, sniperForward) > 0.0) {
				return true;
			}

			return false;
		}
		case TFClass_Medic: {
			return true;
		}
		case TFClass_Engineer: {
			return true;
		}
	}

	return false;
}

static CKnownEntity select_closer_threat(INextBot bot, CKnownEntity threat1, CKnownEntity threat2)
{
	float rangeSq1 = bot.GetRangeSquaredToEntity(threat1.Entity);
	float rangeSq2 = bot.GetRangeSquaredToEntity(threat2.Entity);

	if(rangeSq1 < rangeSq2) {
		return threat1;
	}

	return threat2;
}

static CKnownEntity action_treat(CustomBehaviorAction action, INextBot bot, int entity, int subject, CKnownEntity threat1, CKnownEntity threat2)
{
	CKnownEntity closerThreat = select_closer_threat(bot, threat1, threat2);

	bool isImmediateThreat1 = is_immediate_threat(bot, entity, threat1);
	bool isImmediateThreat2 = is_immediate_threat(bot, entity, threat2);

	if(isImmediateThreat1 && !isImmediateThreat2) {
		return threat1;
	} else if(!isImmediateThreat1 && isImmediateThreat2) {
		return threat2;
	} else if(!isImmediateThreat1 && !isImmediateThreat2) {
		return closerThreat;
	}

	//TODO!!!!
#if 0
	if(bot.IsThreatFiringAtMe(threat1.Entity)) {
		if(bot.IsThreatFiringAtMe(threat2.Entity)) {
			return closerThreat;
		}

		return threat1;
	} else if(bot.IsThreatFiringAtMe(threat2.Entity)) {
		return threat2;
	}
#endif

	return closerThreat;
}

enum struct RetreatInfluenceInfo
{
	INextBot bot;
	float m_friendScore;
	float m_foeScore;
}

static RetreatInfluenceInfo retreat_influence_info;

static float get_threat_danger(int entity)
{
	if(entity >= 1 && entity <= MaxClients) {
		if(entity_is_invunerable(entity)) {
			return 1.0;
		}

		TFClassType class = TF2_GetPlayerClass(entity);
		switch(class) {
			case TFClass_Medic: {
				return 0.2;
			}
			case TFClass_Engineer, TFClass_Sniper: {
				return 0.4;
			}
			case TFClass_Scout, TFClass_Spy, TFClass_DemoMan: {
				return 0.4;
			}
			case TFClass_Soldier, TFClass_Heavy: {
				return 0.8;
			}
			case TFClass_Pyro: {
				return 1.0;
			}
		}
	} else {
		int sentry = -1;

		if(EntityIsBaseObject(entity)) {
			if(view_as<TFObjectType>(GetEntProp(entity, Prop_Send, "m_iObjectType")) == TFObject_Sentry) {
				sentry = entity;
			}
		}

		if(sentry != -1) {
			
		}
	}

	return 0.0;
}

static bool retreat_influence(CKnownEntity known, any data)
{
	int entity = known.Entity;
	if(entity_is_alive(entity)) {
		const float nearRange = 750.0;
		if(retreat_influence_info.bot.IsRangeLessThanEntity(entity, nearRange)) {
			if(retreat_influence_info.bot.IsFriend(entity)) {
				retreat_influence_info.m_friendScore += get_threat_danger(entity);
			} else if(known.WasEverVisible && known.TimeSinceLastSeen < 3.0 && retreat_influence_info.bot.IsEnemy(entity)) {
				IVision vision = retreat_influence_info.bot.VisionInterface;
				if(vision.IsIgnored(entity)) {
					return true;
				}

				//TODO!!!
			#if 0
				if(UTIL_IsFacingWithinTolerance(entity, m_me->EyePosition(), 0.5)) {
					retreat_influence_info.m_foeScore += get_threat_danger(entity);
				}
			#endif
			}
		}
	}

	return true;
}

static QueryResultType action_retreat(CustomBehaviorAction action, INextBot bot, int entity)
{
	IVision vision = bot.VisionInterface;

	retreat_influence_info.bot = bot;
	retreat_influence_info.m_friendScore = 0.0;
	retreat_influence_info.m_foeScore = 0.0;
	vision.ForEachKnownEntity(retreat_influence);

	if(retreat_influence_info.m_friendScore < retreat_influence_info.m_foeScore) {
		return ANSWER_YES;
	}

	return ANSWER_NO;
}

static QueryResultType action_hurry(CustomBehaviorAction action, INextBot bot, int entity)
{
	return ANSWER_UNDEFINED;
}

static QueryResultType action_attack(CustomBehaviorAction action, INextBot bot, int entity, CKnownEntity them)
{
	return ANSWER_YES;
}

static QueryResultType action_posallowed(CustomBehaviorAction action, INextBot bot, int entity, const float pos[3])
{
	return ANSWER_YES;
}

static void action_targetpoint(CustomBehaviorAction action, INextBot bot, int entity, int subject, float pos[3])
{
	if(EntityIsBaseObject(subject)) {
		if(view_as<TFObjectType>(GetEntProp(subject, Prop_Send, "m_iObjectType")) == TFObject_Sentry) {
			EntityGetAbsOrigin(subject, pos);

			float offset[3];
			GetEntPropVector(subject, Prop_Data, "m_vecViewOffset", offset);

			ScaleVector(offset, 0.5);

			AddVectors(pos, offset, pos);
			return;
		}
	}

	EntityWorldSpaceCenter(subject, pos);
}

static BehaviorAction action_containedaction(CustomBehaviorAction action, INextBot bot, int entity)
{
	BehaviorAction next_action = tactical_monitor_action.create();
	return next_action;
}

static BehaviorResultType action_contact(CustomBehaviorAction action, INextBot bot, int entity, int other, BehaviorResult result)
{
	if(other != -1) {
		int solidflags = GetEntProp(other, Prop_Send, "m_usSolidFlags");
		if(!(solidflags & FSOLID_NOT_SOLID) && other != 0 && other > 33) {
			action.set_data("m_lastTouch", EntIndexToEntRef(other));
			action.set_data("m_lastTouchTime", GetGameTime());
		}
	}

	return result.TryContinue();
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	action.set_data("m_lastTouch", INVALID_ENT_REFERENCE);
	action.set_data("m_lastTouchTime", 0.0);

	if(!entity_is_alive(entity)) {
		CustomBehaviorAction next_action = dead_action.create();
		CTakeDamageInfo dmginfo;
		dmginfo.Init(-1, -1, 0.0, 0, 0);
		next_action.set_data_array("m_dmgInfo", dmginfo, sizeof(CTakeDamageInfo));
		return result.ChangeTo(next_action, "I'm actually dead");
	}

	return result.Continue();
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	return result.Continue();
}

static BehaviorResultType action_killed(CustomBehaviorAction action, INextBot bot, int entity, const CTakeDamageInfo info, BehaviorResult result)
{
	CustomBehaviorAction next_action = dead_action.create();
	next_action.set_data_array("m_dmgInfo", info, sizeof(CTakeDamageInfo));
	return result.TryChangeTo(next_action, RESULT_CRITICAL, "I died!");
}

static BehaviorResultType action_injured(CustomBehaviorAction action, INextBot bot, int entity, const CTakeDamageInfo dmginfo, BehaviorResult result)
{
	IVision vision = bot.VisionInterface;

	int subject = -1;

	int inflictor = dmginfo.m_hInflictor;
	if(inflictor != -1) {
		if(EntityIsBaseObject(inflictor)) {
			subject = inflictor;
		}
	}

	int attacker = dmginfo.m_hAttacker;

	if(subject == -1) {
		subject = attacker;
	}

	vision.AddKnownEntity(subject);

	if(inflictor != -1 && !TeamManager_AreEntitiesFriends(inflictor, entity)) {
		int sentry = -1;

		if(EntityIsBaseObject(inflictor)) {
			if(view_as<TFObjectType>(GetEntProp(inflictor, Prop_Send, "m_iObjectType")) == TFObject_Sentry) {
				sentry = inflictor;
			}
		}

		EntityNPCInfo npcinfo;
		get_npc_info(entity, npcinfo);

		if(sentry != -1) {
			float my_pos[3];
			bot.GetPosition(my_pos);

			npcinfo.remember_enemy_sentry(sentry, my_pos);
		}

		if(dmginfo.m_iDamageCustom == TF_CUSTOM_BACKSTAB) {
			npcinfo.delayed_threat_notice(inflictor, 0.5);

			//TODO!!!! loop friends and notify about stab
		} else if(attacker != -1 && (dmginfo.m_bitsDamageType & DMG_CRITICAL) && (dmginfo.m_bitsDamageType & DMG_BURN)) {
			if(bot.GetRangeToEntity(attacker) < tf_bot_notice_backstab_max_range.FloatValue) {
				npcinfo.delayed_threat_notice(attacker, 0.5);
			}
		}
	}

	return result.TryContinue();
}

static BehaviorResultType action_other_killed(CustomBehaviorAction action, INextBot bot, int entity, int victim, const CTakeDamageInfo dmginfo, BehaviorResult result)
{
	IVision vision = bot.VisionInterface;

	vision.ForgetEntity(victim);

	int inflictor = dmginfo.m_hInflictor;

	float victim_center[3];
	EntityWorldSpaceCenter(victim, victim_center);

	if(inflictor != -1 && bot.IsFriend(victim) && bot.IsEnemy(inflictor) && CombatCharacterIsLineOfSightClearVec(entity, victim_center)) {
		int sentry = -1;

		if(EntityIsBaseObject(inflictor)) {
			if(view_as<TFObjectType>(GetEntProp(inflictor, Prop_Send, "m_iObjectType")) == TFObject_Sentry) {
				sentry = inflictor;
			}
		}

		if(sentry != -1) {
			EntityNPCInfo npcinfo;
			get_npc_info(entity, npcinfo);

			int enemy_sentry = npcinfo.get_enemy_sentry();
			if(enemy_sentry == -1) {
				float victim_pos[3];
				EntityGetAbsOrigin(victim, victim_pos);

				npcinfo.remember_enemy_sentry(sentry, victim_pos);
			}
		}
	}

	return result.TryContinue();
}