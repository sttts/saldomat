//
//  Version.m
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "Version.h"
#import "svnrevision.h"

@implementation Version

+ (NSString *)revision
{
	return [NSString stringWithFormat:@"r%@", 
		[NSString stringWithCString:SVNREVISION encoding:NSUTF8StringEncoding]];
}


+ (NSString *)version
{
	return [NSString stringWithCString:VERSION encoding:NSUTF8StringEncoding];
}


+ (NSString *)publicVersion
{
	return [NSString stringWithCString:PUBLICVERSION encoding:NSUTF8StringEncoding];
}

@end
