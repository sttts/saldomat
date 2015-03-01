//
//  Buchung.h
//  hbci
//
//  Created by Stefan Schimanski on 18.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Konto.h"


@interface Buchung : NSManagedObject
{ }
@property (retain) NSString * zweck;
@property (copy) NSDecimalNumber * wert;
@property (readonly,copy) NSDecimalNumber * betrag;
@property (retain) NSString * waehrung;
@property (retain) NSString * art;
@property (retain) NSDate * datum;
@property (retain) NSDate * datumGeladen;
@property (retain) NSDate * datumWertstellung; // Valuta
@property (retain) Konto * konto;
@property (retain) Konto * neuFuerKonto;
@property (retain) NSNumber * neu;
@property (retain) NSString * anderesKonto;
@property (retain) NSString * andereBank;
@property (retain) NSString * andererName;
@property (retain) NSString * primaNota;
@property (copy) NSString * farbe;
@property (retain) NSString * guid;
@property (readonly) NSString * kontoIdent;
@property (readonly) NSString * andererNameUndZweck;
@property (readonly) NSString * effektiverZweck;
@property (readonly) NSString * effektiverZweckRaw;
@property (readonly) NSString * effektiverAndererName;
@property (readonly) NSString * effektivesAnderesKonto;
@property (readonly) NSString * effektiveAndereBank;
@end


#define ZweckFilterGeaendertNotification @"ZweckFilterGeaendertNotification"

@interface ZweckFilter : NSManagedObject
{ }

@property (retain) NSString * regexp;
@property (retain) NSNumber * zweck;
@property (retain) NSNumber * andererName;
@property (retain) NSNumber * andereBank;
@property (retain) NSNumber * anderesKonto;

@end

@interface Konto (ArrayAccessors)
- (void)addNeueBuchungenObject:(Buchung *)buchung;
- (void)removeNeueBuchungenObject:(Buchung *)buchung;
- (void)removeBuchungenObject:(Buchung *)buchung;
- (void)addUnterkontoObject:(Unterkonto *)unterkonto;
@end
