// ====================
// GUN SMOKE CLASSES
// ====================

// Gun smoke spawner - spawns multiple smoke puff sprites for pistol
class PistolGunSmoke : Actor
{
    Default
    {
        +NOINTERACTION;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOTELEPORT;
        +CLIENTSIDEONLY;
    }
    
    States
    {
    Spawn:
        TNT1 A 0 NoDelay
        {
            // Spawn 4-6 smoke puffs
            int puffCount = random(4, 6);
            for (int i = 0; i < puffCount; i++)
            {
                let puff = Spawn("GunSmokePuff", pos);
                if (puff)
                {
                    // Increased upward velocity for visible rise
                    puff.vel = (
                        frandom(-0.1, 0.1),
                        frandom(-0.1, 0.1),
                        frandom(0.35, 0.45)
                    );
                }
            }
        }
        TNT1 A 1;
        Stop;
    }
}

// Gun smoke spawner - spawns multiple smoke puff sprites for SMG
class SMGGunSmoke : Actor
{
    Default
    {
        +NOINTERACTION;
        +NOBLOCKMAP;
        +NOGRAVITY;
        +NOTELEPORT;
        +CLIENTSIDEONLY;
    }
    
    States
    {
    Spawn:
        TNT1 A 0 NoDelay
        {
            // Spawn 4-6 smoke puffs
            int puffCount = random(4, 6);
            for (int i = 0; i < puffCount; i++)
            {
                let puff = Spawn("GunSmokePuff", pos);
                if (puff)
                {
                    // Increased upward velocity for visible rise
                    puff.vel = (
                        frandom(-0.1, 0.1),
                        frandom(-0.1, 0.1),
                        frandom(0.35, 0.45)
                    );
                }
            }
        }
        TNT1 A 1;
        Stop;
    }
}

// Individual smoke puff sprite - Citadel style implementation
class GunSmokePuff : Actor
{
    double dissipateRotation;
    int m_sprite;
    int ageOffset;  // Random starting age for varied lifecycle
    
    Default
    {
        Alpha 0.5;  // Starting alpha (will be randomized lower in PostBeginPlay)
        //Renderstyle "Add";
		Renderstyle "Translucent";
        Speed 1;
        BounceFactor 0;
        Radius 0;
        Height 0;
        Mass 0;
        Scale 0.07;  // Increased base scale for better visibility
        +NOBLOCKMAP;
        +NOTELEPORT;
        +DONTSPLASH;
        +MISSILE;
        +FORCEXYBILLBOARD;
        +NOINTERACTION;
        +NOGRAVITY;
        +THRUACTORS;
        +ROLLSPRITE;
        +ROLLCENTER;
        +NOCLIP;
    }
    
    override void PostBeginPlay()
    {
        Super.PostBeginPlay();
        dissipateRotation = frandom(0.7, 1.4) * randompick(-1, 1);
        bXFLIP = randompick(0, 1);
        bYFLIP = randompick(0, 1);
        m_sprite = random(0, 5);  // 6 frames (A-F = 0-5)
        // Bigger range for more variety in smoke puff sizes
        scale.x *= frandom(0.6, 1.4);
        scale.y *= frandom(0.6, 1.4);
        
        // Randomize starting alpha - increased range for better visibility with Add renderstyle
        alpha = frandom(0.45, 0.7);
        
        // Random age offset so puffs spawn at different lifecycle stages
        ageOffset = random(0, 8);
        // Apply initial aging effects based on offset
        if (ageOffset > 0)
        {
            // Scale grows with age but don't reduce alpha more (already randomized)
            scale *= 1.0 + (ageOffset * 0.01);
            roll = frandom(0, 360);  // Random initial rotation
        }
    }
    
    States
    {
    Spawn:
        SMO2 A 1
        {
            invoker.frame = invoker.m_sprite;
            int effectiveAge = GetAge() + invoker.ageOffset;
            
            if (effectiveAge < 22) 
            {
                A_FadeOut(0.017, FTF_CLAMP|FTF_REMOVE); 
                scale *= 1.02;
                vel *= 0.87; 
                roll += dissipateRotation;
                dissipateRotation *= 0.96;
                
                if (CeilingPic == SkyFlatNum)
                {
                    vel.y += 0.02; // wind
                    vel.z += 0.01;
                    vel.x -= 0.01;
                }
            }
            else
            {
                A_FadeOut(0.012, FTF_CLAMP|FTF_REMOVE);
                scale *= 1.01;
                vel *= 0.75; 
                roll += dissipateRotation;
                dissipateRotation *= 0.95;
                
                if (CeilingPic == SkyFlatNum)
                {
                    vel.y += 0.01; // wind
                    vel.z += 0.015;
                    vel.x -= 0.015;
                }

                if (alpha < 0.1)
                    A_FadeOut(0.008, FTF_CLAMP|FTF_REMOVE); 
            }
        }
        Loop;
    }
}