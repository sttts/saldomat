//
//  AuthorizationController.m
//  hbci
//
//  Created by Stefan Schimanski on 27.12.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "debug.h"

#import "AppController.h"
#import "AuthorizationController.h"
#import "KontoWindowController.h"

@implementation AuthorizationController


- (BOOL)appHatRecht
{
	// Rechte abfragen
	OSStatus oss;
	AuthorizationItem items[1];
	items[0].name = "com.limoia.saldomat.unlock";
	items[0].value = 0;
	items[0].valueLength = 0;
	items[0].flags = 0;
	AuthorizationRights rights;
	rights.count = 1;
	rights.items = items;
	oss = AuthorizationCopyRights([auth_ authorizationRef],&rights,
				      kAuthorizationEmptyEnvironment,
				      kAuthorizationFlagExtendRights, NULL);
	return errAuthorizationSuccess == oss;
}


- (void)updateVerschlossen
{
	BOOL appHatRechtJetzt = [self appHatRecht];
	
	// Recht geaendert?
	BOOL verschlossen = !(appHatRechtJetzt || pseudoSchloss_);
	if (verschlossen_ != verschlossen) {
		[self willChangeValueForKey:@"verschlossen"];
		verschlossen_ = verschlossen;
		
		// Zustand merken in Config
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		if (verschlossen_) {
			[defaults setBool:NO forKey:@"pseudoOffen"];

			// pseudo entsperrt?
			if (pseudoSchloss_) {
				[self willChangeValueForKey:@"pseudoSchloss"];
				pseudoSchloss_ = NO;
				[self didChangeValueForKey:@"pseudoSchloss"];
			}
		} else
			[defaults setBool:YES forKey:@"pseudoOffen"];
		[defaults synchronize];
		
		// Fehler verstecken bzw. App nach vorne bringen
		if (verschlossen)
			[theAppCtrl versteckeFehler:self];
		else
			[NSApp activateIgnoringOtherApps:YES];

		[self didChangeValueForKey:@"verschlossen"];
	}
	
	// Fenster verstecken, wenn verschlossen, bzw. wieder zeigen
	NSWindow * kontenWindow = [[theAppCtrl kontoWindowController] window];
	if (verschlossen_) {
		if ([kontenWindow isVisible]) {
			[kontenWindow orderOut:self];
			kontenWindowVersteckt_ = true;
		}
		if ([protokollWindow_ isVisible]) {
			[protokollWindow_ orderOut:self];
			protokollWindowVersteckt_ = true;
		}
	} else {
		if (kontenWindowVersteckt_ && ![kontenWindow isVisible]) {
			kontenWindowVersteckt_ = NO;
			[kontenWindow makeKeyAndOrderFront:self];
		}
		if (protokollWindowVersteckt_ && ![protokollWindow_ isVisible]) {
			protokollWindowVersteckt_ = NO;
			[protokollWindow_ orderFront:self];
		}
	}
}


- (BOOL)offenHalten
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	int sperrenNachSek = (int)([defaults doubleForKey:@"sperrenNach"] * 60);
	countdown_ = sperrenNachSek;
	return !verschlossen_;
}


- (void)updatePolicy
{
	[self offenHalten];
	
	// Recht setzen in Policy-Datenbank
	OSStatus oss = AuthorizationRightGet("com.limoia.saldomat.unlock", NULL);
	if (oss != noErr) {
		// Recht ohne "timeout"-Wert. Damit greift der Timeout-Mechanismus nicht
		// von OSX
		NSDictionary * neuePolicy = [NSDictionary dictionaryWithObjectsAndKeys:
					     @"authenticate-session-owner", @"rule",
					     nil];
		oss = AuthorizationRightSet([auth_ authorizationRef],
					    "com.limoia.saldomat.unlock",
					    neuePolicy,
					    NULL, (CFBundleRef)[NSBundle mainBundle], NULL);
		NSLog(@"AuthorizationRightSet => %d", oss);
	}	
}


- (id)init
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	self = [super init];
	auth_ = [[SFAuthorization authorization] retain];
	kontenWindowVersteckt_ = NO;
	protokollWindowVersteckt_ = NO;
	timer_ = nil;
	countdown_ = 180;
	
	// Pseudo-Offen-Mechanismus initialisieren
	pseudoSchloss_ = [defaults boolForKey:@"pseudoOffen"] 
		&& ![defaults boolForKey:@"sperrenBeimStart"];
	if ([defaults boolForKey:@"sperrenBeimStart"]) {
		[auth_ invalidateCredentials];
		[auth_ init];
	}
	
	// Sounds vom SecurityFramework laden
	lockSound_ = nil;
	unlockSound_ = nil;
	NSBundle * securityFramework = [NSBundle bundleForClass:[SFAuthorizationView class]];
	NSString * path = [securityFramework pathForResource:@"lockClosing" ofType:@"aif"];
	if (path)
		lockSound_ = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
	path = [securityFramework pathForResource:@"lockOpening" ofType:@"aif"];
	if (path)
		unlockSound_ = [[NSSound alloc] initWithContentsOfFile:path byReference:YES];
	
	// Observer installieren
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(windowDidBecomeKey:)
						     name:NSWindowDidBecomeKeyNotification
						   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(willTerminate:) 
						     name:NSApplicationWillTerminateNotification
						   object:nil];
	return self;
}


- (void)willTerminate:(NSNotification *)aNotification
{
//	[self lock:self];
}


- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[self offenHalten];
}


- (void)timer:(NSTimer *)timer
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	BOOL automatischSperren = [defaults boolForKey:@"automatischSperren"];
	
	// Countdown, am Ende verschliessen
	if (!verschlossen_ && automatischSperren) {
		// Saldomat-Fenster aktiv?
		if ([NSApp isActive] && [NSApp keyWindow] != nil)
			[self offenHalten];
		else {
			countdown_--;
			NSLog(@"countdown: %d", countdown_);
			if (countdown_ <= 0)
				[self lock:self];
		}
	}
}


- (void)awakeFromNib
{
	[self updatePolicy];
	[self updateVerschlossen];
	
	// auf Konfiguration reagieren
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults addObserver:self forKeyPath:@"sperrenNach"
		options:NSKeyValueObservingOptionNew context:@"sperrenNach"];
	[defaults addObserver:self forKeyPath:@"automatischSperren"
		options:NSKeyValueObservingOptionNew context:@"automatischSperren"];
	
	// Timer starten
	timer_ = [NSTimer scheduledTimerWithTimeInterval:1.0
						  target:self selector:@selector(timer:)
						userInfo:nil repeats:YES];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
			change:(NSDictionary *)change context:(void *)context
{
	[self updatePolicy];
}


- (IBAction)lock:(id)sender
{
	NSLog(@"lock");
	
	// alten Zustand pruefen
	[self updateVerschlossen];
	if ([self verschlossen])
		return;
	
	// Pseudo-Modus beenden, falls aktiv
	if (pseudoSchloss_) {
		[self willChangeValueForKey:@"pseudoSchloss"];
		pseudoSchloss_ = NO;
		[self didChangeValueForKey:@"pseudoSchloss"];
	}
	
	// sperren
	[auth_ invalidateCredentials];
	[auth_ init];
	
	// Sound spielen, wenn erfolgreich
	[self updateVerschlossen];
	if ([self verschlossen]) {
		// Ton abspielen?
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		BOOL play = [[defaults objectForKey:@"playLockSound"] boolValue];
		
		if (play)
			[lockSound_ play];
	}
		
}


- (IBAction)unlock:(id)sender
{
	NSLog(@"unlock");

	// alten Zustand pruefen
	[self updateVerschlossen];
	if (![self verschlossen])
		return;

	// Recht bekommen
	NSError * error = nil;
	BOOL ok = [auth_ obtainWithRight:"com.limoia.saldomat.unlock" 
				   flags:kAuthorizationFlagInteractionAllowed | kAuthorizationFlagExtendRights 
				   error:&error];
	if (!ok && error) {
		NSLog(@"unlock error: %@", [error description]);
	}

	// Sound spielen, wenn erfolgreich
	[self updateVerschlossen];
	if (![self verschlossen]) {
		// Ton abspielen?
		NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
		BOOL play = [[defaults objectForKey:@"playLockSound"] boolValue];
		
		if (play)
			[unlockSound_ play];
		
		[self offenHalten]; // Countdown neustarten
	}
}


- (void)authorizationViewDidAuthorize:(SFAuthorizationView *)view
{
	[self updateVerschlossen];
}


- (void)authorizationViewDidDeauthorize:(SFAuthorizationView *)view
{
	[self updateVerschlossen];
}

@synthesize authorization = auth_;
@synthesize pseudoSchloss = pseudoSchloss_;
@synthesize verschlossen = verschlossen_;

@end


@implementation SyncedAuthorizationView

- (void)setAuthorizationController:(AuthorizationController *)ctrl
{
	[self willChangeValueForKey:@"authorizationController"];
	[self setAuthorization:[ctrl authorization]];
	[self didChangeValueForKey:@"authorizationController"];
}

@dynamic authorization;

@end
