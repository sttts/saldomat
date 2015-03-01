// Copyright 1997-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWHTTPSession.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniNetworking/OmniNetworking.h>

#import "NSDate-OWExtensions.h"
#import "OWAddress.h"
#import "OWAuthorizationCredential.h"
#import "OWAuthorizationRequest.h"
#import "OWCacheControlSettings.h"
#import "OWContent.h"
#import "OWContentCacheProtocols.h"
#import "OWContentType.h"
#import "OWParameterizedContentType.h"
#import "OWCookieDomain.h"
#import "OWCookie.h"
#import "OWDataStream.h"
#import "OWDataStreamCursor.h"
#import "OWFileInfo.h"
#import "OWHeaderDictionary.h"
#import "OWHTTPProcessor.h"
#import "OWHTTPSessionQueue.h"
#import "OWNetLocation.h"
#import "OWSitePreference.h"
#import "OWUnknownDataStreamProcessor.h"
#import "OWURL.h"

#define DEBUG_TRANSACTIONS

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/Protocols.subproj/HTTP.subproj/OWHTTPSession.m 79079 2006-09-07 22:35:32Z kc $")

@interface OWHTTPSession (Private)

+ (void)_readLanguageDefaults;
+ (void)_calculatePrimaryUserAgentInfo;
+ (NSString *)_acceptEncodingsHeaderString;
+ (NSDictionary *)_customBrowserIdentityDictionary;
+ (NSString *)stringForHeader:(NSString *)aHeader value:(id)aValue;

// Generating request
- (NSString *)commandStringForAddress:(OWAddress *)anAddress;
- (NSString *)acceptEncodingHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)acceptCharsetHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)acceptHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)acceptLanguageHeadersStringForPipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)referrerHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)cacheControlHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)validationHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)hostHeaderStringForURL:(OWURL *)aURL;
- (NSString *)rangeStringForProcessor:(OWHTTPProcessor *)aProcessor;
- (NSString *)keepAliveString;
- (NSString *)cookiesForURL:(OWURL *)aURL pipeline:(id <OWProcessorContext>)aPipeline;
- (NSString *)contentTypeHeaderStringForAddress:(OWAddress *)anAddress;
- (NSString *)contentLengthHeaderStringForAddress:(OWAddress *)anAddress;
- (NSString *)contentStringForAddress:(OWAddress *)anAddress;

// Reading results
- (BOOL)readResponseForProcessor:(OWHTTPProcessor *)processor;
- (void)readBodyForProcessor:(OWHTTPProcessor *)processor ignore:(BOOL)ignoreThis;
- (BOOL)readHeadForProcessor:(OWHTTPProcessor *)processor;
- (void)readHeadersForProcessor:(OWHTTPProcessor *)processor;
- (unsigned int)intValueFromHexString:(NSString *)aString;
- (void)readChunkedBodyIntoStream:(OWDataStream *)dataStream precedingSkipLength:(unsigned)precedingSkipLength forProcessor:(OWHTTPProcessor *)processor;
- (void)readStandardBodyIntoStream:(OWDataStream *)dataStream precedingSkipLength:(unsigned)precedingSkipLength forProcessor:(OWHTTPProcessor *)processor;
- (void)readClosingBodyIntoStream:(OWDataStream *)dataStream precedingSkipLength:(unsigned)precedingSkipLength forProcessor:(OWHTTPProcessor *)processor;

// Closing
- (void)_closeSocketStream;

// Exception handling
- (void)notifyProcessor:(OWHTTPProcessor *)aProcessor ofSessionException:(NSException *)sessionException;

@end

@implementation OWHTTPSession

NSString *OWCustomBrowserIdentity = @"OWCustomBrowserIdentity";
NSString *OWCustomIdentityKey = @"__OWCustomIdent__";
NSString *OWBrowserIdentity = @"OWBrowserIdentity";

static BOOL OWHTTPDebug = NO;
static BOOL OWHTTPCredentialsDebug = NO;
static OFPreference *OWHTTPTrustServerContentType;
static NSArray *OWHTTPWorkarounds;
static NSString *preferredDateFormat;
static NSString *acceptLanguageValue = nil;
static NSString *acceptLanguageString = nil;
static NSString *http10VersionString;
static NSString *http11VersionString;
static NSString *endOfLineString;
static NSString *_primaryUserAgentInfo = nil;
static NSMutableArray *languageArray = nil;
static NSCharacterSet *spaceCharacterSet;
static NSCharacterSet *nonTokenCharacterSet;
static OWContentType *textPlainContentType;
static OWContentType *textXMLContentType;
static OWContentType *applicationXMLContentType;
static OWContentType *applicationOctetStreamContentType;
static OWContentType *wildcardContentType;
static NSDictionary *browserIdentDict = nil;
static NSMutableDictionary *encodingPriorityDictionary = nil;
static const float encodingPriorityDictionaryDefaultValue = 0.1;

#define OWHTTPTrustServerContentTypePreferenceKey (@"OWHTTPTrustServerContentType")
#define OWHTTPFakeAcceptHeaderPreferenceKey (@"OWHTTPFakeAcceptHeader")
#define OWHTTPAcceptCharsetHeaderPreferenceKey (@"OWHTTPAcceptCharsetHeader")

+ (void)initialize;
{
    NSMutableCharacterSet *tokenCharacterSet;
    OWContentType *gzipContentType;
    
    OBINITIALIZE;

    http10VersionString = @"HTTP/1.0";
    http11VersionString = @"HTTP/1.1";
    endOfLineString = @"\r\n";
    spaceCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@" "] retain];
    textPlainContentType = [OWContentType contentTypeForString:@"text/plain"];
    textXMLContentType = [OWContentType contentTypeForString:@"text/xml"];
    applicationXMLContentType = [OWContentType contentTypeForString:@"application/xml"];
    applicationOctetStreamContentType = [OWContentType contentTypeForString:@"application/octet-stream"];
    wildcardContentType = [OWContentType contentTypeForString:@"*/*"];
    
    // Ensure that even if there isn't a processor for this encoding, we still know about it so that -acceptHeadersStringForTarget: can give it a quality factor
    gzipContentType = [OWContentType contentTypeForString:@"encoding/gzip"];
    
    // This is the character set allowed for tokens, [RFC2068 section 2.2]
    tokenCharacterSet = [[NSMutableCharacterSet alloc] init];
    // All US-ASCII chars except controls (0-31) and DEL (127)
    [tokenCharacterSet addCharactersInRange:NSMakeRange(32, (127 - 32))];
    // Remove 'tspecials'
    [tokenCharacterSet removeCharactersInString:@"()<>@,;:\\\"/[]?={} "];
    
    nonTokenCharacterSet = [[tokenCharacterSet invertedSet] retain];
    [tokenCharacterSet release];
    
    browserIdentDict = [[NSDictionary alloc] initWithContentsOfFile:[[OWHTTPSession bundle] pathForResource:@"BrowserIdentity" ofType:@"plist"]];

    encodingPriorityDictionary = [[NSMutableDictionary alloc] init];
    [encodingPriorityDictionary setFloatValue:1.2 forKey:@"bzip2" defaultValue:encodingPriorityDictionaryDefaultValue];
    [encodingPriorityDictionary setFloatValue:1.0 forKey:@"gzip" defaultValue:encodingPriorityDictionaryDefaultValue];
    [encodingPriorityDictionary setFloatValue:0.5 forKey:@"deflate" defaultValue:encodingPriorityDictionaryDefaultValue];
    [encodingPriorityDictionary setFloatValue:0.2 forKey:@"compress" defaultValue:encodingPriorityDictionaryDefaultValue];
    [encodingPriorityDictionary setFloatValue:0.1 forKey:@"identity" defaultValue:encodingPriorityDictionaryDefaultValue];
    [encodingPriorityDictionary setFloatValue:0.0 forKey:@"*" defaultValue:encodingPriorityDictionaryDefaultValue];
}

// OFBundleRegistryTarget informal protocol

+ (void)registerItemName:(NSString *)itemName bundle:(NSBundle *)bundle description:(NSDictionary *)description;
{
    if ([itemName isEqualToString:@"dateFormats"]) 
        preferredDateFormat = [description objectForKey:@"preferredDateFormat"];
}

+ (void)didLoad;
{
    [[OFController sharedController] addObserver:self];
}

+ (void)controllerDidInitialize:(OFController *)controller;
{
    [self _calculatePrimaryUserAgentInfo];
    [self readDefaults];
    
    // Load the list of workarounds
    OWHTTPWorkarounds = [[NSArray alloc] initWithContentsOfFile:[[OWHTTPSession bundle] pathForResource:@"workarounds" ofType:@"plist"]];
}

+ (Class)socketClass;
{
    return [ONTCPSocket class];
}

+ (int)defaultPort;
{
    return 80;
}

+ (NSArray *)browserIdentifierNames;
{
    return [browserIdentDict allKeys];
}

+ (NSDictionary *)browserIdentificationDictionaryForAddress:(OWAddress *)anAddress;
{
    NSDictionary *identificationDictionary;
    NSString *browserIdent = [[OWSitePreference preferenceForKey:OWBrowserIdentity address:anAddress] stringValue];
    
    if ([browserIdent isEqualToString:OWCustomIdentityKey]) {
        identificationDictionary = [[OWSitePreference preferenceForKey:OWCustomBrowserIdentity address:anAddress] objectValue];
    } else {
        identificationDictionary = [browserIdentDict objectForKey:browserIdent];
        if (identificationDictionary == nil) {
            browserIdent = [[OFPreference preferenceForKey:OWBrowserIdentity] objectValue];
            identificationDictionary = [browserIdentDict objectForKey:browserIdent];
        }
        if (identificationDictionary == nil) {
            browserIdent = [[OFPreference preferenceForKey:OWBrowserIdentity] defaultObjectValue];
            identificationDictionary = [browserIdentDict objectForKey:browserIdent];
        }
    }

    return identificationDictionary;
}

+ (NSString *)userAgentHeaderFormatStringForAddress:(OWAddress *)anAddress;
{
    NSDictionary *identificationDictionary = [self browserIdentificationDictionaryForAddress:anAddress];
    return [identificationDictionary objectForKey:@"userAgentHeaderFormat"];
}

+ (NSString *)userAgentInfoForAddress:(OWAddress *)anAddress forceRevealIdentity:(BOOL)forceReveal;
{
    NSString *userAgentHeaderFormatString;
    BOOL hideTrueIdentity;
    
    userAgentHeaderFormatString = [self userAgentHeaderFormatStringForAddress:anAddress];
    hideTrueIdentity = [[OWSitePreference preferenceForKey:@"OWHideOmniWebUserAgentInfo" address:anAddress] boolValue];
    if ([userAgentHeaderFormatString containsString:@"%@"]) {
        // The user agent string has a spot for us to insert our true identity
        NSString *trueIdentityString;
        
        if (hideTrueIdentity)
            trueIdentityString = @"";
        else
            trueIdentityString = _primaryUserAgentInfo;
        
        return [NSString stringWithFormat:userAgentHeaderFormatString, trueIdentityString];
    } else {

        if (forceReveal && !hideTrueIdentity) {
            // Our true identity wasn't included, so we'll just add it to the very end (as Netscape 6.1 does)
            userAgentHeaderFormatString = [NSString stringWithFormat:@"%@ %@", userAgentHeaderFormatString, _primaryUserAgentInfo];
        }

        return userAgentHeaderFormatString;
    }
}

+ (void)readDefaults;
{
    NSUserDefaults *defaults;

    defaults = [NSUserDefaults standardUserDefaults];
    OWHTTPDebug = [defaults boolForKey:@"OWHTTPDebug"];
    OWHTTPTrustServerContentType = [[OFPreference preferenceForKey:OWHTTPTrustServerContentTypePreferenceKey] retain];
    [OWHeaderDictionary setDebug:OWHTTPDebug];
    [self _readLanguageDefaults];
}

+ (void)setDebug:(BOOL)shouldDebug;
{
    OWHTTPDebug = shouldDebug;
}

+ (NSString *)primaryUserAgentInfo;
{
    if (_primaryUserAgentInfo == nil)
        [self _calculatePrimaryUserAgentInfo];
    return _primaryUserAgentInfo;
}

+ (NSString *)preferredDateFormat;
{
    return preferredDateFormat;
}

+ (NSArray *)acceptLanguages;
{
    return languageArray;
}

+ (NSString *)acceptLanguageValue;
{
    return acceptLanguageValue;
}

+ (NSCharacterSet *)nonTokenCharacterSet
{
    return nonTokenCharacterSet;
}

- initWithAddress:(OWAddress *)anAddress inQueue:(OWHTTPSessionQueue *)aQueue;
{
    OWURL *proxyURL, *realURL;
    
    if ([super init] == nil)
        return nil;

    queue = aQueue;
    proxyURL = [anAddress proxyURL];
    realURL = [anAddress url];
    flags.connectingViaProxyServer = (proxyURL != realURL);
    proxyLocation = [[proxyURL parsedNetLocation] retain];
    processorQueue = [[NSMutableArray alloc] initWithCapacity:[queue maximumNumberOfRequestsToPipeline]];
    processorQueueLock = [[NSLock alloc] init];
    flags.pipeliningRequests = NO;
    failedRequests = 0;

    kludge.distrustContentType = [OWHTTPTrustServerContentType boolValue]? 0 : 1;
    kludge.forceTrueIdentityInUAHeader = 1;
    
    return self;
}

- (void)dealloc;
{
    [self disconnectAndRequeueProcessors];
    [proxyLocation release];
    proxyLocation = nil; // Why?  Thread-safety issues?  We should fix those instead--this isn't a reliable cure, since the other thread could access proxyLocation after we release but before we reset it.
    [processorQueue release];
    processorQueue = nil;
    [processorQueueLock release];
    processorQueueLock = nil;

    [super dealloc];
}

- (void)runSession;
{
    do {
        NSException *sessionException = nil;
        OWHTTPProcessor *aProcessor;

        OMNI_POOL_START {
            NS_DURING {
                BOOL continueSession;

                do {
                    OMNI_POOL_START {
                        continueSession = [self sendRequest];
                        if (continueSession) {
                            [processorQueueLock lock];
                            aProcessor = [processorQueue objectAtIndex:0];
                            [processorQueueLock unlock];
                            if ([aProcessor status] != OWProcessorRunning)
                                continueSession = NO;
                            else
                                continueSession = [self fetchForProcessor:aProcessor];
                            if ([aProcessor status] == OWProcessorRunning || [aProcessor status] == OWProcessorAborting)
                                continueSession = NO;
                                
                            if (continueSession) {
                                OBASSERT([aProcessor status] != OWProcessorRunning);
                                [processorQueueLock lock];
                                unsigned finishedProcessorIndex = [processorQueue indexOfObjectIdenticalTo:aProcessor];
                                if (finishedProcessorIndex != NSNotFound)
                                    [processorQueue removeObjectAtIndex:finishedProcessorIndex];
                                [processorQueueLock unlock];
                                if (!flags.pipeliningRequests)
                                    continueSession = NO;
                            }
                        }
                    } OMNI_POOL_END;
                } while (continueSession);
                [self disconnectAndRequeueProcessors];
            } NS_HANDLER {
                sessionException = localException;
            } NS_ENDHANDLER;
            if (sessionException != nil) {
                // Notify processors
                [processorQueueLock lock];
                NSArray *processorQueueSnapshot = [[NSArray alloc] initWithArray:processorQueue];
                [processorQueueLock unlock];
                OFForEachInArray(processorQueueSnapshot, OWHTTPProcessor *, aProcessor,
                                 [self notifyProcessor:aProcessor ofSessionException:sessionException]);
                [processorQueueLock lock];
                [processorQueue removeAllObjects];
                [processorQueueLock unlock];
                [processorQueueSnapshot release];
                [self disconnectAndRequeueProcessors]; // Note:  We don't really have any processors to requeue, we're just disconnecting
                if (requestsSentThisConnection == 0) {
                    // -sendRequest raised an exception before we even started looking for processors (e.g., when trying to connect to a server which is down or doesn't exist).  Send the exception to all queued processors.
                    while ((aProcessor = [queue nextProcessor])) {
                        [self notifyProcessor:aProcessor ofSessionException:sessionException];
                    }
                }
            }
        } OMNI_POOL_END;
    } while (![queue sessionIsIdle:self]);
    
    // At this point we are idle. If we've gotten to this point without ever sending any requests (due to the race condition in the above loop), disconnect from the server. The reason for this is that HTTP/1.0 servers are not allowed to drop connections except after a response, and if we haven't sent any requests, the server does not know our version and must assume we are HTTP/1.0. 
    if (requestsSentThisConnection == 0)
        [self disconnectAndRequeueProcessors];
}

- (BOOL)prepareConnectionForProcessor:(OWProcessor *)aProcessor;
{
    // The HTTPS plug-in subclasses this method to support SSL-Tunneling
    return YES;
}

- (void)abortProcessingForProcessor:(OWProcessor *)aProcessor;
{
    OBPRECONDITION([aProcessor status] != OWProcessorRunning);

    [processorQueueLock lock];
    unsigned abortedProcessorIndex = [processorQueue indexOfObjectIdenticalTo:aProcessor];
#if 0
    NSLog(@"%@ %s:%@ [%d] queue=(%@)",
          [self shortDescription], _cmd, [aProcessor shortDescription],
          abortedProcessorIndex, [[processorQueue arrayByPerformingSelector:@selector(shortDescription)] componentsJoinedByComma]);
#endif
    [processorQueueLock unlock];

    if (abortedProcessorIndex == 0) {
        // The processor being aborted is at the head of the queue, possibly reading its response: drop the connection
        [(ONInternetSocket *)[socketStream socket] abortSocket];
    } else {
        // Do nothing. When the processor reaches the head of the queue, we will notice that its state is OWProcessorAborting and drop the connection. Meanwhile, we can continue to read responses for still-valid requests.
    }
}

- (void)setStatusString:(NSString *)newStatus;
{
    [processorQueueLock lock];
    NSArray *processorQueueSnapshot = [[NSArray alloc] initWithArray:processorQueue];
    [processorQueueLock unlock];
    // Set the status for all processors in this session
    OFForEachInArray(processorQueueSnapshot, OWProcessor *, aProcessor,
                     [aProcessor setStatusString:newStatus]);
    [processorQueueSnapshot release];
    // And for any processors waiting on us
    [queue session:self hasStatusString:newStatus];
}

- (void)setStatusFormat:(NSString *)aFormat, ...;
{
    NSString *newStatus;
    va_list argList;

    va_start(argList, aFormat);
    newStatus = [[NSString alloc] initWithFormat:aFormat arguments:argList];
    va_end(argList);
    [self setStatusString:newStatus];
    [newStatus release];
}

// OBObject subclass

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (fetchAddress)
        [debugDictionary setObject: fetchAddress forKey:@"fetchAddress"];
    if (socketStream)
        [debugDictionary setObject:socketStream forKey:@"socketStream"];
    if (headerDictionary)
        [debugDictionary setObject:headerDictionary forKey:@"headerDictionary"];

    return debugDictionary;
}

@end


@implementation OWHTTPSession (SubclassesOnly)

- (void)connect;
{
    NSString *port;
    ONInternetSocket *socket;
    ONHost *host;
    Class socketClass;
    NSBundle *myBundle = [OWHTTPSession bundle];
    
    requestsSentThisConnection = 0;
    
    [self setStatusFormat:NSLocalizedStringFromTableInBundle(@"Finding %@", @"OWF", myBundle, @"http session status"), [proxyLocation shortDisplayString]];
    port = [proxyLocation port];
    host = [ONHost hostForHostname:[proxyLocation hostname]];
    [self setStatusFormat:NSLocalizedStringFromTableInBundle(@"Contacting %@", @"OWF", myBundle, @"http session status"), [proxyLocation shortDisplayString]];
    flags.serverIsLocal = [host isLocalHost]?1:0;

    // Sadly, we have two socket methods, +[ONInternetSocket socket] and -[ONSocketStream socket], and the compiler doesn't know which it's getting without the final cast.  (There's no way to cast +socketClass to disambiguate ahead of time.)
    socketClass = [isa socketClass];
    socket = (ONInternetSocket *)objc_msgSend(socketClass, @selector(socket));
    [socket setReadBufferSize:32 * 1024];

    OBASSERT(!socketStream);
    socketStream = [[ONSocketStream alloc] initWithSocket:socket];
    [socket connectToHost:host port:port ? [port intValue] : [isa defaultPort]];

    [self setStatusFormat:NSLocalizedStringFromTableInBundle(@"Contacted %@", @"OWF", myBundle, @"session status"), [proxyLocation shortDisplayString]];
    if (OWHTTPDebug)
        NSLog(@"%@: Connected to %@ (%@)", [isa description], [proxyLocation displayString], [socket remoteAddress]);
}

- (void)disconnectAndRequeueProcessors;
{
    unsigned int index, count;

    // Take a snapshot of our processor queue and clear it out
    [processorQueueLock lock];
    NSArray *processorQueueSnapshot = processorQueue;
    processorQueue = [[NSMutableArray alloc] initWithCapacity:[queue maximumNumberOfRequestsToPipeline]];
    [processorQueueLock unlock];

    // Requeue all the processors in the snapshot
    for (index = 0, count = [processorQueueSnapshot count]; index < count; index++)
        [queue queueProcessor:[processorQueueSnapshot objectAtIndex:index]];
        
    // Release our snapshot
    [processorQueueSnapshot release];

    // If we have a socket stream, release it
    [self _closeSocketStream];
}

- (BOOL)fetchForProcessor:(OWHTTPProcessor *)aProcessor;
{
    NSException *sessionException = nil;
    BOOL finishedProcessing = NO;
     
    [aProcessor processBegin];
    
    fetchAddress = [[aProcessor sourceAddress] retain];
    fetchURL = [[fetchAddress url] retain];
    headerDictionary = [[OWHeaderDictionary alloc] init];
    interruptedDataStream = [[aProcessor dataStream] retain];

    NS_DURING {
        if ([[fetchAddress methodString] isEqualToString:@"HEAD"])
            finishedProcessing = [self readHeadForProcessor:aProcessor];
        else
            finishedProcessing = [self readResponseForProcessor:aProcessor];
        failedRequests = 0;
    } NS_HANDLER {
#ifdef DEBUG
        NSLog(@"%@(%@): Caught exception: name='%@', posixErrorNumber=%d, reason='%@'", [fetchAddress addressString], OBShortObjectDescription(self), [localException name], [localException posixErrorNumber], [localException reason]);
#endif
        if (([[localException name] isEqualToString:ONInternetSocketReadFailedExceptionName] && [localException posixErrorNumber] == ECONNRESET) ||
            [[localException name] isEqualToString:ONInternetSocketNotConnectedExceptionName] ||
            [[localException name] isEqualToString:@"No response"]) {
            // Unable to read from socket: Connection reset by peer
            if (flags.pipeliningRequests) {
                // This HTTP 1.1 connection was reset by the server
                if ([interruptedDataStream bufferedDataLength] < 1024) {
                    failedRequests++;
                    if (failedRequests > 0) {
                        // We've been dropped by this server without getting much data:  let's try a traditional HTTP/1.0 connection instead.
                        // NSLog(@"%@: Switching to HTTP/1.0", OBShortObjectDescription(self));
                        [queue setServerCannotHandlePipelinedRequestsReliably];
                        failedRequests = 0;
                    }
                } else {
                    // Well, we got _some_ data...
                    failedRequests = 0;
                }
            } else {
                // Our HTTP/1.0 connection appears to have been dropped:  overloaded server, perhaps?  Let's retry a few times.
                failedRequests++;
                if (interruptedDataStream != nil || failedRequests > 3) {
                    sessionException = [localException retain];
                    [interruptedDataStream dataAbort];
                } else if (failedRequests > 1) {
                    // If this isn't our first retry, give the server a slight rest before connecting again
                    [[NSDate dateWithTimeIntervalSinceNow:3.0] sleepUntilDate];
                }
            }
        } else {
            // Abort the data stream and reraise the exception
            sessionException = [localException retain];
            [interruptedDataStream dataAbort];
        }
    } NS_ENDHANDLER;            

    if (sessionException) {
        [self notifyProcessor:aProcessor ofSessionException:sessionException];
    } else if (finishedProcessing) {
        [aProcessor processEnd];
        [aProcessor retire];        
    } 
        

    // get rid of variables for this fetch
    [fetchAddress release];
    fetchAddress = nil;
    [fetchURL release];
    fetchURL = nil;
    [headerDictionary release];
    headerDictionary = nil;
    [interruptedDataStream release];
    interruptedDataStream = nil;
    return finishedProcessing;
}

- (void)setKludgesForProcessor:(OWHTTPProcessor *)aProcessor address:(OWAddress *)thisAddress;
{
    int workaroundCount, workaroundIndex;
    NSString *hostString;
    id <OWProcessorContext> context;
    id contextObject;

    context = [aProcessor pipeline];

    if ([[context contextObjectForKey:OWHTTPFakeAcceptHeaderPreferenceKey] boolValue]) {
        kludge.fakeAcceptHeader = 1;
        kludge.fakeAcceptEncodingHeader = 0;
    } else {
        kludge.fakeAcceptHeader = 0;
        kludge.fakeAcceptEncodingHeader = 0;
    }
    kludge.suppressAcceptEncodingHeader = 0;
    contextObject = [context contextObjectForKey:OWHTTPTrustServerContentTypePreferenceKey];
    if (contextObject)
        kludge.distrustContentType = [OWHTTPTrustServerContentType boolValue]? 0 : 1;
    
    hostString = [[[[thisAddress url] parsedNetLocation] hostname] lowercaseString];
    
    workaroundCount = [OWHTTPWorkarounds count];
    for(workaroundIndex = 0; workaroundIndex < workaroundCount; workaroundIndex ++) {
        NSDictionary *workaround = [OWHTTPWorkarounds objectAtIndex:workaroundIndex];
        BOOL applicable;
        NSString *value;

        applicable = NO;

        value = [workaround objectForKey:@"domainSuffix"];
        if (value && [hostString hasSuffix:value])
            applicable = YES;

        value = [workaround objectForKey:@"domain"];
        if (value && [hostString isEqual:value])
            applicable = YES;

        if (applicable) {
            kludge.suppressAcceptEncodingHeader = [workaround boolForKey:@"suppressAcceptEncoding" defaultValue:kludge.suppressAcceptEncodingHeader];
            kludge.distrustContentType = [workaround boolForKey:@"distrustContentType" defaultValue:kludge.distrustContentType];
            kludge.forceTrueIdentityInUAHeader = [workaround boolForKey:@"alwaysRevealIdentity" defaultValue:kludge.forceTrueIdentityInUAHeader];
            // More kludges as needed.
        }
    }
}

- (NSString *)requestStringForProcessor:(OWHTTPProcessor *)aProcessor;
{
    NSMutableString *requestString;
    NSString *requestMethod;
    NSString *tempString;
    id <OWProcessorContext> aPipeline;
    OWAddress *anAddress;
    OWURL *aURL;
    
    aPipeline = [aProcessor pipeline];
    anAddress = [aProcessor sourceAddress];
    aURL = [anAddress url];
    requestMethod = [anAddress methodString];

    [self setKludgesForProcessor:aProcessor address:anAddress];
    
    requestString = [NSMutableString stringWithCapacity:2048];
    [requestString appendString:[self commandStringForAddress:anAddress]];
    [requestString appendString:[self rangeStringForProcessor:aProcessor]];
    [requestString appendString:[self keepAliveString]];
    [requestString appendString:[self referrerHeaderStringForPipeline:aPipeline]];
    [requestString appendString:[self userAgentHeaderStringForAddress:anAddress]];
    [requestString appendString:[self cacheControlHeaderStringForPipeline:aPipeline]];
    [requestString appendString:[self validationHeaderStringForPipeline:aPipeline]];
    [requestString appendString:[self hostHeaderStringForURL:aURL]];
    [requestString appendString:[self acceptHeaderStringForPipeline:aPipeline]];
    [requestString appendString:[self acceptEncodingHeaderStringForPipeline:aPipeline]];
    [requestString appendString:[self acceptCharsetHeaderStringForPipeline:aPipeline]];
    [requestString appendString:[self acceptLanguageHeadersStringForPipeline:aPipeline]];
    [requestString appendString:[self authorizationStringForAddress:anAddress processor:aProcessor]];
    [requestString appendString:[self cookiesForURL:aURL pipeline:aPipeline]];    

    // This is used by the Netscape plugin support (plugins can supply arbitrary extra headers to send)
    {
        NSArray *additionalHeaders = [[anAddress methodDictionary] objectForKey: OWAddressContentAdditionalHeadersMethodKey];
        if (additionalHeaders != nil) {
            unsigned int headerIndex, headerCount;
            headerCount = [additionalHeaders count];
            for(headerIndex = 0; headerIndex < headerCount; headerIndex ++) {
                [requestString appendString:[additionalHeaders objectAtIndex:headerIndex]];
                [requestString appendString:endOfLineString];
            }
        }
    }
    
    if ([requestMethod isEqualToString:@"POST"] ||
        [requestMethod isEqualToString:@"PUT"]) {

        [requestString appendString:[self contentTypeHeaderStringForAddress:anAddress]];
        [requestString appendString:[self contentLengthHeaderStringForAddress:anAddress]];

        // Blank line signals end of headers
        [requestString appendString:endOfLineString];

        // We should probably make -requestData return this, and then this code wouldn't have to be here.  Which means that the above statement could be collapsed to be the same as the else clause.
        if ((tempString = [self contentStringForAddress:anAddress]))
            [requestString appendString:tempString];
    } else {
        // Blank line signals end of headers
        [requestString appendString:endOfLineString];
    }
    return requestString;
}

- (NSString *)authorizationStringForAddress:(OWAddress *)anAddress processor:(OWHTTPProcessor *)aProcessor;
{
    NSMutableArray *credentialsToSend;
    OWAuthorizationRequest *serverAuthorization, *proxyAuthorization;
    NSMutableString *buffer;
    unsigned credentialCount, credentialIndex;
    
    if (flags.connectingViaProxyServer && proxyCredentials == nil) {
        proxyAuthorization = [[[OWAuthorizationRequest authorizationRequestClass] alloc] initForType:OWAuth_HTTP_Proxy netLocation:proxyLocation defaultPort:[isa defaultPort] context:[aProcessor pipeline] challenge:nil promptForMoreThan:nil];
    } else
        proxyAuthorization = nil;
    
    if ([aProcessor credentials] == nil) {
        serverAuthorization = [[[OWAuthorizationRequest authorizationRequestClass] alloc] initForType:OWAuth_HTTP netLocation:[[anAddress url] parsedNetLocation] defaultPort:[isa defaultPort] context:[aProcessor pipeline] challenge:nil promptForMoreThan:nil];
    } else
        serverAuthorization = nil;
    
    // Create both AuthorizationRequests before asking either one for its credentials
    
    if (proxyAuthorization != nil) {
        OBASSERT(proxyCredentials == nil); // Or we would need to release them here
        proxyCredentials = [proxyAuthorization credentials];
        if (proxyCredentials && [proxyCredentials count] > 1)
            proxyCredentials = [proxyCredentials subarrayWithRange:NSMakeRange(0,1)];
        [proxyCredentials retain];
        [proxyAuthorization release];
    }
    
    if (serverAuthorization != nil) {
        NSArray *serverCredentials = [serverAuthorization credentials];
        if (serverCredentials && [serverCredentials count])
            [aProcessor addCredential:[serverCredentials objectAtIndex:0]];
        [serverAuthorization release];
    }
    
    credentialsToSend = [[NSMutableArray alloc] init];
    if (OWHTTPCredentialsDebug)
        NSLog(@"%@: proxy credentials = %@, using proxy = %d", [anAddress addressString], proxyCredentials, flags.connectingViaProxyServer);
    if (flags.connectingViaProxyServer && proxyCredentials != nil && [proxyCredentials count])
        [credentialsToSend addObject:[proxyCredentials objectAtIndex:0]];
    if (OWHTTPCredentialsDebug)
        NSLog(@"%@: server credentials = %@", [anAddress addressString], [aProcessor credentials]);
    if ([aProcessor credentials])
        [credentialsToSend addObject:[[aProcessor credentials] objectAtIndex:0]];
    
    credentialCount = [credentialsToSend count];
    if (credentialCount == 0) {
        [credentialsToSend release];
        return @"";
    }
    
    buffer = [[[NSMutableString alloc] init] autorelease];
    for(credentialIndex = 0; credentialIndex < credentialCount; credentialIndex++) {
        NSString *headerString;

        headerString = [[credentialsToSend objectAtIndex:credentialIndex] httpHeaderStringForProcessor:aProcessor];
        if (headerString) {
            [buffer appendString:headerString];
            [buffer appendString:endOfLineString];
        }
    }
    
    [credentialsToSend release];
    
    return buffer;
}

- (NSString *)userAgentHeaderStringForAddress:(OWAddress *)anAddress;
{
    NSString *userAgent;

    userAgent = [isa userAgentInfoForAddress:anAddress forceRevealIdentity:(kludge.forceTrueIdentityInUAHeader)];
    if (userAgent == nil)
        return @"";
    else
        return [isa stringForHeader:@"User-Agent" value:userAgent];
}

- (BOOL)sendRequest;
{    
    if (![(ONInternetSocket *)[socketStream socket] isWritable]) {
        [self disconnectAndRequeueProcessors];
        [self connect];
    }
    NS_DURING {
        [self sendRequests];
    } NS_HANDLER {
        BOOL problemIsTransient = NO;

        if ([[localException name] isEqualToString:ONInternetSocketWriteFailedExceptionName]) {
            switch ([localException posixErrorNumber]) {
                case EPIPE:
                case ECONNRESET:
                    // We'll try again in a bit
                    problemIsTransient = YES;
                    break;
                default:
                    break;
            }
        }
        if (!problemIsTransient) {
            // Reraise the exception
            [localException raise];
        }
    } NS_ENDHANDLER;

    [processorQueueLock lock];
    BOOL stillHaveRequests = ([processorQueue count] != 0);
    [processorQueueLock unlock];

    return stillHaveRequests;
}

- (BOOL)sendRequests;
{
    NSData *requestData;
    NSString *requestString;
    OWAddress *anAddress;
    unsigned int queueCount;
    BOOL shouldPipelineRequests;
    unsigned int maximumNumberOfRequestsToSend;

    // figure out how many requests to send
    shouldPipelineRequests = [queue shouldPipelineRequests];

    [processorQueueLock lock];
    queueCount = [processorQueue count];
    [processorQueueLock unlock];

    flags.pipeliningRequests = shouldPipelineRequests;
    if (shouldPipelineRequests) {
        maximumNumberOfRequestsToSend = [queue maximumNumberOfRequestsToPipeline];
    } else {
        maximumNumberOfRequestsToSend = 1;
    }

    // Fill our queue
    NSMutableArray *newRequests = [NSMutableArray arrayWithCapacity:maximumNumberOfRequestsToSend - queueCount];
    while (queueCount < maximumNumberOfRequestsToSend) {
        OWHTTPProcessor *aProcessor;

        aProcessor = [queue nextProcessor];
        if (aProcessor == nil)
            break;
        switch ([aProcessor status]) {
            case OWProcessorNotStarted:
            case OWProcessorStarting:
            case OWProcessorQueued:
                [aProcessor processBegin];
                // Fall through to running state
            case OWProcessorRunning:
                [newRequests addObject:aProcessor];
                queueCount++;
                [aProcessor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Preparing to request document from %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), [proxyLocation shortDisplayString]];
                break;
            case OWProcessorAborting:
                [aProcessor retire];
                // Fall through to retired state
            case OWProcessorRetired:
                break;
        }
    }

    [processorQueueLock lock];
    [processorQueue addObjectsFromArray:newRequests];
    [processorQueueLock unlock];

    // Send requests for each new processor in the queue
    unsigned int newRequestIndex, newRequestCount;
    for (newRequestIndex = 0, newRequestCount = [newRequests count]; newRequestIndex < newRequestCount; newRequestIndex++) {
        OWHTTPProcessor *aProcessor;

        aProcessor = [newRequests objectAtIndex:newRequestIndex];
        if ([self prepareConnectionForProcessor:aProcessor]) {
            NSDictionary *methodDictionary;
            
            anAddress = [aProcessor sourceAddress];
            methodDictionary = [anAddress methodDictionary];
            requestData = [methodDictionary objectForKey:OWAddressContentDataMethodKey];
            requestString = [self requestStringForProcessor:aProcessor];
            
            if (OWHTTPDebug)
                NSLog(@"%@ Tx: %@", [[anAddress url] scheme], requestString);
                
            [aProcessor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Requesting document from %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), [proxyLocation shortDisplayString]];
            
            if (requestData) {
                if (OWHTTPDebug)
                    // TODO: Eliminate dependence on the default C string encoding, which might change to something which cannot express arbitrary sequences of bytes.
                    NSLog(@"Tx: %@", [NSString stringWithCString:[requestData bytes] length:[requestData length]]);
                [socketStream beginBuffering];
                [socketStream writeString:requestString];
                [socketStream writeData:requestData];
                [socketStream endBuffering];
            } else 
                [socketStream writeString:requestString];
            
            if (flags.serverIsLocal)
                [aProcessor flagResult:OWProcessorContentNoDiskCache];
            
            requestsSentThisConnection++;
        }
    }

    return queueCount != 0;
}

@end

@implementation OWHTTPSession (Private)

+ (void)_readLanguageDefaults;
{
    NSUserDefaults *defaults;
    NSArray *systemLanguages;
    unsigned int systemLanguageIndex, systemLanguageCount;
    NSString *acceptLanguageHeaderOverride;

    defaults = [NSUserDefaults standardUserDefaults];

    if (languageArray != nil)
        [languageArray release];
    if (acceptLanguageValue != nil)
        [acceptLanguageValue release];
    if (acceptLanguageString != nil)
        [acceptLanguageString release];
    
    systemLanguages = [defaults stringArrayForKey:@"OWHTTPSessionLanguages"];
    if (systemLanguages == nil) {
        // If the user didn't provide a specific web language ordering, look up their their language preferences.  Mac OS X stores the user's language preferences in AppleLanguages, using the ISO abbreviations --- very convenient, but see below.
        systemLanguages = [defaults stringArrayForKey:@"AppleLanguages"];
        if (systemLanguages == nil) {
            // Fall back on NSLanguages (perhaps we should remove this code at some point)
            systemLanguages = [defaults stringArrayForKey:@"NSLanguages"];
        }
    }

    systemLanguageCount = systemLanguages != nil ? [systemLanguages count] : 0;
    languageArray = [[NSMutableArray alloc] initWithCapacity:systemLanguageCount];

    // Apple bug fix for 4K78: the system preference is normally in ISO format. However, if it isn't set, then the *default* value is in the old (pre-OSX) format, which we then have to convert to the IANA abbreviations. Bah! (This conversion is also necessary if we got language prefs from NSLanguages.)
    for (systemLanguageIndex = 0; systemLanguageIndex < systemLanguageCount; systemLanguageIndex++) {
        NSString *systemLanguage;
        NSString *languageAbbreviation;
        NSMutableString *mutableLanguageAbbreviation;
        NSString *immutableLanguageAbbreviation;

        systemLanguage = [systemLanguages objectAtIndex:systemLanguageIndex];
        languageAbbreviation = OFISOLanguageCodeForEnglishName(systemLanguage);

        // Note:  the system preference separates subtypes from languages with underscores (e.g. en_US for us-english). RFC2068 [3.10] specifies that subtypes are separated with hyphens (e.g. en-us).
        mutableLanguageAbbreviation = [[languageAbbreviation lowercaseString] mutableCopy];
        [mutableLanguageAbbreviation replaceAllOccurrencesOfString:@"_" withString:@"-"];
        immutableLanguageAbbreviation = [mutableLanguageAbbreviation copy];
        [mutableLanguageAbbreviation release];
        mutableLanguageAbbreviation = nil;

        [languageArray addObject:immutableLanguageAbbreviation];
        [immutableLanguageAbbreviation release];
    }

    OBASSERT(systemLanguageCount == [languageArray count]);
    acceptLanguageHeaderOverride = [defaults stringForKey:@"OWHTTPSessionAcceptLanguageOverride"];
    if (acceptLanguageHeaderOverride != nil) {
        if ([NSString isEmptyString:acceptLanguageHeaderOverride]) {
            acceptLanguageValue = nil;
            acceptLanguageString = nil;
        } else {
            acceptLanguageValue = [acceptLanguageHeaderOverride retain];
            acceptLanguageString = [[self stringForHeader:@"Accept-Language" value:acceptLanguageValue] retain];
        }
    } else if (systemLanguageCount > 0) {
        NSMutableArray *acceptLanguages;
        NSString *qualityFormatString;
        float acceptLanguageCount;

        if (systemLanguageCount < 10) {
            qualityFormatString = @"%@;q=%0.1f";
        } else if (systemLanguageCount < 100) {
            qualityFormatString = @"%@;q=%0.2f";
        } else {
            OBASSERT(systemLanguageCount < 1000); // If not, too bad!  According to RFC2616, a qvalue can only have three digits after the decimal point
            qualityFormatString = @"%@;q=%0.3f";
        }
        acceptLanguageCount = systemLanguageCount + 1.0; // system languages + "*"
        acceptLanguages = [[NSMutableArray alloc] initWithCapacity:systemLanguageCount];
        for (systemLanguageIndex = 0; systemLanguageIndex < systemLanguageCount; systemLanguageIndex++) {
            NSString *language;

            language = [languageArray objectAtIndex:systemLanguageIndex];
            if (systemLanguageIndex == 0) {
                [acceptLanguages addObject:language]; // q=1.0 is redundant
            } else {
                float quality;

                quality = (acceptLanguageCount - systemLanguageIndex) / acceptLanguageCount;
                [acceptLanguages addObject:[NSString stringWithFormat:qualityFormatString, language, quality]];
            }
        }
        if ([defaults boolForKey:@"OWHTTPSessionAcceptLanguageIncludeFallback"])
            [acceptLanguages addObject:[NSString stringWithFormat:qualityFormatString, @"*", 1.0 / acceptLanguageCount]]; // End with "*;q=0.01"
        acceptLanguageValue = [[acceptLanguages componentsJoinedByString:@", "] retain];
        acceptLanguageString = [[self stringForHeader:@"Accept-Language" value:acceptLanguageValue] retain];
        [acceptLanguages release];
    } else {
        acceptLanguageValue = nil;
        acceptLanguageString = nil;
    }
}

+ (void)_calculatePrimaryUserAgentInfo;
{
    NSBundle *mainBundle;
    NSDictionary *mainBundleInfoDictionary;
    NSString *primaryAgentName, *primaryAgentVersion, *primaryAgentBuild, *primaryAgentCombinedVersion;
    NSNumber *hidePrimaryAgentVersionValue;
    BOOL hidePrimaryAgentVersion;

    mainBundle = [NSBundle mainBundle];
    mainBundleInfoDictionary = [mainBundle infoDictionary];
    primaryAgentName = [mainBundleInfoDictionary objectForKey:@"CFBundleName"];
    primaryAgentVersion = [mainBundleInfoDictionary objectForKey:@"CFBundleShortVersionString"];
    primaryAgentBuild = [mainBundleInfoDictionary objectForKey:@"CFBundleVersion"];
    if (![NSString isEmptyString:primaryAgentBuild])
        primaryAgentBuild = [@"v" stringByAppendingString:primaryAgentBuild]; // 319 -> v319
    hidePrimaryAgentVersionValue = [mainBundleInfoDictionary objectForKey:@"OWFHidePrimaryAgentVersion"];
    hidePrimaryAgentVersion = hidePrimaryAgentVersionValue != nil && [hidePrimaryAgentVersionValue boolValue];
    if (!hidePrimaryAgentVersion && ![NSString isEmptyString:primaryAgentVersion]) {
        NSRange firstWordRange;
        NSString *firstWord;

        // Trim "4.0 beta 1" to "4.0".  (They can get full details by looking up the build number.)
        firstWordRange = [primaryAgentVersion rangeOfCharactersAtIndex:0 delimitedBy:[NSCharacterSet whitespaceCharacterSet]];
        firstWord = [primaryAgentVersion substringWithRange:firstWordRange];
        if (![NSString isEmptyString:primaryAgentBuild])
            primaryAgentCombinedVersion = [NSString stringWithFormat:@"%@-%@", firstWord, primaryAgentBuild];
        else
            primaryAgentCombinedVersion = firstWord;
    } else {
        primaryAgentCombinedVersion = primaryAgentBuild;
    }
    if (![NSString isEmptyString:primaryAgentCombinedVersion]) {
        _primaryUserAgentInfo = [[NSString alloc] initWithFormat:@"%@/%@", primaryAgentName, primaryAgentCombinedVersion];
    } else {
        _primaryUserAgentInfo = [primaryAgentName copy];
    }
}

/* A comparison function which we use for sorting the types we place in the Accept headers */
static int acceptEncodingHeaderOrdering(id a, id b, void *ctxt)
{
    OBPRECONDITION([a isKindOfClass:[NSString class]]);
    OBPRECONDITION([b isKindOfClass:[NSString class]]);

    float aPriority = [encodingPriorityDictionary floatForKey:a defaultValue:encodingPriorityDictionaryDefaultValue];
    float bPriority = [encodingPriorityDictionary floatForKey:b defaultValue:encodingPriorityDictionaryDefaultValue];

    if (aPriority == bPriority)
        return [(NSString *)a compare:(NSString *)b];
    else if (aPriority > bPriority)
        return NSOrderedAscending;
    else // (aPriority < bPriority)
        return NSOrderedDescending;
}

+ (NSString *)_acceptEncodingsHeaderString;
{
    static NSString *acceptEncodingsString = nil;
    
    if (acceptEncodingsString != nil)
        return acceptEncodingsString;

    NSMutableArray *acceptsArray;
    NSArray *encodings;
    NSEnumerator *possibleTypesEnumerator;
    OWContentType *possibleType;
    NSString *encodingString;

    // Determine the Accept-Encoding header
    encodings = [OWDataStreamCursor availableEncodingsToRemove];
    acceptsArray = [[NSMutableArray alloc] initWithCapacity:[encodings count]];
    
    possibleTypesEnumerator = [encodings objectEnumerator];
    while ((possibleType = [possibleTypesEnumerator nextObject])) {
        if (![possibleType isPublic])
            continue;
        encodingString = [[possibleType contentTypeString] stringByRemovingPrefix:@"encoding/"];
#if 0
        if (![possibleType isInteresting])
            encodingString = [encodingString stringByAppendingString:@";q=0.5"];
#endif
        
        [acceptsArray addObject:encodingString];
    }
    [acceptsArray addObject:@"identity"];
    [acceptsArray sortUsingFunction:acceptEncodingHeaderOrdering context:NULL];
    
    // Note: We always send the Accept-Encoding header, even if we have no encodings.  In fact, especially when we have no encodings, since according to RFC 2616 no Accept-Encoding header means the server can assume we understand compress and gzip, while an empty header value means the server can only assume that we understand the "identity" encoding.
    acceptEncodingsString = [[self stringForHeader:@"Accept-Encoding" value:[acceptsArray componentsJoinedByString:@", "]] retain];
    [acceptsArray release];

    return acceptEncodingsString;
}

+ (NSDictionary *)_customBrowserIdentityDictionary;
{
    return [[OFPreference preferenceForKey:OWCustomBrowserIdentity] objectValue];
}


+ (NSString *)stringForHeader:(NSString *)aHeader value:(id)aValue;
{
    if (aValue == nil)
        return @"";
        
    NSString *value = [aValue description];
    NSMutableString *header = [[NSMutableString alloc] initWithCapacity:[aHeader length] + 2 + [value length] + [endOfLineString length]];
    [header appendString:aHeader];
    [header appendString:@": "];
    [header appendString:value];
    [header appendString:endOfLineString];
    [header autorelease];
    return header;
}

//
// Generating request
//

- (NSString *)commandStringForAddress:(OWAddress *)anAddress;
{
    NSMutableString *command;
    OWURL *aURL;
    NSString *fetchPath;

    aURL = [anAddress url];
    command = [NSMutableString stringWithCapacity:128];
    [command appendStrings:[anAddress methodString], @" ", nil];
    if (flags.connectingViaProxyServer)
        fetchPath = [aURL proxyFetchPath];
    else
        fetchPath = [aURL fetchPath];
    
    fetchPath = [fetchPath stringByRemovingReturns];
    
    // Last-ditch quoting of the URL path. This is here to catch mistakes (e.g. unquoted spaces) and it is also here to support IURIs (URIs containing characters outside the ASCII range).
    if (fetchPath)
        fetchPath = [fetchPath fullyEncodeAsIURI];
    else
        fetchPath = @"*";  // see rfc2616 [5.1.2]

    [command appendStrings:fetchPath, @" ", ([queue serverCannotHandlePipelinedRequestsReliably] ? http10VersionString : http11VersionString), nil];
    [command appendString:endOfLineString];

    return command;
}

- (NSString *)acceptEncodingHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
{
    if (kludge.suppressAcceptEncodingHeader) {
        return @"";
    } else if (kludge.fakeAcceptEncodingHeader) {
        return [isa stringForHeader:@"Accept-Encoding" value:@"gzip, identity"];
    } else {
        return [isa _acceptEncodingsHeaderString];
    }
}

- (NSString *)acceptCharsetHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
{
    NSString *acceptCharsetString = [aPipeline contextObjectForKey:OWHTTPAcceptCharsetHeaderPreferenceKey];
    if (acceptCharsetString != nil && [acceptCharsetString isKindOfClass:[NSString class]] && [acceptCharsetString length])
        return [isa stringForHeader:@"Accept-Charset" value:acceptCharsetString];
    else
        return @"";
}

/* A comparison function which we use for sorting the types we place in the Accept headers */
static int acceptHeaderOrdering(id a, id b, void *ctxt)
{
    OWContentType *typeA = a, *typeB = b;
    BOOL aInteresting, bInteresting;
    int aWildcarded, bWildcarded;
    NSString *stringA, *stringB;

    aInteresting = [typeA isInteresting];
    bInteresting = [typeB isInteresting];

    // Interesting types always sort in front of uninteresting types.
    if (aInteresting && !bInteresting)
        return NSOrderedAscending;
    else if (bInteresting && !aInteresting)
        return NSOrderedDescending;

    stringA = [typeA contentTypeString];
    stringB = [typeB contentTypeString];

    // Wildcarded types always sort after non-wildcarded types. (We don't distinguish between * / * and foo/*, but that's currently not a problem.)
    aWildcarded = bWildcarded = 0;
    if ([stringA hasPrefix:@"*/"])
        aWildcarded++;
    if ([stringA hasSuffix:@"/*"])
        aWildcarded++;
    if ([stringB hasPrefix:@"*/"])
        bWildcarded++;
    if ([stringB hasSuffix:@"/*"])
        bWildcarded++;
    if (aWildcarded > bWildcarded)
        return NSOrderedDescending;
    else if (bWildcarded > aWildcarded)
        return NSOrderedAscending;

 // Otherwise, sort by name --- no real reason, we just need a stable comparison function.
 return [stringA caseInsensitiveCompare:stringB];
}

- (NSString *)acceptHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
{
    if (kludge.fakeAcceptHeader)
        return [isa stringForHeader:@"Accept" value:@"image/gif, image/x-xbitmap, image/jpeg, image/pjpeg, image/png, image/tiff, multipart/x-mixed-replace, */*;q=0.1"];

    NSMutableArray *acceptsArray;
    NSEnumerator *targetTypesEnumerator, *possibleTypesEnumerator;
    NSMutableSet *desiredContentTypes, *acceptableContentTypes;
    NSMutableArray *sortedContentTypes;
    OWContentType *wildcardContentType = [OWContentType wildcardContentType];
    OWContentType *possibleType, *targetContentType;
    NSDictionary *targetContentTypes;

    // Determine the real Accept header from the set of types which can be converted to the type that our target wants.
    targetContentTypes = [aPipeline contextObjectForKey:OWCacheArcTargetTypesKey];
    desiredContentTypes = [[NSMutableSet alloc] init];
    targetTypesEnumerator = [targetContentTypes keyEnumerator];
    while ( (targetContentType = [targetTypesEnumerator nextObject]) != nil ) {
        [desiredContentTypes addObject:targetContentType];
        [desiredContentTypes unionSet:[targetContentType indirectSourceContentTypes]];
    }

    // Compute the set of types to advertise, based on the set of types we want. Ignore non-public types (and encodings, which go in a different header), and provide wildcard cover types for "uninteresting" types.
    acceptableContentTypes = [[NSMutableSet alloc] init];
    possibleTypesEnumerator = [desiredContentTypes objectEnumerator];
    while ((possibleType = [possibleTypesEnumerator nextObject])) {
        if (![possibleType isPublic] || [possibleType isEncoding]) {
            continue;
        }

        /* Provide a wildcard cover for uninteresting types. But types that are explicitly mentioned by the target are always interesting. */
        if (![possibleType isInteresting] && ([targetContentTypes objectForKey:possibleType] == nil)) {
            OWContentType *wildcardType;
            NSString *mediaType;
            NSRange slashLocation;

            mediaType = [possibleType contentTypeString];
            slashLocation = [mediaType rangeOfString:@"/"];
            if (slashLocation.length > 0) {
                wildcardType = [OWContentType contentTypeForString:[[mediaType substringToIndex:slashLocation.location] stringByAppendingString:@"/*"]]; 
                [acceptableContentTypes addObject:wildcardType];
            }
        } else {
            [acceptableContentTypes addObject:possibleType];
        }
    }

    [desiredContentTypes release];
    desiredContentTypes = nil;

    // Sort the content-types, and convert them to strings
    sortedContentTypes = [[NSMutableArray alloc] initWithCapacity:[acceptableContentTypes count]];
    acceptsArray = [[NSMutableArray alloc] initWithCapacity:[sortedContentTypes count]];
    [sortedContentTypes addObjectsFromSet:acceptableContentTypes];
    [sortedContentTypes sortUsingFunction:acceptHeaderOrdering context:NULL];
    possibleTypesEnumerator = [sortedContentTypes objectEnumerator];
    while ((possibleType = [possibleTypesEnumerator nextObject])) {
        NSString *typeString;

        typeString = [possibleType contentTypeString];
        if (possibleType == wildcardContentType)
            typeString = [typeString stringByAppendingString:@";q=0.1"];
        else if ([typeString hasSuffix:@"/*"])
            typeString = [typeString stringByAppendingString:@";q=0.2"];
        [acceptsArray addObject:typeString];
    }
    
    NSString *acceptTypesString = [isa stringForHeader:@"Accept" value:[acceptsArray componentsJoinedByString:@", "]];
    [acceptsArray release];
    [sortedContentTypes release];
    [acceptableContentTypes release];
    
    return acceptTypesString;
}

- (NSString *)acceptLanguageHeadersStringForPipeline:(id <OWProcessorContext>)aPipeline;
{
    // This can be nil if we didn't find any information on the user's language preferences; we'll return the empty string to avoid crashing in appendString:.
    OFPreference *shouldSend = [aPipeline preferenceForKey:@"OWHTTPSessionSendAcceptLanguageHeader"];
    return acceptLanguageString && [shouldSend boolValue] ? acceptLanguageString : @"";
}

- (NSString *)referrerHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
{
    OWAddress *referringAddress;
    OWURL *referringURL;
    NSString *referrerString;

    referringAddress = [aPipeline contextObjectForKey:OWCacheArcReferringAddressKey isDependency:NO];
    if (!referringAddress)
        return @"";
    referringURL = [[referringAddress url] urlWithoutUsernamePasswordOrFragment];        
    referrerString = [[referringURL compositeString] stringByRemovingReturns];
    if ([NSString isEmptyString:referrerString])
        return @"";
    return [isa stringForHeader:@"Referer" /* [sic] */ value:referrerString];
}

- (NSString *)cacheControlHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
{
    NSString *cacheControl = [aPipeline contextObjectForKey:OWCacheArcCacheBehaviorKey isDependency:NO];
    NSString *result;

    if (cacheControl == nil)
        return @"";
    else if ([cacheControl isEqualToString:OWCacheArcReload]) {
        result = [isa stringForHeader:@"Cache-Control" value:@"no-cache"];
        result = [result stringByAppendingString:[isa stringForHeader:@"Pragma" value:@"no-cache"]];
    } else if ([cacheControl isEqualToString:OWCacheArcRevalidate]) {
        result = [isa stringForHeader:@"Cache-Control" value:@"max-age=0"];
        // We use Pragma: no-cache here since HTTP/1.0 doesn't have a directive exactly equivalent to what we want
        result = [result stringByAppendingString:[isa stringForHeader:@"Pragma" value:@"no-cache"]];
    } else if ([cacheControl isEqualToString:OWCacheArcPreferCache]) {
        return @"";
    } else {
#ifdef DEBUG
        NSLog(@"%@ unsupported %@: %@", OBShortObjectDescription(self), OWCacheArcCacheBehaviorKey, cacheControl);
#endif
        return @"";
    }

    return result;
}

- (NSString *)validationHeaderStringForPipeline:(id <OWProcessorContext>)aPipeline;
{
    NSArray *conditional;
    NSString *validatorKey, *validatorValue;
    BOOL wantChanges;
    
    conditional = [aPipeline contextObjectForKey:OWCacheArcConditionalKey isDependency:NO];
    if (conditional == nil)
        return @"";

    validatorKey = [conditional objectAtIndex:0];
    validatorValue = [conditional objectAtIndex:1];
    wantChanges = [[conditional objectAtIndex:2] boolValue];
        
    if ([validatorKey caseInsensitiveCompare:@"ETag"] == NSOrderedSame) {
        if (wantChanges)
            return [isa stringForHeader:@"If-None-Match" value:validatorValue];
        else
            return [isa stringForHeader:@"If-Match" value:validatorValue];
    } else if ([validatorKey caseInsensitiveCompare:@"Last-Modified"] == NSOrderedSame) {
        if (wantChanges)
            return [isa stringForHeader:@"If-Modified-Since" value:validatorValue];
        else
            return [isa stringForHeader:@"If-Unmodified-Since" value:validatorValue];
    } else {
        NSLog(@"%@ unsupported validator: %@", [aPipeline logDescription], validatorKey);
        return @"";
    }
}

- (NSString *)hostHeaderStringForURL:(OWURL *)aURL;
{
    OWNetLocation *netLocation = [aURL parsedNetLocation];
    NSString *hostname = [ONHost IDNEncodedHostname:[netLocation hostname]];
    NSString *port = [netLocation port];
    NSString *result;
    
    if (hostname == nil)
        return @"";
    
    if (port == nil)
        result = hostname;
    else
        result = [NSString stringWithFormat:@"%@:%@", hostname, port];

    return [isa stringForHeader:@"Host" value:result];
}

- (NSString *)rangeStringForProcessor:(OWHTTPProcessor *)aProcessor;
{
    OWDataStream *dataStream = [aProcessor dataStream];
    NSString *sourceRange = [[aProcessor pipeline] contextObjectForKey:OWAddressSourceRangeContextKey];
    
    desiredRange = NSMakeRange([dataStream bufferedDataLength], 0); 
    
    if (sourceRange != nil) {
        NSRange dashRange = [sourceRange rangeOfString:@"-"];
        
        desiredRange.location += [sourceRange intValue];
        if (dashRange.length && dashRange.location < ([sourceRange length] - 1))
            desiredRange.length = desiredRange.location + 1 - [[sourceRange substringFromIndex:dashRange.location+1] intValue];
        else
            desiredRange.length = 0;
    }  
    
    if (desiredRange.length)
        return [isa stringForHeader:@"Range" value:[NSString stringWithFormat:@"bytes=%d-%d", desiredRange.location, desiredRange.location + desiredRange.length - 1]];
    else if (desiredRange.location)
        return [isa stringForHeader:@"Range" value:[NSString stringWithFormat:@"bytes=%d-", desiredRange.location]];
    else
        return @"";
}

- (NSString *)keepAliveString;
{
    if (flags.connectingViaProxyServer)
        return @"";
    else
        return [isa stringForHeader:@"Connection" value:@"Keep-Alive"];
}

- (NSString *)cookiesForURL:(OWURL *)aURL pipeline:(id <OWProcessorContext>)aPipeline;
{
    return [isa stringForHeader:@"Cookie" value:[aPipeline contextObjectForKey:OWCacheArcApplicableCookiesContentKey isDependency:YES]];
}

- (NSString *)contentTypeHeaderStringForAddress:(OWAddress *)anAddress;
{
    NSMutableString *valueString;
    NSDictionary *addressMethodDictionary;
    NSString *boundaryString;
    NSString *contentTypeHeaderString;
    NSString *contentType;

    addressMethodDictionary = [anAddress methodDictionary];
    contentType = [addressMethodDictionary objectForKey:OWAddressContentTypeMethodKey];
    if (!contentType)
        return @"";
    valueString = [[NSMutableString alloc] initWithString:contentType];
    boundaryString = [addressMethodDictionary objectForKey:OWAddressBoundaryMethodKey];
    if (boundaryString)
        [valueString appendStrings:@"; boundary=", boundaryString, nil];

    contentTypeHeaderString = [isa stringForHeader:@"Content-Type" value:valueString];
    [valueString release];
    return contentTypeHeaderString;
}

- (NSString *)contentLengthHeaderStringForAddress:(OWAddress *)anAddress;
{
    NSDictionary *addressMethodDictionary;

    addressMethodDictionary = [anAddress methodDictionary];
    return [isa stringForHeader:@"Content-Length" value:[NSNumber numberWithInt:[[addressMethodDictionary objectForKey:OWAddressContentStringMethodKey] length] + [[addressMethodDictionary objectForKey:OWAddressContentDataMethodKey] length]]];
}

- (NSString *)contentStringForAddress:(OWAddress *)anAddress;
{
    NSString *methodContentString;

    methodContentString = [[anAddress methodDictionary] objectForKey:OWAddressContentStringMethodKey];
    if (!methodContentString)
        return nil;
    return [methodContentString stringByAppendingString:endOfLineString];
}

//
// Reading results
//

static void notifyCredentials(NSArray *credentials, BOOL success, OWHeaderDictionary *response)
{
    unsigned int credentialIndex, credentialCount;
    
    if (credentials == nil)
        return;
    credentialCount = [credentials count];
    // Only notify the first credential, since we only sent the first credential --- the second through Nth credentials are credentials we've tried and failed with, and are just keeping around so we know not to try them again.
    for (credentialIndex = 0; credentialIndex < credentialCount && credentialIndex < 1; credentialIndex++) {
        OWAuthorizationCredential *credential;

        credential = [credentials objectAtIndex:credentialIndex];
        [credential authorizationSucceeded:success response:response];
    }
}

- (BOOL)readResponseForProcessor:(OWHTTPProcessor *)processor;
{
    NSString *line;
    NSScanner *scanner;
    float httpVersion;
    HTTPStatus httpStatus;
    NSString *commentString;
    OWAuthorizationRequest *authorizationRequest;
    NSArray *newCredentials, *oldCredentials;

    [processor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Awaiting document from %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), [proxyLocation shortDisplayString]];

beginReadResponse:    
    
    line = [socketStream peekLine];
    while (line != nil && [line isEqualToString:@""]) {
        // Skipping past leading newlines in the response fixes a problem I was seeing talking to a SmallWebServer/2.0 (used in some bulletin boards like the one at Clan Fat, http://pub12.ezboard.com/bfat).  I think what might have happened is that they miscalculated their content length in an earlier request, and sent us an extra newline following the counted bytes.  The result was that every other request to the server would fail.
        // Note:  if we're actually talking to an HTTP 0.9 server, it's possible we're losing blank lines at the beginning of the content they're sending us.  But since I haven't seen any HTTP 0.9 servers in a long, long time...
        [socketStream readLine]; // Skip past the empty line
        line = [socketStream peekLine]; // And peek at the next one
    }
    
    if (line == nil) {
        [NSException raise:@"No response" format:NSLocalizedStringFromTableInBundle(@"The web server closed the connection without sending any response", @"OWF", [OWHTTPSession bundle], @"httpsession error - no response")];
    }
    
    if (OWHTTPDebug)
        NSLog(@"%@ Rx: %@", [fetchURL scheme], line);
    scanner = [NSScanner scannerWithString:line];

    if (![scanner scanString:@"HTTP" intoString:NULL]) {
        // 0.9 server:  good luck!
        NSLog(@"%@ is ancient, good luck!", [proxyLocation shortDisplayString]);
        [processor setStatusFormat:NSLocalizedStringFromTableInBundle(@"%@ is ancient, good luck!", @"OWF", [OWHTTPSession bundle], @"httpsession status for HTTP/0.9 servers"), [proxyLocation shortDisplayString]];
        [headerDictionary addString:[[OWContentType unknownContentType] contentTypeString] forKey:@"Content-Type"];
        [OWCookieDomain registerCookiesFromURL:[[processor sourceAddress] url] context:[processor pipeline] headerDictionary:headerDictionary];
        [self readBodyForProcessor:processor ignore:NO];
        return YES;
    }

    [socketStream readLine]; // Skip past the line we're already parsing
    [scanner scanString:@"/" intoString:NULL];
    [scanner scanFloat:&httpVersion];
    if (OWHTTPDebug)
        NSLog(@"Rx: %@", [fetchAddress addressString]);
    if (httpVersion > 1.0) {
        [queue setServerUnderstandsPipelinedRequests];
    }

    [scanner scanInt:(int *)&httpStatus];
    if (![scanner scanUpToString:@"\n" intoString:&commentString])
        commentString = @"";

    [processor setHTTPStatusCode:httpStatus];

processStatus:
    switch (httpStatus) {

        // 100 codes - Informational
        
        case HTTP_STATUS_CONTINUE:
            // read the headers, ignore 'em, start over
            [self readHeadersForProcessor:processor];
            goto beginReadResponse;
            
        // 200 codes - Success: Got MIME object

        case HTTP_STATUS_OK:
        case HTTP_STATUS_PARTIAL_CONTENT:
            [self readHeadersForProcessor:processor];
            notifyCredentials(proxyCredentials, YES, headerDictionary);
            notifyCredentials([processor credentials], YES, headerDictionary);
            [self readBodyForProcessor:processor ignore:NO];
            break;

        case HTTP_STATUS_NO_CONTENT:
            // Netscape 4.0 just ignores request if it returns "NO_CONTENT"
            // was [NSException raise:@"NoContent" format:@"Server returns no content"];
            
            // Return an empty data stream so caller gets success instead of alternate or failure
            [self readHeadersForProcessor:processor];
            [headerDictionary release];
            headerDictionary = [[OWHeaderDictionary alloc] init];
            [headerDictionary addString:[[OWContentType nothingContentType] contentTypeString] forKey:@"Content-Type"];
#ifdef DEBUG_kc
            NSLog(@"headerDictionary = %@", [headerDictionary description]);
#endif
            interruptedDataStream = [[OWDataStream alloc] init];
            [interruptedDataStream dataEnd];
            [processor setDataStream:interruptedDataStream];
            [processor addHeaders:headerDictionary];
            [processor markEndOfHeaders];
            [processor addContent];

            break;		// Don't read headers and body

        // 300 codes - Temporary error (various forms of redirection)

#warning Should double-check our HTTP 1.1 handling
        case HTTP_STATUS_MULTIPLE_CHOICES:
            break;

        case HTTP_STATUS_MOVED_PERMANENTLY:
        case HTTP_STATUS_MOVED_TEMPORARILY:
        case HTTP_STATUS_SEE_OTHER:
            {
                NSString *newLocationString;
                OWAddress *newLocation;
                unsigned redirectionFlags, contentFlags;
                OWContent *newContent;

                /* The difference between MOVED_TEMPORARILY and SEE_OTHER is that SEE_OTHER is specified to result in a GET to the new location, but it would be reasonable to reuse the same method on a new URL after receiveing a MOVED_TEMPORARILY or MOVED_PERMANENTLY response. However, all browsers appear to use a GET after any redirection, probably to avoid security shenanigans. So there isn't actually any difference in how we handle MOVED_TEMPORARILY and SEE_OTHER.
                The other difference (which OmniWeb doesn't care about) is the implication that the result of a SEE_OTHER might be a different resource than originally requested, but MOVED_TEMPORARILY might point to the same resource in a new location. Shrug. */

                [self readHeadersForProcessor:processor];
                newLocationString = [headerDictionary lastStringForKey:@"location"];
                if (newLocationString == nil)
                    [NSException raise:@"Redirect failure" format:NSLocalizedStringFromTableInBundle(@"Location header missing on redirect", @"OWF", [OWHTTPSession bundle], @"httpsession error - required header missing in response")];
                newLocation = [fetchAddress addressForRelativeString:newLocationString];
                [processor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Redirected to %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), newLocationString];

                redirectionFlags = 0;
                contentFlags = [processor flags] & ~(OWProcessorContentIsSource);
                if (httpStatus == HTTP_STATUS_MOVED_PERMANENTLY)
                    redirectionFlags |= OWProcessorRedirectIsPermanent;
                if ([[newLocation addressString] isEqualToString:[[fetchAddress addressString] stringByAppendingString:@"/"]])
                    redirectionFlags |= OWProcessorRedirectIsSame;
                newContent = [OWContent contentWithAddress:newLocation redirectionFlags:redirectionFlags interimContent:[processor content]];
                if (flags.serverIsLocal || !(redirectionFlags & OWProcessorRedirectIsSame))
                    contentFlags |= OWProcessorContentNoDiskCache;
                if (httpStatus == HTTP_STATUS_MOVED_TEMPORARILY) {
                    // [10.3.3] Don't cache moved-temporarily responses unless explicitly allowed to.
                    BOOL explicitControl = NO;
                    if ([headerDictionary lastStringForKey:@"expires"] != nil) {
                        explicitControl = YES;
                    }
                    if ([headerDictionary lastStringForKey:@"cache-control"] != nil) {
                        if ([[headerDictionary stringArrayForKey:@"cache-control"] indexOfString:@"max-age" options:NSCaseInsensitiveSearch] != NSNotFound) {
                            explicitControl = YES;
                        }
                    }
                    if (!explicitControl) {
                        [[processor pipeline] cacheControl:[OWCacheControlSettings cacheSettingsWithNoCache]];
                    }
#ifdef DEBUG_kc0
                NSLog(@"-[%@ %s]: Redirect from <%@> to <%@> explicitControl=%d", OBShortObjectDescription(self), _cmd, [fetchAddress addressString], [newLocation addressString], explicitControl);
#endif
                }
                [processor invalidateForHeaders:headerDictionary];
                [[processor pipeline] addContent:newContent fromProcessor:processor flags:contentFlags];
                [self readBodyForProcessor:processor ignore:YES];
            }
            break;

        case HTTP_STATUS_NOT_MODIFIED:
            [self readHeadersForProcessor:processor];
            [self readBodyForProcessor:processor ignore:YES];
            break;

        case HTTP_STATUS_USE_PROXY:
            break;

        // 400 codes - Permanent error

        case HTTP_STATUS_BAD_REQUEST:
        case HTTP_STATUS_PAYMENT_REQUIRED:
        case HTTP_STATUS_FORBIDDEN:
        case HTTP_STATUS_NOT_FOUND:
            [[processor pipeline] noteErrorName:commentString reason:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Server returns \"%@\" (%d)", @"OWF", [OWHTTPSession bundle], @"httpsession 400-series error - string and numeric code from server"), commentString, httpStatus]];
            [processor flagResult:OWProcessorContentIsError];
            [self readHeadersForProcessor:processor];
            [self readBodyForProcessor:processor ignore:NO];
            break;

        case HTTP_STATUS_UNAUTHORIZED:
        case HTTP_STATUS_PROXY_AUTHENTICATION_REQUIRED:
#define IsProxyAuth (httpStatus == HTTP_STATUS_PROXY_AUTHENTICATION_REQUIRED)
            [processor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Authorizing %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), [proxyLocation shortDisplayString]];
            [self readHeadersForProcessor:processor];
            if (IsProxyAuth) {
                notifyCredentials(proxyCredentials, NO, headerDictionary);
            } else {
                notifyCredentials([processor credentials], NO, headerDictionary);
                notifyCredentials(proxyCredentials, YES, headerDictionary);
            }
            oldCredentials = (IsProxyAuth ? proxyCredentials : [processor credentials]);
            if (!oldCredentials) oldCredentials = [NSArray array];
            authorizationRequest = [[[OWAuthorizationRequest authorizationRequestClass] alloc]
                initForType:(IsProxyAuth ? OWAuth_HTTP_Proxy : OWAuth_HTTP)
                netLocation:(IsProxyAuth ? proxyLocation : [fetchURL parsedNetLocation])
                defaultPort:[isa defaultPort]
                context:[processor pipeline]
                challenge:headerDictionary
                promptForMoreThan:oldCredentials];
            newCredentials = [authorizationRequest credentials];
            if (newCredentials == nil)
                [[processor pipeline] noteErrorName:(IsProxyAuth ? @"ProxyAuthFailed" : @"AuthFailed") reason:[authorizationRequest errorString]];
            if (newCredentials == nil || ![newCredentials count]) {
                [authorizationRequest release];
                [processor flagResult:OWProcessorContentIsError];
                [self readBodyForProcessor:processor ignore:NO];
            } else {
                OWAuthorizationCredential *newCredential;
                // If we got several new credentials, only add the first (hopefully best) one to our list. If it fails, we'll try again with the others.
                newCredential = [newCredentials objectAtIndex:0];
                    
                // We now send only the first (most recent) credential in the array each time, and the OWAuthorizationRequest class will only give us back credential that are not in the oldCredentials list
                if (IsProxyAuth) {
                    newCredentials = [[NSArray arrayWithObject:newCredential] arrayByAddingObjectsFromArray:proxyCredentials];
                    [proxyCredentials release];
                    proxyCredentials = [newCredentials retain];
                } else {
                    [processor addCredential:newCredential];
                }
                [authorizationRequest release];
                [self readBodyForProcessor:processor ignore:YES];
                return NO;  // Try again
            }
#undef IsProxyAuth
            break;

        case HTTP_STATUS_REQUEST_TIMEOUT:
            return NO; // Try again

        // 500 codes - Server error
        case HTTP_STATUS_INTERNAL_SERVER_ERROR:
        case HTTP_STATUS_NOT_IMPLEMENTED:
        case HTTP_STATUS_BAD_GATEWAY:
        case HTTP_STATUS_SERVICE_UNAVAILABLE:
        case HTTP_STATUS_GATEWAY_TIMEOUT:
            [[processor pipeline] noteErrorName:commentString reason:[NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Server returns \"%@\" (%d)", @"OWF", [OWHTTPSession bundle], @"httpsession 500-series error - string and numeric code from server"), commentString, httpStatus]];
            [self readHeadersForProcessor:processor];
            [processor flagResult:OWProcessorContentIsError];
            [self readBodyForProcessor:processor ignore:NO];
            break;

        // Unrecognized client code, treat as x00

        default:
            {
                HTTPStatus equivalentStatus;

                equivalentStatus = httpStatus - httpStatus % 100;
                if (equivalentStatus == httpStatus)
                    httpStatus = HTTP_STATUS_NOT_IMPLEMENTED;
                else
                    httpStatus = equivalentStatus;
            }
            goto processStatus;
    }
    return YES;
}

- (void)readBodyForProcessor:(OWHTTPProcessor *)processor ignore:(BOOL)ignoreThis;
{
    OWParameterizedContentType *parameterizedContentType;
    OWContent *resultContent;
    unsigned int totalLength;
    unsigned int precedingSkipLength, followingSkipLength;
    long long startPosition = 0LL;

    NSString *receivedRangeString = [headerDictionary lastStringForKey:@"content-range"];
    if (receivedRangeString != nil) {
        // Content-Range: bytes 21010-47021/47022

        NSScanner *scanner = [NSScanner scannerWithString:receivedRangeString];
        long long endPosition;
        long long length;

        [scanner scanString:@"bytes" intoString:NULL];
        [scanner scanLongLong:&startPosition];
        [scanner scanString:@"-" intoString:NULL];
        [scanner scanLongLong:&endPosition];
        [scanner scanString:@"/" intoString:NULL];
        [scanner scanLongLong:&length];

        receivedRange.location = startPosition;
        receivedRange.length = endPosition - startPosition + 1;
        totalLength = length;
    } else {
        NSString *contentLengthString = [headerDictionary lastStringForKey:@"content-length"];
        totalLength = [contentLengthString intValue];
        receivedRange = NSMakeRange(0, totalLength);
    }

    precedingSkipLength = receivedRange.location - desiredRange.location;
    if ((NSMaxRange(receivedRange) < NSMaxRange(desiredRange)) || (desiredRange.length == 0 && NSMaxRange(receivedRange) != totalLength - 1)) {
        fetchFlags.incompleteResult = YES;
        followingSkipLength = 0;
    } else if (desiredRange.length)
        followingSkipLength = NSMaxRange(receivedRange) - NSMaxRange(desiredRange);
    else
        followingSkipLength = 0;

    if (ignoreThis) {
        interruptedDataStream = nil;
        resultContent = nil;
    } else if (interruptedDataStream == nil) {
        OWContentType *testContentType;

        if (receivedRange.length > 0)
            interruptedDataStream = [[OWDataStream alloc] initWithLength:receivedRange.length];
        else
            interruptedDataStream = [[OWDataStream alloc] init];
        [processor setDataStream:interruptedDataStream];
        [interruptedDataStream setStartPositionInFile:startPosition];
        resultContent = [processor content];

        parameterizedContentType = [headerDictionary parameterizedContentType];
        testContentType = [parameterizedContentType contentType];
        if (kludge.distrustContentType && (testContentType == textPlainContentType || testContentType == textXMLContentType || testContentType == applicationOctetStreamContentType || testContentType == applicationXMLContentType || testContentType == wildcardContentType)) {
            // Treat text/plain and application/octet-stream as www/unknown.  A lot of web servers out there use these as default content types, which means they end up claiming that, say, .gnutar.gz files are text/plain, or ReadMe is application/octet-stream.  So...if we see a suspicious content type, let's just run it through our data detector and see whether it really is what it claims to be.  (Some HTML pages are also served as text/plain, but IE displays them as HTML even though they're valid plain text.  This also makes us compatible with that behavior.)
            [headerDictionary addString:[[OWContentType unknownContentType] contentTypeString] forKey:@"Content-Type"];
        }
        [processor addHeaders:headerDictionary];
        [processor addContent];
        if ([queue shouldPipelineRequests]) {
            // If it's not okay to pipeline requests, then we can't fetch partial ranges anyway, so we don't want to cache this data stream.
        }
    } else {
        resultContent = [processor content];
    }
    
    [processor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Reading document from %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), [proxyLocation shortDisplayString]];
    
    NS_DURING {

        if ([@"chunked" caseInsensitiveCompare:[headerDictionary lastStringForKey:@"transfer-encoding"]] == NSOrderedSame)
            [self readChunkedBodyIntoStream:interruptedDataStream precedingSkipLength:precedingSkipLength forProcessor:processor];
        else if ([headerDictionary lastStringForKey:@"content-length"])
            [self readStandardBodyIntoStream:interruptedDataStream precedingSkipLength:precedingSkipLength forProcessor:processor];
        else
            [self readClosingBodyIntoStream:interruptedDataStream precedingSkipLength:precedingSkipLength forProcessor:processor];

    } NS_HANDLER {
#warning This probably doesnt work correctly for restarted fetches
        // The session will try to fetch more data into the same interruptedDataStream, which will add more headers to it, which will not work because we've already closed the headers off. On the other hand, what are we supposed to do if we get different headers on the second request?

        if ([processor status] != OWProcessorAborting) {
            [resultContent markEndOfHeaders];
            [localException raise];  // outer exception handler will end the data stream.
        }
        // If status == aborting, handle it below.
    } NS_ENDHANDLER;

    // If we quit reading because the processor is in the OWProcessorAborting state, then end any open streams and return... the caller will disconnect-and-requeue.
    if ([processor status] == OWProcessorAborting) {
        [resultContent markEndOfHeaders];
        [interruptedDataStream dataAbort];
        [(ONInternetSocket *)[socketStream socket] abortSocket];
        return;
    }

    // NSLog(@"%@: ending data stream %@", OBShortObjectDescription(self), OBShortObjectDescription(interruptedDataStream));
    [interruptedDataStream dataEnd];
    // NSLog(@"%@: ended data stream %@", OBShortObjectDescription(self), OBShortObjectDescription(interruptedDataStream));
}

#warning TODO [wiml nov2003] - verify that whoever makes HEAD requests can understand the results we produce here
- (BOOL)readHeadForProcessor:(OWHTTPProcessor *)processor;
{
    NSString *line;
    NSScanner *scanner;
    float httpVersion;
    HTTPStatus httpStatus;
    NSString *commentString;
    OWFileInfo *stamp = nil;
    id <OWProcessorContext> context = [processor pipeline];
    OWContent *resultContent;
    id <OWConcreteCacheEntry,NSObject> result;
    BOOL successResponse;

    [processor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Awaiting document info from %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), [proxyLocation shortDisplayString]];
    line = [socketStream peekLine];
    while (line != nil && [line isEqualToString:@""]) {
        // Skipping past leading newlines in the response fixes a problem I was seeing talking to a SmallWebServer/2.0 (used in some bulletin boards like the one at Clan Fat, http://pub12.ezboard.com/bfat).  I think what might have happened is that they miscalculated their content length in an earlier request, and sent us an extra newline following the counted bytes.  The result was that every other request to the server would fail.
        // Note:  if we're actually talking to an HTTP 0.9 server, it's possible we're losing blank lines at the beginning of the content they're sending us.  But since I haven't seen any HTTP 0.9 servers in a long, long time...
        [socketStream readLine]; // Skip past the empty line
        line = [socketStream peekLine]; // And peek at the next one
    }
    if (line == nil)
        return NO;
    if (OWHTTPDebug)
        NSLog(@"%@ Rx: %@", [fetchURL scheme], line);
    scanner = [NSScanner scannerWithString:line];

    if (![scanner scanString:@"HTTP" intoString:NULL]) {
        // 0.9 server, so can't determine timestamp
        stamp = [[OWFileInfo alloc] initWithLastChangeDate:nil];
        resultContent = [[OWContent alloc] initWithContent:stamp];
        [stamp release];
        [resultContent markEndOfHeaders];
        [context addContent:resultContent fromProcessor:processor flags:OWProcessorTypeAuxiliary];
        [resultContent release];
        return YES;
    }

    [socketStream readLine]; // Skip past the line we're already parsing
    [scanner scanString:@"/" intoString:NULL];
    [scanner scanFloat:&httpVersion];
    if (OWHTTPDebug)
        NSLog(@"Rx: %@", [fetchAddress addressString]);
    if (httpVersion > 1.0) {
        [queue setServerUnderstandsPipelinedRequests];
    }

    [scanner scanInt:(int *)&httpStatus];
    if (![scanner scanUpToString:@"\n" intoString:&commentString])
        commentString = @"";

processStatus:
    switch (httpStatus) {

        // 200 codes - Got MIME object

        case HTTP_STATUS_OK:
        case HTTP_STATUS_CREATED:
        case HTTP_STATUS_ACCEPTED:
        case HTTP_STATUS_NON_AUTHORITATIVE_INFORMATION:
        case HTTP_STATUS_NO_CONTENT:
        case HTTP_STATUS_RESET_CONTENT:
        case HTTP_STATUS_PARTIAL_CONTENT:
            [self readHeadersForProcessor:processor];
            successResponse = YES;
            break;

        // 300 codes - Various forms of redirection

        case HTTP_STATUS_MULTIPLE_CHOICES:
            // Client-driven content negotiation status.
            successResponse = YES;
            break;

        case HTTP_STATUS_MOVED_PERMANENTLY:
        case HTTP_STATUS_MOVED_TEMPORARILY:
        case HTTP_STATUS_SEE_OTHER:
            {
                NSString *newLocationString;
                OWAddress *newLocation;
                unsigned redirectionFlags;
                OWContent *newContent;

                [self readHeadersForProcessor:processor];
                newLocationString = [headerDictionary lastStringForKey:@"location"];
                if (newLocationString == nil)
                    [NSException raise:@"Redirect failure" format:NSLocalizedStringFromTableInBundle(@"Location header missing on redirect", @"OWF", [OWHTTPSession bundle], @"httpsession error - required header missing in response")];
                newLocation = [fetchAddress addressForRelativeString:newLocationString];
                [processor setStatusFormat:NSLocalizedStringFromTableInBundle(@"Redirected to %@", @"OWF", [OWHTTPSession bundle], @"httpsession status"), newLocationString];
                redirectionFlags = 0;
                if (httpStatus == HTTP_STATUS_MOVED_PERMANENTLY)
                    redirectionFlags |= OWProcessorRedirectIsPermanent;
                if (httpStatus == HTTP_STATUS_MOVED_PERMANENTLY &&
                    [[newLocation addressString] isEqualToString:[[fetchAddress addressString] stringByAppendingString:@"/"]])
                    redirectionFlags |= OWProcessorRedirectIsSame;
                newContent = [[OWContent alloc] initWithName:@"Redirect" content:newLocation];
                [newContent addHeader:OWContentRedirectionTypeMetadataKey value:[NSNumber numberWithUnsignedInt:redirectionFlags]];
                [newContent addHeaders:[headerDictionary dictionaryCopy]];
                [newContent markEndOfHeaders];
                [context addContent:newContent fromProcessor:processor flags:OWProcessorTypeRetrieval];
                [newContent release];
            }
            return YES;

        case HTTP_STATUS_NOT_MODIFIED:
            successResponse = YES;
            break;
        case HTTP_STATUS_USE_PROXY:
            successResponse = NO;
            break;

        // 400 codes - Access Authorization problem

        case HTTP_STATUS_UNAUTHORIZED:
            // TODO: authorization

        case HTTP_STATUS_PAYMENT_REQUIRED:
        case HTTP_STATUS_FORBIDDEN:
        case HTTP_STATUS_NOT_FOUND:
            successResponse = NO;
            break;

        case HTTP_STATUS_REQUEST_TIMEOUT:
            return NO; // Try again

        case HTTP_STATUS_BAD_REQUEST:
            // fall through to 500 codes

        // 500 codes - Server error

        case HTTP_STATUS_INTERNAL_SERVER_ERROR:
        case HTTP_STATUS_BAD_GATEWAY:
        case HTTP_STATUS_NOT_IMPLEMENTED: 
        case HTTP_STATUS_SERVICE_UNAVAILABLE:
        case HTTP_STATUS_GATEWAY_TIMEOUT:
            // ignore it and try later?
            successResponse = NO;
            break;

        // Unrecognized client code, treat as x00

        default:
            {
                HTTPStatus equivalentStatus;

                equivalentStatus = httpStatus - httpStatus % 100;
                if (equivalentStatus == httpStatus)
                    httpStatus = HTTP_STATUS_NOT_IMPLEMENTED;
                else
                    httpStatus = equivalentStatus;
            }
            goto processStatus;
    }

    // Create an OWFileInfo object if we have some file info, or an error object if the request failed. In any case, attach the headers to the resulting content.
    if (successResponse) {
        NSString *headerString;
        NSNumber *objectSize;
        NSDate *lastModifiedDate;
        
        headerString = [headerDictionary lastStringForKey:@"last-modified"];
        if (headerString)
            lastModifiedDate = [NSDate dateWithHTTPDateString:headerString];
        else
            lastModifiedDate = nil;

        headerString = [headerDictionary lastStringForKey:@"content-length"];
        objectSize = nil;
        if (headerString) {
            long long contentLength = [headerString longLongValue];
            if (contentLength != 0)
                objectSize = [NSNumber numberWithLongLong:contentLength];
        }
            
        result = [[OWFileInfo alloc] initWithAddress:[processor sourceAddress] size:objectSize isDirectory:NO isShortcut:NO lastChangeDate:lastModifiedDate];
    } else {
        NSString *message;

        message = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"Server returns \"%@\" (%d)", @"OWF", [OWHTTPSession bundle], @"httpsession error - string and numeric code from server"), commentString, httpStatus];

        result = [[NSException alloc] initWithName:[NSString stringWithFormat:@"HTTP %d", httpStatus] reason:message userInfo:nil];
    }

    resultContent = [[OWContent alloc] initWithContent:result];
    [result release];
    [resultContent addHeaders:[headerDictionary dictionaryCopy]];
    [resultContent markEndOfHeaders];

    [context addContent:resultContent fromProcessor:processor flags: (successResponse? 0 : OWProcessorContentIsError)|OWProcessorTypeRetrieval];
    [resultContent release];
    
    return YES;
}

- (void)readHeadersForProcessor:(OWHTTPProcessor *)processor;
{
    [headerDictionary readRFC822HeadersFromSocketStream:socketStream];
    if (OWHTTPDebug)
        NSLog(@"Rx Headers:\n%@", headerDictionary);

    // Caller will add the headers to the content eventually

    [OWCookieDomain registerCookiesFromURL:[[processor sourceAddress] url] context:[processor pipeline] headerDictionary:headerDictionary];

    // Look for possible validators and add best one as the validator key
    NSString *headerString;

	// Prefer Last-Modified before ETag, because Apache's WebDAV support has a huge bug with If-Match (ETag), but works fine with If-Unmodified-Since
	// It is Apache bug #16593: <http://nagoya.apache.org/bugzilla/show_bug.cgi?id=16593>

    if ((headerString = [headerDictionary lastStringForKey:OWEntityLastModifiedHeaderString]))
        [headerDictionary addString:OWEntityLastModifiedHeaderString forKey:OWContentValidatorMetadataKey];
    else if ((headerString = [headerDictionary lastStringForKey:OWEntityTagHeaderString]))
        [headerDictionary addString:OWEntityTagHeaderString forKey:OWContentValidatorMetadataKey];
}

- (unsigned int)intValueFromHexString:(NSString *)aString;
{
    unsigned int addition, result = 0;
    unsigned int index, length = [aString length];
    unichar c;
    
    for (index = 0; index < length; index++) {
        c = [aString characterAtIndex:index];
        if ((c >= '0') && (c <= '9'))
            addition = c - '0';
        else if ((c >= 'a') && (c <= 'f'))
            addition = c - 'a' + 10;
        else if ((c >= 'A') && (c <= 'F'))
            addition = c - 'A' + 10;
        else
            break;
        result *= 16;
        result += addition;
    }
    return result;
}

- (void)readChunkedBodyIntoStream:(OWDataStream *)dataStream precedingSkipLength:(unsigned)precedingSkipLength forProcessor:(OWHTTPProcessor *)processor;
{
    OWHeaderDictionary *trailingHeaderDictionary;
    unsigned int totalByteCount = 0, totalLength = 0;
    
    while ([processor status] == OWProcessorRunning) {
        NSAutoreleasePool *autoreleasePool = nil;
        NSString *contentLengthString;
        unsigned int bytesLeft;
        unsigned int bytesInThisPool;

        autoreleasePool = [[NSAutoreleasePool alloc] init];
        contentLengthString = [socketStream peekLine];
        bytesLeft = [self intValueFromHexString:contentLengthString];
        if (totalLength == 0 && bytesLeft == 0 && ![contentLengthString hasPrefix:@"0"]) {
            // Oops, this isn't actually chunked; try reading this as a "closing" body instead.  (This fixes an intermittent problem reading <http://www.msnbc.com/>.)
            [self readClosingBodyIntoStream:dataStream precedingSkipLength:precedingSkipLength forProcessor:processor];
            return;
        }
#ifdef DEBUG_kc0
        NSLog(@"Rx: %@\nChunk <%@> (%d bytes)", [fetchAddress addressString], contentLengthString, bytesLeft);
#endif
        (void)[socketStream readLine];
        if (bytesLeft == 0)
            break;
            
        bytesInThisPool = 0;
        totalLength += bytesLeft;
#ifdef DEBUG_kc0
        NSLog(@"%@ readChunkedBody: start: processed bytes %d of %d for dataStream %@, bytesLeft = %d", OBShortObjectDescription(self), totalByteCount, totalLength, OBShortObjectDescription(dataStream), bytesLeft);
#endif
        [processor processedBytes:totalByteCount ofBytes:totalLength];
        
        if (dataStream == nil)
            precedingSkipLength = bytesLeft;

        if (precedingSkipLength != 0) {
            int skipBytes = MIN(precedingSkipLength, bytesLeft);
            
            [socketStream skipBytes:skipBytes];
            precedingSkipLength -= skipBytes;
            bytesLeft -= skipBytes;
        }

        while ([processor status] == OWProcessorRunning && bytesLeft != 0) {
            unsigned int dataStreamBytesAvailable, socketBytesWritten;
            void *dataStreamBuffer;

            OBASSERT(dataStream != nil);
            dataStreamBytesAvailable = MIN([dataStream appendToUnderlyingBuffer:&dataStreamBuffer], bytesLeft);
            socketBytesWritten = [socketStream readBytesWithMaxLength:dataStreamBytesAvailable intoBuffer:dataStreamBuffer];
            if (socketBytesWritten == 0)
                break;
                
            totalByteCount += socketBytesWritten;
            bytesLeft -= socketBytesWritten;
            bytesInThisPool += socketBytesWritten;
            [processor processedBytes:totalByteCount ofBytes:totalLength];
#ifdef DEBUG_kc0
            NSLog(@"%@ readChunkedBody: processed bytes %d of %d for dataStream %@, bytesLeft = %d", OBShortObjectDescription(self), totalByteCount, totalLength, OBShortObjectDescription(dataStream), bytesLeft);
#endif
            [dataStream wroteBytesToUnderlyingBuffer:socketBytesWritten];
#ifdef DEBUG_kc0
            NSLog(@"%@ readChunkedBody: wrote data to %@", OBShortObjectDescription(self), OBShortObjectDescription(dataStream));
#endif
            if (bytesInThisPool > 64 * 1024) {
                [autoreleasePool release];
                autoreleasePool = [[NSAutoreleasePool alloc] init];
                bytesInThisPool = 0;
            }
        }
        [socketStream readLine];
        [autoreleasePool release];
    }
    if ([processor status] != OWProcessorRunning)
        return;
        
    trailingHeaderDictionary = [[OWHeaderDictionary alloc] init];
    [trailingHeaderDictionary autorelease];
    [trailingHeaderDictionary readRFC822HeadersFromSocketStream:socketStream];
    [processor addHeaders:trailingHeaderDictionary];
#ifdef DEBUG_kc0
    NSLog(@"Rx: %@\nRead trailing headers: %@", [fetchAddress addressString], trailingHeaderDictionary);
#endif
    [processor markEndOfHeaders];
}

- (void)readStandardBodyIntoStream:(OWDataStream *)dataStream precedingSkipLength:(unsigned)precedingSkipLength forProcessor:(OWHTTPProcessor *)processor;
{
    NSAutoreleasePool *autoreleasePool = nil;
    unsigned int contentLength, bytesLeft;
    unsigned int byteCount, bytesInThisPool;

    [processor markEndOfHeaders];

    autoreleasePool = [[NSAutoreleasePool alloc] init];
    contentLength = [[headerDictionary lastStringForKey:@"content-length"] intValue];
    bytesInThisPool = 0;
    byteCount = 0;
    bytesLeft = contentLength;
    // NSLog(@"%@ readStandardBody: start: processed bytes %d of %d for dataStream %@, bytesLeft = %d", OBShortObjectDescription(self), byteCount, contentLength, OBShortObjectDescription(dataStream), bytesLeft);
    [processor processedBytes:byteCount ofBytes:contentLength];

    if (dataStream == nil)
        precedingSkipLength = bytesLeft;

    if (precedingSkipLength != 0) {
        int skipBytes = MIN(precedingSkipLength, bytesLeft);
        
        [socketStream skipBytes:skipBytes];
        precedingSkipLength -= skipBytes;
        bytesLeft -= skipBytes;
    }

    while ([processor status] == OWProcessorRunning && bytesLeft != 0) {
        void *dataStreamBuffer;
        unsigned int dataStreamBytesAvailable, socketBytesWritten;

        OBASSERT(dataStream != nil);
        dataStreamBytesAvailable = MIN([dataStream appendToUnderlyingBuffer:&dataStreamBuffer], bytesLeft);
        socketBytesWritten = [socketStream readBytesWithMaxLength:dataStreamBytesAvailable intoBuffer:dataStreamBuffer];
        if (socketBytesWritten == 0)
            break;

        byteCount += socketBytesWritten;
        bytesLeft -= socketBytesWritten;
        bytesInThisPool += socketBytesWritten;
        [processor processedBytes:byteCount ofBytes:contentLength];
        // NSLog(@"%@ readStandardBody: processed bytes %d of %d for dataStream %@, bytesLeft = %d", OBShortObjectDescription(self), byteCount, contentLength, OBShortObjectDescription(dataStream), bytesLeft);
        [dataStream wroteBytesToUnderlyingBuffer:socketBytesWritten];
        // NSLog(@"%@ readStandardBody: wrote data to %@", OBShortObjectDescription(self), OBShortObjectDescription(dataStream));
        if (bytesInThisPool > 64 * 1024) {
            [autoreleasePool release];
            autoreleasePool = [[NSAutoreleasePool alloc] init];
            bytesInThisPool = 0;
        }
    }
    [autoreleasePool release];
    // We might be done, or we might be in the OWProcessorAborting state; the caller will check.
}

- (void)readClosingBodyIntoStream:(OWDataStream *)dataStream precedingSkipLength:(unsigned)precedingSkipLength forProcessor:(OWHTTPProcessor *)processor;
{
    NSAutoreleasePool *autoreleasePool = nil;
    void *dataStreamBuffer;
    unsigned int byteCount, bytesInThisPool;

    [processor markEndOfHeaders];

    if (dataStream == nil) {
        [self _closeSocketStream];
        return;
    }

    autoreleasePool = [[NSAutoreleasePool alloc] init];
    bytesInThisPool = 0;
    byteCount = 0;
    // NSLog(@"%@ readClosingBody: start: processed bytes %d for dataStream %@", OBShortObjectDescription(self), byteCount, OBShortObjectDescription(dataStream));
    [processor processedBytes:byteCount ofBytes:0];
    
    NS_DURING {

        if (precedingSkipLength) {
            [socketStream skipBytes:precedingSkipLength];
            byteCount += precedingSkipLength;
        }

        while ([processor status] == OWProcessorRunning) {
            unsigned int dataStreamBytesAvailable, socketBytesWritten;

            OBASSERT(dataStream != nil);
            dataStreamBytesAvailable = [dataStream appendToUnderlyingBuffer:&dataStreamBuffer];
            socketBytesWritten = [socketStream readBytesWithMaxLength:dataStreamBytesAvailable intoBuffer:dataStreamBuffer];
            if (socketBytesWritten == 0)
                break;

            byteCount += socketBytesWritten;
            bytesInThisPool += socketBytesWritten;
            [processor processedBytes:byteCount ofBytes:0];
            // NSLog(@"%@ readClosingBody: processed bytes %d for dataStream %@", OBShortObjectDescription(self), byteCount, OBShortObjectDescription(dataStream));
            [dataStream wroteBytesToUnderlyingBuffer:socketBytesWritten];
            // NSLog(@"%@ readClosingBody: wrote data to %@", OBShortObjectDescription(self), OBShortObjectDescription(dataStream));
            if (bytesInThisPool > 64 * 1024) {
                [autoreleasePool release];
                autoreleasePool = [[NSAutoreleasePool alloc] init];
                bytesInThisPool = 0;
            }
        }        
    } NS_HANDLER {
        // We ignore exceptions here on the assumption that they're just EOF indications from the server.
    } NS_ENDHANDLER;

    [autoreleasePool release];
}

// Closing

- (void)_closeSocketStream;
{
    [socketStream release];
    socketStream = nil;
}

// Exception handling

- (void)notifyProcessor:(OWHTTPProcessor *)aProcessor ofSessionException:(NSException *)sessionException;
{
    NS_DURING {
        [aProcessor handleSessionException:sessionException];
        [aProcessor processEnd];
        [aProcessor retire];
    } NS_HANDLER {
        NSLog(@"Exception trying to notify processor of session exception: sessionException = %@, localException = %@", sessionException, localException);
    } NS_ENDHANDLER;
}

@end
