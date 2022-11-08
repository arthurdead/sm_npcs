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
	IIntentionCustom intention_custom = view_as<IIntentionCustom>(bot.IntentionInterface);

	CKnownEntity closerThreat = select_closer_threat(bot, threat1, threat2);

	if(intention_custom.has_data("melee_only")) {
		return closerThreat;
	}

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
	int entity;
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

static bool IsFacingWithinTolerance(int entity, const float target_pos[3], float tolerance)
{
	float my_pos[3];
	EntityGetAbsOrigin(entity, my_pos);

	float ang[3];
	GetEntPropVector(entity, Prop_Data, "m_angAbsRotation", ang);

	float fwd[3];
	GetAngleVectors(ang, fwd, NULL_VECTOR, NULL_VECTOR);

	float dir[3];
	SubtractVectors(my_pos, target_pos, dir);
	NormalizeVector(dir, dir);

	float dot = GetVectorDotProduct(dir, fwd);
	if(dot >= tolerance) {
		return true;
	}

	return false;
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

				float eye[3];
				EntityEyePosition(retreat_influence_info.entity, eye);

				if(IsFacingWithinTolerance(entity, eye, 0.5)) {
					retreat_influence_info.m_foeScore += get_threat_danger(entity);
				}
			}
		}
	}

	return true;
}

static QueryResultType action_retreat(CustomBehaviorAction action, INextBot bot, int entity)
{
	IVision vision = bot.VisionInterface;

	retreat_influence_info.entity = entity;
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
	//TODO!!!! CanBotsAttackWhileInSpawnRoom

	return ANSWER_UNDEFINED;
}

static QueryResultType action_attack(CustomBehaviorAction action, INextBot bot, int entity, CKnownEntity them)
{
	//TODO!!!! CanBotsAttackWhileInSpawnRoom

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

static void update_looking_around_for_enemies(INextBot bot, int entity, IVision vision, IBody body)
{
	const float maxLookInterval = 1.0;

	CKnownEntity known = vision.GetPrimaryKnownThreat();
	if(known != CKnownEntity_Null) {
		int known_entity = known.Entity;

		if(known.VisibleInFOVNow) {
			body.AimHeadTowardsEnt(known_entity, CRITICAL, 1.0, INextBotReply_Null, "Aiming at a visible threat");
			return;
		}

		if(CombatCharacterIsLineOfSightClearEnt(entity, known_entity, IGNORE_ACTORS)) {
			float knowPos[3];
			EntityGetAbsOrigin(known_entity, knowPos);

			float myPos[3];
			bot.GetPosition(myPos);

			float toThreat[3];
			SubtractVectors(knowPos, myPos, toThreat);

			float threatRange = NormalizeVector(toThreat, toThreat);

			float aimError = FLOAT_PI/6.0;

			float s = Sine(aimError);
			float c = Cosine(aimError);

			float error = threatRange * s;

			float imperfectAimSpot[3];
			EntityWorldSpaceCenter(known_entity, imperfectAimSpot);

			imperfectAimSpot[0] += GetRandomFloat( -error, error );
			imperfectAimSpot[1] += GetRandomFloat( -error, error );

			body.AimHeadTowardsVec(imperfectAimSpot, IMPORTANT, 1.0, INextBotReply_Null, "Turning around to find threat out of our FOV");
			return;
		}

		//TODO!!!!!!
	#if 0
		CNavArea myArea = GetEntityLastKnownArea(entity);
		if(myArea != CNavArea_Null) {
			const CTFNavArea *closeArea = NULL;
			CFindClosestPotentiallyVisibleAreaToPos find( known->GetLastKnownPosition() );
			myArea->ForAllPotentiallyVisibleAreas( find );

			closeArea = find.m_closeArea;

			if ( closeArea )
			{
				// try to not look directly at walls
				const int retryCount = 10.0f;
				for( int r=0; r<retryCount; ++r )
				{
					Vector gazeSpot = closeArea->GetRandomPoint() + Vector( 0, 0, 0.75f * HumanHeight );

					if ( GetVisionInterface()->IsLineOfSightClear( gazeSpot ) )
					{
						// use maxLookInterval so these looks override body aiming from path following
						GetBodyInterface()->AimHeadTowards( gazeSpot, IBody::IMPORTANT, maxLookInterval, NULL, "Looking toward potentially visible area near known but hidden threat" );
						return;
					}
				}					

				// can't find a clear line to look along
				if ( IsDebugging( NEXTBOT_VISION | NEXTBOT_ERRORS ) )
				{
					ConColorMsg( Color( 255, 255, 0, 255 ), "%3.2f: %s can't find clear line to look at potentially visible near known but hidden entity %s(#%d)\n", 
									gpGlobals->curtime,
									GetDebugIdentifier(),
									known->GetEntity()->GetClassname(),
									known->GetEntity()->entindex() );
				}
			}
			else if ( IsDebugging( NEXTBOT_VISION | NEXTBOT_ERRORS ) )
			{
				ConColorMsg( Color( 255, 255, 0, 255 ), "%3.2f: %s no potentially visible area to look toward known but hidden entity %s(#%d)\n", 
								gpGlobals->curtime,
								GetDebugIdentifier(),
								known->GetEntity()->GetClassname(),
								known->GetEntity()->entindex() );
			}
		}
	#endif

		return;
	}

	update_looking_around_for_incoming_players(true);
}

static void update_looking_around_for_incoming_players(bool lookForEnemies)
{
	//TODO!!!!
#if 0
	if ( !m_lookAtEnemyInvasionAreasTimer.IsElapsed() )
		return;

	const float maxLookInterval = 1.0f;
	m_lookAtEnemyInvasionAreasTimer.Start( RandomFloat( 0.333f, maxLookInterval ) );

	float minGazeRange = m_Shared.InCond( TF_COND_ZOOMED ) ? 750.0f : 150.0f;

	CTFNavArea *myArea = GetLastKnownArea();
	if ( myArea )
	{
		int team = GetTeamNumber();

		// if we want to look where teammates come from, we need to pass in
		// the *enemy* team, since the method collects *enemy* invasion areas
		if ( !lookForEnemies )
		{
			team = GetEnemyTeam( team );
		}

		const CUtlVector< CTFNavArea * > &invasionAreaVector = myArea->GetEnemyInvasionAreaVector( team );

		if ( invasionAreaVector.Count() > 0 )
		{
			// try to not look directly at walls
			const int retryCount = 20.0f;
			for( int r=0; r<retryCount; ++r )
			{
				int which = RandomInt( 0, invasionAreaVector.Count()-1 );
				Vector gazeSpot = invasionAreaVector[ which ]->GetRandomPoint() + Vector( 0, 0, 0.75f * HumanHeight );

				if ( IsRangeGreaterThan( gazeSpot, minGazeRange ) && GetVisionInterface()->IsLineOfSightClear( gazeSpot ) )
				{
					// use maxLookInterval so these looks override body aiming from path following
					GetBodyInterface()->AimHeadTowards( gazeSpot, IBody::INTERESTING, maxLookInterval, NULL, "Looking toward enemy invasion areas" );
					break;
				}
			}
		}
	}
#endif
}

static void fire_weapon_at_enemy(INextBot bot, int entity, IBody body, IVision vision, IIntentionCustom intention_custom)
{
	CKnownEntity threat = vision.GetPrimaryKnownThreat();
	if(threat == CKnownEntity_Null || threat.Entity == -1 || !threat.VisibleRecently) {
		return;
	}

	int threat_entity = threat.Entity;

	float sight_pos[3];
	EntityWorldSpaceCenter(threat_entity, sight_pos);
	if(!bot.IsLineOfFireClearVec(sight_pos)) {
		EntityEyePosition(threat_entity, sight_pos);
		if(!bot.IsLineOfFireClearVec(sight_pos)) {
			EntityGetAbsOrigin(threat_entity, sight_pos);
			if(!bot.IsLineOfFireClearVec(sight_pos)) {
				return;
			}
		}
	}

	if(intention_custom.ShouldAttack(bot, threat) == ANSWER_NO) {
		return;
	}

	float my_pos[3];
	bot.GetPosition(my_pos);

	float threat_pos[3];
	EntityGetAbsOrigin(threat_entity, threat_pos);

	float to_threat[3];
	SubtractVectors(my_pos, threat_pos, to_threat);

	bool melee = intention_custom.has_data("melee_only");

	float max_attack_range = 0.0;

	if(melee) {
		max_attack_range = 100.0;
	} else {
		max_attack_range = 9999999.0;
	}

	float threatRange = GetVectorLength(to_threat);
	if(body.HeadAimingOnTarget && threatRange < max_attack_range) {
		Handle pl;
		Function func = intention_custom.get_function("handle_weapon_fire", pl);
		if(func != INVALID_FUNCTION && pl != null) {
			Call_StartFunction(pl, func);
			Call_PushCell(intention_custom);
			Call_PushCell(bot);
			Call_PushCell(entity);
			Call_PushCell(threat_entity);
			Call_PushArray(sight_pos, 3);
			Call_Finish();
		}
	}
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	IVision vision = bot.VisionInterface;
	IBody body = bot.BodyInterface;
	IIntention intention = bot.IntentionInterface;
	IIntentionCustom intention_custom = view_as<IIntentionCustom>(intention);

	if(entity_is_alive(entity)) {
		update_looking_around_for_enemies(bot, entity, vision, body);

		fire_weapon_at_enemy(bot, entity, body, vision, intention_custom);
	}

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
	IIntentionCustom intention_custom = view_as<IIntentionCustom>(bot.IntentionInterface);

	vision.ForgetEntity(victim);

	int attacker = dmginfo.m_hAttacker;
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

	if(intention_custom.has_data("can_taunt")) {
		if(bot.IsEnemy(victim) && bot.IsSelf(attacker)) {
			if(GetRandomFloat(0.0, 100.0) <= tf_bot_taunt_victim_chance.FloatValue) {
				BehaviorAction next_action = taunt_action.create();
				return result.TrySuspendFor(next_action, RESULT_IMPORTANT, "Taunting our victim");
			}
		}
	}

	return result.TryContinue();
}