//
//  Kontouszug.h
//  hbci
//
//  Created by Stefan Schimanski on 09.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "HbciToolLoader.h"
#import "Konto.h"

@class Kontoauszug;

@protocol KontoauszugDelegate

- (void)finishedKontoauszug:(Kontoauszug *)kontoauszug;
- (void)finishedKontoauszug:(Kontoauszug *)kontoauszug withError:(NSError *)error;
- (void)canceledKontoauszug:(Kontoauszug *)kontoauszug;

- (NSTextView *)logView;

@end

@interface Kontoauszug : NSObject {
	Konto * konto_;
	
	HbciToolLoader * hbcitoolLoader_;
	NSMutableArray * buchungen_;
	double kontostand_;
	NSString * kontostandWaehrung_;
	BOOL wirdGeholt_;
	BOOL canceled_;
	NSDate * buchungenVon_;
	BOOL automatischGestartet_;
	
	id<KontoauszugDelegate> delegate_;
}

- (id)initWithKonto:(Konto *)konto automatischGestartet:(BOOL)automatisch;

- (void)setDelegate:(id<KontoauszugDelegate>)delegate;

- (void)cancel;
- (BOOL)wirdGeholt;
- (BOOL)start;

@property (readonly) BOOL automatischGestartet;

- (Konto *)konto;
- (NSArray *)buchungen;
- (double)kontostand;
- (NSString *)kontostandWaehrung;
- (NSDate *)buchungenVon;

@end
