//
//  AuthorizationController.h
//  hbci
//
//  Created by Stefan Schimanski on 27.12.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <SecurityInterface/SFAuthorizationView.h>
#import <Security/Authorization.h>

@class SFAuthorization;

@interface AuthorizationController : NSObject {
	SFAuthorization * auth_;
	
	IBOutlet NSWindow * protokollWindow_;
	
	BOOL kontenWindowVersteckt_;
	BOOL protokollWindowVersteckt_;
	
	NSSound * lockSound_;
	NSSound * unlockSound_;
	NSTimer * timer_;
	int countdown_;
	BOOL verschlossen_;
	BOOL pseudoSchloss_;
}

- (IBAction)lock:(id)sender;
- (IBAction)unlock:(id)sender;
- (BOOL)offenHalten;

@property (readonly) BOOL pseudoSchloss;
@property (readonly) BOOL verschlossen;
@property (readonly) SFAuthorization * authorization;

@end


@interface SyncedAuthorizationView : SFAuthorizationView {
}

@property (retain) SFAuthorization * authorization;

@end