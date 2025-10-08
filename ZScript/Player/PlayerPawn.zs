class CitadelPlayer : DoomPlayer
{
	action bool PressingCrouch(){return player.cmd.buttons & BT_CROUCH;}
	
	action bool JustReleased(int which)
    {
        return !(player.cmd.buttons & which) && player.oldbuttons & which;
    }
	
	override Void Tick()
	{
		Super.Tick();
		
		int buttons = GetPlayerInput(-1, INPUT_BUTTONS);
		
		ArmorType = BCD_ArmorType;
		
		if(CountInv("IsProne"))
		{
			Height = 16;
			ViewHeight = 12;
			AttackZOffset = 6;
			JumpZ = 0;
			MaxStepHeight = 8;
			A_SetScale(0.075, 0.025);
			if(GetCrouchFactor() <= 0.9)
			{
				A_TakeInventory("IsProne");
				ViewHeight = 30;
			}
			
			if(pitch > 45)
			{
				A_SetPitch(45, SPF_INTERPOLATE);
			}
			else if(pitch < -35)
			{
				A_SetPitch(-35, SPF_INTERPOLATE);
			}
		}
		else if(GetCrouchFactor() == 0.5)
		{
			Height = 32;
			ViewHeight = 50;
			AttackZOffset = 16;
			JumpZ = 6;
			MaxStepHeight = 16;
			A_SetScale(0.075, 0.075);
			A_GiveInventory("IsCrouch", 1);
		}
		else
		{
			Height = 50;
			AttackZOffset = 22;
			JumpZ = 8;
			ViewHeight = 44;
			MaxStepHeight = 24;
			A_SetScale(0.075, 0.075);
			A_TakeInventory("IsCrouch", 1);
		}
		if(GetCrouchFactor() >= 0.6)
		{
			//[Pop] dont worry about this, this is here to prevent
			//a sticky graphic on the HUD
			A_TakeInventory("IsCrouch");
		}
	}
		
	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		PlayerInfo plyr = Self.Player;
		if(!plyr || plyr.mo != Self) return 0;
		/*if(plyr.mo.CountInv("MO_PowerInvul") == 1)
		{
			A_StartSound("powerup/invul_damage",3);
		}*/
		return super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}
	
	override void PostBeginPlay()
	{
		Super.PostBeginPlay();
		A_Overlay(10, "FirstPersonTorso");
		A_Overlay(-51, "FirstPersonLegsStand", true);
	}

	int grenadecooktimer;
	
	int ArmorType;
	
	bool PlayerKicking;
	
	bool alternateGMSound;
	
	Default
	{	
		Player.StartItem "Citadel_Holster", 1;
		
		Player.StartItem "ThrowableGrenade", 1;
		Player.StartItem "GrenadeAmmo", 2;
		Player.StartItem "ThrowableBang", 1;
		Player.StartItem "BangAmmo", 2;
		
		Player.StartItem "HolsterYourShitPrivate", 1;
		Player.StartItem "QuickProne", 1;
		Player.StartItem "QuickKick", 1;
		Player.StartItem "SwapAttachment", 1;
		
		Player.AttackZOffset 16;
		Player.ViewBob 0.25;
		Player.ViewBobSpeed 15;
		Player.ViewHeight 50;
		Scale 0.075;
		
		-STRETCHPIXELS;
		+ROLLSPRITE;
		+ROLLCENTER;
		+DONTTRANSLATE;
		
		Player.SoundClass "CitadelPlayer";
		Player.Face "MOS";
	}
	
	States
	{
		Spawn:
			TNT1 A 0 A_JumpIf(CountInv("HolsterToken") == 1, "Spawn3");
			TNT1 A 0 A_JumpIfInventory("AimingToken", 1, "Spawn2");
			TNT1 A 0 A_Overlay(-50, "StunnerCheck", true);
			MART C 10;
			Loop;
		Spawn2:
			TNT1 A 0 A_JumpIf(CountInv("AimingToken") == 0, "Spawn");
			MART B 10;
			Loop;
		Spawn3:
			TNT1 A 0 A_JumpIf(CountInv("HolsterToken") == 0, "Spawn");
			MART A 10;
			Loop;
		See:
			MART A 3;
			Loop;
		Missile:
			MART B 6;
			Goto Spawn;
		Melee:
			MART B 4 BRIGHT;
			TNT1 A 0;
			Goto Missile;
		Pain:
			MART A 2 A_Pain;
			Goto Spawn;
		Death:
		XDeath:
			RANG H 2;
			RANG I 2 A_PlayerScream;
			RANG J 2 A_NoBlocking;
			RANG KL 2;
			RANG L -1;
			Stop;
		
		DoDolphinDive:
			TNT1 A 0;
			TNT1 A 3 A_ChangeVelocity(5, 0, velz+2, CVF_RELATIVE);
			Stop;
		
		StunnerCheck:
			TNT1 A 0;
			TNT1 A 1 A_JumpIfInventory("Stunner", 1, "StunBangMeFuckAss");
			Loop;
		StunBangMeFuckAss:
			TNT1 A 0;
			TNT1 A 0 A_StartSound("CODPlayer/Flashbanged", 0, CHANF_OVERLAP);
			TNT1 A 0 A_SetBlend("99 99 99", 1.0, 325, "99 99 99", 0.0);
			TNT1 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 5
			{
				A_SetPitch(pitch+frandom(-1,1), SPF_INTERPOLATE);
				A_SetAngle(angle+frandom(-1,1), SPF_INTERPOLATE);
			}
			TNT1 A 20;
			Goto StunnerCheck;
			
		KickCheckTakeToken:
			TNT1 A 0;
			TNT1 A 0 A_Overlay(-51, "FirstPersonLegsStand", true);
			TNT1 A 1 A_TakeInventory("Kicking",1);
			Stop;
		KickCheck:
			TNT1 A 0;
			TNT1 A 0
			{
				A_OverlayScale(-50, 0.25, 0.25, WOF_RELATIVE);
				A_OverlayFlags(-50, PSPF_ADDWEAPON, false);
				A_OverlayFlags(-50, PSPF_ADDBOB, false);
				A_TakeInventory("Kicking", 1);
				A_GiveInventory("Kicking", 1);
			}
			TNT1 A 1;
		DoKick:
			TNT1 A 0;
			TNT1 A 0 A_JumpIfInventory("IsProne", 1, "KickCheckTakeToken");
			TNT1 A 0 A_JumpIf(momz > 0 && momx == 0 && momy == 0, "AirKick");
			TNT1 A 0 A_JumpIf(PressingCrouch() && momx != 0 && momy != 0, "Slide");
			TNT1 A 0 A_OverlayOffset(-50, 390, 316);
			TNT1 A 0
			{
				A_PlaySound("KICK",69);
				A_Recoil(-1);
			}
			KCKB AAB 1;
			TNT1 A 0 A_OverlayOffset(-50, 390, 716);
			KCKB C 1;
			KCKB D 6
			{	
				if (CountInv("PowerStrength") == 1)
				{
					//A_FireCustomMissile("SuperKickAttack", 0, 0, 5, -7);
					return;
				}			
				//A_FireCustomMissile("KickAttack", 0, 0, 0, -7);
				return;
			}
			KCKB C 2;
			TNT1 A 0 A_OverlayOffset(-50, 390, 316);
			KCKB BA 2;
			TNT1 A 0;
			Goto KickCheckTakeToken;
		Slide:
			TNT1 A 0
			{
				A_OverlayOffset(-50, 384, 296);
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				A_StartSound("SLIDE", CHAN_WEAPON, CHAN_OVERLAP);
				A_GiveInventory("Sliding",1);
			}
			KCKA A 2;
		SlideLoop:
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-24);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-8);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-8);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-8);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-6);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-6);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-6);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-4);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-4);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-2);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-2);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-2);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			KCKA BB 1
			{
				A_QuakeEx(1, 1, 1, 15, 0, 500, "", 0, 0, 0, 0, 0, 0, 0.25);
				//A_CustomPunch(5, FALSE, 0, 0, 64);
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
				A_Recoil(-2);
			}
		SlideLoop2:
			KCKA B 1
			{
				if(Pitch>=10)
				{
					A_SetPitch(pitch-pitch/2+6);
				}
				A_OverlayOffset(-50, 386, (-pitch*2)+328);
			}
			TNT1 A 0 A_JumpIf(!PressingCrouch() || JustReleased(BT_CROUCH), "SlideEnd");
			Loop;
		SlideEnd:
			KCKA BA 2;
			TNT1 A 0 A_TakeInventory("Sliding");
			Goto KickCheckTakeToken;
		AirKick:
			TNT1 A 0 A_OverlayOffset(-50, 800, 296);
			TNT1 A 0
			{
				A_PlaySound("KICK",69);
				A_Recoil(-8);
			}
			KCKC AB 2;
			KCKC C 2
			{	
				A_OverlayOffset(-50, 224, 296);
				if (CountInv("PowerStrength") == 1)
				{
					//A_FireCustomMissile("SuperKickAttack", 0, 0, 5, -7);
					return;
				}			
				//A_FireCustomMissile("KickAttack", 0, 0, 0, -7);
				return;
			}
			TNT1 A 0 A_OverlayOffset(-50, 800, 296);
			KCKC DE 2;
			TNT1 A 0 A_OverlayOffset(-50, 724, 236);
			KCKC F 2;
			TNT1 A 0 A_OverlayOffset(-50, 756, 236);
			KCKC G 2;
			TNT1 A 0;
			Goto KickCheckTakeToken;
			
		
		
		FirstPersonLegsStand:
			MLST A 0;
			#### A 0 A_OverlayScale(-51, 0.25, 0.25, WOF_RELATIVE);
			#### A 0 A_OverlayFlags(-51, PSPF_ADDBOB, false);
			#### A 0 A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
			#### A 0 A_JumpIf(momZ != 0, "FirstPersonLegsJump");
			#### A 0 A_JumpIf(GetCrouchFactor() < 0.6, "FirstPersonLegsCrouch");
			#### A 0 A_JumpIf(momx > 0.8 || momx < -0.8 || momy > 0.8 || momy < -0.8, "FirstPersonLegsWalk");
			#### A 1 
			{
				A_OverlayOffset(-51, 379, (-pitch*2)+408);
			}
			Loop;
		FirstPersonLegsCrouch:
			MLCR A 0;
			MLCR B 0 A_JumpIf(self.ArmorType == 1, "Faith");
			MLCR C 0 A_JumpIf(self.ArmorType == 2, "Devotion");
			MLCR D 0 A_JumpIf(self.ArmorType == 3, "Zealot");
		Skin:
			MLCR A 0;
			Goto CrouchCont;
		Faith:
			MLCR B 0;
			Goto CrouchCont;
		Devotion:
			MLCR C 0;
			Goto CrouchCont;
		Zealot:
			MLCR D 0;
			Goto CrouchCont;
		CrouchCont:
			#### # 0 A_JumpIf(momZ != 0, "FirstPersonLegsJump");
			#### # 0 A_JumpIf(GetCrouchFactor() > 0.6, "FirstPersonLegsStand");
			#### # 0 A_JumpIf(momx > 0.8 || momx < -0.8 || momy > 0.8 || momy < -0.8, "FirstPersonLegsCrouchWalk");
			#### # 1 
			{
				A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
				A_OverlayOffset(-51, 379, (-pitch*2)+388);
			}
			Loop;
		FirstPersonLegsJump:
			MLJU A 0;
			#### A 0 A_JumpIf(momZ <= 0, "FirstPersonLegsFall");
			#### A 1 
			{
				A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
				A_OverlayOffset(-51, 379, (-pitch*2)+408);
			}
			Loop;
		FirstPersonLegsFall:
			MLFA A 0;
			#### A 1 
			{
				A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
				A_OverlayOffset(-51, 379, (-pitch*2)+408);
			}
			#### A 0 A_JumpIf(momZ == 0, "FirstPersonLegsStand");
			Loop;
		FirstPersonLegsCrouchWalk:
			MLCW A 0;
			#### AABBCCBBAA 1
			{
				A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
				A_OverlayOffset(-51, 379, (-pitch*2)+408);
				If(momZ != 0)
					{ return ResolveState("FirstPersonLegsJump"); }
				Else If(GetCrouchFactor() > 0.6)
					{ return ResolveState("FirstPersonLegsStand"); }
				return ResolveState(null);
			}
			#### DDEEFFEEDD 1
			{
				A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
				A_OverlayOffset(-51, 379, (-pitch*2)+408);
				If(momZ != 0)
					{ return ResolveState("FirstPersonLegsJump"); }
				Else If(GetCrouchFactor() > 0.6)
					{ return ResolveState("FirstPersonLegsStand"); }
				return ResolveState(null);
			}
			Goto FirstPersonLegsCrouch;
		FirstPersonLegsWalk:
			MLSW A 0;
			#### AABBCCDDEE 1
			{
				A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
				A_OverlayOffset(-51, 379, (-pitch*2)+428);
				If(momZ != 0)
					{ return ResolveState("FirstPersonLegsJump"); }
				Else If(GetCrouchFactor() < 0.6)
					{ return ResolveState("FirstPersonLegsCrouch"); }
				return ResolveState(null);
			}
			#### FFGGHHIIJJ 1
			{
				A_OverlayFlags(-51, PSPF_ADDWEAPON, False);
				A_OverlayOffset(-51, 379, (-pitch*2)+428);
				If(momZ != 0)
					{ return ResolveState("FirstPersonLegsJump"); }
				Else If(GetCrouchFactor() < 0.6)
					{ return ResolveState("FirstPersonLegsCrouch"); }
				return ResolveState(null);
			}
			Goto FirstPersonLegsStand;
			
		FirstPersonTorso:
			MLBO # 0 A_OverlayScale(10, 0.25, 0.25, WOF_RELATIVE);
			MLBO A 0;
			MLBO B 0 A_JumpIf(self.ArmorType == 1, "FaithUpper");
			MLBO C 0 A_JumpIf(self.ArmorType == 2, "DevotionUpper");
			MLBO D 0 A_JumpIf(self.ArmorType == 3, "ZealotUpper");
		SkinUpper:
			MLBO A 0;
			Goto TorsoCont;
		FaithUpper:
			MLBO B 0;
			Goto TorsoCont;
		DevotionUpper:
			MLBO C 0;
			Goto TorsoCont;
		ZealotUpper:
			MLBO D 0;
			Goto TorsoCont;
		TorsoCont:
			#### # 1 
			{
				A_OverlayFlags(10, PSPF_ADDWEAPON, False);
				A_OverlayFlags(10, PSPF_ADDBOB, False);
				A_OverlayOffset(10, 385, (-pitch*2)+630);
			}
			Goto FirstPersonTorso;
			
	}
}

class Z_NashMove : CustomInventory
{
	Default
	{
		Inventory.MaxAmount 1;
		+INVENTORY.UNDROPPABLE
		+INVENTORY.UNTOSSABLE
		+INVENTORY.AUTOACTIVATE
	}

	// How much to reduce the slippery movement.
	// Lower number = less slippery.
	const DECEL_MULT = 0.8; //0.8

	//===========================================================================
	//
	//
	//
	//===========================================================================

	bool bIsOnFloor(void)
	{
		return (Owner.Pos.Z == Owner.FloorZ) || (Owner.bOnMObj);
	}

	bool bIsInPain(void)
	{
		State PainState = Owner.FindState('Pain');
		if (PainState != NULL && Owner.InStateSequence(Owner.CurState, PainState))
		{
			return true;
		}
		return false;
	}

	double GetVelocity (void)
	{
		return Owner.Vel.Length();
	}

	//===========================================================================
	//
	//
	//
	//===========================================================================

	override void Tick(void)
	{
		if (Owner && Owner is "PlayerPawn")
		{
			if (bIsOnFloor())
			{
				// bump up the player's speed to compensate for the deceleration
				// TO DO: math here is shit and wrong, please fix
				double s = 0.7 + (1.1 - DECEL_MULT); //1.0
				double mod = 1;
				
				//[Pop] Initialize the base value
				s *= 2;
				
				//[Pop] Handle movement boosts here at some point if needed. IE Stims, holsters gun, etc.
				
				//[Pop] This is the main magic with handling how fast players can move with weapons.
				//If not a CODWeapon, is ignored.
				if(Owner.Player.ReadyWeapon)
				{
					let wpn = CitadelWeapon(Owner.Player.ReadyWeapon);
					if(wpn)
					{
						mod = wpn.GunSpeedMod;
					}
				}
				//[Pop] Handle movement reductions here. IE Stuns or heavy damage.
				if(Owner.CountInv("Stunner"))
				{
					mod = mod * 0.4;
				}
				if(Owner.CountInv("IsProne"))
				{
					mod = mod * 0.2;
				}
				if(Owner.CountInv("Sliding"))
				{
					mod = 0;
				}
				
				Owner.A_SetSpeed(s * mod);
				
				Owner.vel.x *= DECEL_MULT;
				Owner.vel.y *= DECEL_MULT;
				// make the view bobbing match the player's movement
				PlayerPawn(Owner).ViewBob = Owner.vel.length() / 16;//DECEL_MULT / 2;
			}
		}

		Super.Tick();
	}

	//===========================================================================
	//
	//
	//
	//===========================================================================
	States
	{
	Use:
		TNT1 A 0;
		Fail;
	Pickup:
		TNT1 A 0
		{
			return true;
		}
		Stop;
	}
}

Class QuickProne : CustomInventory
{
	int CooldownTimer;
	
	override void DoEffect()
	{
		super.DoEffect();
		if (CooldownTimer < 19)
		{
			CooldownTimer++;
		}
		if (CooldownTimer == 19)
		{
			CooldownTimer = 20;
		}
	}
	
	Default
	{
		Inventory.Amount 1;
		Inventory.MaxAmount 1;
		+INVENTORY.UNDROPPABLE;
	}
	
	States 
	{
		Use:
			TNT1 A 0 
			{
				if (invoker.CooldownTimer >= 20 && !CountInv("IsProne"))
				{
					invoker.CooldownTimer = invoker.CooldownTimer - 20;
					invoker.Owner.A_GiveInventory("IsProne");
					if(invoker.owner.velz > 0)
					{
						invoker.owner.A_Overlay(-51, "DoDolphinDive");
					}
				}
				if (invoker.CooldownTimer >= 20 && CountInv("IsProne"))
				{
					invoker.CooldownTimer = invoker.CooldownTimer - 20;
					invoker.Owner.A_TakeInventory("IsProne");
				}
			}
			TNT1 A 20;
			fail;
	}
}

Class QuickKick : CustomInventory
{
	int CooldownTimer;
	
	override void DoEffect()
	{
		super.DoEffect();
		if (CooldownTimer < 20)
		{
			CooldownTimer++;
		}
		if (CooldownTimer == 19)
		{
			CooldownTimer = 20;
		}
	}
	
	Default
	{
		Inventory.Amount 1;
		Inventory.MaxAmount 1;
		+INVENTORY.UNDROPPABLE;
	}
	
	States 
	{
		Use:
			TNT1 A 0 
			{
				if (invoker.CooldownTimer >= 20 && !CountInv("Kicking"))
				{
					invoker.CooldownTimer = invoker.CooldownTimer - 20;
					invoker.owner.A_Overlay(-50, "KickCheck");
					invoker.owner.A_ClearOverlays(-51,-51);
				}
			}
			TNT1 A 20;
			fail;
	}
}

class IsProne : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}

class IsCrouch : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}

class Kicking : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}

class Sliding : Inventory
{
	Default
	{
		Inventory.MaxAmount 1;
	}
}