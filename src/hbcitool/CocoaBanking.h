//
//  CocoaBanking.h
//  hbcipref
//
//  Created by Stefan Schimanski on 24.03.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "CocoaBankingProtocol.h"
#import "CocoaBankingGui.h"

struct AB_BANKING;
struct AB_PROVIDER;

@interface CocoaBanking : NSObject <CocoaBankingProtocol> {
	NSConnection * connection_;

	SecKeychainRef keychain_;
	struct AB_BANKING * ab_;
	struct AB_PROVIDER * provider_;
	IBOutlet CocoaBankingGui * gui_;
	NSString * bankingGeoeffnetFuer_;
	
	NSObject<CocoaBankingDelegate> * delegate_;
	
	BOOL ok_;
}

- (id)init;
- (void)log:(NSString *)s;
- (SecKeychainRef)keychain;

- (NSObject<CocoaBankingDelegate> *)delegate;

@end
