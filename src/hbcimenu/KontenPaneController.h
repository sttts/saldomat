//
//  KontenPaneController.h
//  hbcimenu
//
//  Created by Michael on 23.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PrefWindowController.h"

@class ExpertenKontoController;
@class FintsInstituteLeser;
@class WebView;

@interface KontenPaneController : NSViewController {
	
	// Kontoinformationen 
	IBOutlet NSTextField * tfServer;
	IBOutlet NSTextField * tfBankleitzahl;
	IBOutlet NSTextField * tfBankname;
	IBOutlet NSTextField * tfKennung; //-> Kontonummer
	IBOutlet NSPopUpButton * tfUnterkonto;
	IBOutlet NSPopUpButton * unterkonten_;
	IBOutlet NSButton * chkAktiv;
	IBOutlet NSButton * btnUnterkontoHolen_;
	IBOutlet NSTableView * tableView_;
	IBOutlet FintsInstituteLeser * fintsInstituteLeser_;
	IBOutlet NSPopUpButton * hbciVersion_;
	IBOutlet NSTextField * kundenId_;
	IBOutlet NSTextField * benutzerId_;
	
	// statusWindowSheet
	IBOutlet NSWindow * statusWindowSheet_;
	IBOutlet NSProgressIndicator * statusSpinner_;
	IBOutlet NSTextView * statusLogView_;
	IBOutlet NSScrollView * statusScrollView_;
	IBOutlet NSButton * statusProtokollAusfahren;
	
	// errorWindowSheet
	IBOutlet NSWindow * errorWindowSheet_;
	IBOutlet NSTextView * errorLogView_;
	IBOutlet NSScrollView * errorScrollView_;
	IBOutlet NSTextField * errorMessage_;
	IBOutlet NSButton * errorProtokollAusfahren;
	BOOL showErrorIfAny_;
	
	
	// Export-Sheets
	IBOutlet NSWindow * iBankWindowSheet_;
	
	
	// ### QIF-Exports START ###
	IBOutlet NSWindow * moneywellWindowSheet_;
	IBOutlet NSButton * moneywellKategorieCheckBox_;
	IBOutlet NSWindow * iFinance3WindowSheet_;
	IBOutlet NSButton * iFinance3KategorieCheckBox_;
	IBOutlet NSWindow * squirrelWindowSheet_;
	IBOutlet NSButton * squirrelKategorieCheckBox_;
	IBOutlet NSWindow * chaChing2WindowSheet_;
	IBOutlet NSButton * chaChing2KategorieCheckBox_;
	IBOutlet NSWindow * iBank4WindowSheet_;
	IBOutlet NSButton * iBank4KategorieCheckBox_;
	
	// FIXME: QIF faehige Programme (1)
	// ### QIF-Exports ENDE ###
	
	
	// Einstellung des Warnsaldos
	IBOutlet NSButton * chkWarnen_;
	IBOutlet NSTextField * tfWarnSaldo_;
	IBOutlet NSNumberFormatter * warnNumberFormatter_;
	IBOutlet NSTextField * warnSaldoLabel_;
	
	// Warnsymbolik, Ein-/Ausgabeobjekte der ermittelten Bankinfos
	IBOutlet NSButton *btnEditServer_;
	IBOutlet NSView * ServerWarningView_;
	IBOutlet NSView * BanknameView_;
	
	// Sonstiges
	IBOutlet NSProgressIndicator * piBankWirdErmittelt_;
	IBOutlet NSArrayController * kontenController_;
	IBOutlet ExpertenKontoController * expertenKontoCtrl_;
	NSArray * subAccounts_;
	int geladeneBuchungenImTestKontoauszug_;
	IBOutlet PrefWindowController * prefWindowCtrl_;
	IBOutlet NSWindow * kontoauszugTestenErfolgsSheet_;
	HbciToolLoader * hbcitoolLoader_;
	IBOutlet NSComboBox * iBankKonten_;
	IBOutlet NSDrawer * drawer_;
	IBOutlet NSTextField * hbciServerLabel_;
	
	// Tan Methoden
	NSArray * theTanMethods_;
	IBOutlet NSArrayController * tanMethods_;
	IBOutlet NSPopUpButton * popupTanMethods_;
	
	// Banken Wiki
	IBOutlet WebView * webView_;
}

- (void)bankInfosPruefen:(NSNotification *)aNotification;
- (void)bankWikiLaden;
- (IBAction)kontenErmitteln:(id)sender;
- (IBAction)statusStopClicked:(id)sender;
- (IBAction)errorCloseClicked:(id)sender;
- (IBAction)statusWindowSheet_protokollausfahren:(id)sender;
- (void)errorProtokollZeigen;
- (void)errorProtokollVerbergen;
- (IBAction)errorWindowSheet_protokollausfahren:(id)sender;
- (IBAction)warnCheckboxClicked:(id)sender;
- (IBAction)neuesKonto:(id)sender;
- (IBAction)kontoDuplizieren:(id)sender;
- (IBAction)loescheKonto:(id)sender;
- (IBAction)bankMelden:(id)sender;
- (IBAction)feedLaden:(id)sender;
- (IBAction)zuruecksetzen:(id)sender;
- (IBAction)protokollAnzeigen:(id)sender;
- (IBAction)unlock:(id)sender;
- (IBAction)lock:(id)sender;

- (IBAction)iBankExportZurueckSetzen:(id)sender;
- (IBAction)iBankKontenAbfragen:(id)sender;
- (IBAction)iBankCloseClicked:(id)sender;
- (IBAction)nachiBankExportieren:(id)sender;

- (IBAction)qifExportZurueckSetzen:(id)sender;


// ### QIF-Exports START ###
- (IBAction)moneywellCloseClicked:(id)sender;
- (IBAction)iFinance3CloseClicked:(id)sender;
- (IBAction)squirrelCloseClicked:(id)sender;
- (IBAction)chaChing2CloseClicked:(id)sender;
- (IBAction)iBank4CloseClicked:(id)sender;

// FIXME: Qif faehige Programme (2)
// ### QIF-Exports ENDE ###


- (IBAction)nachQifExportieren:(id)sender;

- (IBAction)exportMethodeConfig:(id)sender;

- (IBAction)expertenSheetZeigen:(id)sender;

- (IBAction)kontoauszugTesten:(id)sender;
- (IBAction)kontoauszugTestenErfolgsSheetSchliessen:(id)sender;
- (IBAction)updateTanMethods:(id)sender;

// Banken Wiki
- (IBAction)geheNachHause:(id)sender;

// Online-Hilfe
- (IBAction)geheZurOnlineHilfe:(id)sender;
@end
