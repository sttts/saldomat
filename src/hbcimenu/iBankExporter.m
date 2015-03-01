//
//  iBankExporter.m
//  hbci
//
//  Created by Stefan Schimanski on 13.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "iBankExporter.h"

#import "Aktion.h"
#import "AppController.h"
#import "Buchung.h"
#import "debug.h"
#import "GrowlController.h"
#import "QuickenAktionAusfuehrer.h"

@implementation iBankExporter

- (void)export:(Konto *)konto
{
	// Zeitintervall ermitteln fuer die Buchungen zum Export
	NSDate * von = [konto iBankExportVon];
	NSDate * bis = [konto iBankExportBis];
	
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
		NSLog(@"iBank export fetch failed: %@", [error description]);
		return;
	}
	
	// per Growl melden
	[[theAppCtrl growlController] meldeiBankExport:[buchungen count]];
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
	[aktion setOption:@"quicken_datumsformat" toValue:[NSNumber numberWithInt:5]]; // 04/30/08
	
	// Ausfuehrer starten
	AktionAusfuehrer * ausfuehrer = [[QuickenAktionAusfuehrer new] autorelease];
	[ausfuehrer ausfuehren:aktion fuerBuchungen:buchungen];
	
	// Datei nun da und nicht 0 gross?
	NSFileManager * fm = [NSFileManager defaultManager];
	NSDictionary * fileAttr = [fm fileAttributesAtPath:fname traverseLink:YES];
	if (fileAttr == nil || [[fileAttr objectForKey:NSFileSize] intValue] == 0) {
		NSRunAlertPanel(NSLocalizedString(@"iBank export", nil),
				NSLocalizedString(@"iBank export failed. Cannot create QIF export file.", nil),
				NSLocalizedString(@"Ok", nil),
				nil,
				nil);
		return;
	}
	
	// iBank per AppleScript aufrufen
	NSString * scriptSource;
	if ([konto iBankKonto] == nil || [[konto iBankKonto] length] == 0)
		scriptSource= [NSString stringWithFormat:
		 @"tell application \"iBank\"\n"
		 "tell first account of first document\n"
		 "set import file to \"%@\"\n"
		 "import\n"
		 "activate\n"
		 "end tell\n"
		 "end tell\n", fname];
	else
		scriptSource = [NSString stringWithFormat:
		 @"tell application \"iBank\"\n"
		 "tell account \"%@\" of first document\n"
		 "set import file to \"%@\"\n"
		 "import\n"
		 "activate\n"
		 "end tell\n"
		 "end tell\n", [konto iBankKonto], fname];
	NSAppleScript * script = [[[NSAppleScript alloc] initWithSource:scriptSource] autorelease];
	NSDictionary * errorDict = nil;
	NSAppleEventDescriptor * ae = [script executeAndReturnError:&errorDict];
	if (ae == nil) {
		if ([konto iBankKonto])
			NSRunAlertPanel(NSLocalizedString(@"iBank export", nil),
					NSLocalizedString(@"iBank export failed due a problem running the AppleScript to import. "
							  "Maybe iBank is not (correctly) installed. Or the given account '%@' does "
							  "not exist in iBank.", nil),
					NSLocalizedString(@"Ok", nil),
					nil,
					nil,
					[konto iBankKonto]);
		else
			NSRunAlertPanel(NSLocalizedString(@"iBank export", nil),
					NSLocalizedString(@"iBank export failed due a problem running the AppleScript to import. "
							  "Maybe iBank is not (correctly) installed. Have you created an account in iBank? "
							  "You have to to make the export work.", nil),
					NSLocalizedString(@"Ok", nil),
					nil,
					nil);
		return;
	}
	
	[konto setIBankExportVon:[konto buchungenVon]];
	[konto setIBankExportBis:[konto buchungenBis]];
}

@end
