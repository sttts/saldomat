//
//  AppController.h
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Filter.h"
#import "Kontoauszug.h"
#import "KontoWindowController.h"


@class AktionenController;
@class AuthorizationController;
@class AutomatikController;
@class DebugWindowController;
@class DockIconController;
@class ErrorWindowController;
@class FeedServerController;
@class GrowlController;
@class iBankExporter;
@class MoneywellExporter;
@class UniversalQifExporter;
@class IconController;
@class LogWindowController;
@class PrefWindowController;
@class UpdateController;


@interface AppController : NSResponder<KontoauszugDelegate> {
	// Fenster
	IBOutlet LogWindowController * logWindowCtrl_;
	IBOutlet IconController * iconCtrl_;
	IBOutlet PrefWindowController * prefWindowCtrl_;
	IBOutlet KontoWindowController * kontoWindowCtrl_;
	IBOutlet DebugWindowController * debugWindowCtrl_;
	IBOutlet NSWindow * ersterStartWindow_;
	IBOutlet NSImageView * betaView_;	
	
	// max ein ErrorWindowController pro Konto-Bezeichnung
	NSMutableDictionary * errorWindowCtrls_;
	
	// Konten-Logik
	IBOutlet NSArrayController * konten_;
	Kontoauszug * laufenderKontoauszug_;
	NSMutableArray * wartendeKonten_;
	IBOutlet AutomatikController * automatikCtrl_;
	
	// Filter-Logik
	IBOutlet GrowlController * growlController_;
	IBOutlet AktionenController * aktionenController_;
	SharedFilters * filters_;
	
	// Sonstiges
	IBOutlet FeedServerController * feedServerController_;
	IBOutlet UpdateController * updateController_;
	IBOutlet DockIconController * dockIconController_;
	BOOL automatischGestarteteKontoauszuege_;
	IBOutlet AuthorizationController * authController_;
	
	// Version
	NSNumber * standardVersion_;
	NSNumber * proVersion_;
	
	BOOL debugMenu_;
	
	// Exporter
	iBankExporter * ibankExporter_;
	MoneywellExporter * moneywellExporter_;
	UniversalQifExporter * universalQifExporter_;
}

- (void)saveUserDefaults;
- (NSArray *)wartendeKonten;

- (void)holeKontoauszugFuer:(Konto *)konto;
- (void)stopKontoauszugFuerKonto:(Konto *)konto;
- (void)starteKontoauszuegePerSync;

- (IBAction)showPreferences:(id)sender;
- (IBAction)showKontoPreferences:(id)sender;
- (IBAction)showFeedPreferences:(id)sender;
- (IBAction)showAbout:(id)sender;
- (IBAction)geheZurHomepage:(id)sender;
- (IBAction)geheZurOnlineHilfe:(id)sender;
- (IBAction)holeAlleKontoauszuege:(id)sender;
- (IBAction)showLog:(id)sender;
- (NSTextView *)logView;
- (void)leereLogView;
- (IBAction)kontoFensterAnzeigen:(id)sender;
- (IBAction)versteckeFehler:(id)sender;

- (IBAction)zeigeDebugWindow:(id)sender;
- (IBAction)verbesserungsVorschlag:(id)sender;
- (IBAction)ersterStartWindowKontoAnlegen:(id)sender;

- (BOOL)kontoHatteFehler:(Konto *)konto;
- (BOOL)kontoHatteKritischenFehler:(Konto *)konto;
- (IBAction)zeigeFehler:(Konto *)konto;
- (NSString *)kontoFehler:(Konto *)konto;
- (IBAction)fehlerGesehen:(Konto *)konto;

@property (copy) NSNumber * standardVersion;
@property (copy) NSNumber * proVersion;

- (void)zeigeBuchungsFensterMitKonto:(Konto *)konto;
- (void)zeigeBuchungsFensterMitBuchung:(Buchung *)buchung;

@property (readonly) SharedFilters * sharedFilters;
@property (readonly) GrowlController * growlController;
@property (readonly) AktionenController * aktionenController;
@property (readonly) FeedServerController * feedServerController;
@property (readonly) UpdateController * updateController;
@property (readonly) NSArray * konten;
@property (readonly) iBankExporter * ibankExporter;
@property (readonly) MoneywellExporter * moneywellExporter;
@property (readonly) UniversalQifExporter * universalQifExporter;
@property (readonly) Kontoauszug * laufenderKontoauszug;
@property (readonly) DockIconController * dockIconController;
@property (readonly) AuthorizationController * authController;
@property (readonly) KontoWindowController * kontoWindowController;
@property BOOL debugMenu;

@end

extern AppController * theAppCtrl;
