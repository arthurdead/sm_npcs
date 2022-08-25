//#include "hans_volter/hans_volter.sp"

#include "cyst/npc.sp"
#include "clot/npc.sp"
//#include "scrake/npc.sp"

void kf2_npcs_init()
{
	//hans_volter_init();

	kf2_cyst_init();
	kf2_clot_init();
	//kf2_scrake_init();
}

void kf2_npcs_precache(int entity)
{
	//hans_volter_precache(entity, anim);

	kf2_cyst_precache(entity);
	kf2_clot_precache(entity);
	//kf2_scrake_precache(entity);
}

void kf2_npcs_entity_created(int entity, const char[] classname)
{
	/*if(StrEqual(classname, "npc_hans_volter")) {
		//hans_volter_created(entity);
	} else*/ if(StrEqual(classname, "npc_kf2_cyst")) {
		kf2_cyst_created(entity);
	} else if(StrEqual(classname, "npc_kf2_clot")) {
		kf2_clot_created(entity);
	} else if(StrEqual(classname, "npc_kf2_scrake")) {
		//kf2_scrake_created(entity);
	}
}

stock void kf2_npcs_entity_destroyed(int entity, const char[] classname)
{
	/*if(StrEqual(classname, "npc_hans_volter")) {
		//hans_volter_destroyed(entity);
	}*/
}

void kf2_npcs_plugin_end()
{
	//remove_entities_of_classname("npc_hans_volter");
	remove_entities_of_classname("npc_kf2_cyst");
	remove_entities_of_classname("npc_kf2_clot");
	remove_entities_of_classname("npc_kf2_scrake");
}