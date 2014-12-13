//
//  GrowlController.h
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

//#import "Growl/GrowlApplicationBridge.h"

#import "Konto.h"
#import "Kontoauszug.h"

@interface GrowlController : NSObject/*<GrowlApplicationBridgeDelegate>*/ {
	IBOutlet NSFormatter * saldoFormatter_;
}

- (void)meldeNeueBuchungen:(NSArray *)buchungen fuerKonto:(Konto *)konto;
- (void)meldeKontoauszugFehler:(Kontoauszug *)kontoauszug fehlerMeldung:(NSError *)error;
- (void)meldeZuLoeschendeBuchungen:(NSArray *)alteBuchungen fuerKonto:(Konto *)konto;
- (void)meldeSaldoWarnungFuerKonto:(Konto *)konto;
- (void)meldeAktionFilter:(NSString *)titel mitNachricht:(NSString *)nachricht
		   sticky:(BOOL)sticky hohePrioritaet:(BOOL)hohePrioritaet;
- (void)meldeiBankExport:(int)buchungsAnzahl;
- (void)meldeMoneywellExport:(int)buchungsAnzahl;
- (void)meldeUniversalQifExport:(int)buchungsAnzahl theApp:(NSString *)app;

- (void)aufGrowlInstallationPruefen;

@end
