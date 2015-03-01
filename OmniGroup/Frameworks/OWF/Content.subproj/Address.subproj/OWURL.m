// Copyright 1997-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWURL.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniNetworking/ONHostAddress.h>
#import <OmniNetworking/ONHost.h>
#import <ctype.h>

#import "OWContentType.h"
#import "OWNetLocation.h"
#import "OWHTMLToSGMLObjects.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/Address.subproj/OWURL.m 79079 2006-09-07 22:35:32Z kc $")

@interface OWURL (Private)
+ (void)controllerDidInitialize:(OFController *)controller;

+ (OWURL *)urlWithLowercaseScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams query:(NSString *)aQuery fragment:(NSString *)aFragment;
+ (OWURL *)urlWithLowercaseScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;

- _initWithLowercaseScheme:(NSString *)aScheme;
- initWithLowercaseScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams query:(NSString *)aQuery fragment:(NSString *)aFragment;
- initWithLowercaseScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;
- initWithScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;

- (OWURL *)fakeRootURL;

- (void)_locked_parseNetLocation;
- (NSString *)_newURLStringWithEncodedHostname:(BOOL)shouldEncode;

@end

@interface NSURL (OWExtensions)
- (NSString *)_ow_originalDataAsString;
@end

@implementation OWURL

static NSArray *fakeRootURLs = nil;
static NSLock *fakeRootURLsLock;
static OFLowercaseStringCache lowercaseSchemeCache;
static NSArray *shortTopLevelDomains = nil;

// These are carefully derived from RFC1808.
// (http://www.w3.org/hypertext/WWW/Addressing/rfc1808.txt)

static OFCharacterSet *SchemeDelimiterOFCharacterSet;
static OFCharacterSet *NetLocationDelimiterOFCharacterSet;
static OFCharacterSet *PathDelimiterOFCharacterSet;
static OFCharacterSet *ParamDelimiterOFCharacterSet;
static OFCharacterSet *QueryDelimiterOFCharacterSet;
static OFCharacterSet *FragmentDelimiterOFCharacterSet;
static OFCharacterSet *SchemeSpecificPartDelimiterOFCharacterSet;
static OFCharacterSet *NonWhitespaceOFCharacterSet;
static OFCharacterSet *TabsAndReturnsOFCharacterSet;
static NSMutableDictionary *ContentTypeDictionary;
static OFSimpleLockType ContentTypeDictionarySimpleLock;
static NSMutableSet *SecureSchemes;
static OFSimpleLockType SecureSchemesSimpleLock;
static BOOL NetscapeCompatibleRelativeAddresses;

static OFRegularExpression *backslashThenWhitespaceRegularExpression;
static OFRegularExpression *newlinesAndSurroundingWhitespaceRegularExpression;

+ (void)initialize;
{
    OFCharacterSet *AlphaSet, *DigitSet, *ReservedSet;
    OFCharacterSet *UnreservedSet, *UCharSet, *PCharSet;
    OFCharacterSet *SchemeSet, *NetLocationSet, *PathSet;
    OFCharacterSet *ParamSet, *QuerySet, *FragmentSet;
    OFCharacterSet *SchemeSpecificPartSet;

    OBINITIALIZE;

    OFLowercaseStringCacheInit(&lowercaseSchemeCache);

    AlphaSet = [[[OFCharacterSet alloc] initWithCharacterSet:[NSCharacterSet letterCharacterSet]] autorelease];
    DigitSet = [[[OFCharacterSet alloc] initWithString:@"0123456789"] autorelease];
    ReservedSet = [[[OFCharacterSet alloc] initWithString:@";/?:@&="] autorelease];

    // This is a bit richer than the standard allows
    UnreservedSet = [[OFCharacterSet alloc] initWithOFCharacterSet:ReservedSet];
    [UnreservedSet invert];
    [UnreservedSet removeCharactersInString:@"%#"];

    UCharSet = [[OFCharacterSet alloc] init];
    [UCharSet addCharactersFromOFCharacterSet:UnreservedSet];
    [UCharSet addCharactersInString:@"%"]; // escapes

    PCharSet = [[OFCharacterSet alloc] init];
    [PCharSet addCharactersFromOFCharacterSet:UCharSet];
    [PCharSet addCharactersInString:@":@&="];

    SchemeSet = [[OFCharacterSet alloc] init];
    [SchemeSet addCharactersFromOFCharacterSet:AlphaSet];
    [SchemeSet addCharactersFromOFCharacterSet:DigitSet];
    [SchemeSet addCharactersInString:@"+-."];

    NetLocationSet = [[OFCharacterSet alloc] init];
    [NetLocationSet addCharactersFromOFCharacterSet:PCharSet];
    [NetLocationSet addCharactersInString:@";?"];
    [NetLocationSet removeCharactersInString:@"\\"]; // stupid backslash paths found on some sites
    [NetLocationSet removeCharactersInString:@"?"]; // Bug #6399: Support invalid URLs that include a question mark "?" immediately following the domain

    PathSet = [[OFCharacterSet alloc] init];
    [PathSet addCharactersFromOFCharacterSet:PCharSet];
    [PathSet addCharactersInString:@"/"];

    ParamSet = [[OFCharacterSet alloc] init];
    [ParamSet addCharactersFromOFCharacterSet:PCharSet];
    [ParamSet addCharactersInString:@"/"];
    [ParamSet addCharactersInString:@";"];

    QuerySet = [[OFCharacterSet alloc] init];
    [QuerySet addCharactersFromOFCharacterSet:UCharSet];
    [QuerySet addCharactersFromOFCharacterSet:ReservedSet];

#ifdef PEDANTIC_URL_PARSING
    FragmentSet = [QuerySet retain];
#else
    // The spec doesn't include '#' in the fragment set, but this change is required to parse <http://www.nick.com/flash_inits/ainit_container.swf?movie0=/flash_inits/multimedia/logo_atom.swf&movie0_url=#&clicked0=#&movie1=/flash_inits/multimedia/kca2004.swf&movie1_url=/all_nick/specials/kca_2004/&clicked1=/flash_inits/multimedia/click_all_nick.swf&movie2=/flash_inits/multimedia/e_collect2004_fop.swf&movie2_url=/home/mynick/&clicked2=/flash_inits/multimedia/click_games.swf&movie3=/flash_inits/multimedia/sb_bowling.swf&movie3_url=/games/game.jhtml?game-name=sb_bowling&clicked3=/flash_inits/multimedia/click_games.swf&movie4=/flash_inits/multimedia/fop_superwishgame.swf&movie4_url=/games/data/fairlyoddparents/fop_hero/playGame.jhtml&clicked4=/flash_inits/multimedia/click_games.swf&movie5=/flash_inits/multimedia/amanda_games.swf&movie5_url=/amandaplease/archive/index.jhtml&clicked5=/flash_inits/multimedia/click_all_nick.swf&path=&section=home&redval=205&greenval=255&blueval=0&isLoaded=1&>
    FragmentSet = [[OFCharacterSet alloc] initWithOFCharacterSet:QuerySet];
    [FragmentSet addCharactersInString:@"#"];
#endif
    SchemeSpecificPartSet = [QuerySet retain];

    // Now, get the OFCharacterSet *representations of all those character sets
#define delimiterBitmapForSet(ofSet, set) { ofSet = [[OFCharacterSet alloc] initWithOFCharacterSet:set]; [ofSet invert]; }
    delimiterBitmapForSet(SchemeDelimiterOFCharacterSet, SchemeSet);
    delimiterBitmapForSet(NetLocationDelimiterOFCharacterSet, NetLocationSet);
    delimiterBitmapForSet(PathDelimiterOFCharacterSet, PathSet);
    delimiterBitmapForSet(ParamDelimiterOFCharacterSet, ParamSet);
    delimiterBitmapForSet(QueryDelimiterOFCharacterSet, QuerySet);
    delimiterBitmapForSet(FragmentDelimiterOFCharacterSet, FragmentSet);
    delimiterBitmapForSet(SchemeSpecificPartDelimiterOFCharacterSet, SchemeSpecificPartSet);
#undef delimiterBitmapForSet
    NonWhitespaceOFCharacterSet = [[OFCharacterSet alloc] initWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [NonWhitespaceOFCharacterSet invert];

    [UnreservedSet release];
    [UCharSet release];
    [PCharSet release];
    [SchemeSet release];
    [NetLocationSet release];
    [PathSet release];
    [ParamSet release];
    [QuerySet release];
    [FragmentSet release];
    [SchemeSpecificPartSet release];

    TabsAndReturnsOFCharacterSet = [[OFCharacterSet alloc] initWithString:@"\t\r\n"];

    OFSimpleLockInit(&ContentTypeDictionarySimpleLock);
    ContentTypeDictionary = [[NSMutableDictionary alloc] init];
    OFSimpleLockInit(&SecureSchemesSimpleLock);
    SecureSchemes = [[NSMutableSet alloc] init];

    fakeRootURLsLock = [[NSLock alloc] init];
    
    backslashThenWhitespaceRegularExpression = [[OFRegularExpression alloc] initWithString:@"\\\\[ \n\r\t]+"];
    newlinesAndSurroundingWhitespaceRegularExpression = [[OFRegularExpression alloc] initWithString:@"[ \t]*[\n\r][ \t]*"];
}

+ (void)didLoad;
{
    [[OFController sharedController] addObserver:self];
}

+ (void)readDefaults;
{
    NSUserDefaults *userDefaults;
    NSArray *fakeRootURLStrings;
    unsigned int fakeRootCount;

    userDefaults = [NSUserDefaults standardUserDefaults];
    [shortTopLevelDomains release];
    shortTopLevelDomains = [[userDefaults arrayForKey:@"OWShortTopLevelDomains"] retain];
    NetscapeCompatibleRelativeAddresses = [userDefaults boolForKey:@"OWURLNetscapeCompatibleRelativeAddresses"];

    // Don't override the URL encoding --- the draft standard for internationalized URLs specifies the use of UTF-8. (Previously we used the user's default encoding as a way to guess what their favorite server might be expecting, but I'm not sure that ever helped anyone.)
#if 0
    // OmniFoundation doesn't have its own defaults, so we'll register this here
    newURLEncoding = [OWDataStreamCharacterProcessor stringEncodingForDefault:[userDefaults stringForKey:@"OWOutgoingStringEncoding"]];
    if (newURLEncoding != kCFStringEncodingInvalidId)
        [NSString setURLEncoding:newURLEncoding];
    else
        [NSString setURLEncoding:[OWDataStreamCharacterProcessor defaultStringEncoding]];
#endif

    fakeRootURLStrings = [userDefaults arrayForKey:@"OWURLFakeRootURLs"];
    fakeRootCount = [fakeRootURLStrings count];
    if (fakeRootCount > 0) {
        unsigned int fakeRootIndex;
        NSMutableArray *newFakeRootURLs;

        newFakeRootURLs = [[NSMutableArray alloc] initWithCapacity:fakeRootCount];
        for (fakeRootIndex = 0; fakeRootIndex < fakeRootCount; fakeRootIndex++) {
            [newFakeRootURLs addObject:[self urlFromDirtyString:[fakeRootURLStrings objectAtIndex:fakeRootIndex]]];
        }
        [fakeRootURLsLock lock];
        [fakeRootURLs release];
        fakeRootURLs = [[NSArray alloc] initWithArray:newFakeRootURLs];
        [fakeRootURLsLock unlock];
        [newFakeRootURLs release];
    } else {
        [fakeRootURLsLock lock];
        [fakeRootURLs release];
        fakeRootURLs = nil;
        [fakeRootURLsLock unlock];
    }
}


+ (OWURL *)urlWithScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams query:(NSString *)aQuery fragment:(NSString *)aFragment;
{
    return [self urlWithLowercaseScheme:OFLowercaseStringCacheGet(&lowercaseSchemeCache, aScheme) netLocation:aNetLocation path:aPath params:someParams query:aQuery fragment:aFragment];
}

+ (OWURL *)urlWithScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams queryDictionary:(NSDictionary *)queryDictionary fragment:(NSString *)aFragment;
{
    NSMutableString *encodedQuery;
    NSEnumerator *enumerator;
    NSString *queryKey;
    BOOL firstItem = YES;

    encodedQuery = [NSMutableString string];
    enumerator = [[[queryDictionary allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
    while ((queryKey = [enumerator nextObject])) {
        NSString *queryValue;

        queryValue = [queryDictionary objectForKey:queryKey];
        if (queryValue != nil) {
            if (firstItem == YES)
                firstItem = NO;
            else
                [encodedQuery appendString:@"&"];

            [encodedQuery appendString:[NSString encodeURLString:queryKey encoding:kCFStringEncodingUTF8 asQuery:NO leaveSlashes:NO leaveColons:NO]];
            [encodedQuery appendString:@"="];
            [encodedQuery appendString:[NSString encodeURLString:queryValue encoding:kCFStringEncodingUTF8 asQuery:NO leaveSlashes:NO leaveColons:NO]];
        }
    }

    return [self urlWithScheme:aScheme netLocation:aNetLocation path:aPath params:someParams query:[NSString stringWithString:encodedQuery] fragment:aFragment];
}

+ (OWURL *)urlWithScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;
{
    return [self urlWithLowercaseScheme:OFLowercaseStringCacheGet(&lowercaseSchemeCache, aScheme) schemeSpecificPart:aSchemeSpecificPart fragment:aFragment];
}

+ (OWURL *)urlFromString:(NSString *)aString;
{
    NSString *aScheme, *aNetLocation;
    NSString *aPath, *someParams;
    NSString *aQuery, *aFragment;
    NSString *aSchemeSpecificPart;
    OFStringScanner *scanner;

    if (aString == nil || [aString length] == 0)
	return nil;

    scanner = [[OFStringScanner alloc] initWithString:aString];
    scannerScanUpToCharacterInOFCharacterSet(scanner, NonWhitespaceOFCharacterSet);
    aScheme = [scanner readFullTokenWithDelimiterOFCharacterSet:SchemeDelimiterOFCharacterSet forceLowercase:YES];
    if (aScheme == nil || [aScheme length] == 0 || scannerReadCharacter(scanner) != ':') {
        [scanner release];
        return nil;
    }
    if (scannerPeekCharacter(scanner) == '/') {
        // Scan net location or path
        BOOL pathPresent;

        scannerSkipPeekedCharacter(scanner);
        if (scannerPeekCharacter(scanner) == '/') {
            // Scan net location
            scannerSkipPeekedCharacter(scanner);
            aNetLocation = [scanner readFullTokenWithDelimiterOFCharacterSet:NetLocationDelimiterOFCharacterSet forceLowercase:NO];
            if (aNetLocation && [aNetLocation length] == 0)
                aNetLocation = @"localhost";
            pathPresent = scannerPeekCharacter(scanner) == '/' || scannerPeekCharacter(scanner) == '\\'; // some stupid sites use backslash as path delimeters
            if (pathPresent) {
                // To be consistent with the non-netLocation case, skip the '/' here, too
                scannerSkipPeekedCharacter(scanner);
            }
        } else {
            aNetLocation = nil;
            pathPresent = YES;
        }
        if (pathPresent) {
            // Scan path
            aPath = [scanner readFullTokenWithDelimiterOFCharacterSet:PathDelimiterOFCharacterSet forceLowercase:NO];
        } else {
            aPath = nil;
        }
    } else {
        // No net location
        aNetLocation = nil;
        if (scannerPeekCharacter(scanner) == '~') {
            // Scan path that starts with '~'
            //
            // I'm not sure this is actually a path URL, maybe URLs with this
            // form should just drop through to schemeSpecificParams
            aPath = [scanner readFullTokenWithDelimiterOFCharacterSet:PathDelimiterOFCharacterSet forceLowercase:NO];
        } else {
            // No path
            aPath = nil;
        }
    }

    if (scannerPeekCharacter(scanner) == ';') {
        // Scan params
        scannerSkipPeekedCharacter(scanner);
        someParams = [scanner readFullTokenWithDelimiterOFCharacterSet:ParamDelimiterOFCharacterSet forceLowercase:NO];
        if (someParams == nil)
            someParams = @"";
    } else {
        someParams = nil;
    }

    if (scannerPeekCharacter(scanner) == '?') {
        // Scan query
        scannerSkipPeekedCharacter(scanner);
        aQuery = [scanner readFullTokenWithDelimiterOFCharacterSet:QueryDelimiterOFCharacterSet forceLowercase:NO];
        if (aQuery == nil)
            aQuery = @"";
    } else {
        aQuery = nil;
    }

    if (aNetLocation == nil && aPath == nil && someParams == nil && aQuery == nil) {
        // Scan scheme-specific part
        aSchemeSpecificPart = [scanner readFullTokenWithDelimiterOFCharacterSet:SchemeSpecificPartDelimiterOFCharacterSet forceLowercase:NO];
    } else {
        aSchemeSpecificPart = nil;
    }

    if (scannerPeekCharacter(scanner) == '#') {
        // Scan fragment
        scannerSkipPeekedCharacter(scanner);
        aFragment = [scanner readFullTokenWithDelimiterOFCharacterSet:FragmentDelimiterOFCharacterSet forceLowercase:NO];
        if (!aFragment)
            aFragment = @"";
    } else {
        aFragment = nil;
    }

    [scanner release];

    if (aSchemeSpecificPart != nil)
	return [self urlWithLowercaseScheme:aScheme schemeSpecificPart:aSchemeSpecificPart fragment:aFragment];
    return [self urlWithLowercaseScheme:aScheme netLocation:aNetLocation path:aPath params:someParams query:aQuery fragment:aFragment];
}

+ (OWURL *)urlFromDirtyString:(NSString *)aString;
{
    return [self urlFromString:[self cleanURLString:aString]];
}

+ (OWURL *)urlFromFilthyString:(NSString *)aString;
{
    aString = [aString stringByRemovingRegularExpression:backslashThenWhitespaceRegularExpression];
    
    return [self urlFromString:[self cleanURLString:aString]];
}

+ (OWURL *)urlFromNSURL:(NSURL *)nsURL;
{
    if (nsURL == nil)
        return nil;

    // TODO: Make this faster
    return [self urlFromDirtyString:[nsURL _ow_originalDataAsString]];
}

+ (NSString *)cleanURLString:(NSString *)aString;
{
    if (aString == nil || [aString length] == 0)
	return nil;

    aString = [[aString stringByRemovingRegularExpression:newlinesAndSurroundingWhitespaceRegularExpression] stringByRemovingSurroundingWhitespace];
    if ([aString hasPrefix:@"<"]) {
	aString = [aString substringFromIndex:1];
        if ([aString hasSuffix:@">"])
            aString = [aString substringToIndex:[aString length] - 1];
        if ([aString hasPrefix:@"URL:"])
            aString = [aString substringFromIndex:4];
    }
    return aString;
}

// Backwards compatibility methods -- this stuff is in NSString now
+ (void)setURLEncoding:(CFStringEncoding)newURLEncoding;
{
    [NSString setURLEncoding: newURLEncoding];
}

+ (CFStringEncoding)urlEncoding
{
    return [NSString urlEncoding];
}

+ (NSString *)decodeURLString:(NSString *)encodedString encoding:(CFStringEncoding)thisUrlEncoding;
{
    return [NSString decodeURLString:encodedString encoding:thisUrlEncoding];
}

+ (NSString *)decodeURLString:(NSString *)encodedString;
{
    return [NSString decodeURLString:encodedString encoding:[NSString urlEncoding]];
}

+ (NSString *)encodeURLString:(NSString *)unencodedString asQuery:(BOOL)asQuery leaveSlashes:(BOOL)leaveSlashes leaveColons:(BOOL)leaveColons;
{
    return [NSString encodeURLString:unencodedString encoding:[NSString urlEncoding] asQuery:asQuery leaveSlashes:leaveSlashes leaveColons:leaveColons];
}

+ (NSString *)encodeURLString:(NSString *)unencodedString encoding:(CFStringEncoding)thisUrlEncoding asQuery:(BOOL)asQuery leaveSlashes:(BOOL)leaveSlashes leaveColons:(BOOL)leaveColons;
{
    return [NSString encodeURLString:unencodedString encoding:thisUrlEncoding asQuery:asQuery leaveSlashes:leaveSlashes leaveColons:leaveColons];
}

//

+ (OWContentType *)contentTypeForScheme:(NSString *)aScheme;
{
    OWContentType *aContentType;

    OFSimpleLock(&ContentTypeDictionarySimpleLock);
    aContentType = [ContentTypeDictionary objectForKey:aScheme];
    if (aContentType == nil) {
	aContentType = [OWContentType contentTypeForString:[@"url/" stringByAppendingString:aScheme]];
	[ContentTypeDictionary setObject:aContentType forKey:aScheme];
    }
    OFSimpleUnlock(&ContentTypeDictionarySimpleLock);
    return aContentType;
}

+ (void)registerSecureScheme:(NSString *)aScheme;
{
    OFSimpleLock(&SecureSchemesSimpleLock);
    [SecureSchemes addObject:aScheme];
    OFSimpleUnlock(&SecureSchemesSimpleLock);
}

+ (NSArray *)pathComponentsForPath:(NSString *)aPath;
{
    if (aPath == nil)
        return nil;

    return [aPath componentsSeparatedByString:@"/"];
}

+ (NSString *)lastPathComponentForPath:(NSString *)aPath;
{
    NSRange lastSlashRange;
    unsigned int originalLength, lengthMinusTrailingSlash;
    
    if (aPath == nil)
        return nil;

    originalLength = [aPath length];

    // If the last character is a slash, ignore it.
    if (originalLength > 0 && [aPath characterAtIndex:originalLength - 1] == '/')
        lengthMinusTrailingSlash = originalLength - 1;
    else
        lengthMinusTrailingSlash = originalLength;

    // If the path (minus any trailing slash) is empty, return an empty string
    if (lengthMinusTrailingSlash == 0)
        return @"";

    // Find the last slash in the path
    lastSlashRange = [aPath rangeOfString:@"/" options:NSLiteralSearch | NSBackwardsSearch range:NSMakeRange(0, lengthMinusTrailingSlash - 1)];

    // If there is none, return the existing path (minus trailing slash).
    if (lastSlashRange.length == 0)
        return originalLength == lengthMinusTrailingSlash ? aPath : [aPath substringToIndex:lengthMinusTrailingSlash];

    // Return the substring between the last slash and the end of the string (ignoring any trailing slash)
    return [aPath substringWithRange:NSMakeRange(NSMaxRange(lastSlashRange), lengthMinusTrailingSlash - NSMaxRange(lastSlashRange))];
}

+ (NSString *)stringByDeletingLastPathComponentFromPath:(NSString *)aPath;
{
    NSRange lastSlashRange;

    if (aPath == nil)
        return nil;

    lastSlashRange = [aPath rangeOfString:@"/" options:NSLiteralSearch | NSBackwardsSearch];
    if (lastSlashRange.length == 0)
        return @"";
    if (lastSlashRange.location == 0 && [aPath length] > 1)
        return @"/";
    return [aPath substringToIndex:lastSlashRange.location];
}

+ (unsigned int)minimumDomainComponentsForDomainComponents:(NSArray *)domainComponents;
{
    unsigned int componentCount = [domainComponents count];

    if (componentCount < 2)
        return componentCount;

    NSString *lastComponent = [domainComponents objectAtIndex:componentCount - 1];
    if ([shortTopLevelDomains containsObject:lastComponent])
        return 2; // wherever.com

    if ([lastComponent length] == 2) { // Country code domain component, e.g. ".uk"
        NSString *penultimateComponent = [domainComponents objectAtIndex:componentCount - 2];

        if ([penultimateComponent length] == 2)
            return 3; // wherever.co.uk
        if ([shortTopLevelDomains containsObject:penultimateComponent])
            return 3; // wherever.com.au
    }

    return 2; // wherever.uk
}

+ (NSString *)domainForHostname:(NSString *)hostname;
{
    NSString *domain;
    NSArray *domainComponents;
    unsigned int domainComponentCount;
    unsigned int minimumDomainComponents;
    ONHostAddress *numericAddress;

    if (hostname == nil)
        return nil;
    domain = hostname;

    // 198.151.161.1's domain is 198.151.161.1, not 151.161.1
    numericAddress = [ONHostAddress hostAddressWithNumericString:hostname];
    if (numericAddress != nil)
        return [numericAddress stringValue];

    // Otherwise, return the last few components of the domain name
    domainComponents = [domain componentsSeparatedByString:@"."];
    domainComponentCount = [domainComponents count];
    minimumDomainComponents = [OWURL minimumDomainComponentsForDomainComponents:domainComponents];
    if (domainComponentCount > minimumDomainComponents)
        domain = [[domainComponents subarrayWithRange:NSMakeRange(domainComponentCount - minimumDomainComponents, minimumDomainComponents)] componentsJoinedByString:@"."];
    return domain;
}

- (void)dealloc;
{
    [scheme release];
    [netLocation release];
    [path release];
    [params release];
    [query release];
    [fragment release];
    [schemeSpecificPart release];
    OFSimpleLockFree(&derivedAttributesSimpleLock);
    [_cachedCompositeString release];
    [_cachedShortDisplayString release];
    [_cachedParsedNetLocation release];
    [_cachedDomain release];
    [_cacheKey release];
    [super dealloc];
}

- (NSURL *)NSURL;
{
    NSMutableString *compositeString = (NSMutableString *)[self _newURLStringWithEncodedHostname:YES];
    NSURL *url = (NSURL *)CFURLCreateWithString(NULL, (CFStringRef)compositeString, NULL);
    if(url) {
    [compositeString release];
        return [url autorelease];
    } else {
        
        //fix my %'s here
        NSCharacterSet *hexDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
        NSRange percentRange = [compositeString rangeOfString:@"%" options:NSLiteralSearch];
        unsigned int stringLength = [compositeString length];

        while (percentRange.location != NSNotFound) {
            unsigned int lastPosition = NSMaxRange(percentRange);
            if (stringLength < lastPosition + 2 || ![hexDigits characterIsMember:[compositeString characterAtIndex:lastPosition]] || ![hexDigits characterIsMember:[compositeString characterAtIndex:lastPosition + 1]]) { 
                // fix bad %
                [compositeString insertString:@"25" atIndex:lastPosition];
                stringLength = [compositeString length];
                lastPosition += 2;
            }
            percentRange = [compositeString rangeOfString:@"%" options:NSLiteralSearch range:NSMakeRange(lastPosition, stringLength-lastPosition)];
        }
        
        //escape any other characters that ought to be escaped
        CFStringRef percentEscapedString = CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)compositeString, CFSTR("%"), NULL, kCFStringEncodingUTF8);
        NSURL *url = (NSURL *)CFURLCreateWithString(NULL, percentEscapedString, NULL);
        
        [compositeString release];
        CFRelease(percentEscapedString);
        
    OBPOSTCONDITION(url != nil);
    return [url autorelease];
    }
}

- (NSString *)scheme;
{
    return scheme;
}

- (NSString *)netLocation;
{
    return netLocation;
}

- (NSString *)path;
{
    return path;
}

- (NSString *)params;
{
    return params;
}

- (NSString *)query;
{
    return query;
}

- (NSString *)fragment;
{
    return fragment;
}

- (NSString *)schemeSpecificPart;
{
    return schemeSpecificPart;
}

- (NSString *)compositeString;
{
    OFSimpleLock(&derivedAttributesSimpleLock);
    if (_cachedCompositeString == nil) {
        NSMutableString *compositeString = (NSMutableString *)[self _newURLStringWithEncodedHostname:NO];
        _cachedCompositeString = [compositeString copy];
        [compositeString release];
    }
    OFSimpleUnlock(&derivedAttributesSimpleLock);
    return _cachedCompositeString;
}

- (NSString *)cacheKey;
{
    OFSimpleLock(&derivedAttributesSimpleLock);
    if (_cacheKey == nil) {
        NSMutableString *key;
    
        key = [[NSMutableString alloc] initWithString:scheme];
        [key appendString:@":"];
    
        if (schemeSpecificPart) {
            [key appendString:schemeSpecificPart];
        } else {
            if (netLocation != nil || [scheme isEqualToString:@"file"])
                [key appendString:@"//"];
            if (netLocation != nil)
                [key appendString:netLocation];
            [key appendString:@"/"];
            if (path != nil)
                [key appendString:path];
            if (params != nil) {
                [key appendString:@";"];
                [key appendString:params];
            }
            if (query != nil) {
                [key appendString:@"?"];
                [key appendString:query];
            }
        }
    
        // Make the cacheKey immutable so that others will be able to just retain it rather than making their own immutable copy.
        _cacheKey = [key copyWithZone:[self zone]];
        [key release];
    }
    OFSimpleUnlock(&derivedAttributesSimpleLock);
    return _cacheKey;
}

// This is possibly not the best name or this method.  Basically this is just the code from -compositeString except we don't append the path, params, query or fragment.  This is used in OmniWeb in the address completion code.
- (NSString *)stringToNetLocation;
{
    NSMutableString *string;

    string = [[NSMutableString alloc] initWithString:scheme];
    [string appendString:@":"];

    if (!schemeSpecificPart) {
	if (netLocation) {
	    [string appendString:@"//"];
	    [string appendString:netLocation];
	}
	[string appendString:@"/"];
    }
    
    return string;
}

- (NSString *)fetchPath;
{
    if (schemeSpecificPart) {
        return schemeSpecificPart;
    } else {
        NSMutableString *fetchPath;

        fetchPath = [NSMutableString stringWithCapacity:
            1 + [path length] +
            (params? (1+[params length]): 0) +
            (query? (1+[query length]): 0) ];
        [fetchPath appendString:@"/"];

        if (path) {
            if (NetscapeCompatibleRelativeAddresses && [path containsString:@".."]) {
                OWURL *siteURL, *resolvedPathURL;

                // Not the most efficient process, but I think it should work, and hopefully this happens rarely.  I didn't want to go to the trouble of abstracting out all that relative path code from -urlFromRelativeString:.
                siteURL = [self urlFromRelativeString:@"/"];
                resolvedPathURL = [siteURL urlFromRelativeString:path];
                [fetchPath appendString:[resolvedPathURL path]];
            } else
                [fetchPath appendString:path];
        }
        if (params) {
            [fetchPath appendString:@";"];
            [fetchPath appendString:params];
        }
        if (query) {
            [fetchPath appendString:@"?"];
            [fetchPath appendString:query];
        }

        return fetchPath;
    }
}

- (NSString *)proxyFetchPath;
{
    NSMutableString *proxyFetchPath;

    // Yes, this ends up looking a lot like our -cacheKey, except we're calling -fetchPath so the NetscapeCompatibleRelativeAddresses preference will kick in (and we don't want it to kick in for our -cacheKey because it's relatively expensive and -cacheKey gets called a lot more).

    proxyFetchPath = [[NSMutableString alloc] initWithString:scheme];
    [proxyFetchPath appendString:@":"];
    if (netLocation) {
        [proxyFetchPath appendString:@"//"];
        [proxyFetchPath appendString:netLocation];
    }
    [proxyFetchPath appendString:[self fetchPath]];
    return [proxyFetchPath autorelease];
}

- (NSArray *)pathComponents;
{
    return [OWURL pathComponentsForPath:path];
}

- (NSString *)lastPathComponent;
{
    return [OWURL lastPathComponentForPath:path];
}

- (NSString *)stringByDeletingLastPathComponent;
{
    return [OWURL stringByDeletingLastPathComponentFromPath:path];
}

- (OWNetLocation *)parsedNetLocation;
{
    OFSimpleLock(&derivedAttributesSimpleLock);
    if (_cachedParsedNetLocation == nil)
        [self _locked_parseNetLocation];
    OFSimpleUnlock(&derivedAttributesSimpleLock);

    return _cachedParsedNetLocation;
}

- (NSString *)hostname;
{
    return [[self parsedNetLocation] hostname];
}

- (NSString *)domain;
{
    OWNetLocation *urlNetLocation = [self parsedNetLocation];
    
    OFSimpleLock(&derivedAttributesSimpleLock);
    if (_cachedDomain == nil)
        _cachedDomain = [[OWURL domainForHostname:[urlNetLocation hostname]] retain];
    OFSimpleUnlock(&derivedAttributesSimpleLock);
    
    return _cachedDomain;
}

- (NSString *)shortDisplayString;
{
    OFSimpleLock(&derivedAttributesSimpleLock);
    if (_cachedShortDisplayString == nil) {
        NSMutableString *shortDisplayString;
    
        shortDisplayString = [[NSMutableString alloc] init];
        if (netLocation) {
            if (_cachedParsedNetLocation == nil)
                [self _locked_parseNetLocation];
            [shortDisplayString appendString:[_cachedParsedNetLocation shortDisplayString]];
            [shortDisplayString appendString:[NSString horizontalEllipsisString]];
        } else {
            [shortDisplayString appendString:scheme];
            [shortDisplayString appendString:@":"];
        }
        
        if (path) {
            [shortDisplayString appendString:[self lastPathComponent]];
            if ([path hasSuffix:@"/"])
                [shortDisplayString appendString:@"/"];
        }
        if (params) {
            [shortDisplayString appendString:@";"];
            [shortDisplayString appendString:params];
        }
        if (query) {
            [shortDisplayString appendString:@"?"];
            [shortDisplayString appendString:query];
        }
        if (fragment) {
            [shortDisplayString appendString:@"#"];
            [shortDisplayString appendString:fragment];
        }
        // Make the cacheKey immutable so that others will be able to just retain it rather than making their own immutable copy.
        _cachedShortDisplayString = [shortDisplayString retain];
        [shortDisplayString release];
    }
    OFSimpleUnlock(&derivedAttributesSimpleLock);
    return _cachedShortDisplayString;
}

//

- (unsigned)hash;
{
#if 1
    /*
         From <http://www.cs.yorku.ca/~oz/hash.html>

         djb2
         this algorithm (k=33) was first reported by dan bernstein many years ago in comp.lang.c. another version of this algorithm (now favored by bernstein) uses xor: hash(i) = hash(i - 1) * 33 ^ str[i]; the magic of number 33 (why it works better than many other constants, prime or not) has never been adequately explained.
     */
    unsigned long hash = 5381;

    NSString *compositeString = [self compositeString];
    OFStringStartLoopThroughCharacters(compositeString, character) {
        hash = ((hash << 5) + hash) + character; /* hash * 33 + character */
    } OFStringEndLoopThroughCharacters;

    return hash;
#elif 0
    const char *urlBytes = [[self compositeString] UTF8String];
    return adler32(adler32(0L, Z_NULL, 0), urlBytes, strlen(urlBytes));
#elif 0
    unsigned int hash = 0;
    
    NSString *compositeString = [self compositeString];
    OFStringStartLoopThroughCharacters(compositeString, character) {
        hash = (hash >> 1) | ((hash & 0x1) << 31);
        hash += character;
    } OFStringEndLoopThroughCharacters;
    
    return hash;
#else
    return [[self compositeString] hash];
#endif
}

- (BOOL)isEqual:(id)anObject;
{
    OWURL *otherURL;

    if (self == anObject)
	return YES;
    if (anObject == nil)
        return NO;
    otherURL = anObject;
    if (otherURL->isa != isa)
	return NO;
    if (_cachedCompositeString == nil)
	[self compositeString];
    if (otherURL->_cachedCompositeString == nil)
	[otherURL compositeString];
        
    return [_cachedCompositeString isEqualToString:otherURL->_cachedCompositeString];
}

- (OWContentType *)contentType;
{
    OFSimpleLock(&derivedAttributesSimpleLock);
    if (_contentType == nil)
	_contentType = [OWURL contentTypeForScheme:scheme];
    OFSimpleUnlock(&derivedAttributesSimpleLock);
    return _contentType;
}

- (BOOL)isSecure;
{
    BOOL isSecure;

    OFSimpleLock(&SecureSchemesSimpleLock);
    isSecure = [SecureSchemes containsObject:scheme];
    OFSimpleUnlock(&SecureSchemesSimpleLock);
    return isSecure;
}

//

- (OWURL *)urlFromRelativeString:(NSString *)aString;
{
    OWURL *absoluteURL;
    NSString *aNetLocation;
    NSString *aPath, *someParams, *aQuery, *aFragment;
    OFStringScanner *scanner;

    absoluteURL = [OWURL urlFromString:aString];
    if (absoluteURL) {
        if (schemeSpecificPart) {
            // If our scheme uses a non-uniform URL syntax, relative URLs are illegal
            return absoluteURL;
        }

        if (NetscapeCompatibleRelativeAddresses && [scheme isEqualToString:[absoluteURL scheme]] && ![absoluteURL netLocation]) {
            NSString *otherFetchPath, *otherFragment;

            // For Netscape compatibility, treat "http:whatever" as a relative link to "whatever".

            otherFetchPath = [absoluteURL fetchPath];
            otherFragment = [absoluteURL fragment];
            if (otherFragment)
                aString = [NSString stringWithFormat:@"%@#%@", otherFetchPath, otherFragment];
            else
                aString = otherFetchPath;
            absoluteURL = nil;
        } else {
            return absoluteURL;
        }
    }

    if (aString == nil || [aString length] == 0)
	return self;

    // Relative URLs default to the current location
    aNetLocation = netLocation;
    aPath = path;
    someParams = params;
    aQuery = query;
    aFragment = fragment;

    scanner = [[OFStringScanner alloc] initWithString:aString];
    scannerScanUpToCharacterInOFCharacterSet(scanner, NonWhitespaceOFCharacterSet);
    if (scannerPeekCharacter(scanner) == '/') {
        // Scan net location or absolute path
        BOOL absolutePathPresent;

        scannerSkipPeekedCharacter(scanner);
        if (scannerPeekCharacter(scanner) == '/') {
            // Scan net location
            scannerSkipPeekedCharacter(scanner);
            aNetLocation = [scanner readFullTokenWithDelimiterOFCharacterSet:NetLocationDelimiterOFCharacterSet forceLowercase:NO];
            if (aNetLocation != nil && [aNetLocation length] == 0)
                aNetLocation = @"localhost";
            absolutePathPresent = scannerPeekCharacter(scanner) == '/';
            if (absolutePathPresent) {
                // To be consistent with the non-netLocation case, skip the '/' here, too
                scannerSkipPeekedCharacter(scanner);
            }
        } else {
            // That slash started a path, not a net location
            absolutePathPresent = YES;
        }
        if (absolutePathPresent) {
            OWURL *fakeRootURL;

            // Scan path
            aPath = [scanner readFullTokenWithDelimiterOFCharacterSet:PathDelimiterOFCharacterSet forceLowercase:NO];
            fakeRootURL = [self fakeRootURL];
            if (fakeRootURL)
                aPath = [[fakeRootURL urlFromRelativeString:aPath] path];
        } else {
            // Reset path
            aPath = nil;
        }
        // Reset remaining parameters
        someParams = nil;
        aQuery = nil;
        aFragment = nil;
    } else if (scannerHasData(scanner) && !OFCharacterSetHasMember(PathDelimiterOFCharacterSet, scannerPeekCharacter(scanner))) {
        // Scan relative path
	NSMutableArray *pathElements;
	unsigned int preserveCount = 0, pathElementCount;
	NSArray *relativePathArray;
	unsigned int relativePathIndex, relativePathCount;
	BOOL lastElementWasDirectory = NO;

        aPath = [scanner readFullTokenWithDelimiterOFCharacterSet:PathDelimiterOFCharacterSet forceLowercase:NO];

        if (path == nil || [path length] == 0)
	    pathElements = [NSMutableArray arrayWithCapacity:1];
	else
            pathElements = [[[OWURL pathComponentsForPath:path] mutableCopy] autorelease];
	pathElementCount = [pathElements count];
	if (pathElementCount != 0) {
	    if ([[pathElements objectAtIndex:0] length] == 0)
		preserveCount = 1;
	    if (pathElementCount > preserveCount)
		[pathElements removeLastObject];
	}
        relativePathArray = [OWURL pathComponentsForPath:aPath];
	relativePathCount = [relativePathArray count];
	for (relativePathIndex = 0; relativePathIndex < relativePathCount; relativePathIndex++) {
	    NSString *pathElement;

	    pathElement = [relativePathArray objectAtIndex:relativePathIndex];
	    if ([pathElement isEqualToString:@".."]) {
		lastElementWasDirectory = YES;
		if ([pathElements count] > preserveCount)
		    [pathElements removeLastObject];
		else {
		    if (NetscapeCompatibleRelativeAddresses) {
			// Netscape doesn't preserve leading ..'s
		    } else {
			[pathElements addObject:pathElement];
			preserveCount++;
		    }
		}
	    } else if ([pathElement isEqualToString:@"."]) {
		lastElementWasDirectory = YES;
	    } else {
		lastElementWasDirectory = NO;
		[pathElements addObject:pathElement];
	    }
	}
	if (lastElementWasDirectory && [[pathElements lastObject] length] != 0) {
	    [pathElements addObject:@""];
	}
	aPath = [pathElements componentsJoinedByString:@"/"];

        // Reset remaining parameters
        someParams = nil;
        aQuery = nil;
        aFragment = nil;
    }
    if (scannerPeekCharacter(scanner) == ';') {
        // Scan params
        scannerSkipPeekedCharacter(scanner);
        someParams = [scanner readFullTokenWithDelimiterOFCharacterSet:ParamDelimiterOFCharacterSet forceLowercase:NO];

        // Reset remaining parameters
        aQuery = nil;
        aFragment = nil;
    }
    if (scannerPeekCharacter(scanner) == '?') {
        // Scan query
        scannerSkipPeekedCharacter(scanner);
        aQuery = [scanner readFullTokenWithDelimiterOFCharacterSet:QueryDelimiterOFCharacterSet forceLowercase:NO];
        if (aQuery == nil)
            aQuery = @"";

        // Reset remaining parameters
        aFragment = nil;
    }
    if (scannerPeekCharacter(scanner) == '#') {
        // Scan fragment
        scannerSkipPeekedCharacter(scanner);
        aFragment = [scanner readFullTokenWithDelimiterOFCharacterSet:FragmentDelimiterOFCharacterSet forceLowercase:NO];
        if (!aFragment)
            aFragment = @"";
    }

    [scanner release];

    return [OWURL urlWithLowercaseScheme:scheme netLocation:aNetLocation path:aPath params:someParams query:aQuery fragment:aFragment];
}

- (OWURL *)urlForPath:(NSString *)newPath;
{
    return [OWURL urlWithLowercaseScheme:scheme netLocation:netLocation path:newPath params:nil query:nil fragment:nil];
}

- (OWURL *)urlForQuery:(NSString *)newQuery;
{
#warning Bring this MSIE compatibility preference (appending queries) out to the UI?
    /* Some forms pages depend on this behavior */
#if 0
    /* Screwy MSIE semantics */
    if (query)
        newQuery = [query stringByAppendingString:newQuery];
#endif
    return [OWURL urlWithLowercaseScheme:scheme netLocation:netLocation path:path params:params query:newQuery fragment:nil];
}

- (OWURL *)urlWithoutFragment;
{
    if (!fragment)
	return self;
    return [OWURL urlWithLowercaseScheme:scheme netLocation:netLocation path:path params:params query:query fragment:nil];
}

- (OWURL *)urlWithFragment:(NSString *)newFragment
{
    if (newFragment == fragment ||
        [fragment isEqualToString:newFragment])
        return self;

    return [OWURL urlWithLowercaseScheme:scheme netLocation:netLocation path:path params:params query:query fragment:newFragment];
}

- (OWURL *)urlWithoutUsernamePasswordOrFragment;
{
    OWNetLocation *parsedLocation = [self parsedNetLocation];
    if ([parsedLocation username] == nil && [parsedLocation password] == nil && fragment == nil)
        return self;
    
    return [OWURL urlWithLowercaseScheme:scheme netLocation:[parsedLocation hostnameWithPort] path:path params:params query:query fragment:nil];
}

- (OWURL *) baseURL;
{
    BOOL hasTrailingSlash;
    NSString *basePath;
    
    hasTrailingSlash = [path hasSuffix: @"/"];
    if (!fragment && !query && hasTrailingSlash)
        return self;
    
    basePath = path;
    if (!hasTrailingSlash) {
        NSRange lastSlashRange = [path rangeOfString:@"/" options: NSBackwardsSearch];
        if (lastSlashRange.length == 1)
            // Take everything up to and including the slash
            basePath = [path substringWithRange: (NSRange){0, lastSlashRange.location + 1}];
        else {
            OBASSERT(path == nil || lastSlashRange.length == 0);
            // No slashes, either path is empty or has one component.  We'll strip one component by stripping everything
            basePath = @"";
        }
            
    }
    return [OWURL urlWithLowercaseScheme:scheme netLocation:netLocation path:basePath params:nil query:nil fragment:nil];
}

// NSCopying protocol

- (id)copyWithZone:(NSZone *)zone
{
    OWURL *newURL;
    
    if (NSShouldRetainWithZone(self, zone))
        return [self retain];

    newURL = [[isa allocWithZone:zone] init];
    
    newURL->scheme = [scheme copyWithZone:zone];
    newURL->netLocation = [netLocation copyWithZone:zone];
    newURL->path = [path copyWithZone:zone];
    newURL->params = [params copyWithZone:zone];
    newURL->query = [query copyWithZone:zone];
    newURL->fragment = [fragment copyWithZone:zone];
    newURL->schemeSpecificPart = [schemeSpecificPart copyWithZone:zone];
        
    return newURL;
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];

    [debugDictionary setObject:scheme forKey:@"scheme"];
    if (netLocation)
	[debugDictionary setObject:netLocation forKey:@"netLocation"];
    if (path)
	[debugDictionary setObject:path forKey:@"path"];
    if (params)
	[debugDictionary setObject:params forKey:@"params"];
    if (query)
	[debugDictionary setObject:query forKey:@"query"];
    if (fragment)
	[debugDictionary setObject:fragment forKey:@"fragment"];
    if (schemeSpecificPart)
	[debugDictionary setObject:schemeSpecificPart forKey:@"schemeSpecificPart"];

    [debugDictionary setObject:[self compositeString] forKey:@"compositeString"];

    return debugDictionary;
}

- (NSString *)shortDescription;
{
    return [NSString stringWithFormat:@"<URL:%@>", [self compositeString]];
}

@end

@implementation OWURL (Private)

+ (void)controllerDidInitialize:(OFController *)controller;
{
    [self readDefaults];
}

+ (OWURL *)urlWithLowercaseScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams query:(NSString *)aQuery fragment:(NSString *)aFragment;
{
    if (!aScheme)
	return nil;
    return [[[self alloc] initWithLowercaseScheme:aScheme netLocation:aNetLocation path:aPath params:someParams query:aQuery fragment:aFragment] autorelease];
}

+ (OWURL *)urlWithLowercaseScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;
{
    if (!aScheme)
	return nil;

    return [[[self alloc] initWithLowercaseScheme:aScheme schemeSpecificPart:aSchemeSpecificPart fragment:aFragment] autorelease];
}

- _initWithLowercaseScheme:(NSString *)aScheme;
{
    if (![super init])
	return nil;

    if (aScheme == nil) {
	[self release];
	return nil;
    }
    scheme = [aScheme retain];
    OFSimpleLockInit(&derivedAttributesSimpleLock);
    return self;
}

- initWithLowercaseScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams query:(NSString *)aQuery fragment:(NSString *)aFragment;
{
    if (![self _initWithLowercaseScheme:aScheme])
        return nil;
            
        
    netLocation = [aNetLocation retain];
    path = [aPath retain];
    params = [someParams retain];
    query = [aQuery retain];
    fragment = [aFragment retain];

    OBPOSTCONDITION([[[self compositeString] stringByRemovingCharactersInOFCharacterSet:TabsAndReturnsOFCharacterSet] isEqualToString:[self compositeString]]);
    
    return self;
}

- initWithScheme:(NSString *)aScheme netLocation:(NSString *)aNetLocation path:(NSString *)aPath params:(NSString *)someParams query:(NSString *)aQuery fragment:(NSString *)aFragment;
{
    return [self initWithLowercaseScheme:OFLowercaseStringCacheGet(&lowercaseSchemeCache, aScheme) netLocation:aNetLocation path:aPath params:someParams query:aQuery fragment:aFragment];
}

- initWithLowercaseScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;
{
    if (![self _initWithLowercaseScheme:aScheme])
        return nil;
    
    schemeSpecificPart = [aSchemeSpecificPart copy];
    fragment = [aFragment copy];
    
    return self;
}

- initWithScheme:(NSString *)aScheme schemeSpecificPart:(NSString *)aSchemeSpecificPart fragment:(NSString *)aFragment;
{
    return [self initWithLowercaseScheme:OFLowercaseStringCacheGet(&lowercaseSchemeCache, aScheme) schemeSpecificPart:aSchemeSpecificPart fragment:aFragment];
}

- (OWURL *)fakeRootURL;
{
    OWURL *fakeRootURL;
    unsigned int fakeRootIndex, fakeRootCount;

    if (fakeRootURLs == nil)
        return nil;

    [fakeRootURLsLock lock];
    fakeRootCount = [fakeRootURLs count];
    for (fakeRootIndex = 0, fakeRootURL = nil; fakeRootIndex < fakeRootCount && fakeRootURL == nil; fakeRootIndex++) {
        OWURL *someFakeRootURL;

        someFakeRootURL = [fakeRootURLs objectAtIndex:fakeRootIndex];
        if ([[self compositeString] hasPrefix:[someFakeRootURL compositeString]]) {
            fakeRootURL = [[someFakeRootURL retain] autorelease];
        }
    }
    [fakeRootURLsLock unlock];
    return fakeRootURL;
}

- (void)_locked_parseNetLocation;
{
    OBPRECONDITION(_cachedParsedNetLocation == nil);
    _cachedParsedNetLocation = [[OWNetLocation netLocationWithString:netLocation != nil ? netLocation : schemeSpecificPart] retain];
}

- (NSString *)_newURLStringWithEncodedHostname:(BOOL)shouldEncode;
{
    NSMutableString *compositeString;
    
    compositeString = [[NSMutableString alloc] initWithString:scheme];
    [compositeString appendString:@":"];
    
    if (schemeSpecificPart) {
        [compositeString appendString:schemeSpecificPart];
    } else {
        if ((netLocation != nil && ![scheme isEqualToString:@"mailto"]) || [scheme isEqualToString:@"file"])
            [compositeString appendString:@"//"];
        if (netLocation != nil)
            [compositeString appendString:(shouldEncode ? [ONHost IDNEncodedHostname:netLocation] : netLocation)];
        if (![scheme isEqualToString:@"mailto"])
            [compositeString appendString:@"/"];
        if (path != nil)
            [compositeString appendString:path];
        if (params != nil) {
            [compositeString appendString:@";"];
            [compositeString appendString:params];
        }
        if (query != nil) {
            [compositeString appendString:@"?"];
            [compositeString appendString:query];
        }
    }
    if (fragment != nil) {
        [compositeString appendString:@"#"];
        [compositeString appendString:fragment];
    }
    
    return compositeString;
}

@end

@interface NSURL (Private)
- (NSString *)_web_originalDataAsString;
@end

@implementation NSURL (OWExtensions)

- (NSString *)_ow_originalDataAsString;
{
    // TODO: Once we're 10.3-only, we can use CFURLGetBytes() rather than the private -_web_originalDataAsString method
    static BOOL alreadyInitialized = NO;
    static BOOL shouldUsePrivateAPI;
    
    if (!alreadyInitialized) {
        alreadyInitialized = YES;
        shouldUsePrivateAPI = [self respondsToSelector:@selector(_web_originalDataAsString)];
        OBASSERT(shouldUsePrivateAPI);
    }
    
    if (shouldUsePrivateAPI)
        return [self _web_originalDataAsString];
    else
        return (NSString *)CFURLGetString((CFURLRef)self);
}

@end
