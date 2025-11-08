// Custom ammo type for the pistol - max 100 rounds
class PistolAmmo : Ammo replaces Clip
{
    Default
    {
        Inventory.Amount 10;        // Amount given per pickup
        Inventory.MaxAmount 100;    // Maximum reserve ammo
        Ammo.BackpackAmount 10;     // Amount given by backpack
        Ammo.BackpackMaxAmount 100; // Max amount with backpack
        Inventory.Icon "CLIPA0";
        Inventory.PickupMessage "Picked up pistol ammo.";
    }
    
    States
    {
    Spawn:
        CLIP A -1;
        Stop;
    }
}

// Smoke spawner - invisible projectile that spawns smoke puffs
class GunSmokeSpawner : Actor
{
    Default
    {
        Speed 25;  // Increased speed to travel further forward before spawning smoke
        Projectile;
        +NOCLIP;
        +NOGRAVITY;
    }
    
    States
    {
    Spawn:
        TNT1 A 2;  // Travel for 2 tics before spawning (moves smoke further forward)
        TNT1 A 1 A_SpawnItemEx("PistolGunSmoke", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
        Stop;
    }
}

// ADS smoke spawner - spawns smoke higher for ADS position
class GunSmokeSpawnerADS : Actor
{
    Default
    {
        Speed 35;
        Projectile;
        +NOCLIP;
        +NOGRAVITY;
    }
    
    States
    {
    Spawn:
        TNT1 A 2;
        TNT1 A 1 A_SpawnItemEx("PistolGunSmoke", 0, 0, 0, 0, 0, 0, 0, SXF_NOCHECKPOSITION);
		//TNT1 A 1 A_SpawnItemEx("PistolGunSmoke", 0, 0, 4, 0, 0, 0, 0, SXF_NOCHECKPOSITION);  // Spawns 1 units higher
        Stop;
    }
}

// Custom Pistol with Reload, ADS, Magazine System, and Fire Mode Toggle
// 
// BUG FIXES APPLIED:
// ==================
// 1. ADS Empty Magazine Bug: Added magazine check BEFORE A_Overlay in AimFire state
//    - Previously, firing with 0 rounds would trigger muzzle flash but not fire
//    - Now checks magazine first and jumps to EmptyADS if empty
// 2. Magazine Empty Checks: Added checks after firing in AimFire to prevent animation
//    playing with empty magazine in semi-auto mode
// 3. ZOOM EFFECT FIX: Changed zoom behavior on firing to eliminate "pushing in" feeling
//    - The original pitch direction (pitch - recoil) was CORRECT for upward kick
//    - The problem was the zoom factor increasing when firing, creating a "push in" effect
//    - Hipfire: 1.03x -> 0.98x (zooms OUT slightly for kickback feel)
//    - ADS: 1.545x -> 1.47x (zooms OUT from 1.5x base for proper recoil sensation)
//
// ADS LOCK SYSTEM DOCUMENTATION:
// ===============================
// This weapon implements a realistic reload-from-ADS behavior where reloading while aiming
// exits ADS and prevents re-entering ADS until the button is released (like Beyond Citadel).
//
// SYSTEM FLOW:
// 1. User enters ADS (AltFire) -> bADSButtonHeld is set to true
// 2. User presses reload while in ADS and holding ADS button
// 3. Reload state captures bADSButtonHeld value (true) before exiting ADS
// 4. At end of reload animation, bADSLocked is set to bADSButtonHeld (true)
// 5. Reload exits to ForceHipfire -> ReadyLocked state
// 6. ReadyLocked displays CPIS (hipfire) sprite and blocks ADS entry
// 7. A_ReFire detects when ADS button is released
// 8. On release, bADSLocked is cleared and state returns to Ready
// 9. User can now press ADS again to re-enter ADS normally
//
// CRITICAL COMPONENTS:
// - bADSButtonHeld: Captured in AltFire, read at end of reload to set lock
// - bADSLocked: Prevents ADS entry, cleared only when button released
// - ForceHipfire: Explicitly sets CPIS sprite before ReadyLocked
// - ReadyLocked: Uses WRF_NOSECONDARY to block AltFire + A_ReFire to detect release
// - A_ReFire: Reliable button release detection (doesn't get consumed by A_WeaponReady)
//
// WHY GetPlayerInput DOESN'T WORK:
// GetPlayerInput(INPUT_BUTTONS) returns button state AFTER A_WeaponReady has processed it.
// When WRF_NOSECONDARY is used, the button appears released even when held.
// A_ReFire works because it checks the button state independently of A_WeaponReady.
//
// SEMI-AUTO SYSTEM (COMBINED APPROACH):
// ======================================
// Uses BOTH edge detection AND conditional WRF_NOFIRE for reliable semi-auto that's responsive to clicks:
// 1. JustPressedFire() detects rising edge (button transition from not-pressed to pressed)
// 2. Edge detection checks at start of Ready/AltHold/ReadyLocked allow instant firing on press
// 3. Edge detection checks during fire animation allow responsive follow-up shots mid-recovery
// 4. After firing in semi-auto, bJustFired flag is set to true
// 5. WRF_NOFIRE flag is added ONLY when button is held AND bJustFired is true
// 6. When button is released, bJustFired is cleared
// 7. This allows fast clicking while preventing hold-to-fire in semi-auto mode
// 8. WRF_NOFIRE is only active conditionally, so AltFire/reload/etc. work normally
//
// Key Benefits:
// - Edge detection = responsive to rapid clicks (can fire mid-recovery animation)
// - Conditional WRF_NOFIRE = prevents hold-to-fire abuse in semi-auto
// - Combination = best of both worlds for competitive FPS feel
//
// Why not WRF_NOFIRE alone? It would block AltFire/reload when active.
// Why not edge detection alone? Players could hold to fire by creating micro-releases.
//
class CustomReloadPistol : DoomWeapon
{
    bool bInADS;
    bool bAutoFire;  // Fire mode: false = semi-auto, true = full-auto
    int modeCooldown; // debounce cooldown in tics
    int loaded;
    
    // ADS Lock System - prevents re-entering ADS after reload until button is released
    // This mimics the behavior in games like Beyond Citadel where reloading while in ADS
    // exits to hipfire and requires you to release and re-press the ADS button
    bool bADSLocked;      // True when ADS is locked (can't enter ADS until button released)
    bool bADSButtonHeld;  // Captures if ADS button was held at the moment reload started
    int reloadCooldown;   // Prevents reload spam (frames remaining)
    int adsLockFrames;    // Reserved for future use
    
    // Semi-Auto System - blocks repeat firing until button released
    bool bJustFired;      // Set after firing in semi-auto, cleared when button released
    
    const MAGAZINE_CAPACITY = 20;
    
    // Recoil system for automatic fire - increased for more noticeable impact
    double recoilAccumulator;      // Current accumulated recoil
    const RECOIL_PER_SHOT = 2.0;   // More pronounced recoil for impactful feel
    const RECOIL_RECOVERY = 0.22;  // Slightly faster recovery to keep it controllable
    const MAX_RECOIL = 16.0;       // Higher cap for longer bursts
    
    // Breathing effect variables for ADS (now used for camera movement)
    int breathCounter;
    int adsHoldFrames;          // Count frames at center before breathing starts
    double breathPhaseX;        // random phase X per ADS
    double breathPhaseY;        // random phase Y per ADS
    double breathFreqX;         // random sign per ADS for X frequency
    double breathFreqY;         // random sign per ADS for Y frequency
    double breathBlend;         // 0.0 = U-shape, 1.0 = circular, 2.0 = inverted U
    double breathTargetBlend;   // target blend to transition towards
    
    // Crosshair expansion variables (for future hip-fire bloom)
    double crosshairScale;
    
    Default
    {
        Weapon.SelectionOrder 1900;
        Weapon.AmmoUse 0;
        Weapon.AmmoGive 30;
        Weapon.AmmoType "PistolAmmo";
        Weapon.SlotNumber 2;
        Inventory.Pickupmessage "Picked up a custom pistol!";
        Obituary "%o was shot down.";
        Tag "Custom Pistol";
        Scale 0.2;
        +WEAPON.WIMPY_WEAPON;
        +WEAPON.AMMO_OPTIONAL;
        +WEAPON.NOALERT;
    }
    
    override void PostBeginPlay()
    {
        Super.PostBeginPlay();
        loaded = MAGAZINE_CAPACITY;
        crosshairScale = 1.0;  // Initialize crosshair scale
        bAutoFire = false;  // Start in semi-auto mode
        recoilAccumulator = 0;
        modeCooldown = 0;
        bADSLocked = false;
        bADSButtonHeld = false;
        reloadCooldown = 0;
        adsLockFrames = 0;
        bJustFired = false;  // Initialize semi-auto flag
    }
    
    override void AttachToOwner(Actor other)
    {
        Super.AttachToOwner(other);
        if (loaded == 0)
            loaded = MAGAZINE_CAPACITY;
    }
    
    override bool CheckAmmo(int fireMode, bool autoSwitch, bool requireAmmo, int ammocount)
    {
        return true;
    }
    
    // Action function to toggle fire mode
    action void A_ToggleFireMode()
    {
        invoker.bAutoFire = !invoker.bAutoFire;
        A_StartSound("custompistol/firemode", CHAN_WEAPON);
        
        String modeMsg = invoker.bAutoFire ? "Full-Auto Mode" : "Semi-Auto Mode";
        //A_Print(modeMsg);
    }
    
    // Edge detection: detects when button transitions from not-pressed to pressed
    action bool JustPressedFire()
    {
        return (player.cmd.buttons & BT_ATTACK) && !(player.oldbuttons & BT_ATTACK);
    }
    
    // Edge detection for ADS button
    action bool JustPressedADS()
    {
        return (player.cmd.buttons & BT_ALTATTACK) && !(player.oldbuttons & BT_ALTATTACK);
    }
    
    // Apply recoil to view (both hipfire and ADS)
    action void A_ApplyRecoil(double amount)
    {
        // Add to accumulator
        invoker.recoilAccumulator = min(invoker.recoilAccumulator + amount, invoker.MAX_RECOIL);
        
        // Apply accumulated recoil to pitch (camera kicks UP)
        // pitch - value = look UP (recoil direction) - this is CORRECT
        A_SetPitch(pitch - invoker.recoilAccumulator * 0.3);
    }
    
    // Recover from recoil gradually
    action void A_RecoverRecoil()
    {
        if (invoker.recoilAccumulator > 0)
        {
            invoker.recoilAccumulator = max(0, invoker.recoilAccumulator - invoker.RECOIL_RECOVERY);
        }
    }
    
    States
    {
    Ready:
        // COMBINED SEMI-AUTO: Edge detection for instant response + WRF_NOFIRE to prevent hold-to-fire
        CPIS A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS A 1 
        {
            int buttons = GetPlayerInput(-1, INPUT_BUTTONS);
            bool fireButtonHeld = (player.cmd.buttons & BT_ATTACK) != 0;
            
            // Clear bJustFired when button is released
            if (!fireButtonHeld && invoker.bJustFired)
            {
                invoker.bJustFired = false;
            }
            
            // Clear reload cooldown when reload button is released
            if ((buttons & BT_RELOAD) == 0)
            {
                invoker.reloadCooldown = 0;
            }
            
            // Setup ready flags
            int readyFlags = WRF_ALLOWRELOAD | WRF_ALLOWUSER1;
            
            // CRITICAL: Only add WRF_NOFIRE if in semi-auto AND button is held after firing
            // This allows AltFire to work while still preventing hold-to-fire
            if (!invoker.bAutoFire && fireButtonHeld && invoker.bJustFired)
            {
                readyFlags |= WRF_NOFIRE;
            }
            
            A_WeaponReady(readyFlags);
            A_RecoverRecoil();
            
            if (invoker.modeCooldown > 0) invoker.modeCooldown--;
            
            // Continue zoom transition if coming from ADS
            if (!invoker.bInADS)
            {
                A_ZoomFactor(1.0, ZOOM_NOSCALETURNING);
                A_ClearOverlays(1000, 1000);
                A_SetViewAngle(0);
                A_SetViewPitch(0);
            }
            
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        }
        Loop;
    
    // Fire mode toggle with debounce so it only flips once per press
    User1:
        TNT1 A 0
        {
            if (invoker.modeCooldown > 0)
            {
                if (invoker.bInADS)
                    return ResolveState("AltHold");
                else if (invoker.bADSLocked)
                    return ResolveState("ReadyLocked");
                else
                    return ResolveState("Ready");
            }
            invoker.modeCooldown = 12;
            A_ToggleFireMode();
            if (invoker.bInADS)
                return ResolveState("ADSNod");
            else
                return ResolveState("HipNod");
        }
    
    ADSToggleWait:
        CPAD A 1
        {
            int now = GetPlayerInput(-1, INPUT_BUTTONS);
            if ((now & BT_USER1) != 0)
                return ResolveState(null); // keep waiting while held
            return ResolveState("AltHold"); // released
        }
        Goto AltHold;
    
    HipToggleWait:
        CPIS A 1
        {
            int now = GetPlayerInput(-1, INPUT_BUTTONS);
            if ((now & BT_USER1) != 0)
                return ResolveState(null); // keep waiting while held
            if (invoker.bADSLocked)
                return ResolveState("ReadyLocked");
            else
                return ResolveState("Ready"); // released
        }
        Goto Ready;
    
    ADSNod:
        CPAD A 2 A_WeaponOffset(0, 50, WOF_INTERPOLATE);
        CPAD A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto ADSToggleWait;
    
    HipNod:
        CPIS A 2 A_WeaponOffset(0, 50, WOF_INTERPOLATE);
        CPIS A 2 A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        Goto HipToggleWait;
    
    Deselect:
        CPIS A 0 
        {
            A_ClearOverlays(1000, 1000);  // Remove crosshair when switching weapons
            // Reset camera view
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0, SPF_INTERPOLATE);
            invoker.recoilAccumulator = 0;  // Reset recoil on weapon switch
            invoker.modeCooldown = 0; // clear debounce on switch
            invoker.bJustFired = false; // Clear semi-auto flag
        }
        CPIS A 1 A_Lower;
        Loop;
    
    Select:
        CPIS A 0 A_SetCrosshair(-1);  // Hide default crosshair permanently
        CPIS A 1 A_Raise;
        Loop;
    
    Fire:
        TNT1 A 0
        {
            if (invoker.loaded <= 0)
            {
                A_StartSound("custompistol/empty", CHAN_WEAPON);
                return ResolveState("DryFire");
            }
            return ResolveState(null);
        }
        TNT1 A 0 A_JumpIf(invoker.bInADS, "AimFire");
        TNT1 A 0 A_Overlay(-2, "MuzzleFlash");  // Add muzzle flash overlay
        CPIS E 2 Bright  // Balanced speed for auto-fire
        {
            A_AlertMonsters();
            A_FireBullets(2.0, 2.0, -1, 10, "BulletPuff", FBF_USEAMMO, 0, "GunSmokeSpawner", 0, 0);
            A_StartSound("custompistol/fire", CHAN_WEAPON);
            A_Light1();
            invoker.loaded--;
            // Zoom OUT for kickback sensation (was 1.03 zoom IN)
            A_ZoomFactor(0.98, ZOOM_NOSCALETURNING);
            
            //A_Log("About to spawn hipfire casing spawner");
            // Spawn brass casing using spawner that respects pitch
            A_FireProjectile("PistolCasingSpawner", 0, false, 0, -6);
            //A_Log("Hipfire casing spawner command executed");
            
            // Apply recoil if in auto mode
            if (invoker.bAutoFire)
                A_ApplyRecoil(invoker.RECOIL_PER_SHOT);
            
            // SEMI-AUTO: Set flag after firing
            if (!invoker.bAutoFire)
            {
                invoker.bJustFired = true;
            }
        }
        CPIS F 1 Bright
        {
            A_Light0();
            A_ZoomFactor(1.0, ZOOM_NOSCALETURNING);
        }
        TNT1 A 0 A_JumpIf(invoker.bAutoFire, "FireAuto");
        // Semi-auto: Edge detection checks on EVERY tic during recovery animation
        // This allows responsive follow-up shots even mid-animation for competitive gameplay feel
        // Also check for ADS button to allow quick transition to ADS mid-recovery
        CPIS G 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS G 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS G 1;
        CPIS G 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS G 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS G 1;
        CPIS H 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS H 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS H 1;
        CPIS H 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS H 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS H 1;
        CPIS I 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS I 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS I 1;
        CPIS I 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS I 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS I 1;
        CPIS J 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS J 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS J 1;
        CPIS J 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS J 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS J 1;
        CPIS K 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS K 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS K 1;
        CPIS K 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS K 0 A_JumpIf(JustPressedADS(), "AltFire");
        CPIS K 1;
        Goto Ready;
    
    // Balanced fire rate for automatic mode
    FireAuto:
        CPIS J 1 A_RecoverRecoil();
        TNT1 A 0 A_JumpIf(JustPressedADS(), "AltFire");  // Allow quick ADS transition
        TNT1 A 0 A_ReFire("Fire");  // Refire after 1-tic recovery
        Goto Ready;
    
    DryFire:
        CPIS A 0 A_JumpIf(invoker.bInADS, "EmptyADS");
        CPIS A 10;
        Goto Ready;
    
    EmptyADS:
        CPAD A 10;
        Goto AltHold;
    
    AltFire:
        TNT1 A 0
        {
            // If already in ADS, go straight to AltHold
            if (invoker.bInADS)
                return ResolveState("AltHold");
            
            invoker.bADSButtonHeld = true;
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);  // Reset to center before starting ADS
            return ResolveState(null);
        }
        CPAD A 1 
        {
            A_ZoomFactor(1.5, ZOOM_NOSCALETURNING);
            invoker.bInADS = true;
            // Start counter at 0 for smooth start from center
            invoker.breathCounter = 0;
            invoker.adsHoldFrames = 0;

            // Mix phase with level time so each ADS entry gets a different start even with deterministic RNG
            double t = double(level.time % 1024) / 1024.0;
            invoker.breathPhaseX = (t + frandom(0.0, 1.0)) * 6.28318530718; // 0..2Ãâ‚¬
            invoker.breathPhaseY = (double((level.time * 3) % 1024) / 1024.0 + frandom(0.0, 1.0)) * 6.28318530718;

            // Randomize frequency sign per ADS to avoid consistent pull bias
            invoker.breathFreqX = (random(0, 1) == 0 ? 1.9 : -1.9);
            invoker.breathFreqY = (random(0, 1) == 0 ? 2.2 : -2.2);
            
            
            // Randomly start with one of three patterns: U-shape (0), circular (1), inverted U (2)
            invoker.breathBlend = double(random(0, 2));
            int nextPattern = random(0, 2);
            while (nextPattern == int(invoker.breathBlend)) nextPattern = random(0, 2);
            invoker.breathTargetBlend = double(nextPattern);
            
            // Start ADS crosshair overlay (fixed at center)
            A_Overlay(1000, "ADSCrosshair");
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        }
        Goto AltHold;
    
    AltHold:
        // COMBINED SEMI-AUTO: Edge detection for instant response + WRF_NOFIRE to prevent hold-to-fire
        CPAD A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "AimFire");
        CPAD A 1 
        {
            int buttons = GetPlayerInput(-1, INPUT_BUTTONS);
            bool fireButtonHeld = (player.cmd.buttons & BT_ATTACK) != 0;
            
            // Clear bJustFired when button is released
            if (!fireButtonHeld && invoker.bJustFired)
            {
                invoker.bJustFired = false;
            }
            
            // Clear reload cooldown when reload button is released
            if ((buttons & BT_RELOAD) == 0)
            {
                invoker.reloadCooldown = 0;
            }
            
            // Setup ready flags
            int readyFlags = WRF_NOBOB | WRF_ALLOWUSER1;
            if (invoker.reloadCooldown == 0)
                readyFlags |= WRF_ALLOWRELOAD;
            
            // CRITICAL: Only add WRF_NOFIRE if in semi-auto AND button is held after firing
            if (!invoker.bAutoFire && fireButtonHeld && invoker.bJustFired)
            {
                readyFlags |= WRF_NOFIRE;
            }
            
            A_WeaponReady(readyFlags);
            A_RecoverRecoil();
            
            if (invoker.modeCooldown > 0) invoker.modeCooldown--;
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            
            // Apply breathing motion to camera
            if (invoker.adsHoldFrames < 4)
            {
                invoker.adsHoldFrames++;
                A_SetViewAngle(0, SPF_INTERPOLATE);
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
        CPAD A 0 A_ReFire("AltHold");
        Goto AltRelease;
    
    AltRelease:
        CPAD A 0
        {
            // ADS LOCK SYSTEM: Clear button held flag when exiting ADS normally
            // This ensures that if you enter ADS, release without reloading, the flag is cleared
            invoker.bADSButtonHeld = false;
            
            // Remove ADS crosshair overlay immediately
            A_ClearOverlays(1000, 1000);
            // Reset camera view offsets
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0, SPF_INTERPOLATE);
        }
        CPAD A 1 
        {
            A_ZoomFactor(1.0, ZOOM_NOSCALETURNING);
            invoker.bInADS = false;
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
            invoker.breathCounter = 0;
            invoker.adsHoldFrames = 0;
        }
        Goto Ready;
    
    // Custom crosshair overlay for ADS - using sprite XHADS0 (fixed at center)
    ADSCrosshair:
        XHAD S 1 
        {
            A_OverlayFlags(1000, PSPF_RENDERSTYLE | PSPF_ALPHA, true);
        	A_OverlayScale(1000, 0.1, 0.1 * 0.83334, WOF_INTERPOLATE); // Compensate for 1.2x vertical stretch
			// Keep ADS crosshair fixed at center
            A_OverlayOffset(1000, 159.75, 69.25, WOF_INTERPOLATE);
            // Check if we should stop this overlay
            if (!invoker.bInADS)
                return ResolveState("Null");
            return ResolveState(null);
        }
        Loop;
    
    AimFire:
        TNT1 A 0
        {
            // BUG FIX: Check magazine BEFORE overlay/firing
            if (invoker.loaded <= 0)
            {
                A_StartSound("custompistol/empty", CHAN_WEAPON);
                return ResolveState("EmptyADS");
            }
            return ResolveState(null);
        }
        TNT1 A 0 A_Overlay(-2, "MuzzleFlashADS");  // Add ADS muzzle flash overlay
        CPAD D 2 Bright  // Balanced speed for auto-fire
        {
            A_AlertMonsters();
            A_FireBullets(0, 0, 1, 10, "BulletPuff", FBF_USEAMMO, 0, "GunSmokeSpawnerADS", 8, 0);
            A_StartSound("custompistol/fire", CHAN_WEAPON);
            A_Light1();
            invoker.loaded--;
            // Zoom OUT from base 1.5x ADS for proper kickback sensation
            A_ZoomFactor(1.47, ZOOM_NOSCALETURNING);
            
            //A_Log("About to spawn ADS casing spawner");
            // Spawn brass casing using spawner that respects pitch (higher for ADS)
            A_FireProjectile("PistolCasingSpawner", 0, false, 0, 2);
            //A_Log("ADS casing spawner command executed");
            
            // Apply recoil if in auto mode
            if (invoker.bAutoFire)
                A_ApplyRecoil(invoker.RECOIL_PER_SHOT);
            
            // SEMI-AUTO: Set flag after firing
            if (!invoker.bAutoFire)
            {
                invoker.bJustFired = true;
            }
        }
        CPAD D 1 Bright
        {
            A_Light0();
            A_ZoomFactor(1.5, ZOOM_NOSCALETURNING);
        }
        TNT1 A 0 A_JumpIf(invoker.bAutoFire, "AimFireAuto");
        // BUG FIX: Check if magazine is empty after firing
        // These repeated checks prevent the recovery animation from playing when magazine is empty
        // Without them, semi-auto would show full recovery animation even with 0 rounds left
        // Semi-auto: check for edge detection every tic during recovery for responsive follow-up shots
        // A_ReFire(null) checks if ADS button is held - if released, exits to hipfire via AltRelease
        CPAD A 0 A_JumpIf(invoker.loaded <= 0, "EmptyADS");
        CPAD A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "AimFire");
        CPAD A 0 A_ReFire(null);  // Check if ADS button is still held, if not exit to hipfire
        CPAD A 1;
        CPAD A 0 A_JumpIf(invoker.loaded <= 0, "EmptyADS");
        CPAD A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "AimFire");
        CPAD A 0 A_ReFire(null);
        CPAD A 1;
        CPAD A 0 A_JumpIf(invoker.loaded <= 0, "EmptyADS");
        CPAD A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "AimFire");
        CPAD A 0 A_ReFire(null);
        CPAD A 1;
        CPAD A 0 A_JumpIf(invoker.loaded <= 0, "EmptyADS");
        CPAD A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "AimFire");
        CPAD A 0 A_ReFire(null);
        CPAD A 1;
        CPAD A 0 A_JumpIf(invoker.loaded <= 0, "EmptyADS");
        CPAD A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "AimFire");
        CPAD A 0 A_ReFire(null);
        CPAD A 1;
        CPAD A 0 A_JumpIf(invoker.loaded <= 0, "EmptyADS");
        CPAD A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "AimFire");
        CPAD A 0 A_ReFire(null);
        CPAD A 1;
        CPAD A 0 A_ReFire("AltHold");  // Stay in ADS if button still held
        Goto AltRelease;  // Exit ADS if button was released
    
    // Balanced fire rate for ADS automatic mode
    AimFireAuto:
        CPAD A 1 A_RecoverRecoil();
        TNT1 A 0 A_ReFire("AimFire");  // Refire after 1-tic recovery
        // Check if ADS button is still held manually
        CPAD A 0
        {
            if (player.cmd.buttons & BT_ALTATTACK)
                return ResolveState("AltHold");
            return ResolveState("AltRelease");
        }
        Goto AltRelease;
    
    // Muzzle flash overlay for hip-fire
    MuzzleFlash:
        MZFL ABCDEF 1 Bright A_OverlayFlags(2, PSPF_RENDERSTYLE | PSPF_ALPHA, true);
        Stop;
    
    // Muzzle flash overlay for ADS - positioned higher to align with ADS view
    MuzzleFlashADS:
        MZFL ABCDEF 1 Bright 
        {
            A_OverlayFlags(-2, PSPF_RENDERSTYLE | PSPF_ALPHA, true);
            A_OverlayOffset(-2, -1, -10, WOF_INTERPOLATE);  // Offset upward for ADS alignment
        }
        Stop;
    
    Reload:
        TNT1 A 0
        {
            // IMPORTANT: Check magazine capacity BEFORE exiting ADS
            // This prevents the weapon from exiting ADS when reload is pressed with a full magazine
            if (invoker.loaded >= invoker.MAGAZINE_CAPACITY)
            {
                // Return to appropriate state without changing anything
                return invoker.bInADS ? ResolveState("AltHold") : ResolveState("Ready");
            }
            
            // Set reload cooldown to prevent reload spam
            invoker.reloadCooldown = 35;
            
            // ADS LOCK SYSTEM INITIALIZATION:
            // At this point, bADSButtonHeld already contains the button state from when we entered AltFire
            // We DON'T set it here because that would read the button state AFTER A_WeaponReady consumed it
            // The value was captured in AltFire state and will be used later to set bADSLocked
            
            // Always exit ADS when performing a reload
            A_ZoomFactor(1.0, ZOOM_INSTANT | ZOOM_NOSCALETURNING);
            invoker.bInADS = false;
            A_ClearOverlays(1000, 1000);
            // Reset camera view offsets when reloading
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0, SPF_INTERPOLATE);
            invoker.recoilAccumulator = 0;  // Reset recoil when reloading
            invoker.modeCooldown = 0; // clear debounce on reload
            invoker.bJustFired = false; // Clear semi-auto flag when reloading
            
            return ResolveState(null);
        }
        TNT1 A 0 A_JumpIfInventory("PistolAmmo", 1, "PerformReload");
        TNT1 A 0 A_StartSound("custompistol/empty", CHAN_WEAPON);
        TNT1 A 0
        {
            // Even with no ammo, if ADS was held, lock it
            invoker.bADSLocked = invoker.bADSButtonHeld;
            return invoker.bADSLocked ? ResolveState("ForceHipfire") : ResolveState("Ready");
        }
        Goto Ready;
    
    PerformReload:
        TNT1 A 0 A_JumpIf(invoker.loaded > 0, "ReloadHasAmmo");
        Goto ReloadEmpty;
    
    ReloadHasAmmo:
        CPRL A 2;
        CPRL B 2;
        CPRL C 2 A_StartSound("custompistol/unloadmag", CHAN_WEAPON);
        CPRL D 2;
        CPRL E 2;
        CPRL F 2;
        CPRL G 2 
        {
            A_StartSound("custompistol/loadmag", CHAN_WEAPON);
            int needed = invoker.MAGAZINE_CAPACITY - invoker.loaded;
            int available = CountInv("PistolAmmo");
            int toLoad = min(needed, available);
            A_TakeInventory("PistolAmmo", toLoad, TIF_NOTAKEINFINITE);
            invoker.loaded += toLoad;
        }
        CPRL H 2;
        CPRL I 2;
        CPRL J 2;
        CPRL K 2;
        CPRL L 2
        {
            // ADS LOCK ACTIVATION: At the end of reload, check if ADS button was held when reload started
            // If it was held, activate the ADS lock to prevent immediately re-entering ADS
            invoker.bADSLocked = invoker.bADSButtonHeld;
        }
        Goto CheckReloadExit;
    
    ReloadEmpty:
        CPRE A 2;
        CPRE B 2;
        CPRE C 2 A_StartSound("custompistol/unloadmagempty", CHAN_WEAPON);
        CPRE D 2;
        CPRE E 2;
        CPRE F 2;
        CPRE G 2;
        CPRE H 2 
        {
            A_StartSound("custompistol/loadmagempty", CHAN_WEAPON);
            int available = CountInv("PistolAmmo");
            int toLoad = min(invoker.MAGAZINE_CAPACITY, available);
            A_TakeInventory("PistolAmmo", toLoad, TIF_NOTAKEINFINITE);
            invoker.loaded = toLoad;
        }
        CPRE I 2;
        CPRE J 2;
        CPRE K 2;
        CPRE L 2;
        CPRE M 2 A_StartSound("custompistol/slide", CHAN_WEAPON);
        CPRE N 2;
        CPRE O 2
        {
            // ADS LOCK ACTIVATION: Same as ReloadHasAmmo
            invoker.bADSLocked = invoker.bADSButtonHeld;
        }
        Goto CheckReloadExit;
    
    // RELOAD EXIT ROUTING: Determine which ready state to enter based on ADS lock status
    CheckReloadExit:
        TNT1 A 0 A_JumpIf(invoker.bADSLocked, "ForceHipfire");
        Goto Ready;
    
    // SPRITE FORCING STATE: Explicitly sets weapon sprite to hipfire before entering ReadyLocked
    // This is necessary because state transitions don't always update the sprite immediately
    // Without this, the ADS sprite (CPAD) could remain displayed even though we're in a hipfire state
    ForceHipfire:
        TNT1 A 0
        {
            // Explicitly set the weapon layer sprite to hipfire (CPIS A)
            let psp = player.FindPSprite(PSP_WEAPON);
            if (psp)
            {
                psp.sprite = GetSpriteIndex("CPIS");
                psp.frame = 0;
            }
        }
        CPIS A 0;  // Ensure state also uses CPIS sprite
        Goto ReadyLocked;
    
    // ADS LOCKED READY STATE: Weapon is ready but ADS is locked until button is released
    // This state is entered after reloading while holding the ADS button
    // Key behaviors:
    // 1. Displays hipfire sprite (CPIS) even if ADS button is held
    // 2. Blocks ADS entry using WRF_NOSECONDARY flag
    // 3. Uses A_ReFire to reliably detect when ADS button is released
    // 4. Allows firing, reloading, and fire mode toggle
    ReadyLocked:
        // COMBINED SEMI-AUTO: Edge detection for instant response + WRF_NOFIRE to prevent hold-to-fire
        CPIS A 0 A_JumpIf(!invoker.bAutoFire && JustPressedFire(), "Fire");
        CPIS A 1
        {
            int buttons = GetPlayerInput(-1, INPUT_BUTTONS);
            bool reloadHeld = (buttons & BT_RELOAD) != 0;
            bool fireButtonHeld = (player.cmd.buttons & BT_ATTACK) != 0;
            
            // Clear bJustFired when button is released
            if (!fireButtonHeld && invoker.bJustFired)
            {
                invoker.bJustFired = false;
            }
            
            // Clear reload cooldown when reload button is released
            if (!reloadHeld)
            {
                invoker.reloadCooldown = 0;
            }
            
            // Setup ready flags
            int readyFlags = WRF_ALLOWUSER1 | WRF_NOSECONDARY;
            if (invoker.reloadCooldown == 0)
                readyFlags |= WRF_ALLOWRELOAD;
            
            // CRITICAL: Only add WRF_NOFIRE if in semi-auto AND button is held after firing
            if (!invoker.bAutoFire && fireButtonHeld && invoker.bJustFired)
            {
                readyFlags |= WRF_NOFIRE;
            }
            
            A_WeaponReady(readyFlags);
            A_RecoverRecoil();
            if (invoker.modeCooldown > 0) invoker.modeCooldown--;
            
            // Force hipfire visual state
            A_ZoomFactor(1.0, ZOOM_NOSCALETURNING);
            A_ClearOverlays(1000, 1000);
            A_SetViewAngle(0, SPF_INTERPOLATE);
            A_SetViewPitch(0, SPF_INTERPOLATE);
            
            A_WeaponOffset(0, 32, WOF_INTERPOLATE);
        }
        // BUTTON RELEASE DETECTION using A_ReFire:
        // A_ReFire checks if the alt fire button is still held
        // - If held: loops back to ReadyLocked (stays locked)
        // - If released: falls through to unlock code below
        // This is more reliable than GetPlayerInput because A_WeaponReady doesn't consume it
        CPIS A 0 A_ReFire("ReadyLocked");
        // Button was released - unlock ADS and return to normal Ready state
        CPIS A 0
        {
            invoker.bADSLocked = false;
            invoker.bADSButtonHeld = false;
        }
        Goto Ready;
    
    Spawn:
        CPIP A -1;
        Stop;
    }
}