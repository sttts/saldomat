//
//  DebugWindowController.h
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AppController;


@interface DebugWindowController : NSWindowController {
}

- (NSManagedObjectContext *)managedObjectContext;
- (AppController *)appCtrl;

- (IBAction)automatischeKontoauszuegeHolen:(id)sender;

@end
