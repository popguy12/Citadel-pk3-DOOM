// ====================
// CASING CLASSES
// ====================

// Casing spawner - invisible projectile that spawns casings and respects pitch
class PistolCasingSpawner : Actor
{
    Default
    {
        Speed 25;
        Projectile;
        +NOCLIP;
        +NOGRAVITY;
    }
    
    States
    {
    Spawn:
        TNT1 A 2;  // Travel for 2 tics to move forward
        TNT1 A 1
        {
            // Spawn the actual casing with rightward and increased upward velocity
            A_SpawnItemEx("PistolBrassCasing", 0, 0, 0, frandom(1,3), frandom(3,6), frandom(2.5,4.5), 0, SXF_NOCHECKPOSITION);
        }
        Stop;
    }
}

// Brass casing actor - spawned by PistolCasingSpawner (spinning version for pistol)
class PistolBrassCasing : Actor
{
    Default
    {
        Radius 2;
        Height 4;
        Scale 0.15;
        RenderStyle "Translucent";
        Alpha 1.0;
        +MISSILE
        +DROPOFF
        +NOTELEPORT
        +CANNOTPUSH
        -NOGRAVITY
        Gravity 0.4;
        BounceFactor 0.3;
        BounceCount 2;
    }
    
    States
    {
    Spawn:
        SHEL ABCD 1;  // Spinning while airborne (side view)
        Loop;
    Death:
        TNT1 A 0
        {
            //A_Log("Casing entered Death state");
            int pick = random(1, 4);
            if (pick == 1) return ResolveState("Ground1");
            if (pick == 2) return ResolveState("Ground2");
            if (pick == 3) return ResolveState("Ground3");
            return ResolveState("Ground4");
        }
    Ground1:
        TNT1 A 0 
        {
            //A_Log("Ground1: Playing sound");
            A_StartSound("custompistol/casing1", CHAN_AUTO, 0, frandom(0.2, 0.4));
        }
        SHEL E 350;
        SHEL E 1 A_FadeOut(0.05);
        Wait;
    Ground2:
        TNT1 A 0 
        {
            //A_Log("Ground2: Playing sound");
            A_StartSound("custompistol/casing2", CHAN_AUTO, 0, frandom(0.2, 0.4));
        }
        SHEL F 350;
        SHEL F 1 A_FadeOut(0.05);
        Wait;
    Ground3:
        TNT1 A 0 
        {
            //A_Log("Ground3: Playing sound");
            A_StartSound("custompistol/casing3", CHAN_AUTO, 0, frandom(0.2, 0.4));
        }
        SHEL G 350;
        SHEL G 1 A_FadeOut(0.05);
        Wait;
    Ground4:
        TNT1 A 0 
        {
            //A_Log("Ground4: Playing sound");
            A_StartSound("custompistol/casing4", CHAN_AUTO, 0, frandom(0.2, 0.4));
        }
        SHEL E 350;
        SHEL E 1 A_FadeOut(0.05);
        Wait;
    }
}

// SMG Brass Casing - non-spinning version for rapid ejection
class SMGBrassCasing : Actor
{
    Default
    {
        Radius 2;
        Height 4;
        Scale 0.15;
        RenderStyle "Translucent";
        Alpha 1.0;
        +MISSILE
        +DROPOFF
        +NOTELEPORT
        +CANNOTPUSH
        -NOGRAVITY
        Gravity 0.4;
        BounceFactor 0.3;
        BounceCount 2;
    }
    
    States
    {
    Spawn:
        SHEL D 1;  // Static frame - no spinning for SMG casings
        Loop;
    Death:
        TNT1 A 0
        {
            int pick = random(1, 4);
            if (pick == 1) return ResolveState("Ground1");
            if (pick == 2) return ResolveState("Ground2");
            if (pick == 3) return ResolveState("Ground3");
            return ResolveState("Ground4");
        }
    Ground1:
        TNT1 A 0 
        {
            A_StartSound("customsmg/casing1", CHAN_AUTO, 0, frandom(0.1, 0.3));
        }
        SHEL E 350;
        SHEL E 1 A_FadeOut(0.05);
        Wait;
    Ground2:
        TNT1 A 0 
        {
            A_StartSound("customsmg/casing2", CHAN_AUTO, 0, frandom(0.1, 0.3));
        }
        SHEL F 350;
        SHEL F 1 A_FadeOut(0.05);
        Wait;
    Ground3:
        TNT1 A 0 
        {
            A_StartSound("customsmg/casing3", CHAN_AUTO, 0, frandom(0.1, 0.3));
        }
        SHEL G 350;
        SHEL G 1 A_FadeOut(0.05);
        Wait;
    Ground4:
        TNT1 A 0 
        {
            A_StartSound("customsmg/casing4", CHAN_AUTO, 0, frandom(0.1, 0.3));
        }
        SHEL E 350;
        SHEL E 1 A_FadeOut(0.05);
        Wait;
    }
}

// SMG Casing spawner - spawns non-spinning casings with consistent height
class SMGCasingSpawner : Actor
{
    Default
    {
        Speed 25;
        Projectile;
        +NOCLIP;
        +NOGRAVITY;
    }
    
    States
    {
    Spawn:
        TNT1 A 2;  // Travel for 2 tics to move forward
        TNT1 A 1
        {
            // Spawn the SMG casing with increased distance but same arc shape
            // Scaled up velocities proportionally: Y increased to 4-8, Z to 2.66 for consistent arc
            A_SpawnItemEx("SMGBrassCasing", 0, 0, 0, frandom(1,3), frandom(4,8), 2.66, 0, SXF_NOCHECKPOSITION);
        }
        Stop;
    }
}
