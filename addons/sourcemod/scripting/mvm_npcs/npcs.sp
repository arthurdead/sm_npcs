#include "deadnaut/npc.sp"

void mvm_npcs_init()
{
	mvm_deadnaut_init();
}

void mvm_npcs_precache(int entity)
{
	mvm_deadnaut_precache(entity);
}

void mvm_npcs_entity_created(int entity, const char[] classname)
{
	if(StrContains(classname, "npc_mvm_deadnaut") != -1) {
		mvm_deadnaut_created(entity);
	}
}

void mvm_npcs_entity_destroyed(int entity, const char[] classname)
{
	
}

void mvm_npcs_plugin_end()
{
	remove_entities_of_classname("npc_mvm_deadnaut*");
}