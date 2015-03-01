// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWObjectStream.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWObjectStreamCursor.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Content.subproj/OWObjectStream.m 68913 2005-10-03 19:36:19Z kc $")

@interface OWObjectStream (Private)
- (void)_noMoreData;
@end

@implementation OWObjectStream

enum {
    OBJECTS_AVAILABLE, READERS_WAITING
};
enum {
    MORE_DATA_POSSIBLE, DATA_ENDED
};

// Init and dealloc

- initWithName:(NSString *)aName;
{
    if ([super initWithName:aName] == nil)
	return nil;
    first = last = NSZoneMalloc(NULL, sizeof(OWObjectStreamBuffer));
    last->nextIndex = OWObjectStreamBuffer_BufferedObjectsLength;
    last->next = NULL;
    nextObjectInBuffer = last->objects;
    beyondBuffer = last->objects + OWObjectStreamBuffer_BufferedObjectsLength;
    count = 0;
    endOfObjects = NO;
    objectsLock = [[NSConditionLock alloc] initWithCondition:OBJECTS_AVAILABLE];
    endOfDataLock = [[NSConditionLock alloc] initWithCondition:MORE_DATA_POSSIBLE];
    return self;
}

- (void)dealloc;
{
    while (first) {
        last = first->next;
        nextObjectInBuffer = first->objects;
        beyondBuffer = first->objects + OWObjectStreamBuffer_BufferedObjectsLength;
        if (first->nextIndex > count)
            beyondBuffer -= (first->nextIndex - count);
        while (nextObjectInBuffer < beyondBuffer)
            [*nextObjectInBuffer++ release];
        NSZoneFree(NULL, first);
        first = last;
    }
    [objectsLock release];
    [endOfDataLock release];
    [super dealloc];
}

//

- (void)writeObject:(id)anObject;
{
    if (!anObject)
	return;
    [objectsLock lock];
    *nextObjectInBuffer = [anObject retain];
    count++;
    if (++nextObjectInBuffer == beyondBuffer) {
        last->next = NSZoneCalloc(NULL, sizeof(OWObjectStreamBuffer), 1);
        last = last->next;
        last->nextIndex = count + OWObjectStreamBuffer_BufferedObjectsLength;
        last->next = NULL;
        nextObjectInBuffer = last->objects;
        beyondBuffer = last->objects + OWObjectStreamBuffer_BufferedObjectsLength;
    }
    [objectsLock unlockWithCondition:OBJECTS_AVAILABLE];
}

//

- (id)objectAtIndex:(unsigned int)index withHint:(void **)hint;
{
    OWObjectStreamBuffer *buffer;
    
    if (index >= count && !endOfObjects) {
        [objectsLock lock];
        while (index >= count && !endOfObjects) {
            [objectsLock unlockWithCondition:READERS_WAITING];
            [objectsLock lockWhenCondition:OBJECTS_AVAILABLE];
        }
        [objectsLock unlockWithCondition:OBJECTS_AVAILABLE];
    }
    
    if (index >= count)
        return nil;

    buffer = *(OWObjectStreamBuffer **)hint;
    if (buffer == NULL || ((buffer->nextIndex - index) > OWObjectStreamBuffer_BufferedObjectsLength))
        buffer = first;
    while (buffer->nextIndex <= index)
        buffer = buffer->next;
    *(OWObjectStreamBuffer **)hint = buffer;
    
    return buffer->objects[index - (buffer->nextIndex - OWObjectStreamBuffer_BufferedObjectsLength)];
}

- (id)objectAtIndex:(unsigned int)index;
{
    void *ignored = NULL;

    return [self objectAtIndex:index withHint:&ignored];
}

- (unsigned int)objectCount;
{
    [self waitForDataEnd];
    return count;
}

- (BOOL)isIndexPastEnd:(unsigned int)anIndex
{
    if (anIndex >= count && !endOfObjects) {
        [objectsLock lock];
        while (anIndex >= count && !endOfObjects) {
            [objectsLock unlockWithCondition:READERS_WAITING];
            [objectsLock lockWhenCondition:OBJECTS_AVAILABLE];
        }
        [objectsLock unlockWithCondition:OBJECTS_AVAILABLE];
    }

    if (anIndex >= count)
        return NO;
    else
        return YES;
}

// OWObjectStream subclass

- (void)dataEnd;
{
    [self _noMoreData];
}

- (void)dataAbort;
{
    [self _noMoreData];
}

- (void)waitForDataEnd;
{
    [endOfDataLock lockWhenCondition: DATA_ENDED];
    [endOfDataLock unlock];
}

- (BOOL)endOfData;
{
    return endOfObjects;
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    if (objectsLock)
	[debugDictionary setObject:objectsLock forKey:@"objectsLock"];
    [debugDictionary setObject:endOfObjects ? @"YES" : @"NO" forKey:@"endOfObjects"];
    // UNDONE: debug info for the buffers
    return debugDictionary;
}

@end

@implementation OWObjectStream (Private)

- (void)_noMoreData;
{
    [objectsLock lock];
    endOfObjects = YES;
    [objectsLock unlockWithCondition:OBJECTS_AVAILABLE];
    [endOfDataLock lock];
    [endOfDataLock unlockWithCondition: DATA_ENDED];
}

@end
