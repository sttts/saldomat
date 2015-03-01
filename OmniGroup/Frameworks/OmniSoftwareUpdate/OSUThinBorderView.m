// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSUThinBorderView.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Frameworks/OmniSoftwareUpdate/OSURunTime.m 89476 2007-08-01 23:59:32Z kc $");

#define BORDER_WIDTH (1.0f)

@implementation OSUThinBorderView

- (void)awakeFromNib;
{
    // This is hard to get right in nib
    NSView *subview = [[self subviews] lastObject];
    NSRect bounds = [self bounds];
    NSRect inset = NSInsetRect(bounds, BORDER_WIDTH, BORDER_WIDTH);
    [subview setFrame:inset];
}

- (void)drawRect:(NSRect)rect
{
    NSRect bounds = [self bounds];
    [[NSColor lightGrayColor] set];
    NSFrameRectWithWidth(bounds, BORDER_WIDTH);
}

@end
