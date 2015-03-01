// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OIF/OIAnimationInstance.h 68913 2005-10-03 19:36:19Z kc $

#import <OIF/OIImage.h>

@class NSTimer;
@class OFScheduledEvent;
@class OIAnimation, OIAnimationFrame;

#import <OmniFoundation/OFWeakRetainConcreteImplementation.h>

@interface OIAnimationInstance : OIImage <OIImageObserver, OFWeakRetain>
{
    OIAnimation *animation;
    OIAnimationFrame *frame;
    int loopSeconds;                    // Total duration the animation should last before stopping
    unsigned int loopCount;             // Maximum number of loops to display
    unsigned int remainingLoops;        // Remaining number of loops to display, initialized from loopCount
    unsigned int nextFrame;             // Index of animation frame to display
    OFScheduledEvent *nextFrameEvent;
    NSLock *nextFrameEventLock;
    NSTimer *expirationTimer;
    NSLock *expirationTimerLock;

    OFWeakRetainConcreteImplementation_IVARS;
}

- (id)initWithAnimation:(OIAnimation *)animation;
- (OIAnimation *)animation;

- (void)setLoopCount:(unsigned int)aLoopCount;
- (void)setLoopSeconds:(int)aLoopSeconds;

// Called by the animation, possibly from another thread.
- (void)animationEnded;
- (void)animationReceivedFrame:(OIAnimationFrame *)aFrame;

OFWeakRetainConcreteImplementation_INTERFACE

@end
