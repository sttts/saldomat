// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWDataStreamCursor.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "OWContentType.h"
#import "OWDataStream.h"
#import "OWDataStreamCharacterCursor.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWDataStreamCursor.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OWDataStreamCursor

NSException *OWDataStreamCursor_UnderflowException;

NSString *OWDataStreamCursor_UnknownEncodingException = @"OWDataStreamCursor: Unknown Encoding";

NSMutableDictionary *encoders, *decoders;

+ (void)initialize;
{
    OBINITIALIZE;

    OWDataStreamCursor_UnderflowException = [[NSException alloc] initWithName:@"Underflow" reason:@"Attempted read off end of buffer" userInfo:nil];
    // OWDataStreamCursor_EndOfDataException = [[NSException alloc] initWithName:@"Out of data" reason:@"More data required, but no more data available" userInfo:nil];   // never used anymore --wim

    encoders = nil;
    decoders = [[NSMutableDictionary alloc] init];
}

// OFBundleRegistry support
+ (void)registerItemName:(NSString *)itemName bundle:(NSBundle *)bundle description:(NSDictionary *)dict;
{

    OFBundledClass *bundleClass = [OFBundledClass createBundledClassWithName:itemName bundle:bundle description:dict];

    {
        NSDictionary *codingList = [dict objectForKey:@"encodes"];
        OFForEachObject([codingList keyEnumerator], NSString *, encoding) {
            [encoders setObject:[NSArray arrayWithObjects:bundleClass, [codingList objectForKey:encoding], nil] forKey:[OWContentType contentEncodingForString:encoding]];
        }
    }

    {
        NSDictionary *codingList = [dict objectForKey:@"decodes"];
        OFForEachObject([codingList keyEnumerator], NSString *, encoding) {
            [decoders setObject:[NSArray arrayWithObjects:bundleClass, [codingList objectForKey:encoding], nil] forKey:[OWContentType contentEncodingForString:encoding]];
        }
    }
}

static OWDataStreamCursor *applyCursor(NSArray *coderInfo, OWDataStreamCursor *aCursor)
{
    OFBundledClass *coderClassBundle;
    Class coderClass;
    NSString *coderInitMethod;
    SEL coderInitSel;
    OWDataStreamCursor *newCursor;
    
    coderClassBundle = [coderInfo objectAtIndex:0];
    coderInitMethod = [coderInfo objectAtIndex:1];

    coderClass = [coderClassBundle bundledClass];
    OBASSERT(OBClassIsSubclassOfClass(coderClass, [OWDataStreamCursor class]));
    coderInitSel = NSSelectorFromString(coderInitMethod);
    // NSLog(@"Coder class: %@ (%p), sel=%s", coderClass, coderClass, coderInitSel);
    OBASSERT(coderInitSel != NULL);
    OBASSERT([coderClass instancesRespondToSelector:coderInitSel]);

    newCursor = [[coderClass allocWithZone:[aCursor zone]] performSelector:coderInitSel withObject:aCursor];
    [newCursor autorelease];
    return newCursor;
}

+ (OWDataStreamCursor *)cursorToRemoveEncoding:(OWContentType *)coding fromCursor:(OWDataStreamCursor *)aCursor
{
    NSArray *decodeInfo = [decoders objectForKey:coding];

    if (decodeInfo == nil) {
        [NSException raise:OWDataStreamCursor_UnknownEncodingException format:@"Unknown or unsupported data encoding: \"%@\"", [coding readableString]];
    }

    return applyCursor(decodeInfo, aCursor);
}

+ (OWDataStreamCursor *)cursorToApplyEncoding:(OWContentType *)coding toCursor:(OWDataStreamCursor *)aCursor;
{
    NSArray *encodeInfo = [encoders objectForKey:coding];

    if (encodeInfo == nil) {
        [NSException raise:OWDataStreamCursor_UnknownEncodingException format:@"Unknown or unsupported data encoding: \"%@\"", [coding readableString]];
    }

    return applyCursor(encodeInfo, aCursor);
}

+ (BOOL)availableEncoding:(OWContentType *)coding apply:(BOOL)wantToApply remove:(BOOL)wantToRemove tryLoad:(BOOL)loadNow
{
    NSArray *info;
    OFBundledClass *bundle;

    if (wantToApply) {
        info = [encoders objectForKey:coding];
        if (!info)
            return NO;
        bundle = [info objectAtIndex:0];
        if (![bundle isLoaded]) {
            if (loadNow)
                [bundle loadBundledClass];
            if (![bundle isLoaded])
                return NO;
        }
    }

    if (wantToRemove) {
        info = [decoders objectForKey:coding];
        if (!info)
            return NO;
        bundle = [info objectAtIndex:0];
        if (![bundle isLoaded]) {
            if (loadNow)
                [bundle loadBundledClass];
            if (![bundle isLoaded])
                return NO;
        }
    }

    return YES;
}

+ (NSArray *)availableEncodingsToRemove
{
    return [decoders allKeys];
}

// Init and dealloc

- initForDataStream:(OWDataStream *)aStream;
{
    if (![super init])
        return nil;

    byteOrder = NS_UnknownByteOrder;
    dataOffset = 0;
    bitsLeft = 0;

    return self;
}

//

- (void)setByteOrder:(OFByteOrder)newByteOrder;
{
    byteOrder = newByteOrder;
}

#define ABSTRACT { OBRequestConcreteImplementation(self, _cmd); }

- (id)initFromCursor:(id)aCursor				   ABSTRACT
- (BOOL)isAtEOF                                                    ABSTRACT
- (BOOL)haveFinishedReadingData                                    ABSTRACT
- (OWDataStream *)underlyingDataStream                             ABSTRACT
- (unsigned int)dataLength                                         ABSTRACT
- (void)readBytes:(unsigned int)count intoBuffer:(void *)buffer    ABSTRACT
- (void)peekBytes:(unsigned int)count intoBuffer:(void *)buffer    ABSTRACT
- (NSData *)peekBytesOrUntilEOF:(unsigned int)count                ABSTRACT
- (void)bufferBytes:(unsigned int)count                            ABSTRACT
- (BOOL)haveBufferedBytes:(unsigned int)count                      ABSTRACT
- (unsigned int)copyBytesToBuffer:(void *)buffer
                     minimumBytes:(unsigned int)maximum maximumBytes:(unsigned int)minimum
                          advance:(BOOL)shouldAdvance              ABSTRACT
- (unsigned int)peekUnderlyingBuffer:(void **)returnedBufferPtr    ABSTRACT
- (NSData *)readAllData                                            ABSTRACT

- (unsigned int)currentOffset;
{
    return dataOffset;
}

- (void)skipBytes:(unsigned int)count
{
    [self bufferBytes:count];
    dataOffset += count;
}

- (NSData *)readData
{
    unsigned int count;
    void *buf;

    count = [self readUnderlyingBuffer:&buf];
    return [[[NSData alloc] initWithBytes:buf length:count] autorelease];
}

- (NSData *)peekData
{
    unsigned int count;
    void *buf;

    count = [self peekUnderlyingBuffer:&buf];
    return [[[NSData alloc] initWithBytes:buf length:count] autorelease];
}

- (NSData *)readBytes:(unsigned int)count
{
    char *buffer;
    
    [self bufferBytes:count];
    
    buffer = malloc(count);
    [self readBytes:count intoBuffer:buffer];
    return [[[NSData alloc] initWithBytesNoCopy:buffer length:count freeWhenDone:YES] autorelease];
}

- (NSData *)peekBytes:(unsigned int)count
{
    char *buffer;

    [self bufferBytes:count];

    buffer = malloc(count);
    [self peekBytes:count intoBuffer:buffer];
    return [[[NSData alloc] initWithBytesNoCopy:buffer length:count freeWhenDone:YES] autorelease];
}

- (unsigned int)readMaximumBytes:(unsigned int)maximum intoBuffer:(void *)buffer;
{
    return [self copyBytesToBuffer:buffer minimumBytes:1 maximumBytes:maximum advance:YES];
}

- (unsigned int)peekMaximumBytes:(unsigned int)maximum intoBuffer:(void *)buffer;
{
    return [self copyBytesToBuffer:buffer minimumBytes:1 maximumBytes:maximum advance:NO];
}

#define SWAP_BYTES(inputValue, returnValue, swapType)		\
{									\
    switch (byteOrder) {						\
        case NS_UnknownByteOrder:	     				\
            memcpy(&returnValue, &inputValue, sizeof(returnValue));	\
            break;	   						\
        case NS_LittleEndian:						\
            returnValue = NSSwapLittle ## swapType ## ToHost(inputValue); \
            break;     							\
        case NS_BigEndian:     						\
            returnValue = NSSwapBig ## swapType ## ToHost(inputValue);	\
            break;	   						\
    }									\
}

#define READ_DATA_OF_TYPE(readType, swapType)				\
- (readType)read ## swapType;						\
{									\
    OWSwapped ## swapType inputValue;					\
    readType returnValue;						\
									\
    [self readBytes:sizeof(readType) intoBuffer:&inputValue];		\
    SWAP_BYTES(inputValue, returnValue, swapType);			\
    return returnValue;							\
}

#define PEEK_DATA_OF_TYPE(readType, swapType)				\
- (readType)peek ## swapType;						\
{									\
    OWSwapped ## swapType inputValue;					\
    readType returnValue;						\
									\
    [self peekBytes:sizeof(readType) intoBuffer:&inputValue];		\
    SWAP_BYTES(inputValue, returnValue, swapType);			\
    return returnValue;							\
}

typedef int OWSwappedInt;
typedef short OWSwappedShort;
typedef long OWSwappedLong;
typedef long long OWSwappedLongLong;
typedef NSSwappedFloat OWSwappedFloat;
typedef NSSwappedDouble OWSwappedDouble;

READ_DATA_OF_TYPE(int, Int);
PEEK_DATA_OF_TYPE(int, Int);
READ_DATA_OF_TYPE(short, Short);
PEEK_DATA_OF_TYPE(short, Short);
READ_DATA_OF_TYPE(long, Long);
PEEK_DATA_OF_TYPE(long, Long);
READ_DATA_OF_TYPE(long long, LongLong);
PEEK_DATA_OF_TYPE(long long, LongLong);
READ_DATA_OF_TYPE(float, Float);
PEEK_DATA_OF_TYPE(float, Float);
READ_DATA_OF_TYPE(double, Double);
PEEK_DATA_OF_TYPE(double, Double);

- (OFByte)readByte;
{
    OFByte returnValue;
    [self readBytes:1 intoBuffer:&returnValue];
    return returnValue;
}

- (OFByte)peekByte;
{
    OFByte returnValue;
    [self peekBytes:1 intoBuffer:&returnValue];
    return returnValue;
}

- (unsigned int)readBits:(unsigned int)number;
{
    unsigned int result = 0;

    if (bitsLeft) {
        partialByte &= (1 << bitsLeft) - 1;
        if (number > bitsLeft) {
            number -= bitsLeft;
            result = partialByte << number;
        } else {
            bitsLeft -= number;
            result = partialByte >> bitsLeft;
            number = 0;
        }
    }
    while (number) {
        [self readBytes:1 intoBuffer:&partialByte];
        if (number <= 8) {
            bitsLeft = 8 - number;
            result |= (partialByte >> bitsLeft);
            number = 0;
        } else {
            number -= 8;
            result |= (partialByte << number);
        }
    }
    return result;
}

- (int)readSignedBits:(unsigned int)number;
{
    int result = (int)[self readBits:number];

    if (result & (1 << (number-1)))
        result |= (-1 << number);
    return result;
}

- (void)skipToNextFullByte;
{
    bitsLeft = 0;
}

- (unsigned)scanUpToByte:(OFByte)byteMatch
{
    unsigned int scanOffset = dataOffset;

    while (![self isAtEOF]) {
        OFByte *buffer;
        void *fetch, *found;
        unsigned int bufferSize;

        bufferSize = [self readUnderlyingBuffer:&fetch];
        buffer = fetch;

        if (bufferSize == 0)
            continue;

        found = memchr(fetch, byteMatch, bufferSize);
        if (found) {
            // rewind to just before the byte we found
            [self seekToOffset: ( found - fetch ) - bufferSize fromPosition:OWCursorSeekFromCurrent];
            return dataOffset - scanOffset;
        }
    }

    /* byte not found */
    [OWDataStreamCursor_UnderflowException raise];
    /* NOTREACHED */
    return 0;
}

- (unsigned int)readUnderlyingBuffer:(void **)returnedBufferPtr;
{
    unsigned int count = [self peekUnderlyingBuffer:returnedBufferPtr];
    dataOffset += count;
    return count;
}

- (NSData *)readUpToByte:(OFByte)byteMatch
{
    OFByte *buffer;
    void *fetch, *found;
    unsigned int bufferSize;
    NSMutableData *accumulator;
    
    if ([self isAtEOF])
        return [NSData data];

    bufferSize = [self readUnderlyingBuffer:&fetch];
    buffer = fetch;

    found = memchr(fetch, byteMatch, bufferSize);
    if (found) {
        // rewind to just before the byte we found
        [self seekToOffset: ( found - fetch ) - bufferSize fromPosition:OWCursorSeekFromCurrent];
        return [NSData dataWithBytes:fetch length: (found - fetch)];
    }

    accumulator = [[NSMutableData alloc] initWithBytes:fetch length:bufferSize];
    [accumulator autorelease];

    while (![self isAtEOF]) {
        bufferSize = [self readUnderlyingBuffer:&fetch];
        buffer = fetch;
        
        if (bufferSize == 0)
            continue;

        found = memchr(fetch, byteMatch, bufferSize);
        if (found) {
            // rewind to just before the byte we found
            [self seekToOffset: ( found - fetch ) - bufferSize fromPosition:OWCursorSeekFromCurrent];
            [accumulator appendBytes:fetch length: (found - fetch)];
            return accumulator;
        } else {
            [accumulator appendBytes:fetch length:bufferSize];
        }
    }

    /* byte not found */
    return accumulator;
}

// OWCursor subclass

- (unsigned int)seekToOffset:(int)offset fromPosition:(OWCursorSeekPosition)position;
{
    switch (position) {
        case OWCursorSeekFromEnd:
            offset = [self dataLength] + offset - dataOffset;
            break;
        case OWCursorSeekFromCurrent:
            break;
        case OWCursorSeekFromStart:
            offset = offset - dataOffset;
            break;
    }
    if (offset > 0)
        [self skipBytes:offset];
    else
        dataOffset += offset;
    return dataOffset;    
}


// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;
    NSString *lookahead;

    debugDictionary = [super debugDictionary];
    [debugDictionary setIntValue:(int)byteOrder forKey:@"byteOrder"];
    if (bitsLeft) {
        [debugDictionary setObject:[NSString stringWithFormat:@"0x%02x", partialByte] forKey:@"partialByte"];
        [debugDictionary setIntValue:(int)bitsLeft forKey:@"bitsLeft"];
    }

    lookahead = [self logDescription];
    if (lookahead)
        [debugDictionary setObject:lookahead forKey:@"data"];

    return debugDictionary;
}

- (NSString *)logDescription
{
#define LOG_BYTES_LEN 45
    unsigned char peekBuffer[LOG_BYTES_LEN];
    unsigned int peeked, peekIndex;
    NSMutableString *descript;

    NS_DURING {
        peeked = [self copyBytesToBuffer:peekBuffer minimumBytes:0 maximumBytes:LOG_BYTES_LEN advance:NO];
    } NS_HANDLER {
        return [NSString stringWithFormat:@"<Invalid: %@>", [localException name]];
    } NS_ENDHANDLER;

    descript = [[[NSMutableString alloc] initWithCapacity:LOG_BYTES_LEN + 6] autorelease];

    for(peekIndex = 0; peekIndex < peeked; peekIndex ++) {
        int ch = peekBuffer[peekIndex];

        if ([descript length] >= LOG_BYTES_LEN)
            break;

        if (ch > 0 && ch < 128 && (isgraph(ch) || (ch == ' '))) {
            [descript appendCharacter:ch];
        } else if (ch == '\n') {
            [descript appendString:@"\\n"];
        } else if (ch == '\r') {
            [descript appendString:@"\\r"];
        } else {
            [descript appendFormat:@"\\%03o", ch];
        }
    }

    if ([descript length] >= LOG_BYTES_LEN)
        [descript appendString:@"..."];

    return descript;
#undef LOG_BYTES_LEN
}

@end

@implementation OWDataStreamConcreteCursor

- initForDataStream:(OWDataStream *)aStream;
{
    if (![super init])
        return nil;

    dataStream = [aStream retain];
    [dataStream _adjustCursorCount:1];
    byteOrder = NS_UnknownByteOrder;
    dataOffset = 0;

    return self;
}

- (id)initFromCursor:(id)aCursor;
{
    OBPRECONDITION([aCursor class] == [self class]);
    return [self initForDataStream:[(OWDataStreamConcreteCursor *)aCursor dataStream]];
}

- (void)dealloc;
{
    [dataStream _adjustCursorCount:-1];
    [dataStream release];
    [super dealloc];
}

// These inlines make the data access functions use the same code base without being deadly slow

static inline void _raiseIfAborted(OWDataStreamConcreteCursor *self)
{
    if (self->abortException != nil)
        [self->abortException raise];
    [self->dataStream raiseIfInvalid];
}

static inline void _getBytes(OWDataStreamConcreteCursor *self, void *buffer, unsigned int count)
{
    _raiseIfAborted(self);
    if (![self->dataStream getBytes:buffer range:(NSRange){self->dataOffset, count}])
        [OWDataStreamCursor_UnderflowException raise];
    self->bitsLeft = 0;
}

static inline void _ensureBytesAvailable(OWDataStreamConcreteCursor *self, unsigned int count)
{
    _raiseIfAborted(self);
    if (![self->dataStream waitForBufferedDataLength:self->dataOffset + count])
        [OWDataStreamCursor_UnderflowException raise];
}

static inline NSData *_getData(OWDataStreamConcreteCursor *self, unsigned int count)
{
    NSData *result;

    _raiseIfAborted(self);
    if (!(result = [self->dataStream dataWithRange:(NSRange){self->dataOffset, count}]))
        [OWDataStreamCursor_UnderflowException raise];
    return result;
}

static inline NSData *_getBufferedData(OWDataStreamConcreteCursor *self, BOOL incrementOffset)
{
    unsigned int count;
    NSData *result;

    if (![self->dataStream waitForBufferedDataLength:(self->dataOffset + 1)])
        return nil;
    count = [self->dataStream bufferedDataLength] - self->dataOffset;
    result = [self->dataStream dataWithRange:(NSRange){self->dataOffset, count}];
    if (incrementOffset)
        self->dataOffset += count;
    return result;
}

//

- (OWDataStream *)dataStream;
{
    return dataStream;
}

- (OWDataStream *)underlyingDataStream;
{
    return dataStream;
}

//

- (unsigned int)dataLength;
{
    return [dataStream dataLength];
}

- (BOOL)isAtEOF;
{
    [dataStream raiseIfInvalid];
    if ([dataStream knowsDataLength]) {
        return !(dataOffset < [dataStream dataLength]);
    } else {
        if ([dataStream waitForBufferedDataLength:(dataOffset + 1)])
            return NO;
        return YES;
    }
}

- (BOOL)haveFinishedReadingData;
{
    return [dataStream knowsDataLength] && !(dataOffset < [dataStream dataLength]);
}

//

- (void)readBytes:(unsigned int)count intoBuffer:(void *)buffer;
{
    _getBytes(self, buffer, count);
    dataOffset += count;
}

- (void)peekBytes:(unsigned int)count intoBuffer:(void *)buffer;
{
    _getBytes(self, buffer, count);
}

- (void)bufferBytes:(unsigned int)count;
{
    _ensureBytesAvailable(self, count);
}

- (BOOL)haveBufferedBytes:(unsigned int)count
{
    if (abortException)
        [abortException raise];

    if ([dataStream bufferedDataLength] >= dataOffset + count)
        return YES;
    else
        return NO;
}

- (unsigned int)copyBytesToBuffer:(void *)buffer minimumBytes:(unsigned int)minimum maximumBytes:(unsigned int)maximum advance:(BOOL)shouldAdvance
{
    unsigned int count;

    if (minimum > 0 && ![dataStream waitForBufferedDataLength:dataOffset + minimum])
        return 0;
    count = MIN([dataStream bufferedDataLength] - dataOffset, maximum);
    _getBytes(self, buffer, count);
    if (shouldAdvance)
        dataOffset += count;
    return count;
}

- (NSData *)readData;
{
    return _getBufferedData(self, YES);
}

- (NSData *)peekData;
{
    return _getBufferedData(self, NO);
}

- (unsigned int)peekUnderlyingBuffer:(void **)returnedBufferPtr;
{
    unsigned int count;

    _raiseIfAborted(self);
    count = [dataStream accessUnderlyingBuffer:returnedBufferPtr startingAtLocation:dataOffset];
    if (count == 0) {
        if (![dataStream waitForBufferedDataLength:(dataOffset + 1)])
            return 0;
        count = [dataStream accessUnderlyingBuffer:returnedBufferPtr startingAtLocation:dataOffset];
    }
    return count;
}

- (NSData *)readAllData;
{
    [dataStream waitForDataEnd];
    return _getBufferedData(self, YES);
}

- (NSData *)readBytes:(unsigned int)count;
{
    NSData *returnData;

    returnData = _getData(self, count);
    dataOffset += count;
    return returnData;
}

- (NSData *)peekBytes:(unsigned int)count;
{
    return _getData(self, count);
}

- (NSData *)peekBytesOrUntilEOF:(unsigned int)count;
{
    unsigned available;

    _raiseIfAborted(self);
    if ([self->dataStream waitForBufferedDataLength:self->dataOffset + count])
        return _getData(self, count);
    
    available = [self->dataStream bufferedDataLength] - self->dataOffset;
    return [self->dataStream dataWithRange:(NSRange){self->dataOffset, MIN(available, count)}];
}

- (OFByte)readByte;
{
    OFByte returnValue;

    _getBytes(self, &returnValue, 1);
    dataOffset += 1;
    return returnValue;
}

- (OFByte)peekByte;
{
    OFByte returnValue;

    _getBytes(self, &returnValue, 1);
    return returnValue;
}

// 

- (void)scheduleInQueue:(OFMessageQueue *)aQueue invocation:(OFInvocation *)anInvocation
{
    OFInvocation *thisAgain;
    BOOL rightNow;

    thisAgain = [[OFInvocation alloc] initForObject:self selector:_cmd withObject:aQueue withObject:anInvocation];
    rightNow = [dataStream _checkForAvailableIndex:dataOffset+1 orInvoke:thisAgain];
    [thisAgain release];
#ifdef DEBUG_scheduling
    NSLog(@"-[%@ %s], available=%d, invocation=%@", self, _cmd, rightNow, [anInvocation description]);
#endif
    if (rightNow) {
        if (aQueue)
            [aQueue addQueueEntry:anInvocation];
        else
            [anInvocation invoke];
    }
}


// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (dataStream)
        [debugDictionary setObject:dataStream forKey:@"dataStream"];
    [debugDictionary setObject:[NSNumber numberWithInt:dataOffset] forKey:@"dataOffset"];

    return debugDictionary;
}

@end

