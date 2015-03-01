//
//  GrandtotalAktionAusfuehrer.m
//  hbci
//
//  Created by Michael on 17.09.09.
//  Copyright 2009 Limoia. All rights reserved.
//

#import "GrandtotalAktionAusfuehrer.h"

#import "Aktion.h"
#import "Buchung.h"
#import "debug.h"
#import "Filter.h"
#import "Konto.h"
#import "NSString+extras.h"
#import "AppController.h"


@implementation GrandtotalAktionAusfuehrer


- (NSData *)encodeString:(NSString *)s
{
	s = [s stringMitErsetztenUmlauten];
	return [s dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
}


- (NSString *)zeileMitDatum:(NSString *)datum wert:(NSString *)wert waehrung:(NSString *)waehrung
			art:(NSString *)art zweck:(NSString *)zweck absender:(NSString *)absender
	      absenderKonto:(NSString *)anderesKonto absenderBank:(NSString *)andereBank
		  buchungid:(NSString *)buchungid fuerAktion:(Aktion *)aktion
{
	// " ersetzen
	zweck = [zweck stringByReplacingOccurrencesOfString:@"\"" withString:@""];
	zweck = [zweck stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	waehrung = [waehrung stringByReplacingOccurrencesOfString:@"\"" withString:@""];
	absender = [absender stringByReplacingOccurrencesOfString:@"\"" withString:@""];
	anderesKonto = [anderesKonto stringByReplacingOccurrencesOfString:@"\"" withString:@""];
	andereBank = [andereBank stringByReplacingOccurrencesOfString:@"\"" withString:@""];
	art = [art stringByReplacingOccurrencesOfString:@"\"" withString:@""];
	art = [art stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	
	// Variablen ersetzen
	NSString * s = [NSString stringWithString:@"\"$d\",\"$v\",\"$c\",\"$p\",\"$r\",\"$i\""];
	s = [s stringByReplacingOccurrencesOfString:@"$d" withString:datum];
	s = [s stringByReplacingOccurrencesOfString:@"$r" withString:absender];
	s = [s stringByReplacingOccurrencesOfString:@"$k" withString:anderesKonto];
	s = [s stringByReplacingOccurrencesOfString:@"$b" withString:andereBank];
	s = [s stringByReplacingOccurrencesOfString:@"$v" withString:wert];
	s = [s stringByReplacingOccurrencesOfString:@"$c" withString:waehrung];
	s = [s stringByReplacingOccurrencesOfString:@"$a" withString:art];
	s = [s stringByReplacingOccurrencesOfString:@"$p" withString:zweck];
	s = [s stringByReplacingOccurrencesOfString:@"$i" withString:buchungid];
	return [s stringByAppendingString:@"\n"];
}


- (BOOL)grandtotalRunning
{
	NSArray * apps = [[NSWorkspace sharedWorkspace] launchedApplications];
	for (NSDictionary * app in apps) {
		if ([[app objectForKey:@"NSApplicationBundleIdentifier"] isEqualToString:@"com.mediaatelier.GrandTotal"])
			return YES;
	}
	return NO;
}


- (void)ausfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen
{
	NSString * pfad = [NSString stringWithFormat:@"%@/Library/Application Support/GrandTotal/Saldomat/", NSHomeDirectory()];
	NSString * datei = [NSString stringWithString:@"saldomat.csv"];
	NSString * path = [pfad stringByAppendingPathComponent:datei];
	@try {
		NSFileHandle * f = nil;
		
		// Datei vorhanden?
		if ([[aktion option:@"grandtotal_append"] boolValue])
			f = [NSFileHandle fileHandleForWritingAtPath:path];
					
		// Wenn nicht, erstellen wir sie
		if (f == nil) {
			// Verzeichnis anlegen
			BOOL dok = [[NSFileManager defaultManager] createDirectoryAtPath:pfad
									      attributes:nil];
			if (!dok) {
				NSLog(@"Verzeichnis '%@' vorhanden.", pfad);
			}
			
			// Datei erstellen
			BOOL fok = [[NSFileManager defaultManager] createFileAtPath:path
									  contents:nil
									attributes:nil];
			if (!fok) {
				NSRunAlertPanel(NSLocalizedString(@"GrandTotal Export Error", nil),
						NSLocalizedString(@"Cannot create file '%@' to write CSV transactions to.", nil),
						NSLocalizedString(@"Ok", nil), nil, nil, path);
				return;
			}
			
			// nochmal oeffnen
			f = [NSFileHandle fileHandleForWritingAtPath:path];
			if (!f) {
				NSRunAlertPanel(NSLocalizedString(@"GrandTotal Export Error", nil),
						NSLocalizedString(@"Cannot open file '%@' to write CSV transactions to.", nil),
						NSLocalizedString(@"Ok", nil), nil, nil, path);
			}
			
			// Header schreiben
			NSString * zeile = [self zeileMitDatum:NSLocalizedString(@"date", nil)
							  wert:NSLocalizedString(@"value", nil)
						      waehrung:NSLocalizedString(@"currency", nil)
							   art:NSLocalizedString(@"category", nil)
							 zweck:NSLocalizedString(@"purpose", nil)
						      absender:NSLocalizedString(@"remote", nil)
						 absenderKonto:NSLocalizedString(@"remoteAccount", nil)
						  absenderBank:NSLocalizedString(@"remoteBank", nil)
						     buchungid:NSLocalizedString(@"guid", nil)
						    fuerAktion:aktion];
			[f writeData:[self encodeString:zeile]];
		}
		
		// Zum Ende der Datei gehen
		[f seekToEndOfFile];
		
		// Datumsformat
		NSString * datumsformat = @"%d.%m.%Y";
		/*switch ([[aktion option:@"grandtotal_datumsformat"] intValue]) {
			case 0: datumsformat = @"%d.%m.%Y"; break;
			case 1: datumsformat = @"%d.%m.%y"; break;
			case 2: datumsformat = @"%d/%m/%Y"; break;
			case 3: datumsformat = @"%d/%m/%y"; break;
			case 4: datumsformat = @"%m/%d/%Y"; break;
			case 5: datumsformat = @"%m/%d/%y"; break;
			case 6: datumsformat = @"%Y/%m/%d"; break;
			case 7: datumsformat = @"%y/%m/%d"; break;
		}*/
		
		// Zahlenformat
		NSNumberFormatter * nf = [[NSNumberFormatter new] autorelease];
		[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[nf setThousandSeparator:@""];
		[nf setFormat:@"0.00;-0.00"];
		/*if ([[aktion option:@"csv_komma"] intValue] == 1)
			[nf setDecimalSeparator:@","];
		else*/
			[nf setDecimalSeparator:@"."];
		
		// Buchungen ausgeben
		for (Buchung * b in buchungen) {
			NSString * date = [[b datum] descriptionWithCalendarFormat:datumsformat timeZone:nil locale:nil];
			NSString * wert = [nf stringFromNumber:[b wert]];
			NSString * zweck = [b effektiverZweck];
			NSString * waehrung = [b waehrung];
			
			NSString * absender = [b effektiverAndererName];
			if (absender == nil) absender = @"";
			
			NSString * anderesKonto = [b effektivesAnderesKonto];
			if (anderesKonto == nil) anderesKonto = @"";
			
			NSString * andereBank = [b effektiveAndereBank];
			if (andereBank == nil) andereBank = @"";
			
			NSString * art = [b art];
			if (art == nil) art = @"";
			
			NSString * bid = [b guid];
			
			NSString * zeile = [self zeileMitDatum:date wert:wert waehrung:waehrung 
							   art:art zweck:zweck 
						      absender:absender 
						 absenderKonto:anderesKonto
						  absenderBank:andereBank
						     buchungid:bid
						    fuerAktion:aktion];
			
			[f writeData:[self encodeString:zeile]];
		}
		
		// Datei schliessen
		[f closeFile];
		
	}
	@catch (NSException * e) {
		NSLog(@"Error during GrandTotal export: %@", [e description]);
	}
}



@end
