AddCSLuaFile()

SWEP.PrintName 				= "Satellite Mapping Utility"

SWEP.Category 				= "Pointcloud"

SWEP.Author 				= "TankNut"
SWEP.Instructions 			= [[Point up at the sky and fire to start a surface scan

Primary: Start scan
Secondary: Abort scan]]

SWEP.Slot 					= 2

SWEP.Spawnable 				= true

SWEP.ViewModel 				= Model("models/weapons/c_irifle.mdl")
SWEP.WorldModel 			= Model("models/weapons/w_irifle.mdl")

SWEP.UseHands 				= true
SWEP.ViewModelFOV 			= 54

SWEP.Primary.ClipSize 		= -1
SWEP.Primary.DefaultClip 	= -1
SWEP.Primary.Ammo 			= ""
SWEP.Primary.Automatic 		= false

SWEP.Secondary.ClipSize 	= -1
SWEP.Secondary.DefaultClip 	= -1
SWEP.Secondary.Ammo 		= ""
SWEP.Secondary.Automatic 	= false

function SWEP:Deploy()
	self:SetHoldType("ar2")
end

function SWEP:PrimaryAttack()
	if game.SinglePlayer() then
		self:CallOnClient("PrimaryAttack")
	end

	local ply = self:GetOwner()

	ply:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	if CLIENT and ply == LocalPlayer() then
		pointcloud.Sampler.Mode:SetInt(POINTCLOUD_SAMPLE_SATMAP)

		local tr = ply:GetEyeTrace()

		pointcloud.Sampler.z = (tr.HitPos + (tr.HitNormal * pointcloud:GetResolution())).z
	end
end

function SWEP:SecondaryAttack()
	if game.SinglePlayer() then
		self:CallOnClient("SecondaryAttack")
	end

	local ply = self:GetOwner()

	ply:SetAnimation(PLAYER_ATTACK1)
	self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)

	if CLIENT and ply == LocalPlayer() and pointcloud.Sampler.Mode:GetInt() == POINTCLOUD_SAMPLE_SATMAP then
		pointcloud.Sampler.Mode:SetInt(POINTCLOUD_SAMPLE_NONE)
	end
end
