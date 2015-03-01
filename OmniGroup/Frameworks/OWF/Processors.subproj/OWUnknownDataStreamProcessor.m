// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWUnknownDataStreamProcessor.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWAddress.h>
#import <OWF/OWContent.h>
#import <OWF/OWContentType.h>
#import <OWF/OWDataStream.h>
#import <OWF/OWDataStreamCursor.h>
#import <OWF/OWDataStreamCharacterCursor.h>
#import <OWF/OWDataStreamCharacterProcessor.h>
#import <OWF/OWPipeline.h>
#import <OWF/OWURL.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Processors.subproj/OWUnknownDataStreamProcessor.m 93428 2007-10-25 16:36:11Z kc $")

@interface OWUnknownDataStreamProcessor (Private)

#define DEFAULT_LOOKAHEAD_BYTES 1024
#define ENCODING_GUESS_BUFFER_SIZE 1024
#define DEFAULT_LOOKAHEAD_CHARACTERS 512

- (NSDictionary *)contentTypeGuessForBytes:(OWDataStreamCursor *)cursor;
- (NSDictionary *)contentTypeGuessForCharacters:(OWDataStreamCharacterCursor *)cursor;
- (NSString *)characterEncodingGuessForBytes:(OWDataStreamCursor *)cursor;
- (OWContentType *)contentTypeGuessForXML;

@end

static OWContentType *textPlainContentType;
static OWContentType *applicationOctetStreamContentType;
static NSMutableArray *guessList;

@implementation OWUnknownDataStreamProcessor

+ (void)initialize;
{
    OBINITIALIZE;

    guessList = [[NSMutableArray alloc] init];

    textPlainContentType = [OWContentType contentTypeForString:@"text/plain"];
    applicationOctetStreamContentType = [OWContentType contentTypeForString:@"application/octet-stream"];
}

+ (void)didLoad;
{
    [self registerProcessorClass:self fromContentType:[OWContentType unknownContentType] toContentType:[OWContentType wildcardContentType] cost:1.0 producingSource:NO];
    [self registerProcessorClass:self fromContentType:[OWContentType sourceContentType] toContentType:[OWContentType retypedSourceContentType] cost:1.0 producingSource:NO];
}

+ (OWContentType *)unknownContentType;
{
    return [OWContentType unknownContentType];
}

static void
readGuessesIntoList(NSMutableArray *guessList, id guessObject, OWContentType *contentType, BOOL anywhere, NSNumber *lookahead, NSData *mask)
{
    NSMutableDictionary *guess;
    
    if ([guessObject isKindOfClass:[NSArray class]]) {
        NSEnumerator *guessEnumerator;
        id newGuessObject;

        guessEnumerator = [(NSArray *)guessObject objectEnumerator];
        while ((newGuessObject = [guessEnumerator nextObject]))
            readGuessesIntoList(guessList, newGuessObject, contentType, anywhere, lookahead, mask);
        return;
    }

    guess = [NSMutableDictionary dictionary];
    
    if ([guessObject isKindOfClass:[NSString class]]) {
        [guess setObject:guessObject forKey:@"string"];
    } else if ([guessObject isKindOfClass:[NSData class]]) {
        [guess setObject:guessObject forKey:@"bytes"];
    } else {
        return;
    }
    
    if (lookahead)
        [guess setObject:lookahead forKey:@"lookahead"];
    [guess setObject:contentType forKey:@"type"];
    [guess setBoolValue:anywhere forKey:@"anywhere"];
    if (mask)
        [guess setObject:mask forKey:@"mask"];

    [guessList addObject:[[guess copy] autorelease]];
}

+ (void)registerGuessesDictionary:(NSDictionary *)guessesDictionary;
{
    NSEnumerator *contentTypeEnumerator;
    NSString *contentTypeString;

    contentTypeEnumerator = [guessesDictionary keyEnumerator];

    while ((contentTypeString = [contentTypeEnumerator nextObject])) {
	OWContentType *contentType;
	NSDictionary *guessDictionary;
        NSNumber *lookahead;
        NSData *mask;

	contentType = [OWContentType contentTypeForString:contentTypeString];
	guessDictionary = [guessesDictionary objectForKey:contentTypeString];
        lookahead = [guessDictionary objectForKey:@"lookahead"];
        mask = [guessDictionary objectForKey:@"mask"];

	readGuessesIntoList(guessList, [guessDictionary objectForKey:@"prefix"], contentType, NO, nil, mask);
	readGuessesIntoList(guessList, [guessDictionary objectForKey:@"anywhere"], contentType, YES, lookahead, mask);
    }
}

//

- (void)dealloc
{
    [workingContent release];
    [super dealloc];
}

//

#if 0
// This is the standard naive quadratic string-search algorithm. I'm kind of suprised it isn't in libc somewhere.
static const char *OW_memfind(const char *buf, unsigned buflen, const char *pat, unsigned patlen)
{
    const char *bufend;
    
    if (patlen == 0)
        return buf;

    bufend = buf + buflen;
    while (buf + patlen <= bufend) {
        buf = memchr(buf, *pat, ( bufend - buf ) - ( patlen - 1 ));
        if (buf == NULL)
            break;
        if (memcmp(buf, pat, patlen) == 0)
            return buf;
        buf ++;
    }
    return NULL;
}
#endif

- (NSDictionary *)contentTypeGuessForBytes:(OWDataStreamCursor *)cursor
{
    unsigned guessIndex, guessCount;
    NSData *peekedData = nil;

    guessCount = [guessList count];
    for(guessIndex = 0; guessIndex < guessCount; guessIndex ++) {
        NSDictionary *guess = [guessList objectAtIndex:guessIndex];
        NSData *bytes;
        NSData *mask;
        NSMutableData *maskedData;
        NSNumber *lookaheadNumber;
        unsigned lookahead;
        BOOL anywhere;
        BOOL matches;

        bytes = [guess objectForKey:@"bytes"];
        if (!bytes)
            continue;
        mask = [guess objectForKey:@"mask"];
        lookaheadNumber = [guess objectForKey:@"lookahead"];
        anywhere = [guess boolForKey:@"anywhere" defaultValue:NO];
        if (lookaheadNumber)
            lookahead = [lookaheadNumber unsignedIntValue];
        else if (anywhere)
            lookahead = DEFAULT_LOOKAHEAD_BYTES;
        else
            lookahead = [bytes length];

        if (!peekedData || [peekedData length] < lookahead) {
            peekedData = [cursor peekBytesOrUntilEOF:lookahead];
        }

        // Apply a mask, if one was specified
        if (mask) {
            unsigned char *fileBytes;
            const unsigned char *maskBytes;
            unsigned length;
            maskedData = [peekedData mutableCopy];
            length = MIN([maskedData length], [mask length]);
            fileBytes = [maskedData mutableBytes];
            maskBytes = [mask bytes];
            while (length) {
                *fileBytes &= *maskBytes;
                fileBytes ++;
                maskBytes ++;
                length --;
            }
        } else
            maskedData = [peekedData retain];

        matches = (anywhere? [maskedData containsData:bytes] : [maskedData hasPrefix:bytes]);

        [maskedData release];
        
        if (matches)
            return guess;
    }

    return nil;
}

- (NSDictionary *)contentTypeGuessForCharacters:(OWDataStreamCharacterCursor *)cursor;
{
    unsigned guessIndex, guessCount;
    NSMutableString *beginning;

    beginning = [NSMutableString string];

    guessCount = [guessList count];
    for (guessIndex = 0; guessIndex < guessCount; guessIndex ++) {
        NSDictionary *guess = [guessList objectAtIndex:guessIndex];
        NSString *pattern;
        NSNumber *lookaheadNumber;
        unsigned lookahead;
        BOOL anywhere;
        NSRange searchRange, foundRange;

        pattern = [guess objectForKey:@"string"];
        if (!pattern)
            continue;
        lookaheadNumber = [guess objectForKey:@"lookahead"];
        anywhere = [guess boolForKey:@"anywhere" defaultValue:NO];
        if (lookaheadNumber)
            lookahead = [lookaheadNumber unsignedIntValue];
        else if (anywhere)
            lookahead = DEFAULT_LOOKAHEAD_CHARACTERS;
        else
            lookahead = [pattern length];

        while ([beginning length] < lookahead && ![cursor isAtEOF]) {
            [beginning appendString:[cursor readString]];
        }

        searchRange.location = 0;
        searchRange.length = MIN(lookahead, [beginning length]);
        foundRange = [beginning rangeOfString:pattern options:anywhere? 0 : NSAnchoredSearch range:searchRange];
        if (foundRange.length > 0)
            return guess;
    }

    return nil;
}

- (OWContentType *)contentTypeGuessForXML;
{
    // TODO: Parse the first few XML elements and see if we recognize the DTD or XMLNS names
    return [OWContentType contentTypeForString:@"application/xml"];
}

- (OWContentType *)contentTypeGuess;
{
    unsigned const char *buffer;
    int index;
    int controlCount;
    int textCount;
    int linefeedCount;
    int highCount;
    NSDictionary *guess;
    OWDataStreamCursor *byteCursor;
    NSData *prefixData;
    CFStringEncoding cfEncoding = kCFStringEncodingInvalidId;
        
    // TODO: Attempt to guess character encoding of text streams?

    // First we look for specific patterns of bytes. This catches .jpgs that are really .gifs and vice-versa.
    byteCursor = [workingContent dataCursor];
    guess = [self contentTypeGuessForBytes:byteCursor];
    if ([guess objectForKey:@"type"])
        return [guess objectForKey:@"type"];
    
    // Next we see if we can interpret the data stream as text, and if so, we look for textual patterns. This catches HTML that's been labeled as text/plain or application/octet-stream.
    if (guess && [guess objectForKey:@"charset"])
        cfEncoding = [OWDataStreamCharacterProcessor stringEncodingForIANACharSetName:[guess objectForKey:@"charset"]];
    if (cfEncoding == kCFStringEncodingInvalidId) {
        prefixData = [byteCursor peekBytesOrUntilEOF:3];

        if ([prefixData length] >= 3) {
            const unsigned char *buf = [prefixData bytes];
            // Check for the UTF-16 byte order mark.
            if ( (buf[0] == 0xFE && buf[1] == 0xFF) ||
                 (buf[0] == 0xFF && buf[1] == 0xFE) )
                cfEncoding = kCFStringEncodingUnicode;
            // Check for a BOM in UTF-8. This isn't very common, but it's a pretty good indication of UTF8 if it is there.
            if (buf[0] == 0xEF && buf[1] == 0xBB && buf[2] == 0xBF)
                cfEncoding = kCFStringEncodingUTF8;
        }

        // TODO: More guessing?
        // (WIM:) I think this is actually a bad idea. The charset= header is widely understood now, and most places do use it. Pandering to the few places that don't use it will only ensure that every browser ever written will have to ignore the RFCs and run the guessing algorithm. I'd rather not support that.
        // (WIM:) KHTML has a decoder class that does a bunch of heuristic goo (looking for META tags, looking for XML declarations, evaluating Japanese encodings, and so forth) but it's not visible from this framework, alas.
    }
    if (cfEncoding == kCFStringEncodingInvalidId)
        cfEncoding = kCFStringEncodingASCII;

    guess = [self contentTypeGuessForCharacters:[[[OWDataStreamCharacterCursor alloc] initForDataCursor:byteCursor encoding:cfEncoding] autorelease]];
    byteCursor = nil; // -contentTypeGuessForCharacters: will have advanced the cursor a random amount

    if ([guess objectForKey:@"type"])
        return [guess objectForKey:@"type"];

#if 0
    // We couldn't guess from the contents, so let's guess based on the filename
    OWAddress *sourceAddress = [pipeline contextObjectForKey:OWCacheArcSourceAddressKey];
    if (sourceAddress != nil) {
        OWContentType *guessContentType;

        guessContentType = [sourceAddress probableContentTypeBasedOnPath];
        if (guessContentType != [OWContentType unknownContentType])
            return guessContentType;
    }
#endif
    
    // Try a heuristic based on the ratio of text to line feeds (and no control characters).
    prefixData = [[workingContent dataCursor] peekBytesOrUntilEOF:1024];
    textCount = 0;
    controlCount = 0;
    linefeedCount = 0;
    highCount = 0;
    index = [prefixData length];
    buffer = [prefixData bytes];
    while (index--) {
        unsigned char ch;

        ch = buffer[index];
        switch (ch) {
            case '\n':
                linefeedCount++;
                break;
            case '\r':
            case '\f': // ignore FF
                break;
            case '\t':
                textCount++;
                break;
            default:
                if (ch < 32)
                    controlCount++;
                else if (ch < 128)
                    textCount++;
                else
                    highCount++;
        }
    }

    // This is the same questionable heuristic that the CERN library uses.
    if (controlCount == 0 || (textCount + linefeedCount >= 16 * (controlCount + highCount)))
	return textPlainContentType;
    else if ([prefixData hasPrefix:[NSData dataWithBytes:"BM" length:2]])
        return [OWContentType contentTypeForString:@"image/x-bmp"];
    else
	return applicationOctetStreamContentType;
}

- (void)process;
{
    OWContentType *typeGuess;

    [self setStatusString:NSLocalizedStringFromTableInBundle(@"Taking a guess at content type", @"OWF", [OWUnknownDataStreamProcessor bundle], @"unknowndatastreamprocessor status")];

    [workingContent release];
    workingContent = [originalContent retain];

    typeGuess = [self contentTypeGuess];
    if (typeGuess == [OWContentType contentTypeForString:@"application/xml"]) {
        typeGuess = [self contentTypeGuessForXML];
        OBASSERT(typeGuess != nil);
    }

    OWAddress *sourceAddress = [pipeline contextObjectForKey:OWCacheArcSourceAddressKey];
    NSString *addressString = [sourceAddress addressString];

    if (typeGuess == nil) {
        // Guessing apparently didn't help us any.
#ifdef DEBUG
        NSLog(@"DEBUG: %@: Could not guess content type: data=%@", addressString, [[originalContent dataCursor] logDescription]);
#endif
        return;
    }
    if (typeGuess == [workingContent contentType]) {
        // Guessing apparently didn't help us any.
#ifdef DEBUG
        NSLog(@"DEBUG: %@: Tried to guess better content-type, but it seems to really be %@ (data=%@)", addressString, [typeGuess contentTypeString], [[originalContent dataCursor] logDescription]);
#endif
        return;
    }
    
    if (typeGuess != nil && [typeGuess isEncoding]) {
        NSString *encodingString;
        encodingString = [[typeGuess contentTypeString] substringStartingAfterString:@"/"];
        if ([workingContent contentEncodings] != nil) {
#ifdef DEBUG
            NSLog(@"DEBUG: %@: Nested encoding (%@ inside %@)? Not likely.", addressString, encodingString, [workingContent contentEncodings]);
#endif
            return;
        }
        NSLog(@"%@: Guessing content encoding is %@", addressString, encodingString);
        [workingContent autorelease];
        workingContent = [workingContent copyWithMutableHeaders];
        [workingContent removeHeader:OWContentTypeHeaderString];
        [workingContent removeHeader:OWContentEncodingHeaderString];
        [workingContent removeHeader:OWContentIsSourceMetadataKey];
        [workingContent addHeader:OWContentEncodingHeaderString value:encodingString];
        [workingContent markEndOfHeaders];
        
        typeGuess = [self contentTypeGuess];
        if (typeGuess == [OWContentType contentTypeForString:@"application/xml"]) {
            typeGuess = [self contentTypeGuessForXML];
        }
    }

    OBASSERT(typeGuess != [OWContentType unknownContentType]);
    if (typeGuess != nil && ![typeGuess isEncoding] && typeGuess != [workingContent contentType] && typeGuess != [OWContentType unknownContentType]) {
        if ([workingContent contentType] != [OWContentType unknownContentType])
            NSLog(@"%@: Guessing content type is %@, not %@", addressString, [typeGuess contentTypeString], [[workingContent contentType] contentTypeString]);
        [workingContent autorelease];
        workingContent = [workingContent copyWithMutableHeaders];
        [workingContent removeHeader:OWContentTypeHeaderString];
        [workingContent removeHeader:OWContentIsSourceMetadataKey];
        [workingContent setContentType:typeGuess];
        [workingContent markEndOfHeaders];
    }

    if (![workingContent isEqual:originalContent]) {
        [pipeline addContent:workingContent fromProcessor:self flags:OWProcessorContentNoDiskCache|OWProcessorTypeDerived];
    } else {
#ifdef DEBUG
        NSLog(@"DEBUG: %@: Could not determine content type", addressString);
#endif
    }
}


@end
