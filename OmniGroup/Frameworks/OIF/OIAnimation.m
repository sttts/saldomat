// Copyright 1998-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OIF/OIAnimation.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OWF/OWF.h>

#import <OIF/OIAnimationInstance.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OIF/OIAnimation.m 68913 2005-10-03 19:36:19Z kc $")

static OWContentType *contentType;
static NSString *animationContentName = nil;

@implementation OIAnimation

+ (void)initialize;
{
    OBINITIALIZE;

    contentType = [OWContentType contentTypeForString:@"omni/animation"];
    animationContentName = [NSLocalizedStringFromTableInBundle(@"Animation", @"OIF", [OIAnimation bundle], "content or task type name for animated image content") retain];
}

- initWithSourceContent:(OWContent *)someContent loopCount:(unsigned int)aLoopCount;
{
    NSZone *zone;

    if (![super initWithName:animationContentName])
        return nil;

    zone = [self zone];
    sourceContent = [someContent retain];
    frames = [[NSMutableArray allocWithZone:zone] init];

    loopCount = aLoopCount;

    waitingInstances = [[NSMutableArray allocWithZone:zone] init];
    lock = [[NSLock allocWithZone:zone] init];
    haveAllFrames = NO;
    return self;
}

- (void)dealloc;
{
    [sourceContent release];
    [frames release];
    [waitingInstances release];
    [lock release];
    [super dealloc];
}

- (OWContent *)sourceContent;
{
    return sourceContent;
}

- (void)addFrame:(OIAnimationFrame *)frame;
{
    unsigned int waitingInstanceIndex, waitingInstanceCount;
    NSMutableArray *snapshotOfWaitingInstances;

    [lock lock];

    if (loopCount == 0 && [frames count] != 0) {
        // We only want the first frame
        [lock unlock];
        return;
    }

    [frames addObject:frame];
    waitingInstanceCount = [waitingInstances count];
    if (waitingInstanceCount == 0) {
        // No waiting instances to notify
        [lock unlock];
        return;
    }

    // Notify waiting instances
    snapshotOfWaitingInstances = waitingInstances; // inherit retain
    waitingInstances = [[NSMutableArray allocWithZone:[self zone]] init];
    [lock unlock];

    for (waitingInstanceIndex = 0; waitingInstanceIndex < waitingInstanceCount; waitingInstanceIndex++)
        [[snapshotOfWaitingInstances objectAtIndex:waitingInstanceIndex] animationReceivedFrame:frame];
    [snapshotOfWaitingInstances release];        
}

- (void)endFrames;
{
    unsigned int waitingInstanceIndex, waitingInstanceCount;
    NSMutableArray *snapshotOfWaitingInstances = waitingInstances;

    [lock lock];
    haveAllFrames = YES;
    waitingInstances = nil;
    [lock unlock];

    waitingInstanceCount = [snapshotOfWaitingInstances count];
    for (waitingInstanceIndex = 0; waitingInstanceIndex < waitingInstanceCount; waitingInstanceIndex++)
        [[snapshotOfWaitingInstances objectAtIndex:waitingInstanceIndex] animationEnded];
    [snapshotOfWaitingInstances release];
}

- (OIImage *)animationInstance;
{
    BOOL shouldNotAnimate;
    unsigned int frameCount;
    OIImage *result = nil;
    
    [lock lock];
    frameCount = [frames count];
    shouldNotAnimate = (haveAllFrames && frameCount == 1) || loopCount == 0;
    if (shouldNotAnimate && frameCount > 0)
        result = [frames objectAtIndex:0];
    [lock unlock];

    if (!result)
        result = [[[OIAnimationInstance allocWithZone:[self zone]] initWithAnimation:self] autorelease];
    return result;
}

- (unsigned int)loopCount;
{
    return loopCount;
}

- (void)animationInstance:(OIAnimationInstance *)instance wantsFrame:(unsigned int)frameNumber;
{
    BOOL ended = NO;
    OIAnimationFrame *frame = nil;
    
    [lock lock];
    if (frameNumber < [frames count])
        frame = [frames objectAtIndex:frameNumber];
    else if (haveAllFrames)
        ended = YES;
    else
        [waitingInstances addObject:instance];
    [lock unlock];
        
    if (frame)
        [instance animationReceivedFrame:frame];
    else if (ended)
        [instance animationEnded];
}

// OWContent protocol

- (OWContentType *)contentType;
{
    return contentType;
}

- (OWCursor *)contentCursor;
{
    return nil;
}

- (unsigned long int)cacheSize;
{
    unsigned long int total = 0;
    unsigned int index;

    index = [frames count];
    while (index--)
        total += [[frames objectAtIndex:index] cacheSize];

    return total;
}

- (BOOL)shareable;
{
    return YES;
}

- (BOOL)contentIsValid;
{
    return YES;
}

- (BOOL)endOfData;
{
    return YES;
}

// Debugging

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];
    [debugDictionary setObject:frames forKey:@"frames"];
    [debugDictionary setObject:[NSNumber numberWithInt:loopCount] forKey:@"loopCount"];
    [debugDictionary setObject:haveAllFrames ? @"YES" : @"NO" forKey:@"haveAllFrames"];

    return debugDictionary;
}

@end
