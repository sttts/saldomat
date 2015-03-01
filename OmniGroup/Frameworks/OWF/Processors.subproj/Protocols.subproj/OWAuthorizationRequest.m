// Copyright 2001-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWAuthorizationRequest.h"
#import "OWAuthorizationCredential.h"
#import "OWNetLocation.h"
#import "OWPipeline.h"
#import "OWHeaderDictionary.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "OWAuthSchemeHTTPBasic.h"
#import "OWAuthSchemeHTTPDigest.h"
#import "OWAuthorization-KeychainFunctions.h"

// TODO: None of the strings in here are localizable

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/OWAuthorizationRequest.m 68913 2005-10-03 19:36:19Z kc $")

@interface OWAuthorizationRequest (Private)
- (NSArray *)findCachedCredentials;
- (BOOL)_schemeIsSupported:(NSString *)schemeString;
- (NSComparisonResult)_compareChallenge:(NSDictionary *)a toChallenge:(NSDictionary *)b;
- (NSDictionary *)_bestSupportedScheme:(NSArray *)challenges;
- (void)_gatherCredentials;
- (void)mainThreadGetPassword:(NSDictionary *)useParameters;
- (void)getPasswordFallback:(NSDictionary *)useParameters;
- (OWAuthorizationCredential *)_credentialForUsername:(NSString *)aName password:(id)aPassword challenge:(NSDictionary *)useParameters;

static BOOL credentialMatchesHTTPChallenge(OWAuthorizationCredential *credential, NSArray *challenges);

@end

@implementation OWAuthorizationRequest

static Class authorizationRequestClass = nil;

#ifdef DEBUG_wiml
static BOOL OWAuthorizationDebug = YES;
#else
static BOOL OWAuthorizationDebug = NO;
#endif
static NSLock *credentialCacheLock = nil;
static OFMultiValueDictionary *credentialCache = nil;

NSString *OWAuthorizationCacheChangedNotificationName = @"OWAuthorizationCacheChanged";

+ (Class)authorizationRequestClass;
{
    if (authorizationRequestClass == nil)
        return self;
    else
        return authorizationRequestClass;
}

+ (void)setAuthorizationRequestClass:(Class)aClass;
{
    authorizationRequestClass = aClass;
}

+ (NSData *)entropy;
{
    NSAutoreleasePool *pool;
    NSMutableString *buffer;
    NSData *entropyBytes;
    NSEnumerator *cacheKeyEnumerator;
    NSString *cacheKey;
    NSArray *cacheValue;
    
    pool = [[NSAutoreleasePool alloc] init];
    buffer = [[NSMutableString alloc] init];
    [credentialCacheLock lock];
    cacheKeyEnumerator = [credentialCache keyEnumerator];
    while ((cacheKey = [cacheKeyEnumerator nextObject]) != nil) {
        cacheValue = [credentialCache arrayForKey:cacheKey];
        
        [buffer appendFormat:@"{*}%lu;%lu;%@{*}", (unsigned long)cacheKey, (unsigned long)cacheValue, cacheKey];
        NS_DURING {
            [buffer appendString:[cacheValue description]];
        } NS_HANDLER {
            NSLog(@"Ignoring unexpected exception: %@", localException);
        } NS_ENDHANDLER;
    }
    [credentialCacheLock unlock];
        
    entropyBytes = [buffer dataUsingEncoding:[buffer fastestEncoding] allowLossyConversion:YES];
    [buffer release];
    entropyBytes = [[entropyBytes sha1Signature] retain];
    
    [pool release];
    
    return [entropyBytes autorelease];
}

+ (void)initialize;
{
    OBINITIALIZE;

    credentialCache = [[OFMultiValueDictionary alloc] init];
    credentialCacheLock = [[NSLock alloc] init];
}

+ (void)flushCache:(id)sender;
{
    NSEnumerator *cacheKeyEnumerator;
    NSString *key;
    id object;
    BOOL flushedAnything = NO;
    
    [credentialCacheLock lock];
    // This is pretty inefficient, but who cares
    cacheKeyEnumerator = [[credentialCache allKeys] objectEnumerator];  // don't use -keyEnumerator because we're changing the dictionary while iterating
    while ((key = [cacheKeyEnumerator nextObject]) != nil) {
        while ((object = [credentialCache lastObjectForKey:key]) != nil) {
            [credentialCache removeObject:object forKey:key];
            flushedAnything = YES;
        }
    }
    [credentialCacheLock unlock];
    
    if (flushedAnything) {
        NSNotification *notification;

        notification = [NSNotification notificationWithName:OWAuthorizationCacheChangedNotificationName object:nil userInfo:nil];
        [[NSNotificationCenter defaultCenter] mainThreadPerformSelector:@selector(postNotification:) withObject:notification];
    }
}


- initForType:(enum OWAuthorizationType)authType netLocation:(OWNetLocation *)aHost defaultPort:(unsigned)defaultPort context:(id <OWProcessorContext,NSObject>)aPipe challenge:(OWHeaderDictionary *)aChallenge promptForMoreThan:(NSArray *)iWantMore;
{
    NSString *portSpecification;
    
    if ([super init] == nil)
        return nil;
    
    type = authType;
    server = [aHost retain];
    pipeline = [aPipe retain];
    challenge = [aChallenge retain];
    theseDidntWork = [iWantMore retain];
    
    portSpecification = [server port];
    if (portSpecification != nil && [portSpecification length] != 0) {
        parsedPortnumber = [portSpecification unsignedIntValue];
    } else {
        parsedPortnumber = 0;
    }
    defaultPortnumber = defaultPort;
    parsedHostname = [[[server hostname] lowercaseString] retain];
    parsedChallenges = [[isa findParametersOfType:type headers:challenge] retain];
	
    requestCondition = [[NSConditionLock alloc] initWithCondition:NO];
    results = nil;

    // If our nonce is stale, that means the last of the theseDidntWork actually had the right username and password, it just needs updating...
    NSDictionary *bestChallenge = [self _bestSupportedScheme:parsedChallenges];
    if ([[bestChallenge objectForKey:@"stale"] isEqualToString:@"true"] && [theseDidntWork count] > 0) {
        [requestCondition lock];
        // this will need review if we ever add other auth schemes that may also become stale
        OWAuthSchemeHTTPDigest *newCredential = [[OWAuthSchemeHTTPDigest alloc] initAsCopyOf:[theseDidntWork lastObject]];
        [newCredential setParameters:bestChallenge];
        [isa cacheCredentialIfAbsent:newCredential];
        results = [[NSArray alloc] initWithObjects:newCredential, nil];
        [newCredential release];
        [requestCondition unlockWithCondition:YES];
    } else {
        if (![self checkForSatisfaction])
            [self _gatherCredentials];
    }

    return self;
}

- (void)dealloc;
{
    [server release];
    [pipeline release];
    [challenge release];
    [theseDidntWork release];
    [requestCondition release];
    [results release];
    [parsedHostname release];
    [parsedChallenges release];
    
    [super dealloc];
}

- (enum OWAuthorizationType)type;
{
    return type;
}

- (NSString *)hostname;
{
    return parsedHostname;
}

- (unsigned int)port;
{
    return parsedPortnumber ? parsedPortnumber : defaultPortnumber;
}

- (BOOL)checkForSatisfaction;
{
    BOOL satisfied = NO;
    
    [requestCondition lock];
    
    if ([requestCondition condition] == YES) {
        [requestCondition unlock];
        return YES;
    } else {
        // If we've already tried at least one authorization that failed, why not try no authorization at all, just for kicks?  This is because resources in Public folders on Mac.com work if you give them no credential at all, but will give you a permissions error if you try to give them the wrong credential.
        if ([theseDidntWork count] > 0 && ![theseDidntWork containsObjectIdenticalTo:[OWAuthorizationCredential nullCredential]]) {
            satisfied = YES;
            [results release];
            results = [[NSArray alloc] initWithObjects:[OWAuthorizationCredential nullCredential], nil];
        } else {
            NSArray *cacheContents;

            // find cached credentials
            NS_DURING {
                cacheContents = [self findCachedCredentials];
            } NS_HANDLER {
                [requestCondition unlockWithCondition:YES];
                // This will indicate an error condition to the processor that is blocked on us, so we are "satisfied"
                return YES;
            } NS_ENDHANDLER;
            
            if (theseDidntWork) {
                NSMutableArray *mutableResults = [[NSMutableArray alloc] init];
                unsigned int credentialIndex, credentialCount = [cacheContents count];
                for (credentialIndex = 0; credentialIndex < credentialCount; credentialIndex++) {
                    OWAuthorizationCredential *aCredential = [cacheContents objectAtIndex:credentialIndex];
                    if ([theseDidntWork indexOfObjectIdenticalTo:aCredential] == NSNotFound) {
                        [mutableResults addObject:aCredential];
                        satisfied = YES;
                    }
                }
                if (satisfied) {
                    [results release];
                    results = mutableResults;
                }
            } else {
                // If theseDidntWork is nil, then the caller doesn't want to do anything expensive, they're just optimistically querying the cache.  In that case, we're satisfied no matter what -findCachedCredentials returned.
                
                satisfied = YES;
                [results release];
                if (cacheContents == nil)
                    results = [[NSArray alloc] init];
                else
                    results = [[NSArray alloc] initWithArray:cacheContents];
            }
        }
    }
        
    [requestCondition unlockWithCondition:satisfied];
    
    return satisfied;
}

- (NSArray *)credentials;
{
    NSArray *result;
    
    [requestCondition lockWhenCondition:YES];
    
    result = [[results retain] autorelease];  // caller will probably release us immediately after calling this method
    
    [requestCondition unlock];
    
    return result;
}

- (NSString *)errorString;
{
    if (!errorString && !results)
        return NSLocalizedStringFromTableInBundle(@"No useful credentials found or generated.", @"OWF", [OWAuthorizationRequest bundle], @"error when authenticating - unable to find any credentials [passwords or other info] which can be used for this server");
    return errorString;
}

- (void)failedToCreateCredentials:(NSString *)reason;
{
    [requestCondition lock];
    if (!errorString && reason)
        errorString = [reason retain];
    if (OWAuthorizationDebug)
        NSLog(@"cred failure: reason=%@", reason);
    [requestCondition unlockWithCondition:YES];
}

+ (BOOL)cacheCredentialIfAbsent:(OWAuthorizationCredential *)newCredential;
{
    NSEnumerator *credentialEnumerator;
    NSMutableArray *credentialsToReplace;
    NSArray *cachedCredentials;
    OWAuthorizationCredential *cachedCredential;
    NSString *cacheKey;
    BOOL alreadyHaveIt;

    if (!newCredential)
        return NO;
    
    cacheKey = [newCredential hostname];
    [credentialCacheLock lock];
    alreadyHaveIt = NO;
    credentialsToReplace = [[NSMutableArray alloc] init];
    cachedCredentials = [credentialCache arrayForKey:cacheKey];
    credentialEnumerator = [cachedCredentials objectEnumerator];
    while ((cachedCredential = [credentialEnumerator nextObject]) != nil) {
        int compare;

        compare = [cachedCredential compareToNewCredential:newCredential];
        if (compare == OWCredentialIsEquivalent) {
            alreadyHaveIt = YES;
            break;
        }
        if (compare == OWCredentialWouldReplace)
            [credentialsToReplace addObject:cachedCredential];
        // otherwise, compare == OWCredentialIsUnrelated
    }
    
    if (!alreadyHaveIt) {
        credentialEnumerator = [credentialsToReplace objectEnumerator];
        while ((cachedCredential = [credentialEnumerator nextObject]) != nil) {
            [credentialCache removeObject:cachedCredential forKey:cacheKey];
        }
    
        [credentialCache addObject:newCredential forKey:cacheKey];

        // Instead of actually getting rid of replaced crdentials, we move them to the end of the array. We need to do this in case there are two nearly-identical items in the keychain: if we don't do this, then we'll loop forever fetching one and then the other, not realizing we've already seen them both. TODO: Think about this. 
        [credentialCache addObjects:credentialsToReplace forKey:cacheKey];
    }
    [credentialsToReplace release];
        
    [credentialCacheLock unlock];
    
    if (OWAuthorizationDebug)
        NSLog(@"adding credential (a.h.i.=%d) %@", alreadyHaveIt, newCredential);
        
    if (!alreadyHaveIt) {
        // TODO: use the main-thread-ified notification queue?
        NSNotification *note = [NSNotification notificationWithName:OWAuthorizationCacheChangedNotificationName object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:cacheKey, @"key", nil]];
        [[NSNotificationCenter defaultCenter] mainThreadPerformSelector:@selector(postNotification:) withObject:note];
    }
    
    return !alreadyHaveIt;
}

- (BOOL)cacheUsername:(NSString *)aName password:(id)aPassword forChallenge:(NSDictionary *)useParameters;
{
    OWAuthorizationCredential *newCredential;

    newCredential = [self _credentialForUsername:aName password:aPassword challenge:useParameters];
    if (newCredential) {
        return [[self class] cacheCredentialIfAbsent:newCredential];
    } else
        return NO;
}

- (BOOL)cacheUsername:(NSString *)aName password:(id)aPassword forChallenge:(NSDictionary *)useParameters saveInKeychain:(BOOL)saveInKeychain;
{
    OSType protocol;
    OSType authType;
    OSStatus keychainStatus;
    NSString *realm;

    if (OWAuthorizationDebug)
        NSLog(@"cacheUsername[%@] psw[%@] save=%d parms=%@", aName, aPassword, saveInKeychain, useParameters);

    if (![self cacheUsername:aName password:aPassword forChallenge:useParameters])
        return NO;

    if (!saveInKeychain)
        return YES;
    
    switch (type) {
        case OWAuth_HTTP:
        case OWAuth_HTTP_Proxy:
        default:  // to make the compiler happy; should never happen
            protocol = kSecProtocolTypeHTTP;
            break;
        case OWAuth_FTP:
            protocol = kSecProtocolTypeFTP;
            break;
        case OWAuth_NNTP:
            protocol = kSecProtocolTypeNNTP;
            break;
    }

    if ([[useParameters objectForKey:@"scheme"] isEqual:@"digest"])
        authType = kSecAuthenticationTypeHTTPDigest;
    else
        authType = kSecAuthenticationTypeDefault;

    realm = [useParameters objectForKey:@"realm"];

    keychainStatus = OWKCUpdateInternetPassword(parsedHostname, realm, aName, parsedPortnumber ? parsedPortnumber : defaultPortnumber, protocol, authType, [aPassword dataUsingEncoding:[NSString defaultCStringEncoding]]);
    if (keychainStatus != noErr)
        [[NSException exceptionWithName:OWAuthorizationRequestKeychainExceptionName reason:[NSString stringWithFormat:@"Unable to store password in keychain (error code %d)", keychainStatus] userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:keychainStatus], OWAuthorizationRequestKeychainExceptionKeychainStatusKey, nil]] raise];

    return YES;
}

+ (NSArray *)findParametersOfType:(enum OWAuthorizationType)authType headers:(OWHeaderDictionary *)httpChallenge
{
    NSMutableArray *parmsArray;
    NSArray *headers;
    NSMutableCharacterSet *delimiterSet;
    unsigned int headerIndex, headerCount;
    
    if (authType == OWAuth_HTTP) {
        headers = [httpChallenge stringArrayForKey:@"WWW-Authenticate"];
        if (headers == nil) {
            // Some non-RFC2068-compliant servers give us a header with the wrong name but otherwise valid
            headers = [httpChallenge stringArrayForKey:@"www-authorization"];
        }
    } else if (authType == OWAuth_HTTP_Proxy) {
        headers = [httpChallenge stringArrayForKey:@"Proxy-Authenticate"];
    } else {
        headers = nil;
    }

    delimiterSet = [[NSMutableCharacterSet alloc] init]; // inefficient, TODO
    [delimiterSet addCharactersInString:@"=\""];
    [delimiterSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    [delimiterSet autorelease];

    headerCount = headers != nil ? [headers count] : 0;
    parmsArray = [[NSMutableArray alloc] initWithCapacity:headerCount];
    for (headerIndex = 0; headerIndex < headerCount; headerIndex++) {
        NSMutableDictionary *parameters;
        OFStringScanner *scanner;
        NSString *token, *value;
        
        scanner = [[OFStringScanner alloc] initWithString:[headers objectAtIndex:headerIndex]];
        token = [scanner readFullTokenWithDelimiters:delimiterSet forceLowercase:YES];
        if (!token)
            continue;
        parameters = [[NSMutableDictionary alloc] init];
        [parameters setObject:token forKey:@"scheme"];
        
        for (;;) {
            unichar peeked;

            while ((peeked = scannerPeekCharacter(scanner)) != OFCharacterScannerEndOfDataCharacter && [delimiterSet characterIsMember:peeked])
                  scannerSkipPeekedCharacter(scanner);

            if (peeked == OFCharacterScannerEndOfDataCharacter)
                break;

            token = [scanner readFullTokenWithDelimiters:delimiterSet forceLowercase:YES];
            if (token == nil)
                break;

            if (!scannerScanUpToCharacter(scanner, '='))
                break;

            while ((peeked = scannerPeekCharacter(scanner)) != OFCharacterScannerEndOfDataCharacter && [delimiterSet characterIsMember:peeked] && (peeked != '"'))
                  scannerSkipPeekedCharacter(scanner);

            if (peeked == '"') {
                // Read a double-quoted string, including backslash-quoting of quotes and backslashes.
                NSMutableString *fragment;
                unichar character;
 
                fragment = [[NSMutableString alloc] init];
                scannerSkipPeekedCharacter(scanner);  // skip the open-quote
                while ((character = scannerReadCharacter(scanner)) != OFCharacterScannerEndOfDataCharacter) {
                    if (character == '"')   // close-quote?
                        break;
                    if (character == '\\')  // backslash escape?
                        character = scannerReadCharacter(scanner);
                    [fragment appendCharacter:character];
                }
 
                value = [[fragment copy] autorelease];
                [fragment release];
            } else {
                value = [scanner readFullTokenWithDelimiters:delimiterSet forceLowercase:NO];
            }
 
            [parameters setObject:value forKey:token];
 
            while ((peeked = scannerPeekCharacter(scanner)) != OFCharacterScannerEndOfDataCharacter && ([delimiterSet characterIsMember:peeked] || (peeked == ',')))
                  scannerSkipPeekedCharacter(scanner);
        }
        
        [parmsArray addObject:parameters];
        [scanner release];
        [parameters release];
    }
    
    if (OWAuthorizationDebug && [parmsArray count])
        NSLog(@"Auth parameters: %@", parmsArray);
    
    return [parmsArray autorelease];
}

@end

@implementation OWAuthorizationRequest (Private)

// do we even support the given authentication scheme?
- (BOOL)_schemeIsSupported:(NSString *)schemeString;
{
    if ([schemeString caseInsensitiveCompare:@"Basic"] == NSOrderedSame)
        return YES;
    
    if ([schemeString caseInsensitiveCompare:@"Digest"] == NSOrderedSame)
        return YES;
    
    return NO;
}

/* Compare two challenges and decide which one is better. Both have already been tested by _schemeIsSupported:. */
- (NSComparisonResult)_compareChallenge:(NSDictionary *)a toChallenge:(NSDictionary *)b
{
    NSString *schemeA = [[a objectForKey:@"scheme"] lowercaseString];
    NSString *schemeB = [[b objectForKey:@"scheme"] lowercaseString];

    if ([schemeA isEqualToString:schemeB]) {
        // If we were clever, we might want to pick the one which specifies a realm for which we have a password, or things like that. We're not that clever.
        // We might also be able to compare different Digest challenges and choose the mose secure one.
        return NSOrderedSame;  
    }
    
    if ([schemeA isEqualToString:@"basic"] && [schemeB isEqualToString:@"digest"])
        return NSOrderedAscending;
    if ([schemeA isEqualToString:@"digest"] && [schemeB isEqualToString:@"basic"])
        return NSOrderedDescending;

    OBASSERT(NO);  // shouldn't be able to get here.
    return NSOrderedSame;
}

- (NSDictionary *)_bestSupportedScheme:(NSArray *)challenges
{
    unsigned int challengeIndex, challengeCount = [challenges count];
    NSDictionary *bestSoFar;

    bestSoFar = nil;
    for (challengeIndex = 0; challengeIndex < challengeCount; challengeIndex++) {
        NSDictionary *aChallenge;

        aChallenge = [challenges objectAtIndex:challengeIndex];
        if (![self _schemeIsSupported:[aChallenge objectForKey:@"scheme"]])
            continue;
        
        if (!bestSoFar ||
            ([self _compareChallenge:bestSoFar toChallenge:aChallenge] == NSOrderedAscending))
            bestSoFar = aChallenge;
    }

    return bestSoFar;
}

- (void)_gatherCredentials;
{
    NSDictionary *useParameters;

    switch(type) {
        case OWAuth_HTTP:
        case OWAuth_HTTP_Proxy:
            if (parsedChallenges != nil && [parsedChallenges count] != 0) {
                useParameters = [self _bestSupportedScheme:parsedChallenges];
                
                if (!useParameters) {
                    NSString *msg = NSLocalizedStringFromTableInBundle(@"Server requested authentication, but OmniWeb does not support the requested authentication method(s).", @"OWF", [OWAuthorizationRequest bundle], @"error when authenticating - omniweb does not support any of the methods that the server accepts");
                    [self failedToCreateCredentials:msg];
                    return;
                }
            } else {
                NSString *msg = NSLocalizedStringFromTableInBundle(@"Server requested authentication, but did not provide an authentication method.", @"OWF", [OWAuthorizationRequest bundle], @"error when authenticating - server requires authentication but doesnt supply any methods for authenticating");
                [self failedToCreateCredentials:msg];
                return;
            }
            break;
        case OWAuth_FTP:
            // FTP authentication is always the simple USER/PASS mechanism.  No parameters.
            useParameters = nil;
            break;
        case OWAuth_NNTP:
        default:
            // These don't have any use parameters, and aren't implemented yet anyway
            useParameters = nil;
            break;
    }
    
    // All the schemes we support or are likely to support in the near future are basically password-based schemes. So, just call out to the main thread to get a password. (We have to use the main thread for user interaction; we also have to use it for keychain interaction because something in the keychain libs isn't threadsafe, at least in 4K29.)
    
    // But first: check to see if the password is specified in the URL.
    if ([server username] && [server password]) {
        if ([self cacheUsername:[server username] password:[server password] forChallenge:useParameters] && [self checkForSatisfaction])
            return; // done.
    }
    
    // Okay, now do the main-thread stuff.
    [self mainThreadPerformSelector:@selector(mainThreadGetPassword:) withObject:useParameters];
}

- (void)mainThreadGetPassword:(NSDictionary *)useParameters;
{
    NS_DURING {
    
        // It's not at all unlikely for someone else to have gotten these credentials while we were waiting for our turn in the main thread
        if ([self checkForSatisfaction])
            NS_VOIDRETURN;
    
        if ([self getPasswordFromKeychain:useParameters] && [self checkForSatisfaction])
            NS_VOIDRETURN;
    
        [self getPasswordFallback:useParameters];

    } NS_HANDLER {
        [requestCondition lock];
        // the results are presumably still nil, since an exception is raised. Signaling the completion condition when the results are nil indicates to the caller that an error of some sort occurred.
        if (!errorString) {
            NSString *fmt = NSLocalizedStringFromTableInBundle(@"Exception raised while gathering credentials: %@ (%@)", @"OWF", [OWAuthorizationRequest bundle], @"error when authenticating - an exception was raised. parameters are the exception reason and the exception name.");
            errorString = [[NSString alloc] initWithFormat:fmt, [localException reason], [localException name]];
        }
        [requestCondition unlockWithCondition:YES];
        NSLog(@"%@", errorString);
        // We could re-raise, but there's no point, since we're being called from the event loop. So we just log the exception.
        // TODO: Should we run an alert panel or something? Maybe the routine in OF that invokes us should run the panel? hmmm.
    } NS_ENDHANDLER;    
}

- (void)getPasswordFallback:(NSDictionary *)useParameters;
{
    // This method is here to be overridden by subclasses. The default implementation just signals to the caller that no credentials could be created. Subclasses should attempt to create credentials and only call us if they fail.
    if (![self checkForSatisfaction])
        [self failedToCreateCredentials:nil];
}

- (NSArray *)findCachedCredentials;
{
    if (parsedHostname == nil)
        return [NSArray array];
    
    // Look at the credential cache and retrieve everything relating to this hostname.
    
    NSMutableArray *myCacheLine = [[NSMutableArray alloc] init];
    
    [credentialCacheLock lock];
    NS_DURING {
        NSArray *cacheEntry;
 
        cacheEntry = [credentialCache arrayForKey:parsedHostname];
        if (cacheEntry)
            [myCacheLine addObjectsFromArray:cacheEntry];
    } NS_HANDLER {
        NSString *fmt;
        [credentialCacheLock unlock];
        [errorString release];
        fmt = NSLocalizedStringFromTableInBundle(@"Credential cache access exception: %@ (%@)", @"OWF", [OWAuthorizationRequest bundle], @"error when authenticating - exception raised while using the credentials cache - parameters are exception reason and name - this should rarely if ever happen");
        errorString = [[NSString alloc] initWithFormat:fmt, [localException reason], [localException name]];
        NSLog(@"%@", errorString);
        [myCacheLine release];
        [localException raise];
    } NS_ENDHANDLER;
    [credentialCacheLock unlock];
    
    [myCacheLine autorelease];
    
    if (OWAuthorizationDebug)
        NSLog(@"findCachedCredentials: host cache = %@", [myCacheLine description]);

    
    // Run through the credentials we've retrieved from the cache, and remove all of the credentials that don't relate to this request (wrong scheme, port, realm, etc.)
    unsigned int myPort = parsedPortnumber > 0 ? parsedPortnumber : defaultPortnumber;
    unsigned int credentialIndex = [myCacheLine count];
    while (credentialIndex > 0) {
        OWAuthorizationCredential *credential;
        BOOL credentialValid;
        
        credential = [myCacheLine objectAtIndex:--credentialIndex];
        credentialValid = [credential type] == [self type];
        
        if (credentialValid && myPort != [credential port] && !([credential port] < 1 && myPort == defaultPortnumber))
            credentialValid = NO;

#warning TODO - match username? password? hmmmm?
        
        // perform any protocol or auth-type specific checks
        if (credentialValid)
            switch ([self type]) {
                case OWAuth_HTTP:
                case OWAuth_HTTP_Proxy:
                    // If there are no challenges, send the cached credentials to avoid double round trips for everything
                    if ([parsedChallenges count] != 0)
                        credentialValid = credentialMatchesHTTPChallenge(credential, parsedChallenges);
                    break;
                case OWAuth_FTP:
                case OWAuth_NNTP:
                    // These types do not have an independent concept of realm, so we use the username
                    if ([server username] != nil && ![[credential realm] isEqual:[server username]])
                        credentialValid = NO;
            }

        // TODO: Credential expiration
        
        if (!credentialValid && OWAuthorizationDebug)
            NSLog(@"findCachedCredentials: discarding %@", credential);

        if (!credentialValid) 
            [myCacheLine removeObjectAtIndex:credentialIndex];
    }
            
    return myCacheLine;
}

static BOOL credentialMatchesHTTPChallenge(OWAuthorizationCredential *credential, NSArray *challenges)
{
    unsigned int challengeIndex, challengeCount;
    
    challengeCount = [challenges count];
    for (challengeIndex = 0; challengeIndex < challengeCount; challengeIndex ++) {
        NSDictionary *challenge;

        challenge = [challenges objectAtIndex:challengeIndex];
        if ([credential appliesToHTTPChallenge:challenge])
            return YES;
    }
    
    return NO;
}

- (OWAuthorizationCredential *)_credentialForUsername:(NSString *)aName password:(id)aPassword challenge:(NSDictionary *)useParameters
{
    NSString *scheme;
    OWAuthorizationCredential *newCredential = nil;
    
    scheme = [useParameters objectForKey:@"scheme"];
    if (type == OWAuth_HTTP || type == OWAuth_HTTP_Proxy) {
        if ([scheme caseInsensitiveCompare:@"Basic"] == NSOrderedSame) {
            newCredential = [[OWAuthSchemeHTTPBasic alloc] initForRequest:self realm:[useParameters objectForKey:@"realm"] username:aName password:aPassword];
        } else if ([scheme caseInsensitiveCompare:@"Digest"] == NSOrderedSame) {
            newCredential = [[OWAuthSchemeHTTPDigest alloc] initForRequest:self realm:[useParameters objectForKey:@"realm"] username:aName password:aPassword];
            [(OWAuthSchemeHTTPDigest *)newCredential setParameters:useParameters];
        }
    } else if (type == OWAuth_FTP) {
        // FTP currently uses a generic Password credential but with realm == username
        newCredential = [[OWAuthorizationPassword alloc] initForRequest:self realm:aName username:aName password:aPassword];
    }
    
    if (!newCredential)
        NSLog(@"Don't know how to create a credential for type=%d scheme=%@", type, scheme);
    
    return [newCredential autorelease];
}

@end

@implementation OWAuthorizationRequest (KeychainPrivate)

- (NSSet *)keychainTags;
{
    NSMutableSet *knownKeychainTags;
    
    knownKeychainTags = [[[NSMutableSet alloc] init] autorelease];
    [credentialCacheLock lock];
    NS_DURING {
        NSArray *line;
        unsigned int credentialIndex, credentialCount;
        
        line = [credentialCache arrayForKey:parsedHostname];
        credentialCount = [line count];
        for (credentialIndex = 0; credentialIndex < credentialCount; credentialIndex++) {
            id tag;

            tag = [[line objectAtIndex:credentialIndex] keychainTag];
            if (tag != nil)
                [knownKeychainTags addObject:tag];
        }
        [credentialCacheLock unlock];
    } NS_HANDLER {
        [credentialCacheLock unlock];
        [localException raise];
    } NS_ENDHANDLER;
    
    return knownKeychainTags;
}
    
- (BOOL)getPasswordFromKeychain:(NSDictionary *)useParameters;
{
    NSMutableDictionary *search;
    NSString *realm = nil;
    NSString *scheme;
    NSString *username;
    SecAuthenticationType authType = 0;
    BOOL foundAnything, tryAgain;
    NSSet *knownKeychainTags;
    
    search = [NSMutableDictionary dictionary];

    // Special Case iTools lookup in keychain
    if ([parsedHostname isEqualToString:@"idisk.mac.com"]) {
        [search setObject:[NSNumber numberWithUnsignedInt:kSecGenericPasswordItemClass] forKey:@"class"];
        [search setObject:@"iTools" forKey:@"service"];
    } else {
        username = [server username];
        realm = [useParameters objectForKey:@"realm"];
        scheme = [useParameters objectForKey:@"scheme"];
        if (scheme) {
            if ([scheme caseInsensitiveCompare:@"Basic"] == NSOrderedSame)
                authType = kSecAuthenticationTypeDefault;
            else if([scheme caseInsensitiveCompare:@"Digest"] == NSOrderedSame)
                authType = kSecAuthenticationTypeHTTPDigest;
        }
    
        [search setObject:[NSNumber numberWithUnsignedInt:kSecInternetPasswordItemClass] forKey:@"class"];
        [search setObject:parsedHostname forKey:@"server"];
        if (parsedPortnumber > 0 && parsedPortnumber != defaultPortnumber)
            [search setObject:[NSNumber numberWithInt:parsedPortnumber] forKey:@"port"];
        if (realm != nil) 
            [search setObject:realm forKey:@"securityDomain"];
        if (username != nil)
            [search setObject:username forKey:@"account"];
        
        switch(type) {
            case OWAuth_HTTP:
            case OWAuth_HTTP_Proxy:
                [search setObject:[NSNumber numberWithUnsignedInt:kSecProtocolTypeHTTP] forKey:@"protocol"];
                break;
            case OWAuth_FTP:
                [search setObject:[NSNumber numberWithUnsignedInt:kSecProtocolTypeFTP] forKey:@"protocol"];
                break;
            case OWAuth_NNTP:
                [search setObject:[NSNumber numberWithUnsignedInt:kSecProtocolTypeNNTP] forKey:@"protocol"];
                break;
        }

        if (authType != 0)
            [search setObject:[NSNumber numberWithUnsignedInt:authType] forKey:@"authenticationType"];
    }
    
    // TODO: what are the sematics of the path? security implications?
    // rfc2617 states that we can assume that all Basic/Digest credentials for a given <realm,server> can safely be sent in any request for a path that is 'below' one that they've already been sent to, even if we don't already know that the server considers that URI to be in the same realm. Hm.
    
    if (OWAuthorizationDebug)
        NSLog(@"Keychain search parameters: %@", search);

    knownKeychainTags = [self keychainTags];

    do {
        OSStatus keychainStatus;
        SecKeychainSearchRef grepstate;
        SecKeychainItemRef item;
        
        foundAnything = NO;
        keychainStatus = OWKCBeginKeychainSearch(NULL, search, &grepstate);
        if (OWAuthorizationDebug)
            NSLog(@"beginSearch: keychainStatus=%d", keychainStatus);
        if (keychainStatus == noErr) {
            do {
                NSDictionary *parms;
                BOOL acceptable = YES;

                keychainStatus = SecKeychainSearchCopyNext(grepstate, &item);
                if (OWAuthorizationDebug)
                    NSLog(@"findNext: keychainStatus=%d", keychainStatus);
                if (keychainStatus != noErr)
                    break;
                
                parms = OWKCExtractItemAttributes(item);
                if (OWAuthorizationDebug)
                    NSLog(@"Possible item: %@", parms);
                
                // we don't want the username "Passwords not saved" with nbsp for the spaces
                static NSString *notSavedString = nil;
                if (!notSavedString) {
                    notSavedString = (NSString *)CFStringCreateWithCString(NULL, "Passwords\\312not\\312saved", kCFStringEncodingNonLossyASCII);
                }
                if([[parms objectForKey:@"account"] isEqualToString:notSavedString]){
                    acceptable = NO;
                }
                
                // Don't examine keychain items that are already in our credential cache.
                if ([knownKeychainTags containsObject:parms])
                    acceptable = NO;
            
                // If we've loosened our search critera (eg to accept items with no realm), discard items which do specify a realm which isn't the one we're looking for.
                if (acceptable &&
                    realm && [parms objectForKey:@"securityDomain"] &&
                    ![realm isEqual:[parms objectForKey:@"securityDomain"]])
                    acceptable = NO;
                if (acceptable && [parms objectForKey:@"port"]) {
                    unsigned int itemPortnum;

                    itemPortnum = [[parms objectForKey:@"port"] unsignedIntValue];
                    if (itemPortnum != parsedPortnumber && !(parsedPortnumber == 0 && itemPortnum == defaultPortnumber))
                        acceptable = NO;
                }
                // TODO: Perform similar check for the auth type (it's not good to use a Digest password for Basic authentication, e.g.!)
                // TODO: Perform similar check for the protocol (probably not as important)
            
                if (acceptable) {
                    NSData *itemData = nil;
                
                    keychainStatus = OWKCExtractKeyData(item, &itemData);
                    if (keychainStatus == noErr) {
                        OWAuthorizationCredential *newCredential;

                        // TODO: maybe the password credentials should actually be storing NSDatas? Neither W3C nor Apple seems to have given much thought to what encoding passwords are in, or whether they're conceptually char-arrays vs. octet-arrays, or what.
                        newCredential = [self _credentialForUsername:[parms objectForKey:@"account"] password:[NSString stringWithData:itemData encoding:[NSString defaultCStringEncoding]] challenge:useParameters];
                        [newCredential setKeychainTag:parms];
                        foundAnything = [[self class] cacheCredentialIfAbsent:newCredential];
                    } else if (keychainStatus == userCanceledErr) {
                        NSString *msg = NSLocalizedStringFromTableInBundle(@"User canceled keychain access", @"OWF", [OWAuthorizationRequest bundle], @"error when authenticating using keychain - user canceled");
                        [requestCondition lock];
                        [errorString autorelease];
                        errorString = [msg retain];
                        [requestCondition unlock];  // Store an error message, but don't signal completion.
                        foundAnything = NO;
                        break;  // we will fall through the remaining tests & return NO.
                        // TODO: If we fail here, we may want to continue with a different keychain
                    } else {
                        NSLog(@"error getting key data: keychainStatus=%d", keychainStatus);
                        // TODO: For which errors should we give up on the keychain entirely?
                    }
                    // TODO: make sure we handle cancel vs. denied vs. the unexpected
                }
            
                CFRelease(item);
            } while (!foundAnything && (keychainStatus != userCanceledErr));
            
            CFRelease(grepstate);
        }

        if (keychainStatus == userCanceledErr) {
            tryAgain = NO;
        } else if (keychainStatus != noErr && keychainStatus != errSecItemNotFound) {
            NSLog(@"Keychain error: %d", keychainStatus);
            // TODO: report this better?
            tryAgain = NO;
        } else if (foundAnything == YES && [self checkForSatisfaction]) {
            tryAgain = NO;
        } else {
            // Loosen the search criteria if we've been unsuccessful. Not all attributes are settable (or visible) in Apple's keychain app, so we check to see if ignoring those will get us a matching item. But we loosen the search gradually, so that we'll use a closer match if possible.
            if([search objectForKey:@"authenticationType"]) {
                [search removeObjectForKey:@"authenticationType"];
                tryAgain = YES;
            } else if ([search objectForKey:@"securityDomain"]) {
                [search removeObjectForKey:@"securityDomain"];
                tryAgain = YES;
            } else {
                tryAgain = NO;
            }
        }
    } while (tryAgain);
    
    return foundAnything;
}

@end

NSString *OWAuthorizationRequestKeychainExceptionName = @"OWAuthorizationRequest:KeychainException";
NSString *OWAuthorizationRequestKeychainExceptionKeychainStatusKey = @"OWAuthorizationRequest:KeychainException:KeychainStatus";

