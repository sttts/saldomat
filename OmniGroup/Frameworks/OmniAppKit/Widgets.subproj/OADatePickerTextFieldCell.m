// Copyright 2006, 2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OADatePickerTextFieldCell.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Templates/Developer%20Tools/File%20Templates/%20Omni/OmniAppKit%20public%20class.pbfiletemplate/class.m 70671 2005-11-22 01:01:39Z kc $");

@implementation OADatePickerTextFieldCell

#pragma mark -
#pragma mark NSCell subclass

- (NSRect)titleRectForBounds:(NSRect)bounds;
{
    NSRect titleRect = [super titleRectForBounds:bounds];
    
    // The button will use NxN where N is the height.  Only chop off the height of the interior of the cell, not the full bezelled bounds.
    bounds.size.width -= titleRect.size.height;
    return bounds;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent;
{
    [super editWithFrame:[self titleRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject event:theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength;
{
    [super selectWithFrame:[self titleRectForBounds:aRect] inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

@end
