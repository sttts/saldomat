//
//  Aktion.h
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Aktion;

@interface AktionAusfuehrer : NSObject {

}

- (void)ausfuehren:(Aktion *)aktion fuerBuchungen:(NSArray *)buchungen;

@end
