static void handle_fire(CustomBehaviorAction action, int entity, int victim)
{
	float attack_time = action.get_data("attack_time");
	if(attack_time < GetGameTime()) {
		FireBulletsInfo_t bullets;
		bullets.Init();

		float muzzle_ang[3];
		AnimatingGetAttachment(entity, hl2_helicopter_muzzle, bullets.m_vecSrc, muzzle_ang);

		GetAngleVectors(muzzle_ang, bullets.m_vecDirShooting, NULL_VECTOR, NULL_VECTOR);

		bullets.m_vecSpread = view_as<float>({1.0, 1.0, 1.0});
		bullets.m_nFlags |= FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
		bullets.m_pAttacker = entity;
		bullets.m_flDistance = GetVectorLength(bullets.m_vecDirShooting) + 100.0;
		bullets.m_iTracerFreq = 1;

		bullets.m_flDamage = sk_helicopter_dmg.FloatValue;
		bullets.m_iPlayerDamage = RoundToFloor(bullets.m_flDamage);

		FireBullets(entity, bullets);

		action.set_data("attack_time", GetGameTime() + 0.1);
	}
}

BehaviorAction hl2_helicopter_behavior(int entity)
{
	CustomBehaviorAction action = basic_range_action.create();
	action.set_function("handle_fire", handle_fire);
	return action;
}