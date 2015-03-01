//
//  NSFileManager+AuthorizedMove.m
//  hbci
//
//  Created by Stefan Schimanski on 29.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "NSFileManager+AuthorizedMove.h"

#import <Security/Security.h>


static AuthorizationRef authorizationRef = NULL;

@implementation NSFileManager (AuthorizedMove)

- (BOOL)authorizedMovePath:(NSString *)source toPath:(NSString *)destination
{
	OSStatus os = noErr;
	
	if (authorizationRef == NULL) {
		os = AuthorizationCreate(NULL,
					 kAuthorizationEmptyEnvironment,
					 kAuthorizationFlagDefaults,
					 &authorizationRef);
	}
	
	// Make sure we have authorization.
	if (!authorizationRef)
	{
		NSLog(@"Could not get authorization, failing.");
		return NO;
	}
	
	// Set up the arguments.
	char * args[2];
	args[0] = (char *)[[source stringByStandardizingPath] fileSystemRepresentation];
	args[1] = (char *)[[destination stringByStandardizingPath] fileSystemRepresentation];
	args[2] = NULL;
	
	os = AuthorizationExecuteWithPrivileges(authorizationRef, "/bin/mv", 0, args, NULL);
	if (os != noErr 
	    && !(![[NSFileManager defaultManager] fileExistsAtPath:source]
		 && [[NSFileManager defaultManager] fileExistsAtPath:destination])) {
		NSLog(@"Could not move file.");
		return NO;
	}
	
	return YES;
}

@end
