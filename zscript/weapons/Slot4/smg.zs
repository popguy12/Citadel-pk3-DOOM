// SMG Ammo - uses same ammo pool as pistol
class SMGAmmo : Ammo
{
    Default
    {
        Inventory.Amount 30;        // Amount given per pickup
        Inventory.MaxAmount 300;    // Maximum reserve ammo
        Ammo.BackpackAmount 30;     // Amount given by backpack
        Ammo.BackpackMaxAmount 300; // Max amount with backpack
        Inventory.Icon "CLIPA0";
        Inventory.PickupMessage "Picked up SMG ammo.";
    }
    
    States
    {
    Spawn:
        CLIP A -1;
        Stop;
    }
}

// SMG Smoke spawner
class SMGSmokeSpawner : Actor
{
    Default
    {
        Speed 30;
        Projectile;
        +NOCLIP;
        +NOGRAVITY;
    }
    
    States
    {
    Spawn:
        TNT1 A 2;
        TNT1 A 1 A_SpawnItemEx("SMGGunSmoke", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        Stop;
    }
}

// SMG ADS smoke spawner
class SMGSmokeSpawnerADS : Actor
{
    Default
    {
        Speed 45;
        Projectile;
        +NOCLIP;
        +NOGRAVITY;
    }
    
    States
    {
    Spawn:
        TNT1 A 2;
        TNT1 A 1 A_SpawnItemEx("SMGGunSmoke", 0, 0, -2, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        Stop;
    }
}

// Custom SMG with Reload, ADS, and Magazine System
// Auto-fire only - no fire mode toggle
//
// FEATURES:
// - Magazine capacity: 30 rounds
// - Uses PistolAmmo (shared with custom pistol)
// - ADS with scope vignette
// - Gentle accumulator-based recoil (works in both hipfire and ADS)
// - Recoil stats: 0.5 per shot, 0.15 recovery/frame, 6.0 max
// - Breathing effect in ADS (same as pistol)
// - Non-spinning shell casings (static SHELD frame for rapid ejection)
//
// CROSSHAIR BEHAVIOR:
// - Hipfire: Shows player's default crosshair
// - ADS: Hides all crosshairs (scope vignette only)
//
class CustomReloadSMG : DoomWeapon replaces Chaingun
{
    const MAGAZINE_CAPACITY = 30;  // SMG has 30-round magazine
    int loaded;
    int reloadCooldown;
    bool bInADS;           // ADS state
    bool bADSButtonHeld;   // ADS button held state for lock system
    bool bADSLocked;       // ADS lock after reload
    
    // Recoil system - gentler than pistol for full-auto control
    double recoilAccumulator;      // Current accumulated recoil
    const RECOIL_PER_SHOT = 0.5;   // Gentle recoil per shot (pistol is 2.0)
    const RECOIL_RECOVERY = 0.15;  // Faster recovery for full-auto (pistol is 0.22)
    const MAX_RECOIL = 6.0;       // Lower cap than pistol (pistol is 16.0)

    // NEW: Baseline pitch captured at the start of a burst for relative recoil clamping
    double fireBasePitch;
    
    // Breathing effect variables for ADS (camera movement)
    int breathCounter;
    int adsHoldFrames;          // Count frames at center before breathing starts
    double breathPhaseX;        // random phase X per ADS
    double breathPhaseY;        // random phase Y per ADS
    double breathFreqX;         // random sign per ADS for X frequency
    double breathFreqY;         // random sign per ADS for Y frequency
    double breathBlend;         // 0.0 = U-shape, 1.0 = circular, 2.0 = inverted U
    double breathTargetBlend;   // target blend to transition towards
    
    // Weapon sway during sustained fire (simulates holding SMG)
    int swayCycle;              // Counter for smooth side-to-side weapon movement while firing
    double swayPhase;           // Random starting phase for sway direction
    double swayDirection;       // Random direction multiplier: +1 or -1
    
    // Apply recoil to view (clamps recoil only, not player input)
    action void A_ApplyRecoil(double amount)
    {
        // Calculate how much the player has moved their view since burst started
        double playerPitchChange = invoker.fireBasePitch - pitch;
        
        // Calculate effective recoil ceiling: don't let accumulated recoil push view more than 10Â° up from baseline
        double maxAllowedRecoil = max(0, 10.0 - playerPitchChange);
        
        // Add new recoil and clamp accumulator based on allowed ceiling
        invoker.recoilAccumulator = min(invoker.recoilAccumulator + amount, min(invoker.MAX_RECOIL, maxAllowedRecoil / 0.10));
        
        // Apply accumulated recoil to pitch (camera kicks UP)
        A_SetPitch(pitch - invoker.recoilAccumulator * 0.10);
    }
    
    // Recover from recoil gradually
    action void A_RecoverRecoil()
    {
        if (invoker.recoilAccumulator > 0)
        {
            invoker.recoilAccumulator = max(0, invoker.recoilAccumulator - invoker.RECOIL_RECOVERY);
        }
    }
    
    Default
    {
        Weapon.SelectionOrder 700;
        Weapon.AmmoUse 0;
        Weapon.AmmoGive 30;
        Weapon.AmmoType "PistolAmmo";  // Uses same ammo as pistol
        Inventory.PickupMessage "You got the SMG!";
        Obituary "%o was riddled by %k's SMG.";
        Tag "Combat SMG";
        Weapon.SlotNumber 4;  // Chaingun slot
        +WEAPON.NOAUTOFIRE;
        +WEAPON.AMMO_OPTIONAL;
        +WEAPON.NOALERT;
    }
    
    override void DoEffect()
    {
        Super.DoEffect();
        if (reloadCooldown > 0) reloadCooldown--;
    }
    
    override void AttachToOwner(Actor other)
    {
        Super.AttachToOwner(other);
        loaded = MAGAZINE_CAPACITY;
        recoilAccumulator = 0;
    }
    
    States
    {
    Ready:
        CSIS A 1
        {
            int buttons = GetPlayerInput(-1, INPUT_BUTTONS);
            bool reloadHeld = (buttons & BT_RELOAD) != 0;
            
            // Clear reload cooldown when reload button is released
            if (!reloadHeld)
            {
                invoker.reloadCooldown = 0;
            }
            
            // Setup ready flags - always allow fire for auto mode
            int readyFlags = 0;
            if (invoker.reloadCooldown == 0)
                readyFlags |= WRF_ALLOWRELOAD;
            
            A_WeaponReady(readyFlags);
            A_RecoverRecoil();
            
            // Reset weapon to center position
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            
            // Show crosshair in hipfire
            if (!invoker.bInADS)
            {
                A_SetCrosshair(-1);
            }
        }
        Loop;
    
    Deselect:
        CSIS A 0
        {
            A_ZoomFactor(1.0, ZOOM_INSTANT);
            invoker.bInADS = false;
            A_ClearOverlays(1000, 1000);
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0);
            invoker.recoilAccumulator = 0; // Reset recoil
            invoker.swayCycle = 0; // Reset weapon sway
            A_SetCrosshair(-1); // Restore crosshair when switching weapons
        }
        CSIS A 1 A_Lower;
        Loop;
    
    Select:
        CSIS A 0
        {
            A_ZoomFactor(1.0, ZOOM_INSTANT);
            invoker.bInADS = false;
            A_ClearOverlays(1000, 1000);
            A_SetCrosshair(-1); // Show player's default crosshair in hipfire
        }
        CSIS A 1 A_Raise;
        Loop;
    
    Fire:
        TNT1 A 0
        {
            // If in ADS, use AimFire instead
            if (invoker.bInADS)
            {
                return ResolveState("AimFire");
            }
            
            if (invoker.loaded <= 0)
            {
                A_StartSound("customsmg/empty", CHAN_WEAPON);
                return ResolveState("FireEmpty");
            }
            
            // Initialize random sway phase when starting to fire
            if (invoker.swayCycle == 0)
            {
                double t = double(level.time % 1024) / 1024.0;
                invoker.swayPhase = (t + frandom(0.0, 1.0)) * 6.28318530718; // 0..2Ï€
                invoker.swayDirection = random(0, 1) == 0 ? 1.0 : -1.0;
                // NEW: Capture baseline pitch at burst start
                invoker.fireBasePitch = pitch;
            }
            
            return ResolveState(null);
        }
        CSFR A 1 Bright
        {
            A_AlertMonsters();
            invoker.loaded--;
            A_FireBullets(2.0, 2.0, -1, 5, "BulletPuff", FBF_USEAMMO, 0, "SMGSmokeSpawner", 0, 0);  // SMG has more spread than pistol
            A_StartSound("customsmg/fire", CHAN_WEAPON);
            A_Overlay(-2, "MuzzleFlash");
            
            // Spawn SMG brass casing using spawner that respects pitch
            A_FireProjectile("SMGCasingSpawner", 0, false, 0, -6);
            
            // Apply gentle recoil
            A_ApplyRecoil(invoker.RECOIL_PER_SHOT);
            
            // Zoom kick for visual feedback (zoom OUT for kickback feel)
            A_ZoomFactor(0.995, ZOOM_INSTANT);
            
            // Weapon sway: smooth side-to-side movement
            invoker.swayCycle++;
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        CSFR B 1 Bright
        {
            A_ZoomFactor(1.0, ZOOM_INSTANT);
            
            // Continue sway
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        CSFR C 1
        {
            A_RecoverRecoil();
            
            // Continue sway
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        CSFR D 0
        {
            A_RecoverRecoil();
            
            // Continue sway
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        TNT1 A 0
        {
            // Check if magazine is empty after firing
            if (invoker.loaded <= 0)
            {
                // If trigger still held, play empty sound and go to empty loop
                if ((player.cmd.buttons & BT_ATTACK) != 0)
                {
                    A_StartSound("customsmg/empty", CHAN_WEAPON);
                    return ResolveState("FireEmptyHold");
                }
                invoker.swayCycle = 0; // Reset sway when stopping
                return ResolveState("Ready");
            }
            
            // In auto mode, check if trigger still held
            if ((player.cmd.buttons & BT_ATTACK) != 0)
                return ResolveState("Fire");
            
            invoker.swayCycle = 0; // Reset sway when stopping
            return ResolveState("Ready");
        }
        Goto Ready;
    
    FireEmpty:
        TNT1 A 0
        {
            // Check if trigger still held
            if ((player.cmd.buttons & BT_ATTACK) != 0)
                return ResolveState("FireEmptyHold");
            return ResolveState("Ready");
        }
        Goto Ready;
    
    FireEmptyHold:
        CSIS A 10;  // 10 tic delay to match pistol timing
        TNT1 A 0
        {
            // Check if trigger still held
            if ((player.cmd.buttons & BT_ATTACK) != 0)
            {
                A_StartSound("customsmg/empty", CHAN_WEAPON);
                return ResolveState("FireEmptyHold");
            }
            return ResolveState("Ready");
        }
        Goto Ready;
    
    AltFire:
        TNT1 A 0
        {
            invoker.bADSButtonHeld = true;
            A_ZoomFactor(1.5, ZOOM_INSTANT | ZOOM_NOSCALETURNING);
            invoker.bInADS = true;
            A_SetCrosshair(-1); // Keep default crosshair hidden in ADS
            
            // Initialize breathing effect variables
            invoker.breathCounter = 0;
            invoker.adsHoldFrames = 0;

            // Mix phase with level time so each ADS entry gets a different start even with deterministic RNG
            double t = double(level.time % 1024) / 1024.0;
            invoker.breathPhaseX = (t + frandom(0.0, 1.0)) * 6.28318530718; // 0..2Ï€
            invoker.breathPhaseY = (double((level.time * 3) % 1024) / 1024.0 + frandom(0.0, 1.0)) * 6.28318530718;

            // Randomize frequency sign per ADS to avoid consistent pull bias
            invoker.breathFreqX = (random(0, 1) == 0 ? 1.9 : -1.9);
            invoker.breathFreqY = (random(0, 1) == 0 ? 2.2 : -2.2);
            
            // Randomly start with one of three patterns: U-shape (0), circular (1), inverted U (2)
            invoker.breathBlend = double(random(0, 2));
            int nextPattern = random(0, 2);
            while (nextPattern == int(invoker.breathBlend)) nextPattern = random(0, 2);
            invoker.breathTargetBlend = double(nextPattern);
            
            let psp = player.FindPSprite(PSP_WEAPON);
            if (psp)
            {
                psp.sprite = GetSpriteIndex("CSAD");
                psp.frame = 0;
            }
        }
        CSAD A 0;
        Goto AltHold;
    
    AltHold:
        CSAD A 1
        {
            int readyFlags = WRF_NOSECONDARY;
            if (invoker.reloadCooldown == 0)
                readyFlags |= WRF_ALLOWRELOAD;
            
            A_WeaponReady(readyFlags);
            A_RecoverRecoil();
            
            // Keep crosshair hidden while in ADS
            A_SetCrosshair(-1);
            
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            
            // Apply breathing motion to camera
            if (invoker.adsHoldFrames < 4)
            {
                invoker.adsHoldFrames++;
                A_SetViewAngle(0);
                A_SetViewPitch(0, SPF_INTERPOLATE);
            }
            else
            {
                invoker.breathCounter++;
                
                // Transition blend value towards target
                double transitionSpeed = 0.008;
                if (abs(invoker.breathBlend - invoker.breathTargetBlend) < transitionSpeed)
                {
                    invoker.breathBlend = invoker.breathTargetBlend;
                    // Reached target - randomly pick new target pattern (different from current)
                    int currentPattern = int(invoker.breathBlend);
                    int nextPattern = random(0, 2);
                    while (nextPattern == currentPattern) nextPattern = random(0, 2);
                    invoker.breathTargetBlend = double(nextPattern);
                }
                else if (invoker.breathBlend < invoker.breathTargetBlend)
                    invoker.breathBlend += transitionSpeed;
                else
                    invoker.breathBlend -= transitionSpeed;
                
                // Calculate base X motion
                double breathX = sin(invoker.breathCounter * invoker.breathFreqX + invoker.breathPhaseX) * 0.58;
                
                // Calculate all three patterns
                double breathY_U = -(breathX * breathX) * 1.7;           // U-shape (0)
                double breathY_Circle = sin(invoker.breathCounter * invoker.breathFreqY + invoker.breathPhaseY) * 0.42;  // Circular (1)
                double breathY_InvU = (breathX * breathX) * 1.7;          // Inverted U (2)
                
                // Blend between patterns based on breathBlend value (0.0-2.0)
                double breathY;
                if (invoker.breathBlend < 1.0)
                {
                    // Blend between U-shape (0) and circular (1)
                    breathY = breathY_U * (1.0 - invoker.breathBlend) + breathY_Circle * invoker.breathBlend;
                }
                else
                {
                    // Blend between circular (1) and inverted U (2)
                    double t = invoker.breathBlend - 1.0;
                    breathY = breathY_Circle * (1.0 - t) + breathY_InvU * t;
                }
                
                A_SetViewAngle(breathX, SPF_INTERPOLATE);
                A_SetViewPitch(breathY, SPF_INTERPOLATE);
            }
        }
        CSAD A 0 
        {
            return ResolveState(null);
        }
        CSAD A 0 A_ReFire("AltHold");
        TNT1 A 0
        {
            A_ZoomFactor(1.0, ZOOM_INSTANT);
            invoker.bInADS = false;
            A_ClearOverlays(1000, 1000);
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0, SPF_INTERPOLATE);
            invoker.recoilAccumulator = 0; // Reset recoil
            invoker.bADSButtonHeld = false;
            invoker.swayCycle = 0; // Reset weapon sway
            invoker.breathCounter = 0; // Reset breathing
            invoker.adsHoldFrames = 0; // Reset breathing
            A_SetCrosshair(-1); // Show crosshair when exiting ADS
        }
        Goto Ready;
    
    AimFire:
        TNT1 A 0
        {
            if (invoker.loaded <= 0)
            {
                A_StartSound("customsmg/empty", CHAN_WEAPON);
                return ResolveState("EmptyADS");
            }
            
            // Initialize random sway phase when starting to fire
            if (invoker.swayCycle == 0)
            {
                double t = double(level.time % 1024) / 1024.0;
                invoker.swayPhase = (t + frandom(0.0, 1.0)) * 6.28318530718; // 0..2Ï€
                invoker.swayDirection = random(0, 1) == 0 ? 1.0 : -1.0;
                // NEW: Capture baseline pitch at burst start (ADS)
                invoker.fireBasePitch = pitch;
            }
            
            return ResolveState(null);
        }
        CSAD A 1 Bright
        {
            A_AlertMonsters();
            invoker.loaded--;
            A_FireBullets(0.8, 0.8, 1, 5, "BulletPuff", FBF_USEAMMO, 0, "SMGSmokeSpawnerADS", 8, 0);  // Better accuracy in ADS
            A_StartSound("customsmg/fire", CHAN_WEAPON);
            A_Overlay(-2, "MuzzleFlashADS");
            
            // Spawn SMG brass casing using spawner that respects pitch (higher for ADS)
            A_FireProjectile("SMGCasingSpawner", 0, false, 0, 2);
            
            // Apply gentle recoil - same as hipfire
            A_ApplyRecoil(invoker.RECOIL_PER_SHOT);
            
            // Zoom kick (zoom OUT from base 1.5x)
            A_ZoomFactor(1.48, ZOOM_INSTANT | ZOOM_NOSCALETURNING);
            
            // Weapon sway: smooth side-to-side movement
            invoker.swayCycle++;
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        CSAD A 1 Bright
        {
            A_ZoomFactor(1.5, ZOOM_INSTANT | ZOOM_NOSCALETURNING);
            
            // Continue sway
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        CSAD A 1
        {
            A_RecoverRecoil();
            
            // Continue sway
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        CSAD A 0
        {
            A_RecoverRecoil();
            
            // Continue sway
            double swayOffset = sin(invoker.swayCycle * 60.0 * invoker.swayDirection + invoker.swayPhase) * 0.5;
            A_WeaponOffset(swayOffset, 32, WOF_INTERPOLATE);
        }
        TNT1 A 0
        {
            if (invoker.loaded <= 0)
            {
                // If trigger still held, play empty sound and loop
                if ((player.cmd.buttons & BT_ATTACK) != 0)
                {
                    A_StartSound("customsmg/empty", CHAN_WEAPON);
                    return ResolveState("EmptyADS");
                }
                invoker.swayCycle = 0; // Reset sway when stopping
                return ResolveState("AltHold");
            }
            
            // Check if trigger still held for auto fire
            if ((player.cmd.buttons & BT_ATTACK) != 0)
            {
                return ResolveState("AimFire");
            }
            
            invoker.swayCycle = 0; // Reset sway when stopping
            return ResolveState("AltHold");
        }
        Goto AltHold;
    
    EmptyADS:
        CSAD A 0 
        {
            A_StartSound("customsmg/empty", CHAN_WEAPON);
            return ResolveState(null);
        }
        CSAD A 10;  // 10 tic delay to match pistol timing
        TNT1 A 0
        {
            // Check if trigger still held
            if ((player.cmd.buttons & BT_ATTACK) != 0)
            {
                A_StartSound("customsmg/empty", CHAN_WEAPON);
                return ResolveState("EmptyADS");
            }
            return ResolveState("AltHold");
        }
        Goto AltHold;
    
    Flash:
    MuzzleFlash:
        MZFL ABCDEF 1 Bright 
        {
            A_OverlayFlags(-2, PSPF_RENDERSTYLE | PSPF_ALPHA, true);
            A_OverlayOffset(-2, 0, 0, WOF_INTERPOLATE);
        }
        Stop;
    
    MuzzleFlashADS:
        MZFL ABCDEF 1 Bright 
        {
            A_OverlayFlags(-2, PSPF_RENDERSTYLE | PSPF_ALPHA, true);
            A_OverlayOffset(-2, -1, 0, WOF_INTERPOLATE);
        }
        Stop;
    
    Reload:
        TNT1 A 0
        {
            // Check magazine capacity BEFORE exiting ADS
            if (invoker.loaded >= invoker.MAGAZINE_CAPACITY)
            {
                return invoker.bInADS ? ResolveState("AltHold") : ResolveState("Ready");
            }
            
            // Set reload cooldown
            invoker.reloadCooldown = 35;
            
            // Always exit ADS when reloading
            A_ZoomFactor(1.0, ZOOM_INSTANT);
            invoker.bInADS = false;
            A_ClearOverlays(1000, 1000);
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0, SPF_INTERPOLATE);
            invoker.recoilAccumulator = 0; // Reset recoil
            invoker.swayCycle = 0; // Reset weapon sway
            invoker.breathCounter = 0; // Reset breathing
            invoker.adsHoldFrames = 0; // Reset breathing
            A_SetCrosshair(-1); // Show crosshair when exiting ADS
            
            return ResolveState(null);
        }
        TNT1 A 0 A_JumpIfInventory("PistolAmmo", 1, "PerformReload");
        TNT1 A 0 A_StartSound("customsmg/empty", CHAN_WEAPON);
        TNT1 A 0
        {
            invoker.bADSLocked = invoker.bADSButtonHeld;
            return invoker.bADSLocked ? ResolveState("ForceHipfire") : ResolveState("Ready");
        }
        Goto Ready;
    
    PerformReload:
        TNT1 A 0 A_JumpIf(invoker.loaded > 0, "ReloadHasAmmo");
        Goto ReloadEmpty;
    
    ReloadHasAmmo:
		// Clip removal (forward)
        CSRL A 2;
        CSRL B 2;
        CSRL C 2 A_StartSound("customsmg/unload", CHAN_WEAPON);
        CSRL D 2;
        CSRL E 2;
		CSRL F 2;
        CSRL G 2;
        CSRL H 2;
        // Clip insertion (backward - same frames in reverse)
        CSRL H 2;
        CSRL G 2;
        CSRL F 2 
        {
            A_StartSound("customsmg/load", CHAN_WEAPON);
            int needed = invoker.MAGAZINE_CAPACITY - invoker.loaded;
            int available = CountInv("PistolAmmo");
            int toLoad = min(needed, available);
            A_TakeInventory("PistolAmmo", toLoad, TIF_NOTAKEINFINITE);
            invoker.loaded += toLoad;
        }
        CSRL E 2;
        CSRL D 2;
        CSRL C 2;
        CSRL B 2;
        CSRL A 2
        {
            invoker.bADSLocked = invoker.bADSButtonHeld;
        }
        Goto CheckReloadExit;
    
    ReloadEmpty:
		// Clip removal (forward)
        CSRE A 2;
        CSRE B 2;
        CSRE C 2 A_StartSound("customsmg/unload", CHAN_WEAPON);
        CSRE D 2;
        CSRE E 2;
		CSRE F 2;
        CSRE G 2;
        CSRE H 2;
        // Clip insertion (backward - same frames in reverse)
        CSRE H 2;
        CSRE G 2;
        CSRE F 2 
        {
            A_StartSound("customsmg/load", CHAN_WEAPON);
            int available = CountInv("PistolAmmo");
            int toLoad = min(invoker.MAGAZINE_CAPACITY, available);
            A_TakeInventory("PistolAmmo", toLoad, TIF_NOTAKEINFINITE);
            invoker.loaded = toLoad;
        }
        CSRE E 2;
        CSRE D 2;
        CSRE C 2;
        CSRE B 2;
        CSRE A 2
        {
            invoker.bADSLocked = invoker.bADSButtonHeld;
        }
        Goto Cock;
    
    // Cock animation plays after reload
    Cock:
        CSCK A 2;
        CSCK B 2 A_StartSound("customsmg/cock", CHAN_WEAPON);
        CSCK C 2;
        CSCK D 2;
        CSCK E 2;
        CSCK F 2;
        CSIS A 1;  // Transition frame to prevent weapon disappearing
        Goto CheckReloadExit;
    
    CheckReloadExit:
        CSIS A 0 A_JumpIf(invoker.bADSLocked, "ForceHipfire");
        Goto Ready;
    
    ForceHipfire:
        CSIS A 0
        {
            let psp = player.FindPSprite(PSP_WEAPON);
            if (psp)
            {
                psp.sprite = GetSpriteIndex("CSIS");
                psp.frame = 0;
            }
        }
        CSIS A 0;
        Goto ReadyLocked;
    
    ReadyLocked:
        CSIS A 1
        {
            int buttons = GetPlayerInput(-1, INPUT_BUTTONS);
            bool reloadHeld = (buttons & BT_RELOAD) != 0;
            
            if (!reloadHeld)
            {
                invoker.reloadCooldown = 0;
            }
            
            int readyFlags = WRF_NOSECONDARY;
            if (invoker.reloadCooldown == 0)
                readyFlags |= WRF_ALLOWRELOAD;
            
            A_WeaponReady(readyFlags);
            A_RecoverRecoil();
            
            A_ZoomFactor(1.0, ZOOM_NOSCALETURNING);
            A_ClearOverlays(1000, 1000);
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0, SPF_INTERPOLATE);
            A_SetCrosshair(-1); // Show crosshair in hipfire
            
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        }
        CSIS A 0 A_ReFire("ReadyLocked");
        CSIS A 0
        {
            invoker.bADSLocked = false;
            invoker.bADSButtonHeld = false;
        }
        Goto Ready;
    
    Spawn:
        CSIP A -1;
        Stop;
    }
}
