CustomBehaviorActionEntry attack_action;

void attack_action_init()
{
	attack_action = new CustomBehaviorActionEntry("Attack");
	attack_action.set_function("OnStart", action_start);
	attack_action.set_function("OnEnd", action_end);
	attack_action.set_function("Update", action_update);
}

static BehaviorResultType action_start(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction prior, BehaviorResult result)
{
	ChasePath chasePath = new ChasePath(LEAD_SUBJECT);
	action.set_data("m_chasePath", chasePath);

	PathFollower path = new PathFollower();
	action.set_data("m_path", path);

	action.set_data("m_repathTimer", GetGameTime());

	return result.Continue();
}

static void action_end(CustomBehaviorAction action, INextBot bot, int entity, BehaviorAction next)
{
	ChasePath chasePath = action.get_data("m_chasePath");
	delete chasePath;

	PathFollower path = action.get_data("m_path");
	delete path;
}

static BehaviorResultType action_update(CustomBehaviorAction action, INextBot bot, int entity, float interval, BehaviorResult result)
{
	IVision vision = bot.VisionInterface;
	IIntention intention = bot.IntentionInterface;

	CKnownEntity threat = vision.GetPrimaryKnownThreat();
	if(threat == CKnownEntity_Null || threat.Obsolete || intention.ShouldAttack(bot, threat) == ANSWER_NO) {
		return result.Done("No threat");
	}

	int threat_entity = threat.Entity;

	float threat_pos[3];
	EntityGetAbsOrigin(threat_entity, threat_pos);

	float threat_eye_pos[3];
	EntityEyePosition(threat_entity, threat_eye_pos);

	float attack_range = 500.0;

	if(!threat.VisibleRecently ||
		bot.IsRangeGreaterThanVector(threat_pos, attack_range)
		//|| !bot.IsLineOfFireClearVec(threat_eye_pos)
	)
	{
		ChasePath chasePath = action.get_data("m_chasePath");

		if(threat.VisibleRecently) {
			chasePath.Update(bot, threat_entity, baseline_path_cost, 0);
		} else {
			PathFollower path = action.get_data("m_path");

			chasePath.Invalidate();

			float last_known_pos[3];
			threat.GetLastKnownPosition(last_known_pos);

			if(bot.IsRangeLessThanVector(last_known_pos, 20.0)) {
				vision.ForgetEntity(threat_entity);
				return result.Done("I lost my target!");
			}

			path.Update(bot);

			float repathTimer = action.get_data("m_repathTimer");
			if(repathTimer <= GetGameTime()) {
				repathTimer = GetRandomFloat(3.0, 5.0);
				action.set_data("m_repathTimer", repathTimer);

				path.ComputeVector(bot, last_known_pos, baseline_path_cost, 0);
			}
		}
	}

	return result.Continue();
}