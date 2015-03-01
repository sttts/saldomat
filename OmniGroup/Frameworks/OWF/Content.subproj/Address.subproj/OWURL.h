// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/Address.subproj/OWURL.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniFoundation/OFObject.h>

@class NSArray, NSString, NSURL;
@class OWContentType, OWNetLocation;

#import <CoreFoundation/CFString.h> // For CFStringEncoding
#import <OmniFoundation/OFSimpleLock.h> // For OFSimpleLockType

@interface OWURL : OFObject <NSCopying>
{
    // Basic attributes
    NSString *scheme;

    // Common scheme attributes
    NSString *netLocation;
    NSString *path;
    NSString *params;
    NSString *query;
    NSString *fragment;

    // Irregular scheme attribute
    NSString *schemeSpecificPart;

    // Derived attributes
    OFSimpleLockType derivedAttributesSimpleLock;
    NSString *_cachedCompositeString;
    NSString *_cachedShortDisplayString;
    OWNetLocation *_cachedParsedNetLocation;
    NSString *_cachedDomain;
    NSString *_cacheKey;
    OWContentType *_contentType;
}

+ (void)readDefaults;

+ (OWURL *)urlWithScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams query:(NSString *)aQuery fragment:(NSString *)aFragment;
+ (OWURL *)urlWithScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams queryDictionary:(NSDictionary *)queryDictionary fragment:(NSString *)aFragment;
+ (OWURL *)urlWithScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;
+ (OWURL *)urlFromString:(NSString *)aString;
+ (OWURL *)urlFromDirtyString:(NSString *)aString;
+ (OWURL *)urlFromFilthyString:(NSString *)aString;

+ (OWURL *)urlFromNSURL:(NSURL *)nsURL;

+ (NSString *)cleanURLString:(NSString *)aString;

+ (OWContentType *)contentTypeForScheme:(NSString *)aScheme;
+ (void)registerSecureScheme:(NSString *)aScheme;

+ (NSArray *)pathComponentsForPath:(NSString *)aPath;
+ (NSString *)lastPathComponentForPath:(NSString *)aPath;
+ (NSString *)stringByDeletingLastPathComponentFromPath:(NSString *)aPath;

+ (unsigned int)minimumDomainComponentsForDomainComponents:(NSArray *)domainComponents;
+ (NSString *)domainForHostname:(NSString *)hostname;

- (NSURL *)NSURL;

- (NSString *)scheme;

// Common scheme attributes
- (NSString *)netLocation;
- (NSString *)path;
- (NSString *)params;
- (NSString *)query;
- (NSString *)fragment;

// Irregular scheme attribute
- (NSString *)schemeSpecificPart;

// Derived attributes
- (NSString *)compositeString;
- (NSString *)cacheKey;
- (NSString *)stringToNetLocation;
- (NSString *)fetchPath;
- (NSString *)proxyFetchPath;
- (NSArray *)pathComponents;
- (NSString *)lastPathComponent;
- (NSString *)stringByDeletingLastPathComponent;
- (OWNetLocation *)parsedNetLocation;
    // Many net locations have the form username:password@hostname:port
- (NSString *)hostname;
- (NSString *)domain;

- (NSString *)shortDisplayString;

- (BOOL)isEqual:(id)anObject;

- (OWContentType *)contentType;
- (BOOL)isSecure;

// Creating related URLs

- (OWURL *)urlFromRelativeString:(NSString *)aString;
- (OWURL *)urlForPath:(NSString *)newPath;
- (OWURL *)urlForQuery:(NSString *)newQuery;
- (OWURL *)urlWithoutFragment;	// N.B.: may return self
- (OWURL *)urlWithFragment:(NSString *)newFragment;
- (OWURL *)urlWithoutUsernamePasswordOrFragment;

// Strips the params, fragment, query and the last path component if the path doesn't end with "/"
- (OWURL *) baseURL;

@end
