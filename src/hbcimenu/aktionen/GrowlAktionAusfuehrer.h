//
//  GrowlAktion.h
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "AktionAusfuehrer.h"
#import "GrowlController.h"


@interface GrowlAktionAusfuehrer : AktionAusfuehrer {
	GrowlController * growl_;
}

- (id)initWithGrowlController:(GrowlController *)growl;

@end
