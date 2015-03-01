//
//  QuickenAktionAusfuehrer.m
//  hbci
//
//  Created by Stefan Schimanski on 05.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "QuickenAktionAusfuehrer.h"

#import "Aktion.h"
#import "Buchung.h"
#import "debug.h"
#import "Filter.h"
#import "Konto.h"
#import "NSString+extras.h"


@implementation QuickenAktionAusfuehrer

- (NSData *)encodeString:(NSString *)s
{
/*	s = [s stringMitErsetztenUmlauten];
	return [s dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];*/
	return [s dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
}


- (void)ausfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen
{
	NSString * pfad = [aktion option:@"quicken_pfad"];
	NSString * datei = [aktion option:@"quicken_datei"];
	NSString * path = [pfad stringByAppendingPathComponent:datei];
	BOOL artExportieren = [[aktion option:@"quicken_kategorien"] boolValue];
	@try {
		NSFileHandle * f = nil;
		
		// Datei vorhanden?
		if ([[aktion option:@"quicken_append"] boolValue])
			f = [NSFileHandle fileHandleForWritingAtPath:path];
		
		// Wenn nicht, erstellen wir sie
		if (f == nil) {
			// Datei erstellen
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:path
									  contents:nil
									attributes:nil];
			if (!ok) {
				NSRunAlertPanel(NSLocalizedString(@"Quicken Export Error", nil),
						NSLocalizedString(@"Cannot create file '%@' to write QIF transactions to.", nil),
						NSLocalizedString(@"Ok", nil), nil, nil, path);
				return;
			}
			
			// nochmal oeffnen
			f = [NSFileHandle fileHandleForWritingAtPath:path];
			if (!f) {
				NSRunAlertPanel(NSLocalizedString(@"Quicken Export Error", nil),
						NSLocalizedString(@"Cannot open file '%@' to write QIF transactions to.", nil),
						NSLocalizedString(@"Ok", nil), nil, nil, path);
			}
			
			// Header schreiben
			[f writeData:[@"!Type:Bank\n" dataUsingEncoding:NSASCIIStringEncoding]];
		}
			     
		// Zum Ende der Datei gehen
		[f seekToEndOfFile];
		
		// Datumsformat
		NSString * datumsformat = @"D%m/%d/%Y\n";
		switch ([[aktion option:@"quicken_datumsformat"] intValue]) {
			case 0: datumsformat = @"D%d.%m.%Y\n"; break;
			case 1: datumsformat = @"D%d.%m.%y\n"; break;
			case 2: datumsformat = @"D%d/%m/%Y\n"; break;
			case 3: datumsformat = @"D%d/%m/%y\n"; break;
			case 4: datumsformat = @"D%m/%d/%Y\n"; break;
			case 5: datumsformat = @"D%m/%d/%y\n"; break;
			case 6: datumsformat = @"D%Y/%m/%d\n"; break;
			case 7: datumsformat = @"D%y/%m/%d\n"; break;
		}
		
		// Zahlenformat
		NSNumberFormatter * nf = [[NSNumberFormatter new] autorelease];
		[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[nf setThousandSeparator:@""];
		[nf setFormat:@"0.00;-0.00"];
		if ([[aktion option:@"quicken_komma"] intValue] == 1)
			[nf setDecimalSeparator:@","];
		else
			[nf setDecimalSeparator:@"."];
		
		// Buchungen ausgeben
		for (Buchung * b in buchungen) {
			NSString * date = [[b datum] descriptionWithCalendarFormat:datumsformat timeZone:nil locale:nil];
			NSString * wert = [NSString stringWithFormat:@"T%@\n", [nf stringFromNumber:[b wert]]];
			NSString * zweck = [NSString stringWithFormat:@"M%@\n", [b effektiverZweck]];
			NSString * absender = nil;
			NSString * effAndererName = [b effektiverAndererName];
			if (effAndererName && [effAndererName length] > 0)
				absender = [NSString stringWithFormat:@"P%@\n", effAndererName];
			NSString * art = nil;
			if (artExportieren && [b art] && [[b art] length] > 0)
				art = [NSString stringWithFormat:@"L[%@]\n", [b art]];
			
			[f writeData:[self encodeString:date]];
			[f writeData:[self encodeString:wert]];
			[f writeData:[self encodeString:zweck]];
			[f writeData:[self encodeString:absender]];
			if (art) [f writeData:[self encodeString:art]];
			[f writeData:[@"^\n" dataUsingEncoding:NSASCIIStringEncoding]];
		}
		
		// Datei schliessen
		[f closeFile];
	}
	@catch (NSException * e) {
		NSLog(@"Error during quicken export: %@", [e description]);
	}
}

@end
