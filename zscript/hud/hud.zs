// Custom HUD to display magazine ammo count for both Pistol and SMG
// This single HUD class handles both weapons
class CustomWeaponsHUD : DoomStatusBar
{
    override void Draw(int state, double TicFrac)
    {
        Super.Draw(state, TicFrac);
        
        // Check for pistol
        let pistol = CustomReloadPistol(CPlayer.ReadyWeapon);
        if (pistol)
        {
            if (state == HUD_StatusBar)
            {
                BeginStatusBar();
                DrawString(mHUDFont, FormatNumber(pistol.loaded, 2), (-30, 171), DI_TEXT_ALIGN_RIGHT, Font.CR_GOLD);
                // Draw fire mode indicator for pistol
                String modeText = pistol.bAutoFire ? "AUTO" : "SEMI";
                int modeColor = pistol.bAutoFire ? Font.CR_RED : Font.CR_GREEN;
                DrawString(mHUDFont, modeText, (-25, 163), DI_TEXT_ALIGN_RIGHT, modeColor);
            }
            else if (state == HUD_Fullscreen)
            {
                BeginHUD();
                DrawString(mHUDFont, FormatNumber(pistol.loaded, 2), (-75, -20), DI_SCREEN_RIGHT_BOTTOM|DI_TEXT_ALIGN_RIGHT, Font.CR_GOLD);
                // Draw fire mode indicator for pistol
                String modeText = pistol.bAutoFire ? "AUTO" : "SEMI";
                int modeColor = pistol.bAutoFire ? Font.CR_RED : Font.CR_GREEN;
                DrawString(mHUDFont, modeText, (-70, -28), DI_SCREEN_RIGHT_BOTTOM|DI_TEXT_ALIGN_RIGHT, modeColor);
            }
            
            // Draw pistol scope vignette if in ADS
            DrawPistolScopeVignette(pistol);
            
            // Draw pistol hip-fire crosshair
            DrawPistolHipfireCrosshair(pistol);
        }
        
        // Check for SMG
        let smg = CustomReloadSMG(CPlayer.ReadyWeapon);
        if (smg)
        {
            if (state == HUD_StatusBar)
            {
                BeginStatusBar();
                DrawString(mHUDFont, FormatNumber(smg.loaded, 2), (-30, 171), DI_TEXT_ALIGN_RIGHT, Font.CR_GOLD);
            }
            else if (state == HUD_Fullscreen)
            {
                BeginHUD();
                DrawString(mHUDFont, FormatNumber(smg.loaded, 2), (-75, -20), DI_SCREEN_RIGHT_BOTTOM|DI_TEXT_ALIGN_RIGHT, Font.CR_GOLD);
            }
            
            // Draw SMG scope vignette if in ADS
            DrawSMGScopeVignette(smg);
            
            // Draw SMG hip-fire crosshair
            DrawSMGHipfireCrosshair(smg);
        }
    }
    
    // Pistol scope vignette
    void DrawPistolScopeVignette(CustomReloadPistol weapon)
    {
        if (weapon && weapon.bInADS)
        {
            BeginHUD(1.0, true, 1920, 1080);
            DrawImage("SCOPEA0", (0, 0), DI_SCREEN_CENTER | DI_ITEM_CENTER);
        }
    }
    
    // Pistol hip-fire crosshair
    void DrawPistolHipfireCrosshair(CustomReloadPistol weapon)
    {
        if (weapon && !weapon.bInADS)
        {
            BeginHUD();
            DrawImage("XHAIR0", (0, 0), DI_SCREEN_CENTER | DI_ITEM_CENTER);
        }
    }
    
    // SMG scope vignette
    void DrawSMGScopeVignette(CustomReloadSMG weapon)
    {
        if (weapon && weapon.bInADS)
        {
            BeginHUD(1.0, true, 1920, 1080);
            DrawImage("SCOPEA0", (0, 0), DI_SCREEN_CENTER | DI_ITEM_CENTER);
        }
    }
    
    // SMG hip-fire crosshair
    void DrawSMGHipfireCrosshair(CustomReloadSMG weapon)
    {
        if (weapon && !weapon.bInADS)
        {
            BeginHUD();
            DrawImage("XHAIR0", (0, 0), DI_SCREEN_CENTER | DI_ITEM_CENTER);
        }
    }
}
