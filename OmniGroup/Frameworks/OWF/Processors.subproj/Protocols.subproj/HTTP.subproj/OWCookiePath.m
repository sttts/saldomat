// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWCookiePath.h"

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "OWCookie.h"
#import "OWCookieDomain.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/HTTP.subproj/OWCookiePath.m 68913 2005-10-03 19:36:19Z kc $")


static NSLock *pathLock = nil;

@implementation OWCookiePath

+ (void)initialize;
{
    OBINITIALIZE;        
    pathLock = [[NSLock alloc] init];
}

- initWithPath:(NSString *)aPath;
{
    _path = [aPath copy];
    _cookies = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc;
{
    [_path release];
    [super dealloc];
}

- (NSString *)path;
{
    return _path;
}

- (BOOL)appliesToPath:(NSString *)aPath;
{
    BOOL applies;

    applies = [aPath hasPrefix:_path];
    
    if (OWCookiesDebug)
        NSLog(@"COOKIES: Path %@ applies to path %@ --> %d", _path, aPath, applies);

    return applies;
}

- (void)addCookie:(OWCookie *)cookie;
{
    [self addCookie:cookie andNotify:YES];
}

- (void)removeCookie:(OWCookie *)cookie;
{
    unsigned int index;
    
    [pathLock lock];
    index = [_cookies indexOfObjectIdenticalTo:cookie];
    if (index != NSNotFound)
        [_cookies removeObjectAtIndex:index];
    [pathLock unlock];
    
    if (index != NSNotFound)
        [OWCookieDomain didChange];
}

- (NSArray *)cookies;
{
    NSArray *cookies;
    
    [pathLock lock];
    cookies = [[NSArray alloc] initWithArray:_cookies];
    [pathLock unlock];
    
    return [cookies autorelease];
}

- (OWCookie *)cookieNamed:(NSString *)name;
{
    unsigned int cookieIndex;
    OWCookie *cookie = nil;
    BOOL found = NO;
    
    [pathLock lock];

    cookieIndex = [_cookies count];
    while (cookieIndex--) {
        cookie = [_cookies objectAtIndex:cookieIndex];
        if ([[cookie name] isEqualToString:name]) {
            [[cookie retain] autorelease];
            found = YES;
            break;
        }
    }

    [pathLock unlock];
    
    if (found)
        return cookie;
    return nil;
}

// For use by OWCookieDomain
- (void)addCookie:(OWCookie *)cookie andNotify:(BOOL)shouldNotify;
{
    unsigned int cookieIndex;
    OWCookie *oldCookie;
    BOOL needsAdding = YES;
    NSString *name;
    
	// We block cookies here instead of marking them rejected in OWCookie domain because we don't want users to have to manually clear out their rejected cookies (or Quit/Restart OmniWeb) -- The whole point of Private Browsing is to prevent that!
	if ([[OFPreference preferenceForKey:@"OWPrivateBrowsingEnabled"] boolValue]) {
		[[cookie retain] autorelease]; // In case someone adds the cookie with the expectation that it will be retained
		return;
	}
		
    name = [cookie name];
    
    [pathLock lock];

    // If we have a cookie with the same name, replace it.
    cookieIndex = [_cookies count];
    while (cookieIndex--) {
        oldCookie = [_cookies objectAtIndex:cookieIndex];
        
        // Don't remove and readd the cookie if it is already there
        // since it might get deallocated.
        if (oldCookie == cookie) {
            needsAdding = NO;
            break;
        }

        if ([[oldCookie name] isEqualToString:name]) {
            // Replace the old cookie value but preserve the current status
            // if it is more permissive than the new status

            OWCookieStatus oldStatus = [oldCookie status];

            // If the new cookie has no expirationDate, only promote it to
            // saved if the old cookie also had no expiration date.
            if ([cookie expirationDate] == nil && oldStatus == OWCookieSavedStatus && [oldCookie expirationDate] != nil)
                oldStatus = OWCookieTemporaryStatus;
            
            if ([cookie status] > oldStatus) {
                [cookie setStatus:oldStatus andNotify:NO];
                // When preserving a more permissive old status, also preserve
                // the site that determined that status
                [cookie setSite:[oldCookie site]];
            }
            [_cookies replaceObjectAtIndex:cookieIndex withObject:cookie];
            needsAdding = NO;
            break;
        }
    }

    if (needsAdding) {
        [_cookies addObject:cookie];
    }
    
    [pathLock unlock];
    
    if (shouldNotify) {
        [OWCookieDomain didChange];
        // Should become obsolete with new cache arc validation stuff
#warning deal with cache validation of cookie state
//        [OWContentCache flushCachedContentMatchingCookie:cookie];
    }
}

- (void)addNonExpiredCookiesToArray:(NSMutableArray *)array usageIsSecure:(BOOL)secure includeRejected:(BOOL)includeRejected;
{
    unsigned int cookieIndex, cookieCount;
    OWCookie *cookie;
    
    [pathLock lock];
    
    cookieCount = [_cookies count];
    for (cookieIndex = 0; cookieIndex < cookieCount; cookieIndex++) {
        cookie = [_cookies objectAtIndex:cookieIndex];
        if ([cookie isExpired])
            continue;
        if ([cookie secure] && !secure)
            continue;
        if (!includeRejected && [cookie status] == OWCookieRejectedStatus)
            continue;
        [array addObject:cookie];
    }
    
    [pathLock unlock];
}

- (void)addCookiesToSaveToArray:(NSMutableArray *)array;
{
    unsigned int cookieIndex, cookieCount;
    OWCookie *cookie;

    [pathLock lock];

    cookieCount = [_cookies count];
    for (cookieIndex = 0; cookieIndex < cookieCount; cookieIndex++) {
        cookie = [_cookies objectAtIndex:cookieIndex];
        if ([cookie isExpired])
            continue;
        if ([cookie status] != OWCookieSavedStatus)
            continue;
        [array addObject:cookie];
    }

    [pathLock unlock];
}

- (NSComparisonResult)compare:(id)otherObject;
{
    if (![otherObject isKindOfClass:isa])
        return NSOrderedAscending;
    
    return [_path compare:[(OWCookiePath *)otherObject path]];
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict;
    
    dict = [super debugDictionary];
    [dict setObject:_path forKey:@"path"];
    [dict setObject:_cookies forKey:@"cookies"];
    
    return dict;
}

@end

