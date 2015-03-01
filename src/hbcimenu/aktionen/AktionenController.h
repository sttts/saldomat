//
//  AktionController.h
//  hbci
//
//  Created by Stefan Schimanski on 03.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Aktion;
@class AktionAusfuehrer;
@class GrowlController;

@interface AktionenController : NSObject {
	NSDictionary * ausfuehrer_;
	IBOutlet GrowlController * growl_;
}

- (void)aktionenAusfuehren:(NSArray *)buchungen;
- (void)aktionAusfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen;

@end
