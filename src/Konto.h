//
//  hbciPref_konto.h
//  hbcipref
//
//  Created by Michael on 23.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Konto;
@class ZweckFilter;

enum KontoExportMethode {
	KontoExportKeine = 0,
	KontoExportiBank,
	KontoExportMoneywell,
	KontoExportiFinance3,
	KontoExportSquirrel,
	KontoExportChaChing2,
	KontoExportiBank4,
	KontoExportiFinance3AppStore,
	// FIXME: Qif faehige Programme (1)
};

@interface Saldo : NSManagedObject
{ }
@property (retain) NSDecimalNumber * wert;
@property (retain) NSString * waehrung;
@property (retain) Konto * konto;
@property (retain) NSDate * datum;


@end

@interface TanMethode : NSManagedObject
{ }
@property (retain) NSNumber * funktion;
@property (retain) NSString * id_name;
@property (retain) NSString * name;
@property (retain) Konto * konto;
@property (retain) Konto * tanMethodeFuerKonto;
@property (readonly) NSString * bezeichnung;

@end


@interface Unterkonto : NSManagedObject
{ }
@property (retain) NSString * kontonummer;
@property (retain) Konto * konto;
@property (retain) Konto * unterkontoFuerKonto;
@property (retain) NSString * name;
@property (readonly) NSString * bezeichnung;
@property (retain) NSString * bankleitzahl;

@end

@interface Konto : NSManagedObject <NSCoding> {
	NSArrayController * buchungenArray_;
	NSArrayController * neueBuchungenArray_;
	BOOL versteckt_;
}
@property (retain) NSString * bezeichnung;
@property (copy) NSNumber * automatisch;
@property (retain) NSString * server;
@property (retain) ZweckFilter * zweckFilter;
@property (copy) NSNumber * saldo;
@property (retain) NSSet * saldos;
@property (copy) NSNumber * warnSaldo;
@property (readonly) BOOL warnSaldoUnterschritten;
@property (retain) NSString * bankleitzahl;
@property (retain) NSString * bankname;
@property (retain) NSString * land;
@property (retain) Unterkonto * unterkonto;
@property (retain) NSString * kennung;
@property (retain) NSString * benutzerId;
@property (retain) NSString * kundenId;
@property (retain) NSSet * unterkonten;
@property (retain) NSSet * buchungen;
@property (retain) NSSet * neueBuchungen;
@property (copy) NSNumber * SSL3;
@property (copy) NSNumber * hbciVersion;
@property (retain) NSString * tanMethod;
@property (retain) TanMethode * tanMethode;
@property (retain) NSSet * tanMethoden;
@property (copy) NSDate * buchungenVon;
@property (copy) NSDate * buchungenBis;
@property (retain) NSString * feedGeheimnis;
@property (retain) NSString * guid;
@property (readonly) NSString * ident;
@property (copy) NSNumber * order;

@property (retain) NSDate * iBankExportVon;
@property (retain) NSDate * iBankExportBis;
@property (retain) NSString * iBankKonto;
@property (copy) NSNumber * iBankExportAktiv;


// ### QIF-Exports START ###
@property (retain) NSDate * moneywellExportVon; // global fuer Konto
@property (retain) NSDate * moneywellExportBis; // global fuer Konto

@property (copy) NSNumber * moneywellExportAktiv;
@property (copy) NSNumber * moneywellExportKategorien;
@property (copy) NSNumber * iFinance3ExportAktiv;
@property (copy) NSNumber * iFinance3ExportKategorien;
@property (copy) NSNumber * iFinance3AppStoreExportAktiv;
@property (copy) NSNumber * squirrelExportAktiv;
@property (copy) NSNumber * squirrelExportKategorien;
@property (copy) NSNumber * chaChing2ExportAktiv;
@property (copy) NSNumber * chaChing2ExportKategorien;
@property (copy) NSNumber * iBank4ExportAktiv;
@property (copy) NSNumber * iBank4ExportKategorien;
// FIXME: QIF faehige Programme (2)

// ### QIF-Exports ENDE ###


@property (readonly) NSArray * buchungenArray;
@property (readonly) NSArray * neueBuchungenArray;

@property (copy) NSNumber * exportMethode;

@property (copy) NSNumber * statFehler;
@property (copy) NSNumber * statErfolgreich;

@property (copy) NSNumber * saldoImMenu;

@property BOOL versteckt;

@end

