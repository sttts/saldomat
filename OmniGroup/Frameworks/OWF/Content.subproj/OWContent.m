// Copyright 2003-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWContent.h"

#import <Foundation/Foundation.h>
#import <objc/malloc.h>

#import <OmniBase/rcsid.h>
#import <OmniBase/OBUtilities.h>

#import <OmniFoundation/CFDictionary-OFExtensions.h>
#import <OmniFoundation/CFPropertyList-OFExtensions.h>
#import <OmniFoundation/NSString-OFExtensions.h>
#import <OmniFoundation/OFMultiValueDictionary.h>
#import <OmniFoundation/OFUtilities.h>

#import "OWAddress.h"
#import "OWCacheControlSettings.h"
#import "OWContentInfo.h"
#import "OWContentType.h"
#import "OWDataStream.h"
#import "OWDataStreamCursor.h"
#import "OWDataStreamCharacterProcessor.h"
#import "OWHeaderDictionary.h"
#import "OWObjectStream.h"
#import "OWParameterizedContentType.h"
#import "OWPipeline.h"
#import "OWProcessor.h"
#import "NSDate-OWExtensions.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWContent.m 93428 2007-10-25 16:36:11Z kc $");

@interface OWContent (Private)
- _invalidContentType:(SEL)accessor;
- (void)_locked_fillContent;
- (void)_shareHandles:(NSMutableDictionary *)otherContentHandles;
- (BOOL)_locked_addHeader:(NSString *)headerName values:(NSArray *)several value:(id)one;
@end

// Possible values of smallConcreteType
enum {
    ConcreteType_Unknown,
    ConcreteType_Address,
    ConcreteType_DataStream,
    ConcreteType_ObjectStream,
    ConcreteType_Exception,
    ConcreteType_Other,
    ConcreteType_SwappedOut
};

// Possible values of dataComplete
enum {
    Data_NotComplete = 0,
    Data_EndedMaybeInvalid,
    Data_EndedAndValid,
    Data_Invalid
};

@implementation OWContent

static NSZone *OWContentZone = NULL;

+ (void)initialize;
{
    OBINITIALIZE;

    // TODO: Figure out if it's advantageous to do any zonification.
    OWContentZone = NSDefaultMallocZone();
}

+ (NSZone *)contentZone
{
    return OWContentZone;
}

// API --- convenient methods for creating an OWContent
+ (id)contentWithAddress:(OWAddress *)anAddress;
{
    OWContent *result;

    result = [[OWContent alloc] initWithName:@"Address" content:anAddress];
    [result autorelease];
    [result markEndOfHeaders];

    return result;
}

+ (id)contentWithAddress:(OWAddress *)newAddress redirectionFlags:(unsigned)flags interimContent:(OWContent *)interim;
{
    OWContent *result = [[OWContent alloc] initWithName:@"Redirect" content:newAddress];
    [result autorelease];
    if (flags != 0)
        [result addHeader:OWContentRedirectionTypeMetadataKey value:[NSNumber numberWithUnsignedInt:flags]];
    if (interim != nil)
        [result addHeader:OWContentInterimContentMetadataKey value:[NSNumber numberWithUnsignedInt:flags]];
    [result markEndOfHeaders];
    return result;
}

+ (id)contentWithDataStream:(OWDataStream *)dataStream isSource:(BOOL)sourcey
{
    OWContent *result = [[OWContent alloc] initWithName:@"DataStream" content:dataStream];
    [result autorelease];
    if (sourcey)
        [result addHeader:OWContentIsSourceMetadataKey value:[NSNumber numberWithBool:YES]];
    return result;
}

+ (id)contentWithData:(NSData *)someData headers:(OFMultiValueDictionary *)someMetadata;
{
    OWDataStream *dataStream;
    OWContent *result;

    if (someData == nil)
        dataStream = nil;
    else {
        dataStream = [[OWDataStream alloc] initWithLength:[someData length]];
        [dataStream writeData:someData];
        [dataStream dataEnd];
    }

    result = [self contentWithDataStream:dataStream isSource:NO];

    [dataStream release];
    
    if (someMetadata)
        [result addHeaders:someMetadata];

    [result markEndOfHeaders];

    return result;
}

+ (id)contentWithString:(NSString *)someText contentType:(NSString *)fullContentType isSource:(BOOL)contentIsSource;   // calls -markEndOfHeaders
{
    OWParameterizedContentType *parameterizedContentType;
    CFStringEncoding encoding;
    NSStringEncoding nsEncoding;
    NSData *bytes;
    OWDataStream *dataStream;
    OWContent *content;

    parameterizedContentType = [OWParameterizedContentType contentTypeForString:fullContentType];
    OBASSERT(parameterizedContentType != nil); // Or you shouldn't use this method!
    encoding = [OWDataStreamCharacterProcessor stringEncodingForContentType:parameterizedContentType];
    if (encoding == kCFStringEncodingInvalidId) {
        if ([someText canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            nsEncoding = NSASCIIStringEncoding;
        } else {
            nsEncoding = [someText smallestEncoding];
            encoding = CFStringConvertNSStringEncodingToEncoding(nsEncoding);
            [parameterizedContentType setObject:[OWDataStreamCharacterProcessor charsetForCFEncoding:encoding] forKey:@"charset"];
            fullContentType = [parameterizedContentType contentTypeString];
        }
    } else
        nsEncoding = CFStringConvertEncodingToNSStringEncoding(encoding);

    bytes = [someText dataUsingEncoding:nsEncoding allowLossyConversion:YES];
    dataStream = [[OWDataStream alloc] initWithLength:[bytes length]];
    [dataStream writeData:bytes];
    [dataStream dataEnd];

    content = [[self alloc] initWithContent:dataStream];
    [dataStream release];
    [content autorelease];

    [content addHeader:OWContentTypeHeaderString value:fullContentType];
    [content addHeader:OWContentIsSourceMetadataKey value:[NSNumber numberWithBool:contentIsSource]];
    [content markEndOfHeaders];

    OBPOSTCONDITION([content isHashable]);

    return content;
}

+ (id)contentWithConcreteCacheEntry:(id <OWConcreteCacheEntry>)aCacheEntry;
{
    OWContent *someContent;

    someContent = [[OWContent alloc] initWithContent:aCacheEntry];
    [someContent markEndOfHeaders];
    return [someContent autorelease];
}

+ (id)unknownContentFromContent:(OWContent *)mistypedContent;
{
    OWContent *unknownContent = [[mistypedContent copyWithMutableHeaders] autorelease];
    [unknownContent removeHeader:OWContentTypeHeaderString];
    [unknownContent removeHeader:OWContentIsSourceMetadataKey];
    [unknownContent setContentType:[OWContentType unknownContentType]];
    [unknownContent markEndOfHeaders];
    return unknownContent;
}

- (id)initWithContent:(id <OWConcreteCacheEntry>)someContent;
{
    return [self initWithName:nil content:someContent];
}

- (id)initWithContent:(id <OWConcreteCacheEntry>)someContent type:(NSString *)contentTypeString;
{
    if ([self initWithName:nil content:someContent] == nil)
        return nil;

    [self setContentTypeString:contentTypeString];

    return self;
}

- (id)initWithName:(NSString *)typeString content:(id <OWConcreteCacheEntry>)someContent;  // D.I.
{
    OBPRECONDITION(someContent != nil);

    if (![super init])
        return nil;

    if (someContent != nil) {
        // someContent should never be nil, but it possibly is if we're using copyWithReplacementHeader: and the original object's content is swapped out.
        OBASSERT([someContent conformsToProtocol:@protocol(OWConcreteCacheEntry)]);
    }

    if (someContent == nil || ![someContent isKindOfClass:[OWAddress class]])
        contentInfo = [[OWContentInfo alloc] initWithContent:self typeString:typeString];
    else
        contentInfo = nil;  // For some reason, addresses don't deserve contentinfos
    OFSimpleLockInit(&lock);
    metadataCompleteCondition = nil;
    metaData = [[OFMultiValueDictionary alloc] initWithCaseInsensitiveKeys:YES];
    metadataHash = 0;
    contentHash = 0;
    hasValidator = '?';
    concreteContent = [someContent retain];
    cachedContentType = nil;
    cachedContentEncodings = nil;
    containingCaches = (NSMutableDictionary *) CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &OFNSObjectDictionaryKeyCallbacks, &OFNSObjectDictionaryValueCallbacks);

    if ([concreteContent isKindOfClass:[OWAddress class]])
        smallConcreteType = ConcreteType_Address;
    else if ([concreteContent isKindOfClass:[OWDataStream class]])
        smallConcreteType = ConcreteType_DataStream;
    else if ([concreteContent isKindOfClass:[OWAbstractObjectStream class]])
        smallConcreteType = ConcreteType_ObjectStream;
    else if ([concreteContent isKindOfClass:[NSException class]])
        smallConcreteType = ConcreteType_Exception;
    else if (concreteContent != nil)
        smallConcreteType = ConcreteType_Other;
    else
        smallConcreteType = ConcreteType_Unknown;

    return self;
}

- initWithName:(NSString *)aName
{
    return [self initWithName:aName content:nil];
}

#ifdef DEBUG_OWnContent_REFS
static void Thingy(id mememe, SEL wheee);

- retain
{
    Thingy(self, _cmd);
    return [super retain];
}

- (void)release
{
    Thingy(self, _cmd);
    [super release];
}

- autorelease
{
    Thingy(self, _cmd);
    return [super autorelease];
}

static void Thingy(id mememe, SEL wheee)
{
    // breakpoint
    // fprintf(stderr, "<%s %p> %s, rc=%d\n", mememe->isa->name, mememe, wheee, [mememe retainCount]);
}
#endif

- (void)dealloc
{
    NSEnumerator *cacheEnumerator;
    id <OWCacheContentProvider> aCache;
    
    [contentInfo nullifyContent];
    [contentInfo release];
    contentInfo = nil;

    cacheEnumerator = [containingCaches keyEnumerator];
    while( (aCache = [cacheEnumerator nextObject]) != nil ) {
        [aCache adjustHandle:[containingCaches objectForKey:aCache] reference:-1];
    }
    [containingCaches release];
    containingCaches = nil;
    
    [metaData release];
    [metadataCompleteCondition release];
    [concreteContent release];
    [cachedContentType release];
    [cachedContentEncodings release];
    OFSimpleLockFree(&lock);
    [super dealloc];
}

- (OWContentInfo *)contentInfo;
{
    return contentInfo;
}

- (BOOL)checkForAvailability:(BOOL)loadNow
{
    NSArray *codings;
    unsigned codingIndex, codingCount;

    // Check whether we have any content-encodings whose filters aren't loaded
    codings = [self contentEncodings];
    if (codings && (codingCount = [codings count])) {
        for(codingIndex = 0; codingIndex < codingCount; codingIndex ++) {
            OWContentType *coding = [codings objectAtIndex:codingIndex];
            BOOL coderLoaded;

            coderLoaded = [OWDataStreamCursor availableEncoding:coding apply:NO remove:YES tryLoad:loadNow];
            
            if (!coderLoaded && !loadNow)
                return NO;
            if (!coderLoaded && loadNow)
                [NSException raise:OWDataStreamCursor_UnknownEncodingException format:@"Unknown or unsupported content encoding: \"%@\"", [coding readableString]];
        }
    }

    // right now the only kind of non-availability we have is unloaded content-encoding filters.
    return YES;
}

- (OWContentType *)contentType;
{
    OWContentType *contentType;

    // Note that the concreteContent's content type overrides any content type derived from the metadata; this is necessary for things like error responses and HEAD responses.

    if (concreteContent && [concreteContent respondsToSelector:@selector(contentType)])
        contentType = [(id)concreteContent contentType];
    else
        contentType = [[self fullContentType] contentType];
    if (contentType == nil)
        contentType = [OWContentType unknownContentType];

    OBPOSTCONDITION(contentType != nil);
    return contentType;
}

- (OWParameterizedContentType *)fullContentType;
{
    NSString *ctString;
    BOOL maybeStash;
    OWParameterizedContentType *parameterizedContentType;
    
    if (concreteContent && [concreteContent respondsToSelector:@selector(fullContentType)])
        return [(id)concreteContent fullContentType];

    OFSimpleLock(&lock);

    if (cachedContentType != nil) {
        parameterizedContentType = [[cachedContentType retain] autorelease];
        OFSimpleUnlock(&lock);
        return parameterizedContentType;
    }

    ctString = [[metaData lastObjectForKey:OWContentTypeHeaderString] retain];
    maybeStash = metadataComplete;
    
    OFSimpleUnlock(&lock);

    parameterizedContentType = [OWParameterizedContentType contentTypeForString:ctString];
    if (parameterizedContentType == nil)
        parameterizedContentType = [[[OWParameterizedContentType alloc] initWithContentType:[OWContentType unknownContentType]] autorelease];

    if (maybeStash) {
        OFSimpleLock(&lock);
        // Someone else may have come along and cached a content-type and/or modified the metadata
        if (cachedContentType == nil &&
            [ctString isEqual:[metaData lastObjectForKey:OWContentTypeHeaderString]]) {
            cachedContentType = [parameterizedContentType retain];
        }
        OFSimpleUnlock(&lock);
    }

    [ctString release];

    OBPOSTCONDITION(parameterizedContentType != nil);
    return parameterizedContentType;
}

- (NSArray *)contentEncodings
{
    NSArray *codingHeaders, *codingHeadersCopy;
    NSMutableArray *codingTokens, *codings;
    BOOL shouldCache;

    OFSimpleLock(&lock);

    if (metadataComplete && cachedContentEncodings != nil) {
        OFSimpleUnlock(&lock);
        return cachedContentEncodings;
    }
    shouldCache = metadataComplete;
    
    codingHeaders = [metaData arrayForKey:OWContentEncodingHeaderString];
    if (codingHeaders != nil && [codingHeaders count] > 0)
        codingHeadersCopy = [[NSArray alloc] initWithArray:codingHeaders];
    else
        codingHeadersCopy = nil;
    
    OFSimpleUnlock(&lock);
    
    if (codingHeadersCopy == nil)
        return nil;

    codingTokens = [OWHeaderDictionary splitHeaderValues:codingHeadersCopy];
    [codingHeadersCopy release];

    codings = [[NSMutableArray alloc] initWithCapacity:[codingTokens count]];
    [codings autorelease];
    while ([codingTokens count]) {
        NSString *codingName = [OWHeaderDictionary parseParameterizedHeader:[codingTokens lastObject] intoDictionary:nil valueChars:nil];
        OWContentType *encoding = [OWContentType contentEncodingForString:codingName];
        if (encoding != nil && encoding != [OWContentType contentEncodingForString:@"identity"])
            [codings insertObject:encoding atIndex:0];
        [codingTokens removeLastObject];
    }

    if (shouldCache) {
        OFSimpleLock(&lock);
        if (cachedContentEncodings == nil)
            cachedContentEncodings = [[NSArray alloc] initWithArray:codings];
        OFSimpleUnlock(&lock);
    }

    return codings;
}

- (BOOL)isAddress
{
    if (smallConcreteType == ConcreteType_Address)
        return YES;
    else
        return NO;
}

- (OWAddress *)address
{
    if (smallConcreteType == ConcreteType_Address)
        return (OWAddress *)concreteContent;
    else
        return [self _invalidContentType:_cmd];
}

- (BOOL)isDataStream
{
    if (smallConcreteType == ConcreteType_DataStream)
        return YES;
    else
        return NO;
}

- (OWDataStreamCursor *)dataCursor
{
    OWDataStreamCursor *cursor;
    NSArray *encodings;
    unsigned encodingIndex, encodingCount;
    
    if (smallConcreteType != ConcreteType_DataStream)
        return [self _invalidContentType:_cmd];

    OFSimpleLock(&lock);
    OWDataStream *thisDataStream = (OWDataStream *)concreteContent;
    OFSimpleUnlock(&lock);
    NS_DURING {
        cursor = [thisDataStream newCursor];
        if ([thisDataStream endOfData]) {
            BOOL contentIsValid = [thisDataStream contentIsValid];
            OFSimpleLock(&lock);
            if (contentIsValid)
                dataComplete = Data_EndedAndValid;
            else
                dataComplete = Data_Invalid;
            OFSimpleUnlock(&lock);
        }
    } NS_HANDLER {
        if ([[localException name] isEqualToString:OWDataStreamNoLongerValidException]) {
            OFSimpleLock(&lock);
            dataComplete = Data_Invalid;
            OFSimpleUnlock(&lock);
        }
        [localException raise];
        cursor = nil; // compiler pacification
    } NS_ENDHANDLER;

    // Add filters to remove any content-encodings which may have been applied, starting at the last (outermost) encoding and working back.
    encodings = [self contentEncodings];
    encodingCount = [encodings count];
    for(encodingIndex = 0; encodingIndex < encodingCount; encodingIndex ++) {
        OWContentType *contentEncoding = [encodings objectAtIndex:(encodingCount - encodingIndex - 1)];
        cursor = [OWDataStreamCursor cursorToRemoveEncoding:contentEncoding fromCursor:cursor];
    }

    return cursor;
}

- (OWObjectStreamCursor *)objectCursor;
{
    if (smallConcreteType == ConcreteType_ObjectStream)
        return [(OWAbstractObjectStream *)concreteContent newCursor];
    else
        return [self _invalidContentType:_cmd];
}

- (id)objectValue
{
    if (smallConcreteType != ConcreteType_Address)
        return [[concreteContent retain] autorelease];
    else
        return [self _invalidContentType:_cmd];
}

- (BOOL)isException;
{
    if (smallConcreteType == ConcreteType_Exception)
        return YES;
    else
        return NO;
}

- (BOOL)endOfData
{
    unsigned char dataStatus;
    BOOL dataEnded;

    OFSimpleLock(&lock);
    dataStatus = dataComplete;
    OFSimpleUnlock(&lock);

    if (dataStatus == Data_NotComplete) {

        dataEnded = [concreteContent endOfData];

        if (dataEnded) {
            OFSimpleLock(&lock);
            if (dataComplete == Data_NotComplete)
                dataComplete = Data_EndedMaybeInvalid;
            dataStatus = dataComplete;
            OFSimpleUnlock(&lock);
        }
    }

    return (dataStatus != Data_NotComplete);
}

- (BOOL)isHashable
{
    unsigned char dataCompleteCopy;
    
    OFSimpleLock(&lock);
    if (!metadataComplete) {
        OFSimpleUnlock(&lock);
        return NO;
    }
    dataCompleteCopy = dataComplete;
    OFSimpleUnlock(&lock);
    switch (dataCompleteCopy) {
        case Data_EndedAndValid:
            return YES;
        default:
        case Data_Invalid:
            return NO;
        case Data_NotComplete:
            if (![concreteContent endOfData])
                return NO;
            // FALLTHROUGH
        case Data_EndedMaybeInvalid:
            NS_DURING {
                [self contentHash];
            } NS_HANDLER {
                OFSimpleLock(&lock);
                dataComplete = Data_Invalid;
                OFSimpleUnlock(&lock);
                return NO;
            } NS_ENDHANDLER;
            OFSimpleLock(&lock);
            dataComplete = Data_EndedAndValid;
            OFSimpleUnlock(&lock);
            return YES;
    }
}

- (BOOL)contentIsValid;
{
    return [concreteContent contentIsValid];
}

- (BOOL)isStorable;
{
    OWCacheControlSettings *cacheControlSettings = [self cacheControlSettings];
    return cacheControlSettings->noStore == NO;
}

- (BOOL)isSource;
{
    id isSourceHeader = [self lastObjectForKey:OWContentIsSourceMetadataKey];

    return isSourceHeader? [isSourceHeader boolValue] : NO;
}

- (BOOL)hasValidator
{
    if (hasValidator == '?') {
        NSString *validator;
        BOOL validatorSeen = NO;

        OFSimpleLock(&lock);

        validator = [metaData lastObjectForKey:OWEntityTagHeaderString];
        if (validator && [validator isKindOfClass:[NSString class]] && ![NSString isEmptyString:validator])
            validatorSeen = YES;
        if (!validatorSeen) {
            validator = [metaData lastObjectForKey:OWEntityLastModifiedHeaderString];
            if (validator && [validator isKindOfClass:[NSString class]] && ![NSString isEmptyString:validator])
                validatorSeen = YES;
        }

        if (metadataComplete)
            hasValidator = validatorSeen;

        OFSimpleUnlock(&lock);
        
        return validatorSeen;
    }

    if (hasValidator == 1)
        return YES;
    else
        return NO;
}

- (void)addHeader:(NSString *)headerName value:(id)headerValue;
{
    NSNotification *note;

    note = nil;

    OBASSERT(!metadataComplete);
    OBASSERT(headerValue != nil);

    OFSimpleLock(&lock);
    [self _locked_addHeader:headerName values:nil value:headerValue];
/*
    if ([self _locked_addHeader:headerName values:nil value:headerValue])
        note = [NSNotification notificationWithName:OWContentHasNewMetadataNotificationName object:self];
*/
    OFSimpleUnlock(&lock);
/*
    if (note)
        [OWPipeline lockAndPostNotification:note];
*/        
}

- (void)addHeader:(NSString *)headerName values:(NSArray *)values
{
    NSNotification *note;

    note = nil;

    OBASSERT(!metadataComplete);

    OFSimpleLock(&lock);

    [self _locked_addHeader:headerName values:values value:nil];
/*
    if ([self _locked_addHeader:headerName values:values value:nil])
        note = [NSNotification notificationWithName:OWContentHasNewMetadataNotificationName object:self];
*/
    OFSimpleUnlock(&lock);
/*
    if (note)
        [OWPipeline lockAndPostNotification:note];
*/        
}


- (void)addHeaders:(OFMultiValueDictionary *)headers;
{
    NSNotification *note;
    NSArray *newHeaders;
    NSString *headerName;
    unsigned int newHeaderIndex, newHeaderCount;
    
    note = nil;

    OBASSERT(!metadataComplete);

    OFSimpleLock(&lock);

    newHeaders = [headers allKeys];
    newHeaderCount = [newHeaders count];
    for(newHeaderIndex = 0; newHeaderIndex < newHeaderCount; newHeaderIndex ++) {
        BOOL changed;
        headerName = [newHeaders objectAtIndex:newHeaderIndex];

        changed = [self _locked_addHeader:headerName
                                   values:[headers arrayForKey:headerName] value:nil];
/*        
        if (changed && !note) {
            note = [NSNotification notificationWithName:OWContentHasNewMetadataNotificationName object:self];
        }
*/        
    }

    OFSimpleUnlock(&lock);
/*    
    if (note)
        [OWPipeline lockAndPostNotification:note];
*/        
}

- (void)removeHeader:(NSString *)headerName;
{
    NSNotification *note;

    note = nil;

    OBASSERT(!metadataComplete);

    OFSimpleLock(&lock);

    if ([metaData lastObjectForKey:headerName] != nil) {
        [metaData setObjects:nil forKey:headerName];
//        note = [NSNotification notificationWithName:OWContentHasNewMetadataNotificationName object:self];

        if (cachedContentType != nil &&
            [headerName caseInsensitiveCompare:OWContentTypeHeaderString] == NSOrderedSame) {
            [cachedContentType release];
            cachedContentType = nil;
        }
    }

    OFSimpleUnlock(&lock);
/*
    if (note)
        [OWPipeline lockAndPostNotification:note];
*/        
}

- (void)setContentTypeString:(NSString *)aString
{
    [self addHeader:OWContentTypeHeaderString value:aString];
}

- (void)setContentType:(OWContentType *)aType;
{
    [self addHeader:OWContentTypeHeaderString value:[aType contentTypeString]];
}

- (void)setFullContentType:(OWParameterizedContentType *)aType;
{
    [self setContentTypeString:[aType contentTypeString]];

    OFSimpleLock(&lock);

    if(cachedContentType == nil) {
        cachedContentType = [aType retain];
    } else {
        OBASSERT([cachedContentType isEqual:aType]);
    }

    OFSimpleUnlock(&lock);
}

- (void)setCharsetProvenance:(enum OWStringEncodingProvenance)provenance;
{
    [self addHeader:OWContentEncodingProvenanceMetadataKey value:[NSNumber numberWithInt:provenance]];
}

- (void)markEndOfHeaders;
{
    BOOL wasEnded;
    
    OFSimpleLock(&lock);
    wasEnded = metadataComplete;
    metadataComplete = YES;
    if (metadataCompleteCondition) {
        [metadataCompleteCondition lock];
        [metadataCompleteCondition unlockWithCondition:metadataComplete];
    }
    OFSimpleUnlock(&lock);

/*
    if (!wasEnded) {
        [OWPipeline lockAndPostNotification:[NSNotification notificationWithName:OWContentHasNewMetadataNotificationName object:self]];
    }
*/    
}

- (BOOL)endOfHeaders
{
    BOOL eoh;
    OFSimpleLock(&lock);
    eoh = metadataComplete;
    OFSimpleUnlock(&lock);
    return eoh;
}

- (void)waitForEndOfHeaders
{
    NSConditionLock *waitCondition;

    OFSimpleLock(&lock);

    if (metadataComplete) {
        OFSimpleUnlock(&lock);
        return;
    }

    if (metadataCompleteCondition == nil) {
        metadataCompleteCondition = [[NSConditionLock alloc] initWithCondition:metadataComplete];
    }

    waitCondition = [metadataCompleteCondition retain];

    OFSimpleUnlock(&lock);

    [waitCondition lockWhenCondition:YES];
    [waitCondition unlock];
    [waitCondition release];
    waitCondition = nil;

#ifdef OMNI_ASSERTIONS_ON
    OFSimpleLock(&lock);
    OBASSERT(metadataComplete);
    OFSimpleUnlock(&lock);
#endif
}

- (OFMultiValueDictionary *)headers
{
    OFMultiValueDictionary *result;

    OFSimpleLock(&lock);
    if (metadataComplete)
        result = [metaData retain];
    else
        result = [metaData mutableCopy];
    OFSimpleUnlock(&lock);

    return [result autorelease];
}

- lastObjectForKey:(NSString *)headerKey
{
    id result;

    OFSimpleLock(&lock);
    result = [[metaData lastObjectForKey:headerKey] retain];
    OFSimpleUnlock(&lock);
    return [result autorelease];
}

- (OWCacheControlSettings *)cacheControlSettings;
{
    return [OWCacheControlSettings cacheSettingsForMultiValueDictionary:[self headers]];
}

- (id)headersAsPropertyList
{
    NSDictionary *result;
    
    OFSimpleLock(&lock);
    if (metadataComplete)
        result = [[metaData dictionary] retain];
    else
        result = [[metaData dictionary] copy];
    OFSimpleUnlock(&lock);

    return [result autorelease];
}

- (void)addHeadersFromPropertyList:(id)plist
{
    if (plist == nil)
        return;
    
    {OFForEachObject([plist keyEnumerator], NSString *, aKey) {
        [metaData addObjects:[plist objectForKey:aKey] forKey:aKey];
    }}
}

- (NSDictionary *)suggestedFileAttributesWithAddress:(OWAddress *)originAddress;
{
    NSString *contentDisposition;
    OFMultiValueDictionary *contentDispositionParameters;
    NSString *filename;
    OWContentType *mimeType;
    NSMutableDictionary *fileAttributes;
    NSString *value;
    BOOL hfsTypesInContentDisposition;

    fileAttributes = [NSMutableDictionary dictionary];
    hfsTypesInContentDisposition = NO;

    mimeType = [self contentType];

    contentDispositionParameters = [[OFMultiValueDictionary alloc] init];
    contentDisposition = [OWHeaderDictionary parseParameterizedHeader:[self lastObjectForKey:OWContentDispositionHeaderString] intoDictionary:contentDispositionParameters valueChars:nil];
    
    // Extract and sanitize the filename parameter
    filename = [contentDispositionParameters lastObjectForKey:@"filename"];
    if (filename && ![filename containsString:[NSString stringWithCharacter:0]]) {
        filename = [[filename lastPathComponent] stringByRemovingSurroundingWhitespace];
        if ([filename hasPrefix:@"."] || [filename hasPrefix:@"~"])
            filename = [@"_" stringByAppendingString:[filename substringFromIndex:1]];
        if (![NSString isEmptyString:filename])
            [fileAttributes setObject:filename forKey:OWContentFileAttributeNameKey];
    }
    
    // Nonstandard but widely used Content-Disposition parameters for storing HFS types.
    value = [contentDispositionParameters lastObjectForKey:@"x-mac-creator"];
    if (value) {
        OSType fourcc = [value hexValue];
        if (fourcc != 0) {
            [fileAttributes setObject:[NSNumber numberWithUnsignedLong:fourcc] forKey:NSFileHFSCreatorCode];
            hfsTypesInContentDisposition = YES;
        }
    }
    value = [contentDispositionParameters lastObjectForKey:@"x-mac-type"];
    if (value) {
        OSType fourcc = [value hexValue];
        if (fourcc != 0) {
            [fileAttributes setObject:[NSNumber numberWithUnsignedLong:fourcc] forKey:NSFileHFSTypeCode];
            hfsTypesInContentDisposition = YES;
        }
    }
    
    // Copy out some timestamps.
    value = [contentDispositionParameters lastObjectForKey:@"creation-date"];
    if (value) {
        NSDate *creationDate = [NSDate dateWithHTTPDateString:value];
        if (creationDate)
            [fileAttributes setObject:creationDate forKey:NSFileCreationDate];
    }

    [contentDispositionParameters release];
    
    // If not found in Content-Disposition, copy the HFS types from the Content-Type.
    if (mimeType && !hfsTypesInContentDisposition) {
        OSType macType;

        macType = [mimeType hfsType];
        if (macType != 0)
            [fileAttributes setObject:[NSNumber numberWithUnsignedLong:macType] forKey:NSFileHFSTypeCode];
        macType = [mimeType hfsCreator];
        if (macType != 0)
            [fileAttributes setObject:[NSNumber numberWithUnsignedLong:macType] forKey:NSFileHFSCreatorCode];
    }
    
    // If not found in Content-Disposition, try to cons up a filename from the address.
    if (![fileAttributes objectForKey:OWContentFileAttributeNameKey]) {
        filename = [originAddress suggestedFilename];
        if (![NSString isEmptyString:filename]) {
            filename = [mimeType pathForEncodings:[self contentEncodings] givenOriginalPath:filename];
            if (filename)
                [fileAttributes setObject:filename forKey:OWContentFileAttributeNameKey];
        }
    }

    return fileAttributes;
}

- (BOOL)isEqual:(id)anotherObject;
{
    OWContent *other;
    OFMultiValueDictionary *otherHeaders;
    BOOL handleMatch, locked;

    // NB: The pipeline lock is not necessarily held at this point.

    if (anotherObject == self)
        return YES;

    if (anotherObject == nil || ((OWContent *)anotherObject)->isa != isa)
        return NO;

    other = anotherObject;

    NS_DURING;

    if (![self isHashable] || ![other isHashable])
        NS_VALUERETURN(NO, BOOL);

    if ([self hash] != [other hash])
        NS_VALUERETURN(NO, BOOL);
    
    NS_HANDLER {
        return NO;
    } NS_ENDHANDLER;

    locked = NO;
    NS_DURING {

        otherHeaders = [other headers];
    
        OFSimpleLock(&lock);
        locked = YES;
    
        if (![metaData isEqual:otherHeaders]) {
            OFSimpleUnlock(&lock);
            NS_VALUERETURN(NO, BOOL);
        }
    
        NSArray *cacheKeys = [containingCaches allKeys];
    
        locked = NO;
        OFSimpleUnlock(&lock);
    
        handleMatch = NO;
        unsigned int keyCount = [cacheKeys count];
        unsigned int keyIndex;
        
        for (keyIndex = 0; keyIndex < keyCount; keyIndex++) {
            id <OWCacheContentProvider> aCache = (id)CFArrayGetValueAtIndex((CFArrayRef)cacheKeys, keyIndex);
            id otherHandle;
    
            otherHandle = [other handleForCache:aCache];
    
            if (otherHandle == nil)
                continue;
            if (![otherHandle isEqual:[self handleForCache:aCache]])
                NS_VALUERETURN(NO, BOOL);
            else {
                handleMatch = YES;
                break;
            }
        }
    
        if (!handleMatch) {
            BOOL contentMatch;
    
    #warning TODO LESS-BROKEN equality tests.
            // problems here:
            // 1. thread safety of access to concreteContent
            // 2. either our content or theirs may be missing atm.
            if (smallConcreteType == ConcreteType_DataStream)
                contentMatch = [(OWDataStream *)concreteContent isEqualToDataStream:[other objectValue]];
            else
                contentMatch = [concreteContent isEqual:other->concreteContent];
    
            if (!contentMatch)
                NS_VALUERETURN(NO, BOOL);
        }
    
        // If we reach this point, we've decided we're equivalent to the other content (all our values are equal). Share any cache handles with the other content for efficiency's sake.
        OFSimpleLock(&lock);
        locked = YES;
        [other _shareHandles:containingCaches];
        locked = NO;
        OFSimpleUnlock(&lock);
    
    } NS_HANDLER {
        if (locked)
            OFSimpleUnlock(&lock);
        if ([localException name] != OWDataStreamNoLongerValidException)
            NSLog(@"-[%@ %s]: %@", OBShortObjectDescription(self), _cmd, [localException description]);
        return NO;
    } NS_ENDHANDLER;


    return YES;
}

- (unsigned)hash
{
    unsigned myContentHash;
    
    if (!metadataComplete)
        [NSException raise:NSInternalInconsistencyException format:@"Cannot compute hash of %@", [self description]];

    myContentHash = [self contentHash];

    if (metadataHash == 0) {
        unsigned hashAccum = 0xfaded;
        
        OFForEachObject([metaData keyEnumerator], NSString *, aKey) {
            hashAccum ^= ( [aKey hash] | 1 ) * ( [[metaData lastObjectForKey:aKey] hash] | 1 );
        }
        
        if (hashAccum == 0)  // Highly unlikely, but ...
            hashAccum = 1;

        metadataHash = hashAccum;
    }

    return myContentHash ^ metadataHash;
}

- (unsigned)contentHash
{
    if (contentHash == 0) {
        unsigned myContentHash;
        NSEnumerator *cacheEnumerator;
        id <OWCacheContentProvider> aCache;
        id valueToHash;

        valueToHash = nil;
        NS_DURING {
            OFSimpleLock(&lock);
    
            if (concreteContent == nil) {
                cacheEnumerator = [containingCaches keyEnumerator];
                while( (aCache = [cacheEnumerator nextObject]) != nil) {
                    id handle = [containingCaches objectForKey:aCache];
                    [handle retain];
                    OFSimpleUnlock(&lock);
                    myContentHash = [aCache contentHashForHandle:handle];
                    [handle release];
                    if (myContentHash != 0) {
                        contentHash = myContentHash;
                        NS_VALUERETURN(myContentHash, unsigned);
                    }
                    OFSimpleLock(&lock);
                }
    
                [self _locked_fillContent];
            }
    
            if (dataComplete == Data_NotComplete) {
                if ([concreteContent endOfData])
                    dataComplete = Data_EndedMaybeInvalid;
                else
                    [NSException raise:NSInternalInconsistencyException format:@"Cannot compute hash of unfinished %@", [self shortDescription]];
            }
            if (dataComplete == Data_EndedMaybeInvalid) {
                if (smallConcreteType == ConcreteType_DataStream) {
                    if ([concreteContent contentIsValid])
                        dataComplete = Data_EndedAndValid;
                    else
                        dataComplete = Data_EndedMaybeInvalid;
                }
            }
            if (dataComplete == Data_Invalid) {
                [NSException raise:NSInternalInconsistencyException format:@"Cannot compute hash of invalidated %@", [self shortDescription]];
            }
    
            valueToHash = [[concreteContent retain] autorelease];

            OFSimpleUnlock(&lock);
        } NS_HANDLER {
            OFSimpleUnlock(&lock);
            [localException raise];
        } NS_ENDHANDLER;

        if ([valueToHash respondsToSelector:@selector(contentHash)]) {
            myContentHash = [valueToHash contentHash];
        } else if ([valueToHash respondsToSelector:@selector(md5Signature)]) {
            NSData *md5 = [valueToHash md5Signature];
            myContentHash = CFSwapInt32BigToHost(*(unsigned int *)[md5 bytes]);
        } else {
            myContentHash = [valueToHash hash];
        }
        
        if (myContentHash == 0)
            myContentHash = 1;

        contentHash = myContentHash;
    }

    return contentHash;
}

- (void)useHandle:(id)newHandle forCache:(id <OWCacheContentProvider>)aCache;
{
    id oldHandle;
    id incrementHandle, decrementHandle;
    CFMutableDictionaryRef handles;
    
    OBASSERT(newHandle != nil);
    OBASSERT(aCache != nil);

    OFSimpleLock(&lock);

    handles = (CFMutableDictionaryRef)containingCaches;
    incrementHandle = nil;
    decrementHandle = nil;

    oldHandle = (id)CFDictionaryGetValue(handles, aCache);
    if (oldHandle != newHandle) {
        incrementHandle = [newHandle retain];
        if (oldHandle != nil)
            decrementHandle = [oldHandle retain];
        CFDictionarySetValue(handles, aCache, newHandle);
    }

    OFSimpleUnlock(&lock);

    if (incrementHandle) {
        [aCache adjustHandle:incrementHandle reference:+1];
        [incrementHandle release];
    }

    if (decrementHandle) {
        [aCache adjustHandle:decrementHandle reference:-1];
        [decrementHandle release];
    }
}

- (id)handleForCache:(id <OWCacheContentProvider>)aCache;
{
    id handle;
    
    OFSimpleLock(&lock);
    handle = [containingCaches objectForKey:aCache];
    [handle retain];
    OFSimpleUnlock(&lock);

    return [handle autorelease];
}

- (OWContent *)copyWithMutableHeaders;
{
    OWContent *newContent;

    OFSimpleLock(&lock);
    newContent = [[isa alloc] initWithContent:concreteContent];
    // Direct access is OK here because nobody has a reference to the new content except us.
    newContent->contentHash = contentHash;
    [newContent addHeaders:metaData];
    OFSimpleUnlock(&lock);

    return newContent;
}

#warning OWContentHasNewMetadata notifications are commented out because they are currently unused
//NSString *OWContentHasNewMetadataNotificationName = @"OWContentHasNewMetadata";

@end


@implementation OWContent (Private)

- _invalidContentType:(SEL)accessor
{
    [NSException raise:NSInvalidArgumentException format:@"Accessor -%@ invoked on %@ with content type %@",
        NSStringFromSelector(accessor), [self shortDescription], [concreteContent class]];
    return nil;
}

- (void)_locked_fillContent;
{
    NSEnumerator *cacheEnumerator;
    id <OWCacheContentProvider> aCache;

    OBPRECONDITION(concreteContent == nil);

    cacheEnumerator = [containingCaches keyEnumerator];
    while ( (aCache = [cacheEnumerator nextObject]) != nil ) {
        concreteContent = [aCache contentForHandle:[containingCaches objectForKey:aCache]];
        [concreteContent retain];
        if (concreteContent != nil)
            break;
    }

    OBPOSTCONDITION([concreteContent conformsToProtocol:@protocol(OWConcreteCacheEntry)]);
    OBPOSTCONDITION(concreteContent != nil);
}

- (void)_shareHandles:(NSMutableDictionary *)otherContentHandles;
{
    NSEnumerator *cacheEnumerator;
    id <OWCacheContentProvider> aCache;
    id aHandle;

    // It's possible, though unlikely, for us to be deadlocking here (since the other content's lock will also be held at the moment). So we don't exchange handles if it would cause a block.
    if (!OFSimpleLockTry(&lock))
        return;

    cacheEnumerator = [otherContentHandles keyEnumerator];
    while( (aCache = [cacheEnumerator nextObject]) != nil ) {
        if ([containingCaches objectForKey:aCache] == nil) {
            aHandle = [otherContentHandles objectForKey:aCache];
            [aCache adjustHandle:aHandle reference:+1];
            CFDictionarySetValue((CFMutableDictionaryRef)containingCaches, aCache, aHandle);
        }
    }
    cacheEnumerator = [containingCaches keyEnumerator];
    while( (aCache = [cacheEnumerator nextObject]) != nil ) {
        if ([otherContentHandles objectForKey:aCache] == nil) {
            aHandle = [containingCaches objectForKey:aCache];
            [aCache adjustHandle:aHandle reference:+1];
            CFDictionarySetValue((CFMutableDictionaryRef)otherContentHandles, aCache, aHandle);
        }
    }

    OFSimpleUnlock(&lock);
}

- (BOOL)_locked_addHeader:(NSString *)headerName values:(NSArray *)several value:(id)one
{

    if (several && [several count]) {
        if (one) {
            several = [several arrayByAddingObject:one];
            one = nil;
        } else if ([several count] == 1) {
            one = [several objectAtIndex:0];
            several = nil;
        }
    } else {
        several = nil;
        if (one == nil)
            return NO;
    }

    if (one) {
        id oldValue = [metaData lastObjectForKey:headerName];

        if (oldValue == one && [oldValue isEqual:one])
            return NO;

        [metaData addObject:one forKey:headerName];
    } else {
        [metaData addObjects:several forKey:headerName];
    }

    if (cachedContentType != nil &&
        [headerName caseInsensitiveCompare:OWContentTypeHeaderString] == NSOrderedSame) {
        [cachedContentType release];
        cachedContentType = nil;
    }

    return YES;
}

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];

    // NOTE: Not thread-safe
    
    if (metadataComplete)
        [debugDictionary setObject:metaData forKey:@"metaData"];
    else
        [debugDictionary setObject:@"INCOMPLETE" forKey:@"metaData"];

    if (concreteContent) {
        if ([concreteContent isKindOfClass:[OWAddress class]])
            [debugDictionary setObject:[(OWAddress *)concreteContent addressString] forKey:@"concreteContent"];
        else
            [debugDictionary setObject:concreteContent forKey:@"concreteContent"];
    }

    return debugDictionary;
}

@end

