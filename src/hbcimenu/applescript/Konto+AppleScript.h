//
//  Konto+AppleScript.h
//  hbci
//
//  Created by Stefan Schimanski on 14.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Buchung.h"
#import "Konto.h"


@interface Buchung (AppleScript)

- (NSString *)identifier;
- (NSScriptObjectSpecifier *)objectSpecifier;

@end


@interface Konto (AppleScript)

- (NSString *)identifier;
- (NSScriptObjectSpecifier *)objectSpecifier;

@end
