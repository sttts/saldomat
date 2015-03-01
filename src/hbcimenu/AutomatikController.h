//
//  AutomatikController.h
//  hbci
//
//  Created by Stefan Schimanski on 13.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AppController;

@interface AutomatikController : NSObject {
	IBOutlet AppController * appController_;
	NSTimer * timer_;
}

@end
