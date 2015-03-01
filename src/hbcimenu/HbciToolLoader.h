//
//  HbciToolLoader.h
//  hbcipref
//
//  Created by Stefan Schimanski on 06.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CocoaBankingProtocol.h"

@protocol HbciToolLoaderDelegate

- (void)logStdErr:(NSString *)s;
- (void)logStdOut:(NSString *)s;

@end


@interface HbciToolLoader : NSObject <CocoaBankingDelegate> {
	NSProxy<CocoaBankingProtocol> * hbci_;
	NSTask * hbcitool_;
	BOOL debugMode_;
	
	NSObject<HbciToolLoaderDelegate> * delegate_;
	NSMutableSet * logViews_;
	
	unsigned offeneFenster_;
}

+ (unsigned)offeneHbciToolFenster;

- (void)unload;
- (NSProxy<CocoaBankingProtocol> *)banking;

- (void)setDelegate:(NSObject<HbciToolLoaderDelegate> *)delegate;
- (void)addLogView:(NSTextView *)logView;
- (void)removeLogView:(NSTextView *)logView;

@end
