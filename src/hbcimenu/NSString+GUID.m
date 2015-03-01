//
//  NSString+GUID.m
//  hbci
//
//  Created by Stefan Schimanski on 14.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "NSString+GUID.h"


@implementation NSString (GUID)

+ (NSString*) stringWithNewUUID
{
	CFUUIDRef	uuidObj = CFUUIDCreate(nil);//create a new UUID
	//get the string representation of the UUID
	NSString	*newUUID = (NSString*)CFUUIDCreateString(nil, uuidObj);
	CFRelease(uuidObj);
	return [newUUID autorelease];
}

@end
