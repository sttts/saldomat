//
//  FeedServerController.h
//  hbci
//
//  Created by Stefan Schimanski on 10.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Konto;
@class HTTPServer;

@interface FeedServerController : NSObject {
	HTTPServer * server_;
	
	IBOutlet NSArrayController * konten_;
	IBOutlet NSNumberFormatter * wertFormatter_;
	IBOutlet NSDateFormatter * dateFormatter_;
	
	NSString * baseUrl_;
}

@property (readonly) BOOL running;
@property (readonly) HTTPServer * server;
@property (readonly) NSString * baseUrl;

- (NSURL *)feedUrlFuerKonto:(Konto *)konto;
- (void)oeffneFeedFuerKonto:(Konto *)konto;

@end
