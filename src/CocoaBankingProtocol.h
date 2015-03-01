//
//  CocoaBankingProtocol.h
//  hbcipref
//
//  Created by Stefan Schimanski on 24.03.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Konto;
@class Buchung;

@protocol CocoaBankingDelegate

- (oneway void)log:(in NSString *)s;
- (void)willOpenWindow;
- (void)closedWindow;

@end


@protocol CocoaBankingProtocol

- (BOOL)isValid;
- (void)setDelegate:(NSObject<CocoaBankingDelegate> *)delegate;

- (out bycopy NSArray *)getSubAccounts:(in bycopy Konto *)konto error:(out bycopy NSError **)error;
- (out bycopy NSArray *)getTransactions:(in bycopy Konto *)konto 
		   from:(NSDate *)from 
	      balanceTo:(out bycopy double *)balance 
      balanceCurrencyTo:(out bycopy NSString **)balanceCurrency
		  error:(out bycopy NSError **)error;
- (out bycopy NSArray *)getTanMethods:(in bycopy Konto *)konto error:(out bycopy NSError **)error;
- (out BOOL)updateBankName:(inout Konto *)konto;

- (oneway void)terminate;

@end
