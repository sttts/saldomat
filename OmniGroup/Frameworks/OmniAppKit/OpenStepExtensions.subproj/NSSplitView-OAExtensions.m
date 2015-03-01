// Copyright 1997-2005, 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniAppKit/NSSplitView-OAExtensions.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/OpenStepExtensions.subproj/NSSplitView-OAExtensions.m 92062 2007-09-28 16:52:08Z joshua $")

@implementation NSSplitView (OAExtensions)

- (float)fraction;
{
    NSRect                      topFrame, bottomFrame;

    if ([[self subviews] count] < 2)
	return 0.0;

    topFrame = [[[self subviews] objectAtIndex:0] frame];
    bottomFrame = [[[self subviews] objectAtIndex:1] frame];
    
    if (topFrame.origin.y != bottomFrame.origin.y)
	return bottomFrame.size.height / (bottomFrame.size.height + topFrame.size.height);
    else
	return bottomFrame.size.width / (bottomFrame.size.width + topFrame.size.width);
}

- (void)setFraction:(float)newFract;
{
    NSRect                      topFrame, bottomFrame;
    NSView                       *topSubView;
    NSView                       *bottomSubView;
    float                       total;

    if ([[self subviews] count] < 2)
	return;

    topSubView = [[self subviews] objectAtIndex:0];
    bottomSubView = [[self subviews] objectAtIndex:1];
    topFrame = [topSubView frame];
    bottomFrame = [bottomSubView frame];
    
    if (topFrame.origin.y != bottomFrame.origin.y) {
	total = bottomFrame.size.height + topFrame.size.height;
	bottomFrame.size.height = newFract * total;
	topFrame.size.height = total - bottomFrame.size.height;
    } else {
	total = bottomFrame.size.width + topFrame.size.width;
	bottomFrame.size.width = newFract * total;
	topFrame.size.width = total - bottomFrame.size.width;
    }
    [topSubView setFrame:topFrame];
    [bottomSubView setFrame:bottomFrame];
    [self adjustSubviews];
    [self setNeedsDisplay: YES];
}

- (int)topPixels;
{
    NSRect subFrame;
    NSView *subView = [[self subviews] objectAtIndex:0];

    subFrame = [subView frame];
    return subFrame.size.height;	
}

- (void)setTopPixels:(int)newTop;
{
    NSRect                      topFrame, bottomFrame;
    NSView                       *topSubView;
    NSView                       *bottomSubView;
    float                       totalHeight;

    if ([[self subviews] count] < 2)
	return;

    topSubView = [[self subviews] objectAtIndex:0];
    bottomSubView = [[self subviews] objectAtIndex:1];
    topFrame = [topSubView frame];
    bottomFrame = [bottomSubView frame];
    totalHeight = bottomFrame.size.height + topFrame.size.height;
    if (newTop > totalHeight)
	newTop = totalHeight;
    topFrame.size.height = newTop;
    bottomFrame.size.height = totalHeight - newTop;
    [topSubView setFrame:topFrame];
    [bottomSubView setFrame:bottomFrame];
    [self adjustSubviews];
    [self setNeedsDisplay: YES];
}

- (int)bottomPixels;
{
    NSRect subFrame;
    NSView *subView = [[self subviews] objectAtIndex:1];

    subFrame = [subView frame];
    return subFrame.size.height;	
}

- (void)setBottomPixels:(int)newBottom;
{
    NSRect                      topFrame, bottomFrame;
    NSView                       *topSubView;
    NSView                       *bottomSubView;
    float                       totalHeight;

    if ([[self subviews] count] < 2)
	return;

    topSubView = [[self subviews] objectAtIndex:0];
    bottomSubView = [[self subviews] objectAtIndex:1];
    topFrame = [topSubView frame];
    bottomFrame = [bottomSubView frame];
    totalHeight = bottomFrame.size.height + topFrame.size.height;
    if (newBottom > totalHeight)
	newBottom = totalHeight;
    bottomFrame.size.height = newBottom;
    topFrame.size.height = totalHeight - newBottom;
    [topSubView setFrame:topFrame];
    [bottomSubView setFrame:bottomFrame];
    [self adjustSubviews];
    [self setNeedsDisplay: YES];
}
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_5

- (void)animateSubviewResize:(NSView *)resizingSubview startValue:(float)startValue endValue:(float)endValue;
{
    OBASSERT([resizingSubview superview] == self);
    
    NSRect currentFrame, startingFrame, endingFrame;
    currentFrame = [resizingSubview frame];
    
    if ([self isVertical]) {
	startingFrame = (NSRect){currentFrame.origin, NSMakeSize(startValue, currentFrame.size.height)};
	endingFrame = (NSRect){currentFrame.origin, NSMakeSize(endValue, currentFrame.size.height)};
    } else {
	startingFrame = (NSRect){currentFrame.origin, NSMakeSize(currentFrame.size.width, startValue)};
	endingFrame = (NSRect){currentFrame.origin, NSMakeSize(currentFrame.size.width, endValue)};
    }
    
    NSMutableArray *animationArray = [NSMutableArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:resizingSubview, NSViewAnimationTargetKey, [NSValue valueWithRect:endingFrame], NSViewAnimationEndFrameKey, [NSValue valueWithRect:startingFrame], NSViewAnimationStartFrameKey, nil]];
    NSAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations:animationArray];
    [animation setDelegate:[self delegate]];
    [animation setAnimationBlockingMode:NSAnimationBlocking];
    [animation setDuration:0.25];
    [animation startAnimation];
    [animation release];
}

#endif

@end
