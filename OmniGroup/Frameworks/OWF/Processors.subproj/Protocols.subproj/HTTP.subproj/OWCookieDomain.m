// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWCookieDomain.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSDate-OWExtensions.h"
#import "OWAddress.h"
#import "OWContentInfo.h"
#import "OWCookiePath.h"
#import "OWCookie.h"
#import "OWHeaderDictionary.h"
#import "OWHTTPSession.h"
#import "OWNetLocation.h"
#import "OWProcessor.h"
#import "OWSitePreference.h"
#import "OWURL.h"
#import "OWWebPipeline.h"


RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/HTTP.subproj/OWCookieDomain.m 89466 2007-08-01 23:35:13Z kc $")


static NSLock *domainLock;
static NSMutableDictionary *domainsByName;
static OFScheduledEvent *saveEvent;

static NSCharacterSet *endNameSet, *endNameValueSet, *endValueSet, *endDateSet, *endKeySet;
static NSTimeInterval distantPastInterval;

static id classDelegate;

static NSString *OW5CookieFileName = @"Cookies.xml";
NSString *OWCookiesChangedNotification = @"OWCookiesChangedNotification";

NSString *OWAcceptCookiePreferenceKey = @"OWAcceptCookies";
NSString *OWRejectThirdPartyCookiesPreferenceKey = @"OWRejectThirdPartyCookies";
NSString *OWExpireCookiesAtEndOfSessionPreferenceKey = @"OWExpireCookiesAtEndOfSession";

#ifdef DEBUG_len0
BOOL OWCookiesDebug = YES;
#else
BOOL OWCookiesDebug = NO;
#endif

NSString *OWSetCookieHeader = @"set-cookie";


static inline void _locked_checkCookiesLoaded()
{
    if (!domainsByName) {
        [domainLock unlock];
        [NSException raise:NSInternalInconsistencyException format:@"Attempted to access cookies before they had been loaded."];
    }
}

@interface OWCookieDomain (PrivateAPI)
+ (void)controllerDidInitialize:(OFController *)controller;
+ (void)controllerWillTerminate:(OFController *)controller;
+ (void)saveCookies;
+ (NSString *)cookiePath:(NSString *)fileName;
+ (void)locked_didChange;
+ (void)notifyCookiesChanged;
- (void)addCookie:(OWCookie *)cookie andNotify:(BOOL)shouldNotify;
+ (OWCookieDomain *)domainNamed:(NSString *)name andNotify:(BOOL)shouldNotify;
- (OWCookiePath *)locked_pathNamed:(NSString *)pathName shouldCreate:(BOOL)shouldCreate;
+ (NSArray *)searchDomainsForDomain:(NSString *)aDomain;
+ (OWCookie *)cookieFromHeaderValue:(NSString *)headerValue defaultDomain:(NSString *)defaultDomain defaultPath:(NSString *)defaultPath;
- (void)locked_addApplicableCookies:(NSMutableArray *)cookies forPath:(NSString *)aPath urlIsSecure:(BOOL)secure includeRejected:(BOOL)includeRejected;
+ (BOOL)locked_readOW5Cookies;
- (id)initWithDomain:(NSString *)domain;
@end


@implementation OWCookieDomain

+ (void)initialize;
{
    OBINITIALIZE;

    domainLock = [[NSRecursiveLock alloc] init];
    
    endNameSet = [[NSCharacterSet characterSetWithCharactersInString:@"=;, \t\r\n"] retain];
    endDateSet = [[NSCharacterSet characterSetWithCharactersInString:@";\r\n"] retain];
    endNameValueSet = [[NSCharacterSet characterSetWithCharactersInString:@";\r\n"] retain];
    endValueSet = [[NSCharacterSet characterSetWithCharactersInString:@"; \t\r\n"] retain];
    endKeySet = [[NSCharacterSet characterSetWithCharactersInString:@"=;, \t\r\n"] retain];
    
    distantPastInterval = [[NSDate distantPast] timeIntervalSinceReferenceDate];
}

+ (void)didLoad;
{
    [[OFController sharedController] addObserver:self];    
}

 + (void)readDefaults;
{
#warning 2003-12-19 [LEN] IMPLEMENT ME!
    /*
    NSUserDefaults *userDefaults;
    NSString *value;
    
    [domainLock lock];

    userDefaults = [NSUserDefaults standardUserDefaults];

    // Upgrade our defaults -- check if the old default exists, and if so, what it was
    if ([userDefaults boolForKey:@"OWHTTPRefuseAllCookies"]) {
        [[OWSitePreference preferenceForKey:@"AcceptCookies" address:anAddress] setBoolValue:NO]
        [userDefaults removeObjectForKey:@"OWHTTPRefuseAllCookies"];
        [userDefaults synchronize];
    }
        
    // Upgrade "Default behavior" preference
    if ((value = [userDefaults objectForKey:@"OWHTTPCookieDefaultBehavior"])) {
        switch (value) {
            case 0: // OWCookieDomainDefaultBehavior = 0,
            case 1: // OWCookieDomainPromptBehavior = 1, // i.e., ask the delegate
            case 2: // OWCookieDomainAcceptBehavior = 2,
            case 3: // OWCookieDomainAcceptForSessionBehavior = 3,
            case 4: // OWCookieDomainRejectBehavior = 4,
        [userDefaults setObject:value forKey:@"CookieBehavior"];
        [userDefaults removeObjectForKey:@"OWHTTPCookieDefaultBehavior"];
        [userDefaults synchronize];
    }
        
    [domainLock unlock];
        */
}


+ (void)registerCookie:(OWCookie *)newCookie fromURL:(OWURL *)url siteURL:(OWURL *)siteURL;
{
    if (newCookie == nil)
        return;

    NSString *cookieDomain = [OWSitePreference domainForURL:url];
    NSString *siteDomain = [OWSitePreference domainForURL:siteURL];
    OWCookieStatus proposedStatus;
    
    BOOL isAlienCookie = ([cookieDomain caseInsensitiveCompare:siteDomain] != NSOrderedSame);
    
    if (![[OWSitePreference preferenceForKey:OWAcceptCookiePreferenceKey domain:siteDomain] boolValue])
        proposedStatus = OWCookieRejectedStatus;
    else if (isAlienCookie && [[OWSitePreference preferenceForKey:OWRejectThirdPartyCookiesPreferenceKey domain:siteDomain] boolValue])
        proposedStatus = OWCookieRejectedStatus;
    else if ([newCookie expirationDate] == nil || [[OWSitePreference preferenceForKey:OWExpireCookiesAtEndOfSessionPreferenceKey domain:siteDomain] boolValue])
        proposedStatus = OWCookieTemporaryStatus;
    else
        proposedStatus = OWCookieSavedStatus;
    
    [newCookie setStatus:proposedStatus andNotify:NO];
    [newCookie setSite:[siteURL compositeString]];

    // The cookie itself can specify a domain, so get the domain that ends up in the actual cookie instance.
    OWCookieDomain *domain = [self domainNamed:[newCookie domain]];        
    [domain addCookie:newCookie];
}

+ (void)registerCookiesFromURL:(OWURL *)url outerContentInfos:(NSArray *)outerContentInfos headerValue:(NSString *)headerValue;
{
    NSString *defaultDomain, *defaultPath;
    OWCookie *cookie;
    OWCookieDomain *domain;
    
    if (url == nil)
        return;

    defaultDomain = [[url parsedNetLocation] hostname];
    defaultPath = @"/";

    // defaultDomain could easily be nil:  for example, this might be a file: URL
    // OBASSERT(defaultDomain != nil);

    if (OWCookiesDebug)
        NSLog(@"COOKIES: Register url=%@ domain=%@ path=%@ header=%@", [url shortDescription], defaultDomain, defaultPath, headerValue);

    cookie = [self cookieFromHeaderValue:headerValue defaultDomain:defaultDomain defaultPath:defaultPath];
    if (cookie == nil)
        return;

    NSString *cookieSite = [OWURL domainForHostname:[cookie domain]];
    
    unsigned int contentInfoIndex = [outerContentInfos count];
    if (contentInfoIndex > 0) {
        
        while (contentInfoIndex-- > 0) {
            OWContentInfo *contentInfo = [outerContentInfos objectAtIndex:contentInfoIndex];
            OWAddress *contentInfoAddress = [contentInfo address];
            NSString *contentInfoSite = [OWSitePreference domainForAddress:contentInfoAddress];
            OWCookieStatus proposedStatus;
            
            OBASSERT(contentInfoAddress != nil);

            BOOL isAlienCookie = ([cookieSite caseInsensitiveCompare:contentInfoSite] != NSOrderedSame);

            if (![[OWSitePreference preferenceForKey:OWAcceptCookiePreferenceKey domain:contentInfoSite] boolValue])
                proposedStatus = OWCookieRejectedStatus;
            else if (isAlienCookie && [[OWSitePreference preferenceForKey:OWRejectThirdPartyCookiesPreferenceKey domain:contentInfoSite] boolValue])
                proposedStatus = OWCookieRejectedStatus;
            else if ([cookie expirationDate] == nil || [[OWSitePreference preferenceForKey:OWExpireCookiesAtEndOfSessionPreferenceKey domain:contentInfoSite] boolValue])
                proposedStatus = OWCookieTemporaryStatus;
            else
                proposedStatus = OWCookieSavedStatus;

            if ([cookie status] > proposedStatus || [cookie status] == OWCookieUnsetStatus) {
                [cookie setStatus:proposedStatus andNotify:NO];
                [cookie setSite:[contentInfoAddress addressString]];
            }
        }
    } else {
        NSString *urlSite = [OWSitePreference domainForAddress:[OWAddress addressWithURL:url]];
        OWCookieStatus proposedStatus;

        if (OWCookiesDebug)
            NSLog(@"COOKIES: url=%@, NO OUTER CONTENT INFO", [url shortDescription]);

        BOOL isAlienCookie = ([cookieSite caseInsensitiveCompare:urlSite] != NSOrderedSame);

        if (![[OWSitePreference preferenceForKey:OWAcceptCookiePreferenceKey domain:urlSite] boolValue])
            proposedStatus = OWCookieRejectedStatus;
        else if (isAlienCookie && [[OWSitePreference preferenceForKey:OWRejectThirdPartyCookiesPreferenceKey domain:urlSite] boolValue])
            proposedStatus = OWCookieRejectedStatus;
        else if ([cookie expirationDate] == nil || [[OWSitePreference preferenceForKey:OWExpireCookiesAtEndOfSessionPreferenceKey domain:urlSite] boolValue])
            proposedStatus = OWCookieTemporaryStatus;
        else
            proposedStatus = OWCookieSavedStatus;

        [cookie setStatus:proposedStatus andNotify:NO];
        [cookie setSite:[url compositeString]];
    }
    
    // The cookie itself can specify a domain, so get the domain that ends up in the actual cookie instance.
    if (OWCookiesDebug)
        NSLog(@"COOKIES: url=%@, adding cookie = %@", [url shortDescription], cookie);
        
    domain = [self domainNamed:[cookie domain]];        

    [domain addCookie:cookie];
        
    if (OWCookiesDebug)
        NSLog(@"COOKIES: Notify target of new cookie %@", cookie);
}

+ (void)registerCookiesFromURL:(OWURL *)url context:(id <OWProcessorContext>)procContext headerDictionary:(OWHeaderDictionary *)headerDictionary;
{
    NSArray *valueArray;
    unsigned int valueIndex, valueCount;

    valueArray = [headerDictionary stringArrayForKey:OWSetCookieHeader];
    if (valueArray == nil)
	return;

    valueCount = [valueArray count];
    if (valueCount == 0)
        return;

    // These lookups are potentially expensive, so we only do them after we've found that we do actually have some cookies to register
    for (valueIndex = 0; valueIndex < valueCount; valueIndex++) {
        [self registerCookiesFromURL:url outerContentInfos:[procContext outerContentInfos] headerValue:[valueArray objectAtIndex:valueIndex]];
    }
}

+ (NSArray *)cookiesForURL:(OWURL *)url;
{
    NSString *path = [url path];
    if (path == nil)
        path = @"";
    path = [@"/" stringByAppendingString:path];

    NSString *hostname = [[[url parsedNetLocation] hostname] lowercaseString];
    NSArray *searchDomains = [self searchDomainsForDomain:hostname];

    if (OWCookiesDebug)
        NSLog(@"COOKIES: url=%@ hostname=%@, path=%@ --> domains=%@", url, hostname, path, searchDomains);

    NSMutableArray *cookies = [NSMutableArray array];
    
    [domainLock lock];
    _locked_checkCookiesLoaded();
    
    unsigned int domainIndex, domainCount = [searchDomains count];
    for (domainIndex = 0; domainIndex < domainCount; domainIndex++) {
        NSString *searchDomain = [searchDomains objectAtIndex:domainIndex];
        OWCookieDomain *domain = [domainsByName objectForKey:searchDomain];
        [domain locked_addApplicableCookies:cookies forPath:path urlIsSecure:[url isSecure] includeRejected:NO];
    }
    
    [domainLock unlock];

    if (OWCookiesDebug)
        NSLog(@"COOKIES: -cookiesForURL:%@ --> %@", [url shortDescription], [cookies description]);

    return cookies;
}

+ (NSString *)cookieHeaderStringForURL:(OWURL *)url;
{    
    NSArray *cookies = [self cookiesForURL:url];
    if (cookies == nil)
        return nil;

    NSMutableString *cookieString = nil;
    unsigned int cookieCount = [cookies count];
    unsigned int cookieIndex;
    
    for (cookieIndex = 0; cookieIndex < cookieCount; cookieIndex++) {
        OWCookie *cookie = [cookies objectAtIndex:cookieIndex];

        if (cookieString == nil)
            cookieString = [[[NSMutableString alloc] initWithString:@""] autorelease];
        else
            [cookieString appendString:@"; "];

        NSString *cookieName = [cookie name];
        if (![NSString isEmptyString:cookieName]) {
            [cookieString appendString:cookieName];
            [cookieString appendString:@"="];
        }
        [cookieString appendString:[cookie value]];
    }
    
    return cookieString;
}

+ (BOOL)hasCookiesForSiteDomain:(NSString *)site;
{
    site = [site lowercaseString];
    NSString *dottedSite = [@"." stringByAppendingString:site];
    
    NSArray *allDomains = [self allDomains];
    unsigned int domainCount = [allDomains count];
    unsigned int domainIndex;
    
    for (domainIndex = 0; domainIndex < domainCount; domainIndex++) {
        OWCookieDomain *domain = [allDomains objectAtIndex:domainIndex];
        NSArray *cookies = [domain cookies];
        unsigned int cookieCount = [cookies count];
        unsigned int cookieIndex;
        
        for (cookieIndex = 0; cookieIndex < cookieCount; cookieIndex++) {
            OWCookie *cookie = [cookies objectAtIndex:cookieIndex];
            
            if ([[cookie domain] hasSuffix:dottedSite] || [[cookie domain] isEqual:site] || [[cookie siteDomain] isEqual:site])
                return YES;
        }
    }
    
    return NO;
}

+ (NSArray *)cookiesForSiteDomain:(NSString *)site;
{
    site = [site lowercaseString];
    NSString *dottedSite = [@"." stringByAppendingString:site];
    BOOL emptySiteDomain = [NSString isEmptyString:site];
    
    NSMutableArray *cookiesForSite = [NSMutableArray array];
    NSArray *allDomains = [self sortedDomains];
    unsigned int domainCount = [allDomains count];
    unsigned int domainIndex;
    
    for (domainIndex = 0; domainIndex < domainCount; domainIndex++) {
        OWCookieDomain *domain = [allDomains objectAtIndex:domainIndex];
        NSArray *cookies = [domain cookies];
        unsigned int cookieCount = [cookies count];
        unsigned int cookieIndex;
        
        if (emptySiteDomain)
            [cookiesForSite addObjectsFromArray:cookies];
        else {
            for (cookieIndex = 0; cookieIndex < cookieCount; cookieIndex++) {
                OWCookie *cookie = [cookies objectAtIndex:cookieIndex];
                
                if ([[cookie domain] hasSuffix:dottedSite] || [[cookie domain] isEqual:site] || [[cookie siteDomain] isEqual:site])
                    [cookiesForSite addObject:cookie];
            }
        }
    }
    
    return cookiesForSite;
}

+ (void)didChange;
{
    [domainLock lock];
    [self locked_didChange];
    [domainLock unlock];
}

+ (NSArray *)allDomains;
{
    NSArray *domains;
    
    [domainLock lock];
    _locked_checkCookiesLoaded();
    
    domains = [domainsByName allValues];
    
    [domainLock unlock];
    
    return domains;
}

+ (NSArray *)sortedDomains;
{
    NSArray *domains;
    
    [domainLock lock];
    _locked_checkCookiesLoaded();
    
    domains = [[domainsByName allValues] sortedArrayUsingSelector:@selector(compare:)];
    
    [domainLock unlock];
    
    return domains;
}

+ (OWCookieDomain *)domainNamed:(NSString *)name;
{
    return [self domainNamed:name andNotify:YES];
}

+ (void)deleteDomain:(OWCookieDomain *)domain;
{
    [domainLock lock];
    _locked_checkCookiesLoaded();
    
    [domainsByName removeObjectForKey:[domain name]];
    [self locked_didChange];
    
    [domainLock unlock];
}

+ (void)deleteCookie:(OWCookie *)cookie;
{
    OWCookieDomain *domain;
    
    [domainLock lock];
    _locked_checkCookiesLoaded();
    
    // Its domain might have been deleted already which is why this method exists -- the caller can't call +domainNamed: and delete the cookie from there since that might recreate a deleted domain.

    domain = [domainsByName objectForKey:[cookie domain]];
    [domain removeCookie:cookie];
    
    [domainLock unlock];
}

+ (void)setDelegate:(id)delegate;
{
    classDelegate = delegate;
}

+ (id)delegate;
{
    return classDelegate;
}

- (NSString *)name;
{
    return _name;
}

- (NSString *)nameDomain;
{
    return _nameDomain;
}

- (NSString *)stringValue;
{
    return _name;
}

- (NSArray *)paths;
{
    NSArray *paths;
    
    [domainLock lock];
    paths = [[NSArray alloc] initWithArray:_cookiePaths];
    [domainLock unlock];
    
    return [paths autorelease];
}

- (OWCookiePath *)pathNamed:(NSString *)pathName;
{
    OWCookiePath *path;
    
    [domainLock lock];
    path = [[self locked_pathNamed:pathName shouldCreate:YES] retain];
    [domainLock unlock];
    
    return [path autorelease];
}

//
// Saving
//

- (void)appendXML:(OFDataBuffer *)xmlBuffer;
{
    NSMutableArray *cookies = [NSMutableArray array];
    
    [domainLock lock];

    // The paths are not represented in the XML file (since they are usually the default and there are usually few enough cookies per path that it would be a waste.
    [_cookiePaths makeObjectsPerformSelector:@selector(addCookiesToSaveToArray:) withObject:cookies];
        
    // Don't archive domains with zero cookies
    if ([cookies count]) {
        OFDataBufferAppendCString(xmlBuffer, "<domain name=\"");
        // This *shouldn't* have entities in it, but ...
        OFDataBufferAppendXMLQuotedString(xmlBuffer, (CFStringRef)_name);
        OFDataBufferAppendCString(xmlBuffer, "\">\n");

        [cookies makeObjectsPerformSelector:@selector(appendXML:) withObject:(id)xmlBuffer];
                
        OFDataBufferAppendCString(xmlBuffer, "</domain>\n");
    }
    
    [domainLock unlock];
}

//
// Convenience methods that loop over all the paths
//

- (void)addCookie:(OWCookie *)cookie;
{
    [self addCookie:cookie andNotify:YES];
}

- (void)removeCookie:(OWCookie *)cookie;
{
    OWCookiePath *path;
    
    [domainLock lock];
    path = [self locked_pathNamed:[cookie path] shouldCreate:NO];
    [path removeCookie:cookie];
    [domainLock unlock];
}

- (NSArray *)cookies;
{
    NSMutableArray *cookies;
    unsigned int pathIndex, pathCount;
    
    cookies = [NSMutableArray array];
    [domainLock lock];
    pathCount = [_cookiePaths count];
    for (pathIndex = 0; pathIndex < pathCount; pathIndex++)
        [[_cookiePaths objectAtIndex:pathIndex] addNonExpiredCookiesToArray:cookies usageIsSecure:YES includeRejected:YES];
    [domainLock unlock];
    
    return cookies;
}

- (NSComparisonResult)compare:(id)otherObject;
{
    if (((OWCookieDomain *)otherObject)->isa != isa)
        return NSOrderedAscending;

    NSString *otherNameDomain = [(OWCookieDomain *)otherObject nameDomain];
    NSComparisonResult domainComparisonResult = [_nameDomain compare:otherNameDomain];
    if (domainComparisonResult == NSOrderedSame)
        return [_name compare:[(OWCookieDomain *)otherObject name]];
    else
        return domainComparisonResult;
}

//
//  NSCopying protocol (so this can go in table view columns like in the OW cookies inspector)
//

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];
}

@end



@implementation OWCookieDomain (PrivateAPI)

+ (void)controllerDidInitialize:(OFController *)controller;
{
    [self readDefaults];
    
    [domainLock lock];
    
    domainsByName = [[NSMutableDictionary alloc] init];
    
    // Read the cookies
    NS_DURING {
        [self locked_readOW5Cookies];
    } NS_HANDLER {
        NSLog(@"Exception raised while reading cookies: %@", localException);
    } NS_ENDHANDLER;
    
    [domainLock unlock];
    
    if (OWCookiesDebug)
        NSLog(@"COOKIES: Read cookies");
}

+ (void)controllerWillTerminate:(OFController *)controller;
{
    [self saveCookies];
}

+ (void)saveCookies;
{
    NSString *cookieFilename;
    NSArray *domains;
    OFDataBuffer xmlBuffer;
    unsigned int domainIndex, domainCount;
    NSDictionary *attributes;
    
    // This must get executed in the main thread so that the notification gets posted in the main thread (since that is where the cookie preferences panel is listening).
    OBPRECONDITION([NSThread inMainThread]);

    if (OWCookiesDebug)
        NSLog(@"COOKIES: Saving");

    if (!(cookieFilename = [self cookiePath:OW5CookieFileName])) {
        if (OWCookiesDebug)
            NSLog(@"COOKIES: Unable to compute cookie path");
        return;
    }

    [domainLock lock];
    
    [saveEvent release];
    saveEvent = nil;
    
    OFDataBufferInit(&xmlBuffer);
#warning TJW -- I still need to write a DTD for this file and put it on our web site
    OFDataBufferAppendCString(&xmlBuffer,
    "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
    "<!DOCTYPE OmniWebCookies SYSTEM \"http://www.omnigroup.com/DTDs/OmniWeb5Cookies.dtd\">\n"
    "<OmniWebCookies>\n");

    domains = [[domainsByName allValues] sortedArrayUsingSelector:@selector(compare:)];
    domainCount = [domains count];
    for (domainIndex = 0; domainIndex < domainCount; domainIndex++)
        [(OWCookieDomain *)[domains objectAtIndex:domainIndex] appendXML:&xmlBuffer];

    OFDataBufferAppendCString(&xmlBuffer, "</OmniWebCookies>\n");

    // Cookies must only be readable by the owner since they can contain
    // security sensitive information
    attributes = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedLong:0600], NSFilePosixPermissions,
            nil];
            
    OFDataBufferFlush(&xmlBuffer);
    if (![[NSFileManager defaultManager] atomicallyCreateFileAtPath:cookieFilename contents:OFDataBufferData(&xmlBuffer) attributes:attributes]) {
#warning TJW: There is not currently any good way to pop up a panel telling the user that they need to check the file permissions for a particular path.
        NSLog(@"Unable to save cookies to %@", cookieFilename);
    }
    
    OFDataBufferRelease(&xmlBuffer);
    
    [domainLock unlock];
}

+ (NSString *)cookiePath:(NSString *)fileName;
{
    NSString *directory;
    NSFileManager *fileManager;
    BOOL isDirectory;

    directory = [[[NSUserDefaults standardUserDefaults] objectForKey:@"OWLibraryDirectory"] stringByStandardizingPath];
    fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:directory isDirectory:&isDirectory] || !isDirectory)
        return nil;

    return [directory stringByAppendingPathComponent:fileName];
}

+ (void)locked_didChange;
{
    OFScheduler *mainScheduler;
    
    mainScheduler = [OFScheduler mainScheduler];
    
    // Kill the old scheduled event and schedule one for later
    if (saveEvent) {
        [mainScheduler abortEvent:saveEvent];
        [saveEvent release];
    }

    saveEvent = [[mainScheduler scheduleSelector:@selector(saveCookies) onObject:self withObject:nil afterTime:60.0] retain];

    if (OWCookiesDebug)
        NSLog(@"COOKIES: Did change, saveEvent = %@", saveEvent);
        
    [self queueSelectorOnce:@selector(notifyCookiesChanged)];
}

+ (void)notifyCookiesChanged;
{
    [[NSNotificationCenter defaultCenter] postNotificationName:OWCookiesChangedNotification object:nil];
}

+ (OWCookieDomain *)domainNamed:(NSString *)name andNotify:(BOOL)shouldNotify;
{
    OWCookieDomain *domain;
    
    [domainLock lock];
    _locked_checkCookiesLoaded();
    
    if (!(domain = [domainsByName objectForKey:name])) {
        domain = [[self alloc] initWithDomain:name];
        [domainsByName setObject:domain forKey:name];
        [domain release];
        if (shouldNotify)
            [self locked_didChange];
    }
    
    [domainLock unlock];
    
    return domain;
}

- (void)addCookie:(OWCookie *)cookie andNotify:(BOOL)shouldNotify;
{
    OWCookiePath *path;
    
    [domainLock lock];
    path = [self locked_pathNamed:[cookie path] shouldCreate:YES];
    [path addCookie:cookie andNotify:shouldNotify];
    [domainLock unlock];
}

- (OWCookiePath *)locked_pathNamed:(NSString *)pathName shouldCreate:(BOOL)shouldCreate;
{
    unsigned int pathIndex;
    OWCookiePath *path;
    
    [domainLock lock];

    pathIndex = [_cookiePaths count];
    while (pathIndex--) {
        path = [_cookiePaths objectAtIndex:pathIndex];
        if ([[path path] isEqualToString:pathName]) {
            [path retain];
            goto found;
        }
    }

    if (shouldCreate) {
        path = [[OWCookiePath alloc] initWithPath:pathName];
        [_cookiePaths insertObject:path inArraySortedUsingSelector:@selector(compare:)];
    } else
        path = nil;

found:
    [domainLock unlock];
    
    return [path autorelease];
}

+ (NSArray *)searchDomainsForDomain:(NSString *)aDomain;
{
    NSMutableArray *searchDomains;
    NSMutableArray *domainComponents;
    unsigned int domainComponentCount;
    unsigned int minimumDomainComponents;

    if (aDomain == nil)
        return nil;
    domainComponents = [[aDomain componentsSeparatedByString:@"."] mutableCopy];
    domainComponentCount = [domainComponents count];
    minimumDomainComponents = [OWURL minimumDomainComponentsForDomainComponents:domainComponents];
    searchDomains = [NSMutableArray arrayWithCapacity:domainComponentCount];
    [searchDomains addObject:[@"." stringByAppendingString:aDomain]];
    [searchDomains addObject:aDomain];
    // Apple sets localhost cookie domains to "localhost.local"
    if (domainComponentCount == 1)
        [searchDomains addObject:[NSString stringWithFormat:@"%@.local", aDomain]];
    if (domainComponentCount < minimumDomainComponents) {
        [domainComponents release];
	return searchDomains;
    }
    domainComponentCount -= minimumDomainComponents;
    while (domainComponentCount--) {
	NSString *searchDomain;

	[domainComponents removeObjectAtIndex:0];
	searchDomain = [domainComponents componentsJoinedByString:@"."];
	[searchDomains addObject:[@"." stringByAppendingString:searchDomain]];
    }
    [domainComponents release];
    return searchDomains;
}

+ (OWCookie *)cookieFromHeaderValue:(NSString *)headerValue defaultDomain:(NSString *)defaultDomain defaultPath:(NSString *)defaultPath;
{
    NSString *aName, *aValue;
    NSDate *aDate = nil;
    NSString *aDomain = defaultDomain, *aPath = defaultPath;
    BOOL isSecure = NO;
    NSScanner *scanner;
    NSString *aKey;
    
    scanner = [NSScanner scannerWithString:headerValue];
    if (![scanner scanUpToCharactersFromSet:endNameSet intoString:&aName])
        aName = [NSString string];
    
    if (![scanner scanString:@"=" intoString:NULL])
        return nil;

    // Scan the value if possible
    if ([scanner scanUpToCharactersFromSet:endNameValueSet intoString:&aValue]) {
        unsigned int valueLength;
        // Remove trailing whitespace
        // This could be more efficient.  (Actually, this whole method could be more efficient:  we should rewrite it using OFStringScanner.)

        valueLength = [aValue length];
        do {
            unichar character;
            
            character = [aValue characterAtIndex:valueLength - 1];
            if (character == ' ' || character == '\t')
                valueLength--;
            else
                break;
        } while (valueLength > 0);
        aValue = [aValue substringToIndex:valueLength];
    } else {
        // If there are no characters, treat it as an empty string.
        aValue = [NSString string];
    }

    [scanner scanCharactersFromSet:endKeySet intoString:NULL];
    while ([scanner scanUpToCharactersFromSet:endKeySet intoString:&aKey]) {
        aKey = [aKey lowercaseString];
        [scanner scanString:@"=" intoString:NULL];
        if ([aKey isEqualToString:@"expires"]) {
            NSString *dateString = nil;

            [scanner scanUpToCharactersFromSet:endDateSet intoString:&dateString];
            if (dateString) {
                aDate = [NSDate dateWithHTTPDateString:dateString];
                if (!aDate) {
                    NSCalendarDate *yearFromNowDate;

                    NSLog(@"OWCookie: could not parse expiration date, expiring cookie in one year");
                    yearFromNowDate = [[NSCalendarDate calendarDate] dateByAddingYears:1 months:0 days:0 hours:0 minutes:0 seconds:0];
                    [yearFromNowDate setCalendarFormat:[OWHTTPSession preferredDateFormat]];
                    aDate = yearFromNowDate;
                }
            }
        } else if ([aKey isEqualToString:@"domain"]) {
            [scanner scanUpToCharactersFromSet:endValueSet intoString:&aDomain];
            if (aDomain != nil) {
                NSArray *domainComponents;
                unsigned int domainComponentCount;
                
                //if the domain and the default domain are not identical(nytimes.com vs www.nytimes.com), there needs to be a '.' at the beginning
                if(defaultDomain != nil && ![aDomain isEqualToString:defaultDomain] && ![aDomain hasPrefix:@"."])
                    aDomain = [NSString stringWithFormat:@".%@",aDomain];
                
                domainComponents = [aDomain componentsSeparatedByString:@"."];
                domainComponentCount = [domainComponents count];
                if (domainComponentCount > 0 && [[domainComponents objectAtIndex:0] isEqualToString:@""]) {
                    // ".co.uk" -> ("", "co", "uk"):  we shouldn't count that initial empty component
                    domainComponentCount--;
                }

                if (OWCookiesDebug)
                    NSLog(@"COOKIES: domainComponents = %@, minimum = %d", domainComponents, [OWURL minimumDomainComponentsForDomainComponents:domainComponents]);

                if (defaultDomain && (![[@"." stringByAppendingString:defaultDomain] hasSuffix:aDomain] || domainComponentCount < [OWURL minimumDomainComponentsForDomainComponents:domainComponents])) {
                    // Sorry, you can't create cookies for other domains, nor can you create cookies for "com" or "co.uk".  Make sure that we allow for the case where there is no default domain (file: urls, for example).
                    aDomain = defaultDomain;
                }
            }
        } else if ([aKey isEqualToString:@"path"]) {
            if (![scanner scanUpToCharactersFromSet:endValueSet intoString:&aPath]) {
                // Some deranged people specify an empty string for the path. Assume they really meant "/" (not the default path, which is more limiting).
                aPath = @"/";
            }
        } else if ([aKey isEqualToString:@"secure"]) {
            isSecure = YES;
        }
        [scanner scanCharactersFromSet:endKeySet intoString:NULL];
    }
        
    return [[[OWCookie alloc] initWithDomain:aDomain path:aPath name:aName value:aValue expirationDate:aDate secure:isSecure] autorelease];
}

- (void)locked_addApplicableCookies:(NSMutableArray *)cookies forPath:(NSString *)aPath urlIsSecure:(BOOL)secure includeRejected:(BOOL)includeRejected;
{
    unsigned int pathIndex;
    OWCookiePath *path;
    
    pathIndex = [_cookiePaths count];
    while (pathIndex--) {
        path = [_cookiePaths objectAtIndex:pathIndex];
        if (![path appliesToPath:aPath])
            continue;
        
        [path addNonExpiredCookiesToArray:cookies usageIsSecure:secure includeRejected:includeRejected];
    }
}

//
// OW5 XML Cookie file parsing
//

static NSString *OWCookiesElementName = @"OmniWebCookies";

+ (BOOL)locked_readOW5Cookies;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSString *filename = [self cookiePath:OW5CookieFileName];
    if (filename == nil)
        return NO;
        
    OFXMLWhitespaceBehavior *whitespaceBehavior = [[OFXMLWhitespaceBehavior alloc] init];
    [whitespaceBehavior setBehavior:OFXMLWhitespaceBehaviorTypeIgnore forElementName:OWCookiesElementName];
    
    NSData *cookieData = [NSData dataWithContentsOfFile:filename];
    if (cookieData == nil || [cookieData length] == 0)
        return NO;
        
    OFXMLDocument *document = [[OFXMLDocument alloc] initWithData:cookieData whitespaceBehavior:whitespaceBehavior];
    [whitespaceBehavior release];

    // Read domains
    OFXMLCursor *domainCursor = [document createCursor];
    OFXMLElement *domainElement;
    while ((domainElement = [domainCursor nextChild]) != nil) {
        OBASSERT([domainElement isKindOfClass:[OFXMLElement class]]);
        
        // Domain name
        NSString *domainName = [domainElement attributeNamed:@"name"];
        if ([NSString isEmptyString:domainName])
            continue;
        
        // Create domain
        OWCookieDomain *domain = [OWCookieDomain domainNamed:domainName andNotify:NO];
        
        // Read children
        NSArray *children = [domainElement children];
        unsigned int childCount = [children count];
        unsigned int childIndex;
        
        for (childIndex = 0; childIndex < childCount; childIndex++) {
            OFXMLElement *cookieElement = [children objectAtIndex:childIndex];
            OBASSERT([cookieElement isKindOfClass:[OFXMLElement class]]);
            
            NSString *name = [cookieElement attributeNamed:@"name"];
            NSString *path = [cookieElement attributeNamed:@"path"];
            NSString *value = [cookieElement attributeNamed:@"value"];
            NSString *expiresString = [cookieElement attributeNamed:@"expires"];
            NSDate *expires = expiresString != nil ? [NSDate dateWithTimeIntervalSinceReferenceDate:[expiresString doubleValue]] : nil;
            BOOL secure = [[cookieElement attributeNamed:@"secure"] boolValue];
            NSString *site = [cookieElement attributeNamed:@"receivedBySite"];
            
            OWCookie *cookie = [[OWCookie alloc] initWithDomain:[domain name] path:path name:name value:value expirationDate:expires secure:secure];
            [cookie setStatus:OWCookieSavedStatus andNotify:NO];
            [cookie setSite:site];
            
            [domain addCookie:cookie andNotify:NO];
            [cookie release];
        }
    }

    [domainCursor release];
    [document release];
    
    [pool release];
    
    return YES;
}

- (id)initWithDomain:(NSString *)domain;
{
    _name = [domain copy];
    _nameDomain = [[OWURL domainForHostname:_name] retain];
    _cookiePaths = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc;
{
    [_name release];
    [_nameDomain release];
    [_cookiePaths release];
    [super dealloc];
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *dict;
    
    dict = [super debugDictionary];
    [dict setObject:_name forKey:@"name"];
    [dict setObject:_cookiePaths forKey:@"cookiePaths"];
    
    return dict;
}

@end
