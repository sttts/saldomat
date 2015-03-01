// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniNetworking/ONHost.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniBase/OBObject.h>

@class NSArray, NSDate, NSMutableArray;
@class ONHostAddress, ONServiceEntry;

#import <Foundation/NSDate.h> // For NSTimeInterval

@interface ONHost : OBObject
{
    NSString *hostname;
    NSString *canonicalHostname;
    NSArray *addresses;
    NSMutableDictionary *serviceAddresses;
    NSDate *expirationDate;
}


/* Calling this method causes ONHost to track changes to the host's name and domain name (as returned by +domainName and +localHostname). ONHost will register in the calling thread's run loop the first time this method is called. Calling it multiple times has no effect. */
+ (void)listenForNetworkChanges;

/* Returns the local host's domain name. If the domain name is unavailable for some reason, returns the string "local". In some contexts it may be necessary to append a trailing dot to the domain name returned by this method for it to be interpreted correctly by other routines; see RFC1034 [3.1] (page 8). */
+ (NSString *)domainName;

/* Returns the local host's name, if available, or returns "localhost". */
+ (NSString *)localHostname;

+ (ONHost *)hostForHostname:(NSString *)aHostname;
+ (ONHost *)hostForAddress:(ONHostAddress *)anAddress;

+ (NSString *)IDNEncodedHostname:(NSString *)aHostname;
+ (NSString *)IDNDecodedHostname:(NSString *)anIDNHostname;

+ (void)flushCache;
+ (void)setDefaultTimeToLiveTimeInterval:(NSTimeInterval)newValue;

/* Determines whether ONHost tries to look up 'AAAA' records as well as 'A' records. At the moment this has no effect on the actual lookup, but prevents non-IPv4 addresses from being returned by ONHost's -addresses method. */
+ (void)setOnlyResolvesIPv4Addresses:(BOOL)v4Only;
+ (BOOL)onlyResolvesIPv4Addresses;
+ (void)setResolverType:(NSString *)resolverType;  // Kludge to allow selecting different resolver APIs.

- (NSString *)hostname;
- (NSArray *)addresses;
- (NSString *)canonicalHostname;
- (NSString *)IDNEncodedHostname;
- (NSString *)domainName;

- (BOOL)isLocalHost;

- (void)flushFromHostCache;

/* Returns an array of ONPortAddresses corresponding to a given service of the receiver's host. Somewhat buggy at the moment. */
- (NSArray *)portAddressesForService:(ONServiceEntry *)servEntry;

@end

#import "FrameworkDefines.h"

// Exceptions which may be raised by this class
OmniNetworking_EXTERN NSString *ONHostNotFoundExceptionName;
OmniNetworking_EXTERN NSString *ONHostNameLookupErrorExceptionName;
OmniNetworking_EXTERN NSString *ONHostHasNoAddressesExceptionName;
OmniNetworking_EXTERN NSString *ONGetHostByNameNotFoundExceptionName;
