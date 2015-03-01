//
//  CocoaBankingGui.h
//  hbcipref
//
//  Created by Stefan Schimanski on 03.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Konto.h"
#import "MessageBoxController.h"

struct GWEN_GUI;

@class CocoaBanking;

@interface CocoaBankingGui : NSObject {
	struct GWEN_GUI * gui_;
	Konto * konto_;
	
	IBOutlet CocoaBanking * cocoaBanking_;
	IBOutlet MessageBoxController * msgBoxCtrl_;
	
	NSMutableArray * log_;
	BOOL canceled_;
}

- (void)setCurrentKonto:(Konto *)konto;
- (Konto *)currentKonto;
- (CocoaBanking *)cocoaBanking;
- (MessageBoxController *)messageBoxController;

- (void)startLog;
- (NSArray *)stopLog;

- (NSString *)keychainAccount:(Konto *)konto;
- (NSString *)keychainService:(Konto *)konto;
- (NSString *)oldKeychainService:(Konto *)konto;

@property BOOL canceled;

@end
