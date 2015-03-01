//
//  ZaehlerImage.h
//  hbci
//
//  Created by Stefan Schimanski on 13.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Konto.h"


@interface ZaehlerImage : NSImage {

}

- (id)initMitHoehe:(float)hoehe undSchrift:(NSFont *)font pos:(NSString *)pos neg:(NSString *)neg;
- (id)initMitHoehe:(float)hoehe undSchrift:(NSFont *)font fuerKonto:(Konto *)konto;
- (id)initMitHoehe:(float)hoehe pos:(NSString *)pos neg:(NSString *)neg;
- (id)initMitHoehe:(float)hoehe fuerKonto:(Konto *)konto;
- (id)initMitPos:(NSString *)pos neg:(NSString *)neg;
- (id)initMitKonto:(Konto *)konto;

+ (float)zaehlerBreite:(NSString *)pos undNegZaehler:(NSString *)neg
		  font:(NSFont *)zaehlerFont hoehe:(float)zaehlerH;
+ (void)drawZaehler:(NSString *)pos undNegZaehler:(NSString *)neg
	       font:(NSFont *)zaehlerFont hoehe:(float)zaehlerH
	       left:(float)x top:(float)y;
@end
