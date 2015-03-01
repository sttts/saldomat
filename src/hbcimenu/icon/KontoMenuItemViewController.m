//
//  KontoMenuItemViewController.m
//  hbci
//
//  Created by Michael on 13.05.08.
//  Copyright 2008 michaelschimanski.de. All rights reserved.
//

#import "KontoMenuItemViewController.h"

#import "AppController.h"
#import "debug.h"
#import "ZaehlerImage.h"


@implementation KontoMenuItemViewController

- (void)updateZaehler
{
	[zaehlerIcon_ setImage:[[[ZaehlerImage alloc] initMitHoehe:14 fuerKonto:konto_] autorelease]];
}


- (id)initWithKonto:(Konto *)konto {
	self = [super initWithNibName:@"KontoMenuItemView" bundle:nil];
	
	konto_ = [konto retain];
	warnFarbe_ = [[NSColor colorWithDeviceRed:0.874 green:0.03 blue:0.0 alpha:1.0] retain];
	
	return self;
}


- (void)awakeFromNib {
	// Rot/Gruen setzen
	[saldoFormatter_ setRot:[NSColor colorWithDeviceRed:0.5 green:0.0 blue:0.0 alpha:1.0]];
	[saldoFormatter_ setGruen:[NSColor colorWithDeviceRed:0.0 green:0.5 blue:0.0 alpha:1.0]];
	
	// Saldo-Warnung anzeigen?
	if ([konto_ warnSaldoUnterschritten])
		[tfBezeichnung_ setTextColor:warnFarbe_];
	else
		[tfBezeichnung_ setTextColor:[NSColor blackColor]];
	
	// Fehler?
	[fehlerIcon_ setHidden:![theAppCtrl kontoHatteFehler:konto_]];
	
	// Zaehler-Icon setzen
	[konto_ addObserver:self forKeyPath:@"neueBuchungen" options:NSKeyValueObservingOptionNew context:nil];
	[self updateZaehler];
}


- (void)dealloc
{
	[konto_ removeObserver:self forKeyPath:@"neueBuchungen"];
	
	[menu_ release];
	[konto_ release];
	[warnFarbe_ release];
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self updateZaehler];
}


- (void)setBalken:(BOOL)highlight {
	NSColor * schriftfarbe;
	
	if (highlight == YES) {
		[focusBalken_ setHidden:NO];
		[dreieck_ setImage:[NSImage imageNamed:@"MenuDreieck_w"]];
		schriftfarbe = [NSColor whiteColor];
		[tfSaldo_ setFormatter:saldoHighlightFormatter_];
	} else {
		[focusBalken_ setHidden:YES];
		[dreieck_ setImage:[NSImage imageNamed:@"MenuDreieck"]];
		schriftfarbe = [NSColor blackColor];
		[tfSaldo_ setFormatter:saldoFormatter_];
	}
	
	[tfSaldo_ setTextColor:schriftfarbe];
	if ([konto_ warnSaldoUnterschritten])
		[tfBezeichnung_ setTextColor:warnFarbe_];
	else
		[tfBezeichnung_ setTextColor:schriftfarbe];
}


@synthesize konto = konto_;
@synthesize menu = menu_;

@end