local assets =
{
	Asset( "ANIM", "anim/ghost_kara_build.zip" ),
	Asset( "ANIM", "anim/kara.zip" ),
}

local skins =
{
	normal_skin = "kara",
	ghost_skin = "ghost_kara_build",
}

return CreatePrefabSkin("karaa_none",
{
	base_prefab = "kara",
	type = "base",
	assets = assets,
	skins = skins, 
	skin_tags = {"KARA", "CHARACTER", "BASE"},
	build_name_override = "kara",
	rarity = "Character",
})
