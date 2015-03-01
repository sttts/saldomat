// Copyright 2001-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWAuthorizationCredential.h"

#import <Foundation/Foundation.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/OWAuthorizationCredential.m 68913 2005-10-03 19:36:19Z kc $")

@interface OWAuthorizationCredential (Private)
@end

@implementation OWAuthorizationCredential

NSTimeInterval OWAuthDistantPast;

+ (void)initialize
{
    OWAuthDistantPast = [[NSDate distantPast] timeIntervalSinceReferenceDate];
}

+ (OWAuthorizationCredential *)nullCredential; // a placeholder for no credential at all
{
    static OWAuthorizationCredential *nullCredential = nil;
    
    if (!nullCredential)
        nullCredential = [[self alloc] init];
    return nullCredential;
}

- initForRequest:(OWAuthorizationRequest *)req realm:(NSString *)authRealm
{
    self = [super init];
    if (!self)
        return nil;
    
    if (!req) {
        [super dealloc];
        return nil;
    }
    
    realm = [authRealm retain];
    port = 0;
    hostname = [[req hostname] retain];
    port = [req port];
    type = [req type];
    lastSucceededTimeInterval = OWAuthDistantPast;
    lastFailedTimeInterval = OWAuthDistantPast;
    
    return self;
}

- initAsCopyOf:otherInstance
{
    OWAuthorizationCredential *other;
    
    if (!(self = [super init]))
        return nil;
        
    if (![otherInstance isKindOfClass:[OWAuthorizationCredential class]]) {
        [super dealloc];
        return nil;
    }
    
    other = otherInstance;
    realm = [other->realm copy];
    port = other->port;
    hostname = [other->hostname copy];
    type = other->type;
    
    lastSucceededTimeInterval = OWAuthDistantPast;
    lastFailedTimeInterval = OWAuthDistantPast;
    
    return self;
}

- (void)dealloc
{
    [hostname release];
    [realm release];
    [keychainTag release];
    [super dealloc];
}

- (NSString *)hostname
{
    return hostname;
}

- (enum OWAuthorizationType)type
{
    return type;
}

- (unsigned int)port
{
    return port;
}

- (NSString *)realm
{
    return realm;
}

// Default implementation
- (NSString *)httpHeaderStringForProcessor:(OWHTTPProcessor *)aProcessor
{
    return nil;
}

- (BOOL)appliesToHTTPChallenge:(NSDictionary *)challenge
{
    return NO;
}

- keychainTag
{
    return keychainTag;
}

- (void)setKeychainTag:newTag
{
    [keychainTag release];  // shouldn't ever change, but we might as well be safe
    keychainTag = [newTag retain];
}

- (int)compareToNewCredential:(OWAuthorizationCredential *)other
{
    if (![other isKindOfClass:[self class]])
        return OWCredentialIsUnrelated;
    
    if ([other type] != type)
        return OWCredentialIsUnrelated;
    
    if (![hostname isEqual:(other->hostname)])
        return OWCredentialIsUnrelated;
    
    if (realm) {
        if (![other realm] || ![[other realm] isEqual:realm])
            return OWCredentialIsUnrelated;
    } else {
        if ([other realm])
            return OWCredentialIsUnrelated;
    }
    
    // TODO: handle default port numbers correctly
    if (port != other->port)
        return OWCredentialIsUnrelated;
    
    return OWCredentialIsEquivalent;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary = [super debugDictionary];
    NSString *typeStr;

    [debugDictionary setObject:hostname forKey:@"hostname"];
    switch(type) {
        case OWAuth_HTTP: typeStr = @"HTTP"; break;
        case OWAuth_HTTP_Proxy: typeStr = @"HTTP_Proxy"; break;
        case OWAuth_FTP: typeStr = @"FTP"; break;
        case OWAuth_NNTP: typeStr = @"NNTP"; break;
        default: typeStr = nil;
    }
    if (typeStr)
        [debugDictionary setObject:typeStr forKey:@"type"];
    if (port > 0)
        [debugDictionary setObject:[NSNumber numberWithUnsignedInt:port] forKey:@"port"];
    if (realm)
        [debugDictionary setObject:realm forKey:@"realm"];
    if (lastSucceededTimeInterval > OWAuthDistantPast)
        [debugDictionary setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:lastSucceededTimeInterval] forKey:@"lastSucceededTimeInterval"];
    if (lastFailedTimeInterval > OWAuthDistantPast)
        [debugDictionary setObject:[NSDate dateWithTimeIntervalSinceReferenceDate:lastFailedTimeInterval] forKey:@"lastFailedTimeInterval"];
        
    return debugDictionary;
}

- (void)authorizationSucceeded:(BOOL)success response:(OWHeaderDictionary *)response;
{
    // used by subclasses
    // TODO: if we fail, mark ourselves so we aren't used again, or so that we are only used as a last resort. We don't want to remove ourselves from the cache, because we don't want OWAuthReq. to re-request us from the keychain (possibly popping up another dialogue box).
    
    if (success) 
        lastSucceededTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate];
    else
        lastFailedTimeInterval = [[NSDate date] timeIntervalSinceReferenceDate];
}

@end

@implementation OWAuthorizationCredential (Private)
@end
