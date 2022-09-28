static void handle_fire(CustomBehaviorAction action, int entity, int victim, const float sight_pos[3])
{
	float attack_time = action.get_data("attack_time");
	if(attack_time < GetGameTime()) {
		int weapon = GetEntPropEnt(entity, Prop_Data, "m_hWeaponModel");
		if(weapon == -1) {
			return;
		}

		FireBulletsInfo_t bullets;
		bullets.Init();

		float muzzle_ang[3];
		AnimatingGetAttachment(weapon, hl2_pistol_muzzle, bullets.m_vecSrc, muzzle_ang);

		GetAngleVectors(muzzle_ang, bullets.m_vecDirShooting, NULL_VECTOR, NULL_VECTOR);

		bullets.m_vecSpread = view_as<float>({24.0, 24.0, 24.0});
		bullets.m_nFlags |= FIRE_BULLETS_TEMPORARY_DANGER_SOUND;
		bullets.m_pAttacker = entity;
		bullets.m_flDistance = GetVectorLength(bullets.m_vecDirShooting) + 100.0;
		bullets.m_iTracerFreq = 1;

		bullets.m_flDamage = sk_combine_dmg.FloatValue;
		bullets.m_iPlayerDamage = RoundToFloor(bullets.m_flDamage);

		FireBullets(entity, bullets);

		action.set_data("attack_time", GetGameTime() + 0.5);
	}
}

BehaviorAction hl2_combine_behavior(int entity)
{
	CustomBehaviorAction action = basic_range_action.create();
	action.set_function("handle_fire", handle_fire);
	return action;
}