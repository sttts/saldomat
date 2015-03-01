// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniNetworking/ONHost-InternalAPI.h 68913 2005-10-03 19:36:19Z kc $

#import "ONHost.h"

// If none of the options above are defined, ONHost will use the ONGetHostByName tool to perform hostname lookups in a separate task.

@interface ONHost (ONInternalAPI)
+ (void)_raiseExceptionForHostErrorNumber:(int)hostErrorNumber hostname:(NSString *)hostname;
+ (NSException *)_exceptionForExtendedHostErrorNumber:(int)eaiError hostname:(NSString *)name;

- _initWithHostname:(NSString *)aHostname knownAddress:(ONHostAddress *)anAddress;

- (BOOL)isExpired;

- (void)_lookupHostInfoByPipe;
- (void)_lookupHostInfoUsingGetaddrinfo;

@end
