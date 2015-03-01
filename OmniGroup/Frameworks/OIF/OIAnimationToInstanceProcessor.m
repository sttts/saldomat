// Copyright 1998-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OIAnimationToInstanceProcessor.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OWF/OWF.h>

#import "OIAnimation.h"
#import "OIAnimationInstance.h"
#import "OIImage.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OIF/OIAnimationToInstanceProcessor.m 68913 2005-10-03 19:36:19Z kc $")

@implementation OIAnimationToInstanceProcessor

+ (void)didLoad;
{
    [self registerProcessorClass:self fromContentTypeString:@"omni/animation" toContentTypeString:@"omni/image" cost:0.1 producingSource:NO];
}

- initWithContent:(OWContent *)initialContent context:(id <OWProcessorContext>)aPipeline;
{
    if ([super initWithContent:initialContent context:aPipeline] == nil)
        return nil;

    animation = [initialContent objectValue];
    OBASSERT([animation isKindOfClass:[OIAnimation class]]);
    [animation retain];

    return self;
}

- (void)dealloc;
{
    [animation release];
    [super dealloc];
}

// Normally, startProcessing invokes -processInThread in a subthread, which calls a couple of status-updating methods and calls -process. There's no need to create a subthread for something this simple, however.
- (void)startProcessing;
{
    OWContent *newContent;
    OIAnimationInstance *animationInstance;
    
    [self processBegin];
    animationInstance = (OIAnimationInstance *)[animation animationInstance];

    // Do think for OIAnimationInstances, not frames.
    if ([animationInstance isKindOfClass:[OIAnimationInstance class]]) {
        int animationLimitMode = [[pipeline preferenceForKey:@"OIAnimationLimitationMode"] integerValue];
        unsigned int aLoopCount = [animation loopCount];
        int loopSeconds = -1;
        switch (animationLimitMode) {
            case OIAnimationAnimateForever:
                break;
            
            case OIAnimationAnimateOnce:
                aLoopCount = MIN(aLoopCount, 1U);
                break;
            
            case OIAnimationAnimateThrice:
                aLoopCount = MIN(aLoopCount, 3U);
                break;
            
            case OIAnimationAnimateSeconds:
                aLoopCount = OIAnimationInfiniteLoopCount;
                loopSeconds = [[OFPreference preferenceForKey:@"OIAnimationLimitationSeconds"] integerValue];
                break;
            
            case OIAnimationAnimateNever:
                aLoopCount = 0;
                break;
            
            default:
                break;
        }
        
        [animationInstance setLoopCount:aLoopCount];
        [animationInstance setLoopSeconds:loopSeconds];
    }
    
    newContent = [(OWContent *)[OWContent alloc] initWithContent:animationInstance];
    [newContent markEndOfHeaders];
    [pipeline addContent:newContent fromProcessor:self flags:OWProcessorTypeDerived];
    [newContent release];

    [self processEnd];
    [self retire];
}
    
@end
