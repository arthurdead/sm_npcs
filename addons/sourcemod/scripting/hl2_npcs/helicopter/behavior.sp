static void handle_fire(BehaviorAction action, int entity, int victim)
{
	float attack_time = action.get_data("attack_time");
	if(attack_time < GetGameTime()) {
		float muzzle[3];
		AnimatingGetAttachment(entity, hl2_helicopter_muzzle, muzzle);

		float victim_center[3];
		EntityWorldSpaceCenter(victim, victim_center);

		FireBulletsInfo_t bullets;
		bullets.Init();
		bullets.m_vecSpread = view_as<float>({45.0, 45.0, 45.0});
		bullets.m_vecSrc = muzzle;
		SubtractVectors(victim_center, muzzle, bullets.m_vecDirShooting);
		bullets.m_nFlags |= FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
		bullets.m_pAttacker = entity;
		bullets.m_flDistance = GetVectorLength(bullets.m_vecDirShooting) + 100.0;
		bullets.m_iTracerFreq = 1;

		FireBullets(entity, bullets);

		action.set_data("attack_time", GetGameTime() + 0.1);
	}
}

BehaviorAction hl2_helicopter_behavior(int entity)
{
	BehaviorAction action = basic_range_action.create();
	action.set_function("handle_fire", handle_fire);
	return action;
}