//
//  CsvAktionAusfuehrer.m
//  hbci
//
//  Created by Stefan Schimanski on 13.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "CsvAktionAusfuehrer.h"

#import "Aktion.h"
#import "Buchung.h"
#import "debug.h"
#import "Filter.h"
#import "Konto.h"
#import "NSString+extras.h"


@implementation CsvAktionAusfuehrer

- (NSData *)encodeString:(NSString *)s
{
	s = [s stringMitErsetztenUmlauten];
	return [s dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
}


- (NSString *)zeileMitDatum:(NSString *)datum wertstellung:(NSString *)wertstellung wert:(NSString *)wert
		   waehrung:(NSString *)waehrung art:(NSString *)art zweck:(NSString *)zweck
		   absender:(NSString *)absender absenderKonto:(NSString *)anderesKonto
	       absenderBank:(NSString *)andereBank buchungsKonto:(NSString *)buchungsKonto
		 fuerAktion:(Aktion *)aktion
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
	NSString * s = [aktion option:@"csv_format"];
	s = [s stringByReplacingOccurrencesOfString:@"$d" withString:datum];
	s = [s stringByReplacingOccurrencesOfString:@"$e" withString:wertstellung];
	s = [s stringByReplacingOccurrencesOfString:@"$r" withString:absender];
	s = [s stringByReplacingOccurrencesOfString:@"$k" withString:anderesKonto];
	s = [s stringByReplacingOccurrencesOfString:@"$b" withString:andereBank];
	s = [s stringByReplacingOccurrencesOfString:@"$v" withString:wert];
	s = [s stringByReplacingOccurrencesOfString:@"$c" withString:waehrung];
	s = [s stringByReplacingOccurrencesOfString:@"$a" withString:art];
	s = [s stringByReplacingOccurrencesOfString:@"$p" withString:zweck];
	s = [s stringByReplacingOccurrencesOfString:@"$s" withString:buchungsKonto];
	return [s stringByAppendingString:@"\n"];
}


- (void)ausfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen
{
	NSString * pfad = [aktion option:@"csv_pfad"];
	NSString * datei = [aktion option:@"csv_datei"];
	NSString * path = [pfad stringByAppendingPathComponent:datei];
	@try {
		NSFileHandle * f = nil;
		
		// Datei vorhanden?
		if ([[aktion option:@"csv_append"] boolValue])
			f = [NSFileHandle fileHandleForWritingAtPath:path];
		
		// Wenn nicht, erstellen wir sie
		if (f == nil) {
			// Datei erstellen
			BOOL ok = [[NSFileManager defaultManager] createFileAtPath:path
									  contents:nil
									attributes:nil];
			if (!ok) {
				NSRunAlertPanel(NSLocalizedString(@"CSV Export Error", nil),
						NSLocalizedString(@"Cannot create file '%@' to write QIF transactions to.", nil),
						NSLocalizedString(@"Ok", nil), nil, nil, path);
				return;
			}
			
			// nochmal oeffnen
			f = [NSFileHandle fileHandleForWritingAtPath:path];
			if (!f) {
				NSRunAlertPanel(NSLocalizedString(@"CSV Export Error", nil),
						NSLocalizedString(@"Cannot open file '%@' to write QIF transactions to.", nil),
						NSLocalizedString(@"Ok", nil), nil, nil, path);
			}
			
			// Header schreiben
			NSString * zeile = [self zeileMitDatum:NSLocalizedString(@"date", nil)
				wertstellung:NSLocalizedString(@"valuta", nil)
				wert:NSLocalizedString(@"value", nil)
				waehrung:NSLocalizedString(@"currency", nil)
				art:NSLocalizedString(@"category", nil)
				zweck:NSLocalizedString(@"purpose", nil)
				absender:NSLocalizedString(@"remote", nil)
				absenderKonto:NSLocalizedString(@"remoteAccount", nil)
				absenderBank:NSLocalizedString(@"remoteBank", nil)
				buchungsKonto:NSLocalizedString(@"saldomatBank", nil)
				fuerAktion:aktion];
			[f writeData:[self encodeString:zeile]];
		}
		
		// Zum Ende der Datei gehen
		[f seekToEndOfFile];
		
		// Datumsformat
		NSString * datumsformat = @"%m/%d/%Y";
		switch ([[aktion option:@"csv_datumsformat"] intValue]) {
			case 0: datumsformat = @"%d.%m.%Y"; break;
			case 1: datumsformat = @"%d.%m.%y"; break;
			case 2: datumsformat = @"%d/%m/%Y"; break;
			case 3: datumsformat = @"%d/%m/%y"; break;
			case 4: datumsformat = @"%m/%d/%Y"; break;
			case 5: datumsformat = @"%m/%d/%y"; break;
			case 6: datumsformat = @"%Y/%m/%d"; break;
			case 7: datumsformat = @"%y/%m/%d"; break;
		}
		
		// Zahlenformat
		NSNumberFormatter * nf = [[NSNumberFormatter new] autorelease];
		[nf setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[nf setThousandSeparator:@""];
		[nf setFormat:@"0.00;-0.00"];
		if ([[aktion option:@"csv_komma"] intValue] == 1)
			[nf setDecimalSeparator:@","];
		else
			[nf setDecimalSeparator:@"."];
		
		// Buchungen ausgeben
		for (Buchung * b in buchungen) {
			NSString * buchungsKonto = [[b konto] bezeichnung]; 
			NSString * date = [[b datum] descriptionWithCalendarFormat:datumsformat timeZone:nil locale:nil];
			NSString * valuta;
			if ([b datumWertstellung] != nil) {
				valuta = [[b datumWertstellung] descriptionWithCalendarFormat:datumsformat timeZone:nil locale:nil];
			} else {
				valuta = @"";
			}
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
			
			NSString * zeile = [self zeileMitDatum:date wertstellung:valuta
							  wert:wert waehrung:waehrung 
							   art:art zweck:zweck 
						      absender:absender 
						 absenderKonto:anderesKonto
						  absenderBank:andereBank
						 buchungsKonto:buchungsKonto
						    fuerAktion:aktion];
			
			[f writeData:[self encodeString:zeile]];
		}
		
		// Datei schliessen
		[f closeFile];
	}
	@catch (NSException * e) {
		NSLog(@"Error during csv export: %@", [e description]);
	}
}

@end
