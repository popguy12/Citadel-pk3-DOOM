class CitadelWeapon : Weapon
{ 
	States
	{
		//Select and Ready states will be shared across all weapons
		Deselect:
			TNT1 A 1 Citadel_LowerWeapon;
			Loop;
			
		Select:
			TNT1 A 1 Citadel_RaiseWeapon;
			Wait;
		Ready:
			TNT1 A 1;
			Goto WeaponReady;
		/*[Pop] Note on extra timings per weapon type
		Pistols have no delay
		SMG and Shotgun class weapons have 6 tic delay
		Rifle, DMR, and Sniper weapons have 12 tic delay
		Assault Rifle and Battle Rifle class weapons have 10 tic delay
		LMGs and above have 16 tic delay.
		*/
		
		//Dummy state for loading alternative sprites into virtual memory
		LoadAlternativeSprites:
			TNT1 A 1;
			Stop;
		WeaponReady:
			TNT1 A 1 Citadel_WeaponReady();
			Loop;
		Fire:
			TNT1 A 1;
			Goto WeaponReady;
		
		User1: //replaces BD Weapon Special (which is firemode here) attachment swap will have to be handled on a newly bound one
			TNT1 A 1;
			Goto WeaponReady;
			
		//Special Handling States
		User4:
			TNT1 A 0;
			Goto Ready;
		
		User2:
			TNT1 A 0;
			Goto Ready;
		
		User3:
		KnifeAttack:
			TNT1 A 0 A_StartSound("melee/knife/slash", 0, CHANF_OVERLAP, 1);
			KNI9 AB 1;
			KNI9 CDEF 1 A_CustomPunch(12, 1, CPF_PULLIN | CPF_NOTURN, "BulletPuff", 64, 0, 0, "BasicArmorBonus", "melee/knife/hit");
			KNI9 GHI 1;
			TNT1 A 0 A_Jump(256, "Ready");
			Goto Ready;
		
		FragGrenade:
			TNT1 A 0
			{
				A_ZoomFactor(1);
				A_ClearOverlays(-2, -2);
			}
			TNT1 A 0 A_TakeInventory("AimingToken");
			FRGA ABCDEFGHI 1;
			FRGA JK 2;
			TNT1 A 0 A_StartSound("grenade/pinpull", 0, CHANF_OVERLAP, 1);
			FRGA LMN 2;
			FRGA O 4;
			TNT1 A 0 A_StartSound("grenade/throw", 0, CHANF_OVERLAP, 1);
			FRGA PQR 2;
			TNT1 A 0
			{
				A_FireCustomMissile("ThrownGrenade");
				A_TakeInventory("ThrowGrenade", 1);
				A_TakeInventory("GrenadeAmmo", 1);
			}
			FRGA STUV 1;
			FRGA WX 2;
			TNT1 A 0 A_Jump(256, "Ready");
			Goto Ready;
		
		StunGrenade:
			TNT1 A 0
			{
				A_ZoomFactor(1);
				A_ClearOverlays(-2, -2);
			}
			TNT1 A 0 A_TakeInventory("AimingToken");
			FRGA ABCDEFGHI 1;
			FRGA JK 2;
			TNT1 A 0 A_StartSound("flash/pinpull", 0, CHANF_OVERLAP, 1);
			FRGA LMN 2;
			FRGA O 4;
			TNT1 A 0 A_StartSound("flash/throw", 0, CHANF_OVERLAP, 1);
			FRGA PQR 2;
			TNT1 A 0
			{
				A_FireCustomMissile("ThrownBang");
				A_TakeInventory("ThrowBang", 1);
				A_TakeInventory("BangAmmo", 1);
			}
			FRGA STUV 1;
			FRGA WX 2;
			TNT1 A 0 A_Jump(256, "Ready");
			Goto Ready;
		
		//Reticles
		ReticleEOTECH:
			TNT1 A 0;
			TNT1 A 0
			{
				A_OverlayFlags(-2, PSPF_ADDBOB, false);
			}
			G36C X 35;
			Loop;
		ReticleACOG:
			TNT1 A 0;
			TNT1 A 0
			{
				A_OverlayFlags(-2, PSPF_ADDBOB, false);
			}
			SCAC X 35;
			Loop;
		
		//Muzzle Flashes
		MuzzleSmall:
			TNT1 A 0 A_Jump(256, "S1", "S2", "S3", "S4", "S5");
		S1:
			WMFS AA 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		S2:
			WMFS BB 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		S3:
			WMFS CC 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		S4:
			WMFS DD 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		S5:
			WMFS EE 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
			
		MuzzleMedium:
			TNT1 A 0 A_Jump(256, "M1", "M2", "M3", "M4");
			TNT1 A 0 A_OverlayScale(-3, 2.0, 2.0);
		M1:
			WMFM AA 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		M2:
			WMFM BB 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		M3:
			WMFM CC 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		M4:
			WMFM DD 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
			
		MuzzleSuppressed:
			TNT1 A 0 A_Jump(256, "B1", "B2", "B3", "B4");
		B1:
			WMFM AA 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		B2:
			WMFM BB 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		B3:
			WMFM CC 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
		B4:
			WMFM DD 1 A_OverlayAlpha(-3, alpha-0.5);
			Stop;
			
	}
}

Class PlayerMuzzleFlash : Actor
{
	Default
	{
		Speed 0;
		PROJECTILE;
		+NOCLIP;
		+NOGRAVITY;
		+NOINTERACTION;
	}
	
	States
	{
		Spawn:
			TNT1 A 2 BRIGHT;
			Stop;
	}
}

class AimingToken : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}

class ThrowGrenade : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}

class ThrowBang : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}

class DoAttachment : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}