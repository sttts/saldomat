//
//  UpdateController.m
//  hbci
//
//  Created by Stefan Schimanski on 11.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "UpdateController.h"

#import "../Sparkle.framework/Headers/Sparkle.h"
#import "../Sparkle.framework/Headers/SUConstants.h"
#import "../Sparkle.framework/Headers/SUStandardVersionComparator.h"

#import "AppController.h"
#import "debug.h"
#import "DockIconController.h"
#import "Konto.h"
#import "svnrevision.h"
#import "Version.h"


@implementation UpdateController


- (void)awakeFromNib
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	wartendesUpdate_ = nil;
	
	// Update-Parameter
	[defaults addObserver:self forKeyPath:SUEnableAutomaticChecksKey
		      options:NSKeyValueObservingOptionNew context:@"SUEnableAutomaticChecksKey"];
	[defaults addObserver:self forKeyPath:SUScheduledCheckIntervalKey
		      options:NSKeyValueObservingOptionNew context:@"SUScheduledCheckInterval"];
	
	// Kontoauszugswechsel mitbekommen wegen verzoegertem Update
	[theAppCtrl addObserver:self forKeyPath:@"laufenderKontoauszug" 
			options:NSKeyValueObservingOptionNew context:@"laufenderKontoauszug"];
	updater_ = [SUUpdater sharedUpdater];
	[updater_ setDelegate:self];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
			change:(NSDictionary *)change context:(void *)context
{
	if ([(NSString *)context isEqualToString:@"laufenderKontoauszug"]) {
		// noch Kontoauszuege in Wartestellung oder laufend?
		if (wartendesUpdate_ 
		    && [theAppCtrl laufenderKontoauszug] == nil
		    && ([theAppCtrl wartendeKonten] == nil || [[theAppCtrl wartendeKonten] count] == 0)) {
			// nein. Dann koennen wir das Update starten
			NSLog(@"Starte wartendes Update");
			[wartendesUpdate_ invoke];
			[wartendesUpdate_ release];
			wartendesUpdate_ = nil;
		}
		
		return;
	}
}


- (IBAction)updateStarten:(id)sender
{
	[updater_ checkForUpdates:self];
}


- (NSArray *)feedParametersForUpdater:(SUUpdater *)updater sendingSystemProfile:(BOOL)sendingProfile
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];	
	NSMutableArray * params = [NSMutableArray arrayWithObjects:
				   [NSDictionary dictionaryWithObjectsAndKeys:
				    @"version", @"key",
				    [NSString localizedStringWithFormat:@"Version"], @"displayKey",
				    [Version version], @"value",
				    [Version version], @"displayValue", nil],
				   [NSDictionary dictionaryWithObjectsAndKeys:
				    @"revision", @"key",
				    [NSString localizedStringWithFormat:@"Revision"], @"displayKey",
				    [Version revision], @"value",
				    [Version revision], @"displayValue", nil],
				   [NSDictionary dictionaryWithObjectsAndKeys:
				    @"beta", @"key",
				    [NSString localizedStringWithFormat:@"Beta"], @"displayKey",
				    [NSNumber numberWithInt:!VERSIONRELEASE], @"value",
				    [NSNumber numberWithInt:!VERSIONRELEASE], @"displayValue", nil],
				   [NSDictionary dictionaryWithObjectsAndKeys:
				    @"betaLaden", @"key",
				    [NSString localizedStringWithFormat:@"Betas laden"], @"displayKey",
				    [NSNumber numberWithBool:[defaults boolForKey:@"betaLaden"]], @"value",
				    [NSNumber numberWithBool:[defaults boolForKey:@"betaLaden"]], @"displayValue", nil],
					nil];
	
	// Stats schicken?
	BOOL sendStats = [defaults boolForKey:@"sendStatisticInfo"];
	if (sendStats) {
		// Fehlerzaehler nach Bankleitzahl sortieren und aufaddieren
		NSMutableDictionary * fehler = [NSMutableDictionary dictionary];
		NSMutableDictionary * erfolgreich = [NSMutableDictionary dictionary];
		for (Konto * k in [konten_ arrangedObjects]) {
			// Konto gueltig?
			if ([k bankleitzahl] == nil || [[k bankleitzahl] length] == 0)
				continue;
			
			// Zaehler aufsummieren
			NSNumber * c = [fehler objectForKey:[k bankleitzahl]];
			if (c) {
				[fehler setObject:[NSNumber numberWithInt:[c intValue] + [[k statFehler] intValue]]
					   forKey:[k bankleitzahl]];
				[erfolgreich setObject:[NSNumber numberWithInt:[[erfolgreich objectForKey:[k bankleitzahl]] intValue] + [[k statErfolgreich] intValue]]
					   forKey:[k bankleitzahl]];
			} else {
				[fehler setObject:[k statFehler] forKey:[k bankleitzahl]];
				[erfolgreich setObject:[k statErfolgreich] forKey:[k bankleitzahl]];
			}
		}
		
		// Parameter fuer die appcast URL erzeugen
		for (NSString * blz in fehler) {
			[params addObject:[NSDictionary dictionaryWithObjectsAndKeys:
					   blz, @"key",
					   [NSString stringWithFormat:@"%@-%@", 
					    [fehler objectForKey:blz], 
					    [erfolgreich objectForKey:blz]], @"value",
					   nil]];
		}
	}

	return params;
}


- (SUAppcastItem *)bestValidUpdateInAppcast:(SUAppcast *)ac forUpdater:(SUUpdater *)bundle
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	BOOL betaLaden = [defaults boolForKey:@"betaLaden"];
	SUStandardVersionComparator * comp = [[SUStandardVersionComparator new] autorelease];
	
	SUAppcastItem * neuestesRelease = nil;
	SUAppcastItem * neuesteBeta = nil;
	
	// durch Updates durchgehen. Neuestes zuerst
	NSEnumerator *updateEnumerator = [[ac items] objectEnumerator];
	NSLog(@"my version: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]);
	while (neuestesRelease == nil) {
		// naechstes Update
		SUAppcastItem * item = [updateEnumerator nextObject];
		if (item == nil)
			break;
		
		// zu alt? => abbrechen
		NSLog(@"version found: %@", [item versionString]);
		if ([comp compareVersion:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]
			       toVersion:[item versionString]] != NSOrderedAscending)
			break;
		
		// Beta-Logik: Beta ist ok, wenn
		// * Betas geladen werden sollen (vom Benutzer eingestellt)
		// * wir noch keine neuere Beta gefunden haben
		// * noch kein neueres Release gefunden wurde (dann bricht die Schleife eh ab)
		NSDictionary * props = [item propertiesDictionary];
		NSString * category = [props objectForKey:@"category"];
		BOOL itemIstBeta = [category isEqualToString:@"Beta"];
		if  (itemIstBeta) {
			if (neuesteBeta == nil && (!VERSIONRELEASE || betaLaden))
				neuesteBeta = item;
		} else {
			neuestesRelease = item;
			
			// wenn Benutzer Betas nicht will, nur aufs naechste Release updaten
			if (!betaLaden) {
				neuesteBeta = nil;
			}
		}
	}
	
	// gueltige Beta vorziehen
	SUAppcastItem * updateItem = neuesteBeta ? neuesteBeta : neuestesRelease; 
	[updateItem retain];
	return updateItem;
}


- (void)appcastDidFinishLoading:(SUAppcast *)appcast forHostBundle:(NSBundle *)bundle
{
	NSLog(@"Setze Fehlerstats zurueck");
	for (Konto * k in [konten_ arrangedObjects]) {
		[k setStatFehler:[NSNumber numberWithInt:0]];
		[k setStatErfolgreich:[NSNumber numberWithInt:0]];
	}
}


- (BOOL)shouldPromptForPermissionToCheckForUpdatesToHostBundle:(NSBundle *)bundle
{
	return NO;
}


- (BOOL)shouldPostponeRelaunchForUpdate:(SUAppcastItem *)update toHostBundle:(NSBundle *)hostBundle untilInvoking:(NSInvocation *)invocation
{
	// Laueft ein Kontoauszug?
	if ([theAppCtrl laufenderKontoauszug]) {
		NSLog(@"Kontoauszug am Laufen. Update wird verzoegert.");
		[wartendesUpdate_ autorelease];
		wartendesUpdate_ = [invocation retain];
		return YES;
	}
	
	NSLog(@"Kein Update am Laufen. Update sofort");
	return NO;
}


- (void)updaterWillRelaunchApplication:(SUUpdater *)updater;
{
	NSLog(@"Toete alle Unterprozesse");
	[DockIconController hideDockIcon:self];
	[NSTask launchedTaskWithLaunchPath:@"/usr/bin/killall" 
				 arguments:[NSArray arrayWithObject:@"Saldomat hbcitool"]];
	[NSTask launchedTaskWithLaunchPath:@"/usr/bin/killall" 
				 arguments:[NSArray arrayWithObject:@"Saldomat Dock"]];
}

@end
