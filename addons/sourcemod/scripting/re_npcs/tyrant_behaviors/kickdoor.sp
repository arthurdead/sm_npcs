void tyrant_kickdoor_init()
{
	tyrant_kickdoor = new BehaviorActionEntry("tyrant_kickdoor");
	tyrant_kickdoor.set_function("Update", TyrantKickDoorUpdate);
	tyrant_kickdoor.set_function("OnStart", TyrantKickDoorStart);
	tyrant_kickdoor.set_function("OnEnd", TyrantKickDoorEnd);
	tyrant_kickdoor.set_function("OnMoveToSuccess", TyrantKickDoorMoveToSucc);
}

stock float test_path_cost(INextBot bot, CNavArea area, CNavArea fromArea, CNavLadder ladder, Address elevator, float length, baseline_cost_flags flags)
{
	if(fromArea == CNavArea_Null) {
		return 0.0;
	}

	ILocomotion locomotion = bot.LocomotionInterface;

	if(!locomotion.IsAreaTraversable(area)) {
		return -1.0;
	}

	float dist = 0.0;
	if(ladder != CNavLadder_Null) {
		dist = ladder.Length;
	} else if(length > 0.0) {
		dist = length;
	} else {
		float pos1[3];
		area.GetCenter(pos1);

		float pos2[3];
		fromArea.GetCenter(pos2);

		float sub[3];
		SubtractVectors(pos1, pos2, sub);

		dist = GetVectorLength(sub);
	}

	float cost = dist + fromArea.CostSoFar;

	return cost;
}

BehaviorResultType TyrantKickDoorStart(BehaviorAction action, int entity, BehaviorAction prior, BehaviorResult result)
{
	int door = EntRefToEntIndex(action.get_data("entity"));
	if(door == -1) {
		result.set_reason("door deleted");
		return BEHAVIOR_DONE;
	}

	float center[3];
	GetDoorCenter(door, center);
	action.set_data_array("center", center, 3);

	PathFollower path = base_npc_create_follower(entity);
	action.set_data("path", path);
	action.set_data("reached", false);
	action.set_data("repath", 0.0);

	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantKickDoorMoveToSucc(BehaviorAction action, int entity, BehaviorResult result)
{
	action.set_data("reached", true);
	return BEHAVIOR_CONTINUE;
}

BehaviorResultType TyrantKickDoorUpdate(BehaviorAction action, int entity, float interval, BehaviorResult result)
{
	INextBot bot = INextBot(entity);

	PathFollower path = action.get_data("path");

	int door = EntRefToEntIndex(action.get_data("entity"));

	if(GetEntProp(entity, Prop_Send, "m_nSequence") != 15) {
		if(door == -1) {
			result.set_reason("door deleted");
			result.action = tyrant_chase.create();
			result.action.set_data("target", INVALID_ENT_REFERENCE);
			return BEHAVIOR_CHANGE_TO;
		}
	}

	if(door != -1) {
		if(GetEntProp(door, Prop_Data, "m_eDoorState") != 0) {
			result.set_reason("door opened");
			result.action = tyrant_chase.create();
			result.action.set_data("target", INVALID_ENT_REFERENCE);
			return BEHAVIOR_CHANGE_TO;
		}
	}

	/*float wtf[3];
	action.get_data_array("center", wtf, 3);
	DrawHull(wtf);

	if(door != -1) {
		GetOffsetToDoor(entity, door, wtf, 110.0);
		DrawHull(wtf);
	}*/

	if(!action.get_data("reached")) {
		if(door != -1) {
			if(action.get_data("repath") <= GetGameTime()) {
				float pos[3];
				action.get_data_array("center", pos, 3);

				GetOffsetToDoor(entity, door, pos, 110.0);

				if(!path.ComputeVector(bot, pos, test_path_cost, 0)) {
					result.set_reason("cant path");
					result.action = tyrant_chase.create();
					result.action.set_data("target", INVALID_ENT_REFERENCE);
					return BEHAVIOR_CHANGE_TO;
				}

				action.set_data("repath", GetGameTime() + 5.0);
			}
		}

		path.Update(bot);
		TyrantWalking(bot, entity, door);
	} else {
		ILocomotion locomotion = bot.LocomotionInterface;

		bool facingdoor = false;

		float pos[3];
		if(door != -1) {
			action.get_data_array("center", pos, 3);

			locomotion.FaceTowards(pos);

			IVision vis = bot.VisionInterface;
			facingdoor = vis.IsInFieldOfViewVector(pos);
		} else {
			facingdoor = true;
		}

		if(facingdoor) {
			BaseAnimating anim = BaseAnimating(entity);

			anim.ResetSequenceEx(15);

			bool finished = false;
			if(anim.GetSequenceMovement(finished, pos)) {
				float origin[3];
				GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);

				ScaleVector(pos, 0.1);

				AddVectors(origin, pos, pos);

				locomotion.DriveTo(pos);
			}

			float cycle = GetEntPropFloat(entity, Prop_Send, "m_flCycle");
			if(cycle >= 0.5 && cycle <= 0.6) {
				if(door != -1) {
					OpenDoorAwayFrom(door, entity);
					action.set_data("entity", INVALID_ENT_REFERENCE);
				}
			}

			if(finished) {
				result.set_reason("door kicked");
				result.action = tyrant_chase.create();
				result.action.set_data("target", INVALID_ENT_REFERENCE);
				return BEHAVIOR_CHANGE_TO;
			}
		}
	}

	return BEHAVIOR_CONTINUE;
}

void TyrantKickDoorEnd(BehaviorAction action, int entity, BehaviorAction next)
{
	PathFollower path = action.get_data("path");
	delete path;
}