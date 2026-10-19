local assets =
{
	Asset( "ANIM", "anim/kara.zip" ),
	Asset( "ANIM", "anim/ghost_kara_build.zip" ),
}

local skins =
{
	normal_skin = "kara",
	ghost_skin = "ghost_kara_build",
}

return CreatePrefabSkin("kara_none",
{
	base_prefab = "kara",
	type = "base",
	assets = assets,
	skins = skins, 
	skin_tags = {"kara", "CHARACTER", "BASE"},
	build_name_override = "kara",
	rarity = "Character",
})