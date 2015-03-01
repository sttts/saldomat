//
//  UniversalQifExporter.m
//  hbci
//
//  Created by Michael on 15.09.09.
//  Copyright 2009 Limoia. All rights reserved.
//

#import "UniversalQifExporter.h"

#import "Aktion.h"
#import "AppController.h"
#import "debug.h"
#import "GrowlController.h"
#import "QuickenAktionAusfuehrer.h"


@implementation UniversalQifExporter

- (id) init
{
	self = [super init];
	konto_ = nil;
	
	[[[NSWorkspace sharedWorkspace] notificationCenter] 
	 addObserver:self
	 selector:@selector(willLaunchApp:)
	 name:NSWorkspaceWillLaunchApplicationNotification
	 object:nil];
	[[[NSWorkspace sharedWorkspace] notificationCenter] 
	 addObserver:self
	 selector:@selector(didLaunchApp:)
	 name:NSWorkspaceDidLaunchApplicationNotification
	 object:nil];
	
	return self;
}



- (void) dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	[konto_ release];
	[super dealloc];
}



- (NSString *)theAppInOS:(Konto *)konto {
	
	switch ([[konto exportMethode] intValue]) {
		case KontoExportMoneywell:return @"com.nothirst.MoneyWell";
		case KontoExportiFinance3:return @"de.synium.iFinance3";
		case KontoExportiFinance3AppStore:return @"com.synium.ifinance";
		case KontoExportSquirrel:return @"com.pacificturtle.squirrel";
		case KontoExportChaChing2:return @"com.midnightapps.ChaChingApp2";
		case KontoExportiBank4:return @"com.iggsoftware.iBank4";

		// FIXME: Qif faehige Programme (1)
		default:return @"Export failed. (1)";
	}
}



- (NSString *)theAppName:(Konto *)konto {
	
	switch ([[konto exportMethode] intValue]) {
		case KontoExportMoneywell:return @"MoneyWell";
		case KontoExportiFinance3:return @"iFinance";
		case KontoExportiFinance3AppStore:return @"iFinance";
		case KontoExportSquirrel:return @"Squirrel";
		case KontoExportChaChing2:return @"Cha-Ching";
		case KontoExportiBank4:return @"iBank";
		
		// FIXME: Qif faehige Programme (2)
		default:return @"Export failed. (2)";
	}
}



- (NSNumber *)exportKategorie:(Konto *)konto {
	
	switch ([[konto exportMethode] intValue]) {
		case KontoExportMoneywell:return [konto moneywellExportKategorien];
		case KontoExportiFinance3:return [konto iFinance3ExportKategorien];
		case KontoExportiFinance3AppStore:return [konto iFinance3ExportKategorien];
		case KontoExportSquirrel:return [konto squirrelExportKategorien];
		case KontoExportChaChing2:return [konto chaChing2ExportKategorien];
		case KontoExportiBank4:return [konto iBank4ExportKategorien];
			
		// FIXME: Qif faehige Programme (3)
		default:break;
	}
	
	return [NSNumber numberWithBool:NO];
}



- (BOOL)appRunning:(Konto *)konto
{
	NSArray * apps = [[NSWorkspace sharedWorkspace] launchedApplications];
	for (NSDictionary * app in apps) {
		if ([[app objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:[self theAppInOS:konto]])
			return YES;
	}
	return NO;
}



- (void)exportMitGestartetemApp:(Konto *)konto
{
	// Zeitintervall ermitteln fuer die Buchungen zum Export
	NSDate * von = [konto moneywellExportVon];
	NSDate * bis = [konto moneywellExportBis];
	
	NSDate * exportAb;
	if (bis)
		exportAb = [[[NSDate alloc] initWithTimeInterval:- 7*24*3600 sinceDate:bis] autorelease];
	else
		exportAb = [konto buchungenVon];
	if (von == nil || [von isGreaterThan:[konto buchungenVon]])
		exportAb = [konto buchungenVon];
	
	// Buchungen finden
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	NSFetchRequest * fetch = [[[NSFetchRequest alloc] init] autorelease];
	fetch.entity = [NSEntityDescription entityForName:@"Buchung" inManagedObjectContext:ctx];
	fetch.predicate = [NSPredicate predicateWithFormat:@"(konto = %@) and (datum >= %@)", konto, exportAb];
	NSError * error = nil;
	NSArray * buchungen = [ctx executeFetchRequest:fetch error:&error];
	if (!buchungen) {
		NSLog(@"%@ export fetch failed: %@", [self theAppName:konto], [error description]);
		return;
	}
	
	// per Growl melden
	[[theAppCtrl growlController] meldeUniversalQifExport:[buchungen count] theApp:[self theAppName:konto]];
	if ([buchungen count] == 0)
		return;
	
	// Datei erzeugen
	NSString * fname = [self tempFileErstellen];
	if (fname == nil)
		return;
	
	// QIF-Aktion anlegen zum Exportieren
	Aktion * aktion = [[[Aktion alloc] initWithType:@"quicken"] autorelease];
	[aktion setOption:@"quicken_pfad" toValue:[fname stringByDeletingLastPathComponent]];
	[aktion setOption:@"quicken_datei" toValue:[fname lastPathComponent]];
	[aktion setOption:@"quicken_append" toValue:[NSNumber numberWithBool:NO]];
	if ([konto squirrelExportAktiv]) {
		[aktion setOption:@"quicken_datumsformat" toValue:[NSNumber numberWithInt:3]]; // 30/04/08
	} else {
		[aktion setOption:@"quicken_datumsformat" toValue:[NSNumber numberWithInt:5]]; // 04/30/08
	}
	[aktion setOption:@"quicken_komma" toValue:[NSNumber numberWithInt:1]];
	[aktion setOption:@"quicken_kategorien" toValue:[self exportKategorie:konto]];
	
	// Ausfuehrer starten
	AktionAusfuehrer * ausfuehrer = [[QuickenAktionAusfuehrer new] autorelease];
	[ausfuehrer ausfuehren:aktion fuerBuchungen:buchungen];
	
	// Datei nun da und nicht 0 gross?
	NSFileManager * fm = [NSFileManager defaultManager];
	NSDictionary * fileAttr = [fm fileAttributesAtPath:fname traverseLink:YES];
	if (fileAttr == nil || [[fileAttr objectForKey:NSFileSize] intValue] == 0) {
		NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"%@ export", nil),[self theAppName:konto]],
				[NSString stringWithFormat:NSLocalizedString(@"%@ export failed. Cannot create QIF export file.", nil),[self theAppName:konto]],
				NSLocalizedString(@"Ok", nil),
				nil,
				nil);
		return;
	}
	
	// QIF mit Moneywell oeffnen
	BOOL ok = [[NSWorkspace sharedWorkspace] openFile:fname
					  withApplication:[self theAppName:konto]];
	if (!ok) {
		NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"%@ export", nil),[self theAppName:konto]],
				[NSString stringWithFormat:NSLocalizedString(@"%@ export failed. Is %@ installed on your Mac?", nil),[self theAppName:konto],[self theAppName:konto]],
				NSLocalizedString(@"Ok", nil),
				nil,
				nil);
		return;
	}
	
	// neuen Zeitraum setzen
	[konto setMoneywellExportVon:[konto buchungenVon]];
	[konto setMoneywellExportBis:[konto buchungenBis]];
}



- (void)didLaunchApp:(NSNotification *)notification
{
	if (konto_)
	    if ([[(NSDictionary *)[notification userInfo] objectForKey:@"NSApplicationName"] 
	     isEqualToString:[self theAppName:konto_]]) {
		    NSLog(@"DidLaunchApp");
		    Konto * konto = [konto_ autorelease];
		    konto_ = nil;
		    [self exportMitGestartetemApp:konto];
	    }
}



- (void)willLaunchApp:(NSNotification *)notification
{
	NSLog(@"WillLaunchApp");
}



- (void)export:(Konto *)konto
{	
	NSLog(@"vorher %@", [self theAppName:konto]);
	if ([self appRunning:konto]) {
		// Workaround: Sonst klappt der zweite Export nicht, und Moneywell ignoriert ihn
		NSTask * task = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/open"
							 arguments:[NSArray arrayWithObjects:@"-a", [self theAppName:konto], nil]];
		[task waitUntilExit];
		
		// export
		[self exportMitGestartetemApp:konto];
	} else {
		// App starten
		NSLog(@"Started %@", [self theAppName:konto]);
		[konto_ autorelease];
		konto_ = [konto retain];
		BOOL ok = [[NSWorkspace sharedWorkspace] launchApplication:[self theAppName:konto]];
		if (!ok) {
			NSRunAlertPanel([NSString stringWithFormat:NSLocalizedString(@"%@ export", nil),[self theAppName:konto]],
					[NSString stringWithFormat:NSLocalizedString(@"%@ export failed. Is %@ installed on your Mac?", nil),[self theAppName:konto],[self theAppName:konto]],
					NSLocalizedString(@"Ok", nil),
					nil,
					nil);
			return;
		} else {
			NSLog(@"Finished.");
		}
	}
}


@end

