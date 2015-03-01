//
//  Version.h
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Version : NSObject {
}

+ (NSString *)revision;
+ (NSString *)version;
+ (NSString *)publicVersion;

@end
