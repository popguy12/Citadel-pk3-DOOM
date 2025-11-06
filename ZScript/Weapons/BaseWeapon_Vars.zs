extend class CitadelWeapon
{
	double exaggerationMultiplier;
	
	protected int BraceTicker;
	bool GunBraced;
	
	int GunSlotType; //1: Primary, 2: Secondary, 3: Tools and equipment (not counted towards inventory)
	property SlotType: GunSlotType;
	
	string GunStatGraphic;
	string PickupGraphic;
	string PickupGraphicFull;
	string HUDInfoGraphic;
	
	property InfoGraphics: HUDInfoGraphic, PickupGraphic, PickupGraphicFull, GunStatGraphic;
	
	double GunSpeedMod;
	property PlaySpeed: GunSpeedMod;
	
	class<Ammo> AmmoType3;
	int AmmoGive3;
	int AmmoUse3;
	
	int breathCounter;          // Increments each frame to drive the sine wave
	int adsHoldFrames;          // Delays breathing - holds steady for first 4 frames
	double PhaseX;        // Random starting point for horizontal sway
	double PhaseY;        // Random starting point for vertical sway
	double FreqX;         // Random frequency direction for X (±1.2)
	double FreqY;         // Random frequency direction for Y (±1.4)
	
	property AmmoGive3: AmmoGive3;
	property AmmoUse3: AmmoUse3;
	property AmmoType3: AmmoType3;
	//[Pop] Engine only supports 2 ammo types, so custom third for UB modes
	
	/*
	[Pop] template PlaySpeed values per weapon type
	holser 1.6
	normal 1
	pistol 0.95
	smg 0.85
	AR/shotgun 0.8
	DMR/BattleRifle/Sniper 0.75
	LMG 0.65
	big special shit 0.6
	*/
}