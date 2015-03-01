//
//  GrowlController.m
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "GrowlController.h"

#import "AppController.h"
#import "debug.h"
#import "urls.h"


@implementation GrowlController

- (void)awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}	


- (void)aufGrowlInstallationPruefen
{
	if ([GrowlApplicationBridge isGrowlInstalled] == NO) {
		int ret = NSRunInformationalAlertPanel(
			NSLocalizedString(@"Growl Installation", nil),
			NSLocalizedString(@"Saldomat supports the Growl notification system "
					  "to display nice non-obstrusive messages. Do you want "
					  "to take a look at the Growl homepage to find out more about it "
					  "and how to install it?", nil),
			NSLocalizedString(@"Yes", nil),
			NSLocalizedString(@"No", nil),
			nil);
		if (ret == NSAlertDefaultReturn)
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:GROWL_INFO_URL]];
	}
}


- (void) dealloc
{
	[super dealloc];
}


- (void)growlNotificationWasClicked:(id)clickContext
{
	NSLog(@"growlNotificationWasClicked");
	
	// Fehlernotification?
	NSString * feedGeheimnis = clickContext;
	for (Konto * k in [theAppCtrl konten]) {
		if ([[k feedGeheimnis] isEqualToString:feedGeheimnis]) {
			[theAppCtrl zeigeFehler:k];
			return;
		}
	}
	
	// Fenster nach vorne bringen
	[NSApp activateIgnoringOtherApps:YES];
}


- (void)meldeNeueBuchungen:(NSArray *)buchungen fuerKonto:(Konto *)konto
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		if ([buchungen count] > 0) {
			[GrowlApplicationBridge notifyWithTitle:[konto bezeichnung]
						    description:[NSString stringWithFormat:NSLocalizedString(@"%d new transactions for %@", nil),
								 [buchungen count], [konto bezeichnung]]
					       notificationName:@"NeueBuchungenEmpfangen"
						       iconData:nil
						       priority:0
						       isSticky:NO
						   clickContext:nil];
		} else {
			[GrowlApplicationBridge notifyWithTitle:[konto bezeichnung]
						    description:[NSString stringWithFormat:NSLocalizedString(@"No new transactions for %@", nil),
								 [konto bezeichnung]]
					       notificationName:@"KeineNeuenBuchungenEmpfangen"
						       iconData:nil
						       priority:0
						       isSticky:NO
						   clickContext:nil];
		}
	}
}


- (void)meldeKontoauszugFehler:(Kontoauszug *)kontoauszug fehlerMeldung:(NSError *)error
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		Konto * konto = [kontoauszug konto];
		[GrowlApplicationBridge notifyWithTitle:[konto bezeichnung]
					    description:[NSString stringWithFormat:NSLocalizedString(@"Error: %@", nil), [error localizedDescription]]
				       notificationName:@"KontoauszugsFehler"
					       iconData:nil
					       priority:0
					       isSticky:NO
					   clickContext:[konto feedGeheimnis]];
	}
}


- (void)meldeZuLoeschendeBuchungen:(NSArray *)alteBuchungen fuerKonto:(Konto *)konto
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		[GrowlApplicationBridge notifyWithTitle:[konto bezeichnung]
					    description:[NSString stringWithFormat:NSLocalizedString(@"Deleting %d old transactions", nil),
							 [alteBuchungen count]]
				       notificationName:@"AlteBuchungenWerdenGeloescht"
					       iconData:nil
					       priority:0
					       isSticky:NO
					   clickContext:nil];
	}
}


- (void)meldeSaldoWarnungFuerKonto:(Konto *)konto
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		NSString * formattedSaldoWarnung = [saldoFormatter_ stringForObjectValue:[konto warnSaldo]];
		[GrowlApplicationBridge notifyWithTitle:[konto bezeichnung]
					    description:[NSString stringWithFormat:NSLocalizedString(@"Balance is below %@", nil),
							 formattedSaldoWarnung]
				       notificationName:@"SaldoWarnung"
					       iconData:nil
					       priority:1
					       isSticky:NO
					   clickContext:nil];
	}
}


- (void)meldeAktionFilter:(NSString *)titel mitNachricht:(NSString *)nachricht
		   sticky:(BOOL)sticky hohePrioritaet:(BOOL)hohePrioritaet
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		[GrowlApplicationBridge notifyWithTitle:titel
					     description:nachricht
					notificationName:@"FilterAktion"
						iconData:nil
						priority:hohePrioritaet ? 10 : 0
						isSticky:sticky
					    clickContext:nil];
	}
}


- (void)meldeiBankExport:(int)buchungsAnzahl
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"iBank export", nil)
					    description:[NSString stringWithFormat:NSLocalizedString(@"Exporting %d transactions.", nil),
							 buchungsAnzahl]
				       notificationName:@"iBankExports"
					       iconData:nil
					       priority:0
					       isSticky:NO
					   clickContext:nil];
	}
}


- (void)meldeMoneywellExport:(int)buchungsAnzahl
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		[GrowlApplicationBridge notifyWithTitle:NSLocalizedString(@"Moneywell export", nil)
					    description:[NSString stringWithFormat:NSLocalizedString(@"Exporting %d transactions.", nil),
							 buchungsAnzahl]
				       notificationName:@"MoneywellExports"
					       iconData:nil
					       priority:0
					       isSticky:NO
					   clickContext:nil];
	}
}


- (void)meldeUniversalQifExport:(int)buchungsAnzahl theApp:(NSString *)app
{
	if ([GrowlApplicationBridge isGrowlRunning]) {
		[GrowlApplicationBridge notifyWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ export", nil),app]
					    description:[NSString stringWithFormat:NSLocalizedString(@"Exporting %d transactions.", nil),buchungsAnzahl]
				       notificationName:@"MoneywellExports"
					       iconData:nil
					       priority:0
					       isSticky:NO
					   clickContext:nil];
	}
}

@end
