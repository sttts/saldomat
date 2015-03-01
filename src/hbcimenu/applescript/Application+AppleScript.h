//
//  Application+AppleScript.h
//  hbci
//
//  Created by Stefan Schimanski on 15.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Application.h"


@interface Application (AppleScript)

- (id)scriptSyncAll:(NSScriptCommand *)command;
- (id)scriptSyncKonto:(NSScriptCommand *)command;

@end
