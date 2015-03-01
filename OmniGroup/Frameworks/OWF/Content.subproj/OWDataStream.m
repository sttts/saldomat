// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWDataStream.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniFoundation/md5.h>
#import <OmniBase/system.h>

#import <OWF/OWContentType.h>
#import <OWF/OWDataStreamCharacterProcessor.h>
#import <OWF/OWDataStreamCursor.h>
#import <OWF/OWParameterizedContentType.h>
#import <OWF/OWUnknownDataStreamProcessor.h>

#include <sys/mman.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWDataStream.m 67092 2005-08-16 22:42:19Z kc $")

@interface OWDataStream (Private)
- (void)flushContentsToFile;
- (void)flushAndCloseSaveFile;
- (void)_noMoreData;
@end

@implementation OWDataStream

const unsigned int OWDataStreamUnknownLength = NSNotFound;

static unsigned int DataBufferBlockSize;
#define ROUNDED_ALLOCATION_SIZE(x) (DataBufferBlockSize * ( ( (x) + DataBufferBlockSize - 1 ) / DataBufferBlockSize))

// Tunable buffer sizes. See allocateAnotherBuffer() for details.
#define BUFFER_OOL_THRESHOLD      ( 4096 - sizeof(OWDataStreamBufferDescriptor) )    // fits on one VM page
#define BUFFER_MAXIMUM_SEGMENT_SIZE   ( 16 * 1024 * 1024 )                           // small compared to total VM address space; large compared to most data streams

static OWContentType *unencodedContentEncoding;

+ (void)initialize;
{
    OBINITIALIZE;

    unencodedContentEncoding = [OWContentType contentTypeForString:@"encoding/identity"];
    DataBufferBlockSize = 4 * NSPageSize();
}

static inline void _raiseNoLongerValidException()
{
    [NSException raise:OWDataStreamNoLongerValidException format:@"Data stream no longer contains valid data"];
}

static inline void _raiseIfInvalid(OWDataStream *self)
{
    if (self->flags.hasThrownAwayData)
        _raiseNoLongerValidException();
}

static inline OWDataStreamBufferDescriptor *descriptorForBlockContainingOffset(OWDataStream *self, unsigned int offset, unsigned int *offsetWithinBlock)
{
    OWDataStreamBufferDescriptor *cursor;
    unsigned int cursorOffset = 0;

    _raiseIfInvalid(self);
    cursor = self->_first;
    while (cursor != NULL) {
        OWDataStreamBufferDescriptor cursorBlock = *cursor;
        
        if (cursorOffset <= offset && (cursorOffset + cursorBlock.bufferUsed) > offset) {
            *offsetWithinBlock = ( offset - cursorOffset );
            return cursor;
        }
        
        cursor = cursorBlock.next;
        cursorOffset += cursorBlock.bufferUsed;
    }
    
    return NULL;
}

static inline BOOL copyBuffersOut(OWDataStreamBufferDescriptor *dsBuffer, unsigned int offsetIntoBlock, void *outBuffer, unsigned int length)
{
    while (length != 0) {
        OWDataStreamBufferDescriptor dsBufferCopy;
        unsigned bytesCopied;
        
        if (!dsBuffer)
            return NO;
            
        dsBufferCopy = *dsBuffer;
        bytesCopied = MIN(length, dsBufferCopy.bufferUsed - offsetIntoBlock);
        bcopy(dsBufferCopy.buffer + offsetIntoBlock, outBuffer, bytesCopied);
        outBuffer += bytesCopied;
        length -= bytesCopied;
        
        dsBuffer = dsBufferCopy.next;
        offsetIntoBlock = 0;
    }
    
    return YES;
}

// Allocates another buffer and links it into self's list of buffers. bytesToAllocate is merely a hint; the allocated buffer may be larger or smaller than this for various reasons. In particular:
// Buffers may be rounded up to a multiple of the VM page size.
// Individual buffers have a maximum size (BUFFER_MAXIMUM_SEGMENT_SIZE). This has two benefits:
//    1. We are less sensitive to address-space fragmentation, which is a real problem for users which are in the habit of downloading gigabyte disk images, etc.
//    2. If we are streaming to disk (hasIssuedCursor=0, hasThrownAwayData=1, saveFileHandle!=nil) then this allows us to deallocate individual buffers that are no longer needed, rather than forcing the system to swap them out an incidentally tickling a bug in 10.2.x's virtual-memory system. 
static void allocateAnotherBuffer(OWDataStream *self, unsigned int bytesToAllocate)
{
    OWDataStreamBufferDescriptor *newBuffer;
    NSZone *myZone = [self zone];

    // Create a new buffer descriptor & allocate its data. If the buffer to be allocated is less than BUFFER_OOL_THRESHOLD, we allocate it inline using malloc; if it is larger, we use a large out-of-line buffer to avoid page thrashing while traversing the descriptor list.

    if (bytesToAllocate < BUFFER_OOL_THRESHOLD) {
        newBuffer = NSZoneMalloc(myZone, sizeof(*newBuffer) + bytesToAllocate);
        newBuffer->buffer = (void *)( newBuffer + 1 );
    } else {
        bytesToAllocate = ROUNDED_ALLOCATION_SIZE(bytesToAllocate);
        if (bytesToAllocate > BUFFER_MAXIMUM_SEGMENT_SIZE)
            bytesToAllocate = BUFFER_MAXIMUM_SEGMENT_SIZE;
        newBuffer = NSZoneMalloc(myZone, sizeof(*newBuffer));
        OBASSERT(bytesToAllocate >= BUFFER_OOL_THRESHOLD);
        newBuffer->buffer = NSAllocateMemoryPages(bytesToAllocate);
    }
    newBuffer->bufferSize = bytesToAllocate;
    newBuffer->bufferUsed = 0;
    newBuffer->next = NULL;
    
    // Link it into our list of descriptors.
    // This function is only ever called from the writing thread, so we don't have to worry as much about ordering of operations.
    if (self->_last) {
        self->_last->next = newBuffer;
        self->_last = newBuffer;
    } else {
        OBASSERT(!self->_first);
        self->_first = self->_last = newBuffer;
    }
    
    OBPOSTCONDITION(self->_last != NULL);
    OBPOSTCONDITION(self->_last->bufferUsed < self->_last->bufferSize);
}

static void deallocateBuffer(NSZone *myZone, OWDataStreamBufferDescriptor *oldBuffer)
{
    if (oldBuffer->bufferSize < BUFFER_OOL_THRESHOLD)
        NSZoneFree(myZone, oldBuffer);
    else {
        NSDeallocateMemoryPages(oldBuffer->buffer, oldBuffer->bufferSize);
        NSZoneFree(myZone, oldBuffer);
    }
}

- initWithLength:(unsigned int)newLength;
{
    if (![super init])
	return nil;

    dataLength = newLength;

    pthread_mutex_init(&lengthMutex, NULL);
    pthread_cond_init(&lengthChangedCondition, NULL);

    _first = _last = NULL;

    readLength = 0;

    writeEncoding = kCFStringEncodingInvalidId;

    flags.endOfData = NO;
    flags.hasThrownAwayData = NO;
    
    saveFilename = nil;
    saveFileHandle = nil;
    
    if (dataLength != OWDataStreamUnknownLength && dataLength != 0)
        allocateAnotherBuffer(self, dataLength);

    return self;
}

- init;
{
    return [self initWithLength:OWDataStreamUnknownLength];
}

// OWAbstractContent subclass (to force inspectors to guess what we are)

- initWithName:(NSString *)name;
{
    // Normally, abstractContent gets initWithName:@"DataStream", because the init method takes the class name and creates a guess with that.  However, in this case, we don't want the guess, because we'd rather have OWPipeline's -rebuildCompositeTypeString method take a guess what to call us than to show the user the word "DataStream", which really means nothing to her.
    return [super initWithName:nil];
}

- (void)dealloc;
{
    OWDataStreamBufferDescriptor *cursor, *nextCursor;
    NSZone *myZone;
    
    OBASSERT(saveFileHandle == nil);
    
    myZone = [self zone];
    for (cursor = _first; cursor != NULL; cursor = nextCursor) {
        nextCursor = cursor->next;
        OBASSERT(nextCursor != nil || cursor == _last);
        deallocateBuffer(myZone, cursor);
    }
    _first = _last = NULL;

    pthread_cond_destroy(&lengthChangedCondition);
    pthread_mutex_destroy(&lengthMutex);
    
    [saveFilename release];
    [finalFileAttributes release];
    [super dealloc];
}

- (id)newCursor;
{
    _raiseIfInvalid(self);
    return [[[OWDataStreamConcreteCursor alloc] initForDataStream:self] autorelease];
}

- (NSData *)bufferedData;
{
    OWDataStreamBufferDescriptor *local_first, *local_last, *cursor, *nextCursor;
    NSMutableData *result;
    
    local_first = _first;
    local_last = _last;

    _raiseIfInvalid(self);

    // Special cases...
    if (local_first == NULL)
        return [NSData data];
    if (local_first == local_last)
        return [NSData dataWithBytes:local_first->buffer length:local_first->bufferUsed];
        
    // General case.
    result = [[[NSMutableData alloc] initWithCapacity:readLength] autorelease];
    for (cursor = local_first; cursor != NULL; cursor = nextCursor) {
        nextCursor = cursor->next;  // look at the 'next' pointer before we look at the 'bufferUsed' pointer, in case someone adds to this block and appends a new block while we're appending to 'result'; this way we get a consistent view of the data stream
        [result appendBytes:cursor->buffer length:cursor->bufferUsed];
    }
    
    return result;
}

- (unsigned int)bufferedDataLength;
{
    _raiseIfInvalid(self);

    return readLength;
}

- (unsigned int)accessUnderlyingBuffer:(void **)returnedBufferPtr startingAtLocation:(unsigned int)dataOffset;
{
    OWDataStreamBufferDescriptor *dsBuffer;
    unsigned int remainingOffset;

    _raiseIfInvalid(self);
    if (readLength <= dataOffset)
        return 0;
    
    dsBuffer = descriptorForBlockContainingOffset(self, dataOffset, &remainingOffset);
    if (dsBuffer) {
        *returnedBufferPtr = dsBuffer->buffer + remainingOffset;
        return dsBuffer->bufferUsed - remainingOffset;
    }
    
    return 0;
}

- (unsigned int)dataLength;
{
    if (![self knowsDataLength]) {
        pthread_mutex_lock(&lengthMutex);
        while (dataLength == OWDataStreamUnknownLength && !flags.hasThrownAwayData)
            pthread_cond_wait(&lengthChangedCondition, &lengthMutex);
        pthread_mutex_unlock(&lengthMutex);
    }
    return dataLength;
}

- (BOOL)knowsDataLength;
{
    return dataLength != OWDataStreamUnknownLength;
}

- (BOOL)getBytes:(void *)buffer range:(NSRange)range;
{
    _raiseIfInvalid(self);

    if (![self waitForBufferedDataLength:NSMaxRange(range)])
        return NO;

    unsigned int offsetIntoBlock = 0;
    OWDataStreamBufferDescriptor *dsBuffer = descriptorForBlockContainingOffset(self, range.location, &offsetIntoBlock);
    
    return copyBuffersOut(dsBuffer, offsetIntoBlock, buffer, range.length);
}

- (NSData *)dataWithRange:(NSRange)range;
{
    OWDataStreamBufferDescriptor *dsBuffer;
    unsigned int offsetIntoBlock;

    _raiseIfInvalid(self);

    if (![self waitForBufferedDataLength:NSMaxRange(range)])
        return nil;

    dsBuffer = descriptorForBlockContainingOffset(self, range.location, &offsetIntoBlock);
    if (!dsBuffer)
        return nil;

    if (dsBuffer->bufferUsed - offsetIntoBlock >= range.length) {
        // Special case: the requested range lies entirely within one allocated buffer
        return [NSData dataWithBytes:dsBuffer->buffer + offsetIntoBlock length:range.length];
    } else {
        // General case: create a mutable data object and copy (partial) blocks into it
        NSMutableData *subdata = [[NSMutableData alloc] initWithLength:range.length];
        if (!copyBuffersOut(dsBuffer, offsetIntoBlock, [subdata mutableBytes], range.length)) {
            [subdata release];
            return nil;
        }
        return [subdata autorelease];
    }
}

- (BOOL)waitForMoreData;
{
    unsigned int oldReadLength;

    _raiseIfInvalid(self);

    pthread_mutex_lock(&lengthMutex);
    oldReadLength = readLength;
    while (readLength == oldReadLength) {
        if (flags.endOfData) {
            pthread_mutex_unlock(&lengthMutex);
            return NO;
        }
        pthread_cond_wait(&lengthChangedCondition, &lengthMutex);
    }
    pthread_mutex_unlock(&lengthMutex);
    return YES;
}

- (BOOL)waitForBufferedDataLength:(unsigned int)desiredLength;
{
    _raiseIfInvalid(self);

    pthread_mutex_lock(&lengthMutex);
    while (readLength < desiredLength) {
        if (flags.endOfData) {
            pthread_mutex_unlock(&lengthMutex);
            return NO;
        }
        pthread_cond_wait(&lengthChangedCondition, &lengthMutex);
    }
    pthread_mutex_unlock(&lengthMutex);
    return YES;
}

- (BOOL)_checkForAvailableIndex:(unsigned)position orInvoke:(OFInvocation *)anInvocation;
{
    BOOL available;
    
    pthread_mutex_lock(&lengthMutex);
    
    if (flags.hasThrownAwayData || flags.endOfData)
        available = YES;
    else if (position != (~0U) && readLength >= position)
        available = YES;
    else
        available = NO;
        
    if (!available) {
        if (lengthChangedInvocations == nil)
            lengthChangedInvocations = [[NSMutableArray alloc] init];
        [lengthChangedInvocations addObject:anInvocation];
    }

    pthread_mutex_unlock(&lengthMutex);

    return available;
}

- (void)scheduleInvocationAtEOF:(OFInvocation *)anInvocation inQueue:(OFMessageQueue *)aQueue;
{
    BOOL shouldInvoke;

    pthread_mutex_lock(&lengthMutex);

    if (flags.hasThrownAwayData || flags.endOfData)
        shouldInvoke = YES;
    else
        shouldInvoke = NO;

    if (!shouldInvoke) {
        OFInvocation *repeatInvocation;
        
        if (lengthChangedInvocations == nil)
            lengthChangedInvocations = [[NSMutableArray alloc] init];
        repeatInvocation = [[OFInvocation alloc] initForObject:self selector:_cmd withObject:anInvocation withObject:aQueue];
        [lengthChangedInvocations addObject:repeatInvocation];
        [repeatInvocation release];
    }

    pthread_mutex_unlock(&lengthMutex);

    if (shouldInvoke) {
        if (aQueue)
            [aQueue addQueueEntry:anInvocation];
        else
            [anInvocation invoke];
    }
}

- (void)writeData:(NSData *)newData;
{
    NSRange range;
    unsigned int length, lengthLeft;
    
    length = [newData length];
    if (length == 0)
        return;
    lengthLeft = length;
    range.location = 0;
    range.length = length;
    
    while (range.length != 0) {
        OWDataStreamBufferDescriptor *lastBuffer = _last;
        
        // Copy data into a buffer if we've already allocated one
        if (lastBuffer && lastBuffer->bufferSize > lastBuffer->bufferUsed) {
            NSRange fragment;
            
            fragment.location = range.location;
            fragment.length = MIN(lastBuffer->bufferSize - lastBuffer->bufferUsed, range.length);
            [newData getBytes:lastBuffer->buffer + lastBuffer->bufferUsed range:fragment];
            
            lastBuffer->bufferUsed += fragment.length;
            readLength += fragment.length;
            range.location += fragment.length;
            range.length -= fragment.length;
        }
        
        if (!range.length)
            break;

        // Allocate a new buffer. Try to allocate at least as much as remains in newData (range.length), rounding up to a few VM pages, unless we know our length in advance and know we won't be taking that much space. If we *do* know our total remaining length we might as well allocate enough space for all of it, of course.
        if (dataLength != OWDataStreamUnknownLength && dataLength >= (readLength + range.length))
            allocateAnotherBuffer(self, dataLength - readLength);
        else
            allocateAnotherBuffer(self, ROUNDED_ALLOCATION_SIZE(range.length));
    }

    [self wroteBytesToUnderlyingBuffer:0];
}

- (void)setWriteEncoding:(CFStringEncoding)anEncoding;
{
    writeEncoding = anEncoding;
}

- (void)writeString:(NSString *)string;
{
    CFStringEncoding encoding;
    CFDataRef bytes;

    if (string == nil)
	return;

    encoding = writeEncoding;
    if (encoding == kCFStringEncodingInvalidId)
        encoding = [OWDataStreamCharacterProcessor defaultStringEncoding];
        
    bytes = CFStringCreateExternalRepresentation(kCFAllocatorDefault, (CFStringRef)string, encoding, 0);
    [self writeData:(NSData *)bytes];
    CFRelease(bytes);
}

- (void)writeFormat:(NSString *)formatString, ...;
{
    NSString *string;
    va_list argList;

    va_start(argList, formatString);
    string = [[NSString alloc] initWithFormat:formatString arguments:argList];
    va_end(argList);
    [self writeString:string];
    [string release];
}


- (unsigned int)appendToUnderlyingBuffer:(void **)returnedBufferPtr;
{
    OWDataStreamBufferDescriptor *targetBuffer = _last;
    
    if (!targetBuffer || !(targetBuffer->bufferUsed < targetBuffer->bufferSize)) {
        if (dataLength != OWDataStreamUnknownLength && dataLength > readLength)
            // TODO: This allocates more space than necessary towards the end of a stream whose length is known. Double-check that no code depends on -appendToUnderlyingBuffer: returning a minimum value greater than one byte, and if so, remove the ROUNDED_ALLOCATION_SIZE() invocation.
            allocateAnotherBuffer(self, ROUNDED_ALLOCATION_SIZE(dataLength - readLength));
        else
            allocateAnotherBuffer(self, DataBufferBlockSize);
        targetBuffer = _last;
    }
        
    *returnedBufferPtr = _last->buffer + _last->bufferUsed;
    return _last->bufferSize - _last->bufferUsed;
}

- (void)wroteBytesToUnderlyingBuffer:(unsigned int)count;    
{
    NSArray *notifications;
    
    pthread_mutex_lock(&lengthMutex);

    _last->bufferUsed += count;
    OBINVARIANT(_last->bufferUsed <= _last->bufferSize);
    readLength += count;

    notifications = lengthChangedInvocations;
    lengthChangedInvocations = nil;

    pthread_mutex_unlock(&lengthMutex);

    [notifications makeObjectsPerformSelector:@selector(invoke)];
    [notifications release];
    
    pthread_cond_broadcast(&lengthChangedCondition);
    if (saveFilename)
        [self flushContentsToFile];
}

#if 0
- (CFStringEncoding)stringEncoding;
{
    return stringEncoding;
}

- (enum OWStringEncodingProvenance)stringEncodingProvenance;
{
    return stringEncodingProvenance;
}

- (void)setCFStringEncoding:(CFStringEncoding)aStringEncoding provenance:(enum OWStringEncodingProvenance)whence;
{
    NSString *encodingName;
    OWParameterizedContentType *parameterizedContentType;

    // Don't let less-reliable provenances override more-reliable ones. Allow a newer value to override an older one of equal reliability.
    // (The one case in which we don't want a newer value of the same type to override an older one is charsets specified in META tags, and that's handled by the META tag parser.)
    if (whence < stringEncodingProvenance)
        return;

    stringEncoding = aStringEncoding;
    stringEncodingProvenance = whence;
#warning blegga blegga blegga
#if 0
    encodingName = [OWDataStreamCharacterProcessor charsetForCFEncoding:stringEncoding];
    parameterizedContentType = [self fullContentType];
    if (![[parameterizedContentType objectForKey:@"charset"] isEqual:encodingName]) {
        [parameterizedContentType setObject:encodingName forKey:@"charset"];
    }
#endif
}

- (OWContentType *)contentEncoding;
{
    return contentEncoding;
}

- (OWParameterizedContentType *)encodedContentType;
{
    return [super fullContentType];
}

- (void)setContentEncoding:(OWContentType *)aContentEncoding;
{
    if (aContentEncoding == unencodedContentEncoding)
	aContentEncoding = nil;
    contentEncoding = aContentEncoding;
}

- (NSString *)pathExtensionForContentTypeAndEncoding;
{
    NSString *typeExtension;
    NSString *encodingExtension;
    
    typeExtension = [[[self encodedContentType] contentType] primaryExtension];
    encodingExtension = [contentEncoding primaryExtension];
    if (encodingExtension == nil)
	return typeExtension;
    else if (typeExtension == nil)
	return encodingExtension;
    else
	return [typeExtension stringByAppendingPathExtension:encodingExtension];
}

#endif

//

- (BOOL)pipeToFilename:(NSString *)aFilename contentType:(OWContentType *)myType shouldPreservePartialFile:(BOOL)shouldPreserve;
{
    NSMutableDictionary *someAttributes;

    someAttributes = [NSMutableDictionary dictionary];
    if (myType != nil) {
        [someAttributes setObject:[NSNumber numberWithUnsignedLong:[myType hfsType]] forKey:NSFileHFSTypeCode];
        if ([myType hfsCreator] != 0)
            [someAttributes setObject:[NSNumber numberWithUnsignedLong:[myType hfsCreator]] forKey:NSFileHFSCreatorCode];
    }

    return [self pipeToFilename:aFilename withAttributes:someAttributes shouldPreservePartialFile:shouldPreserve];
}

- (BOOL)pipeToFilename:(NSString *)aFilename withAttributes:(NSDictionary *)requestedFileAttributes shouldPreservePartialFile:(BOOL)shouldPreserve;
{
    BOOL fileCreated;
    NSFileHandle *newFileHandle;
    NSDictionary *temporaryAttributes;

    _raiseIfInvalid(self);
    
    if (saveFilename != nil && !flags.endOfData)
	return NO; // Already busy writing to a file, can't pipe to another one right now

    OBPRECONDITION(finalFileAttributes == nil);

#ifdef USE_TEMPORARY_ATTRIBUTES
    if (requestedFileAttributes != nil && !flags.endOfData) {
        NSString *bundleSignature = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleSignature"];
        NSMutableDictionary *someAttributes = [NSMutableDictionary dictionary];
        [someAttributes setObject:[NSNumber numberWithUnsignedLong:kFirstMagicBusyFiletype] forKey:NSFileHFSTypeCode];
        if (bundleSignature)
            [someAttributes setObject:[NSNumber numberWithUnsignedLong:[bundleSignature fourCharCodeValue]] forKey:NSFileHFSCreatorCode];
        temporaryAttributes = someAttributes;
    } else {
        temporaryAttributes = nil;
    }
#else
    temporaryAttributes = requestedFileAttributes;
#endif

    fileCreated = [[NSFileManager defaultManager] createFileAtPath:aFilename contents:[NSData data] attributes:requestedFileAttributes];
    if (!fileCreated)
        [NSException raise:@"Can't save" format:NSLocalizedStringFromTableInBundle(@"Can't create file at path %@: %s", @"OWF", [OWDataStream bundle], "datastream error: format items are path and errno string"), aFilename, strerror(OMNI_ERRNO())];

    newFileHandle = [NSFileHandle fileHandleForWritingAtPath:aFilename];
    if (!newFileHandle)
	[NSException raise:@"Can't save" format:NSLocalizedStringFromTableInBundle(@"Can't open file %@ for writing: %s", @"OWF", [OWDataStream bundle], "datastream error: format items are path and errno string"), aFilename, strerror(OMNI_ERRNO())];
    [_lock lock];
#warning What if flags.hasThrownAwayData gets set after we check it but before here?
    saveFileHandle = [newFileHandle retain];
#ifdef DEBUG_DataStream
    NSLog(@"new fd: %d", [saveFileHandle fileDescriptor]);
#endif

    flags.shouldPreservePartialFile = shouldPreserve;
    saveFilename = [aFilename retain];
#ifdef USE_TEMPORARY_ATTRIBUTES
    finalFileAttributes = [requestedFileAttributes retain];
#endif
    
    savedBuffer = _first;
    savedInBuffer = 0;
    [_lock unlock];

    // If end of data happened before we set saveFilename, we need to flush out everything ourselves
    if (flags.endOfData)
        [self flushAndCloseSaveFile];

    return YES;
}

- (void)appendToFilename:(NSString *)aFilename;
{
    if (saveFilename != nil)
        _raiseNoLongerValidException();
    _raiseIfInvalid(self);
    
    NSFileHandle *newFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:aFilename];
    if (!newFileHandle)
        [NSException raise:@"Can't save" format:NSLocalizedStringFromTableInBundle(@"Can't open file %@ for writing: %s", @"OWF", [OWDataStream bundle], "datastream error: format items are path and errno string"), aFilename, strerror(OMNI_ERRNO())];
    [newFileHandle seekToFileOffset:startPositionInFile];
    [newFileHandle truncateFileAtOffset:startPositionInFile];
    [_lock lock];
#warning What if flags.hasThrownAwayData gets set after we check it but before here?
    saveFileHandle = [newFileHandle retain];
#ifdef DEBUG_DataStream
    NSLog(@"new fd: %d", [saveFileHandle fileDescriptor]);
#endif

    flags.shouldPreservePartialFile = YES;
    saveFilename = [aFilename retain];
    finalFileAttributes = nil;

    savedBuffer = _first;
    savedInBuffer = 0;
    [_lock unlock];

    // If end of data happened before we set saveFilename, we need to flush out everything ourselves
    if (flags.endOfData)
        [self flushAndCloseSaveFile];
}

- (NSString *)filename;
{
    if (saveFilename == nil)
        return nil; // No file yet
    if (![[NSFileManager defaultManager] fileExistsAtPath:saveFilename])
        return nil; // Woops, someone moved or removed our file!
    return saveFilename;
}

- (BOOL)hasThrownAwayData;
{
    return flags.hasThrownAwayData;
}

- (unsigned int)bytesWrittenToFile;
{
    return readLength;
}

- (unsigned long long)startPositionInFile;
{
    return startPositionInFile;
}

- (void)setStartPositionInFile:(unsigned long long)newStartPosition;
{
    startPositionInFile = newStartPosition;
}

// OWStream subclass

- (void)dataEnd;
{
    dataLength = readLength;
    [self _noMoreData];
}

- (void)dataAbort;
{
    OBASSERT(!flags.endOfData);
    flags.hasThrownAwayData = YES;

    [self _noMoreData];

    if (saveFilename && !flags.shouldPreservePartialFile) {
        NSString *oldFilename;

        oldFilename = saveFilename;
        saveFilename = nil;
        [[NSFileManager defaultManager] removeFileAtPath:oldFilename handler:nil];
        [oldFilename release];
    }
}

- (void)waitForDataEnd;
{
    pthread_mutex_lock(&lengthMutex);
    while (!flags.endOfData)
        pthread_cond_wait(&lengthChangedCondition, &lengthMutex);
    pthread_mutex_unlock(&lengthMutex);
}

- (BOOL)endOfData;
{
    return flags.endOfData;
}

- (BOOL)contentIsValid;
{
    // Note:  Someone could throw away data in another thread after we perform this check but before we return, so while you can always trust -contentIsValid when it returns NO, you can't always trust it when it returns YES
    return ![self hasThrownAwayData];
}

- (void)raiseIfInvalid;
{
    _raiseIfInvalid(self);
}

#define MD5_SIGNATURE_LENGTH 16
- (NSData *)md5Signature;
{
    MD5_CTX md5context;
    unsigned char signature[MD5_SIGNATURE_LENGTH];
    unsigned int location, totalLength;
    void *chunkBuffer;

    [self waitForDataEnd];
    OBASSERT([self knowsDataLength]);
    totalLength = [self dataLength];
    location = 0;

    MD5Init(&md5context);
    while (location < totalLength) {
        unsigned int chunkLength = [self accessUnderlyingBuffer:&chunkBuffer startingAtLocation:location];
        OBASSERT(chunkLength != 0);
        if (chunkLength == 0)
            break; // This should never happen (see the above assertion), but if it does we don't want to get stuck in an infinite loop (with our caller potentially holding a global lock).
        MD5Update(&md5context, chunkBuffer, chunkLength);
        location += chunkLength;
    }
    MD5Final(signature, &md5context);

    OBPOSTCONDITION(location == totalLength);
    return [NSData dataWithBytes:signature length:MD5_SIGNATURE_LENGTH];
}

- (BOOL)isEqualToDataStream:(OWDataStream *)anotherStream
{
    OWDataStreamCursor *cursorA, *cursorB;

    /* Some quick and easy checks ... */
    if (self == anotherStream)
        return YES;
    if (anotherStream == nil)
        return NO;
    if ([self knowsDataLength] && [anotherStream knowsDataLength] &&
        [self dataLength] != [anotherStream dataLength])
        return NO;

    /* Can't do it the easy way; we'll just have to do it the hard way */
    cursorA = [self newCursor];
    cursorB = [anotherStream newCursor];

    for(;;) {
        void *bufferA, *bufferB;
        unsigned int bufferLengthA, bufferLengthB, bufferLengthCommon;
        BOOL eofA, eofB;

        eofA = [cursorA isAtEOF];
        eofB = [cursorB isAtEOF];

        if (eofA && eofB)
            return YES;
        if (eofA || eofB)
            return NO;

        bufferLengthA = [cursorA peekUnderlyingBuffer:&bufferA];
        bufferLengthB = [cursorA peekUnderlyingBuffer:&bufferB];
        bufferLengthCommon = MIN(bufferLengthA, bufferLengthB);

        if (memcmp(bufferA, bufferB, bufferLengthCommon) != 0)
            return NO;

        [cursorA skipBytes:bufferLengthCommon];
        [cursorB skipBytes:bufferLengthCommon];
    }
}

// OBObject subclass (Debugging)

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    [debugDictionary setObject:flags.endOfData ? @"YES" : @"NO" forKey:@"flags.endOfData"];
    [debugDictionary setObject:flags.hasThrownAwayData ? @"YES" : @"NO" forKey:@"flags.hasThrownAwayData"];
    [debugDictionary setObject:[NSNumber numberWithInt:readLength] forKey:@"readLength"];
    return debugDictionary;
}

@end


@implementation OWDataStream (Private)

- (void)flushContentsToFile;
{
    // This always happens in writer's thread, or after writer is done.

    if (savedBuffer == NULL) {
        OBASSERT(!flags.hasThrownAwayData);
        if (_first == NULL) {
            // There's nothing to flush!  (Perhaps we downloaded a 0-byte file.)
            return;
        }
        savedBuffer = _first;
    }

    do {
        unsigned int bytesCount;
        void *bytesPointer;
        
        bytesPointer = savedBuffer->buffer + savedInBuffer;
        bytesCount = savedBuffer->bufferUsed - savedInBuffer;
        
        if (bytesCount > 0) {
            NSData *data;
            data = [[NSData alloc] initWithBytes:bytesPointer length:bytesCount];
            [_lock lock];
            [saveFileHandle writeData:data];
            [_lock unlock];
            [data release];
            savedInBuffer += bytesCount;
        }
        
        OBASSERT(savedInBuffer == savedBuffer->bufferUsed);
        
        if (savedBuffer->next != NULL) {
            savedBuffer = savedBuffer->next;
            savedInBuffer = 0;
        } else {
            // We've written everything in this buffer, and there isn't a next buffer. Since we don't know whether more data will be appended to this buffer before a new buffer is allocated, leave the cursor at the end of this buffer.
            break;
        }
    } while (1);

    // throw away anything no longer needed
    if (issuedCursorsCount > 0)
        return; // Thread-safe shortcut to avoid grabbing the lock unnecessarily

    [_lock lock];
    // Now that we have the lock, check again
    if (issuedCursorsCount == 0 && readLength > 1024 * 1024 /* 1MB */ ) {
        flags.hasThrownAwayData = YES;
        [_lock unlock];
        while (_first != savedBuffer) {
            OWDataStreamBufferDescriptor *this, *nextFirst;

            this = _first;
            nextFirst = this->next;
            deallocateBuffer([self zone], this);
            _first = nextFirst;
        }
    } else {
        [_lock unlock];
    }
}

- (void)flushAndCloseSaveFile;
{
    NSString *savedFilename;
    
    [self flushContentsToFile];
    [_lock lock];
#ifdef DEBUG_DataStream
    NSLog(@"release fd: %d thread: %d", [saveFileHandle fileDescriptor], [NSThread currentThread]);
#endif
    [saveFileHandle release];
    saveFileHandle = nil;
    savedFilename = [[saveFilename retain] autorelease];
    [_lock unlock];

    if (savedFilename && finalFileAttributes) {
        NSFileManager *manager = [NSFileManager defaultManager];
        [manager changeFileAttributes:finalFileAttributes atPath:savedFilename];
        FNNotifyByPath((unsigned char *)[manager fileSystemRepresentationWithPath:[savedFilename stringByDeletingLastPathComponent]],
                       kFNDirectoryModifiedMessage,
                       kNilOptions);
    }
}

- (void)_noMoreData;
{
    NSArray *notifications;
    
    if (saveFilename)
        [self flushAndCloseSaveFile];

    pthread_mutex_lock(&lengthMutex);
    flags.endOfData = YES;
    notifications = lengthChangedInvocations;
    lengthChangedInvocations = nil;
    pthread_mutex_unlock(&lengthMutex);
    pthread_cond_broadcast(&lengthChangedCondition);

    [notifications makeObjectsPerformSelector:@selector(invoke)];
    [notifications release];
}

// This function seems like a good idea, except that madvise(2) doesn't actually do what its documentation says it does (10.1, apple bug ID #2789078  ---wim)
- (void)_adviseDataPages:(int)madviseFlags
{
    OWDataStreamBufferDescriptor *cursor = _first;

    for (cursor = _first; cursor != NULL; cursor = cursor->next)
        madvise(cursor->buffer, cursor->bufferSize, madviseFlags);
}

@end

NSString *OWDataStreamNoLongerValidException = @"Stream invalid";

