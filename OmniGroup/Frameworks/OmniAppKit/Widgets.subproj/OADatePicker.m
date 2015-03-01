// Copyright 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OADatePicker.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/trunk/OmniGroup/Templates/Developer%20Tools/File%20Templates/%20Omni/Omni%20sekrit%20source%20code%20class.pbfiletemplate/class.m 70671 2005-11-22 01:01:39Z kc $");

@implementation OADatePicker
- (void) dealloc {
    [_lastDate release];
    [super dealloc];
}

- (BOOL)sendAction:(SEL)theAction to:(id)theTarget;
{
    if (theAction == @selector(_clockAndCalendarReturnToHomeMonth:)
	|| theAction == @selector(_clockAndCalendarRetreatMonth:)
	|| theAction == @selector(_clockAndCalendarAdvanceMonth:) ) {
	_lastDate = [[self dateValue] retain];
	ignoreNextDateRequest = YES;
	sentAction = YES;
    } else
	ignoreNextDateRequest = NO;

    return [super sendAction:theAction to:theTarget];
}

- (void)mouseDown:(NSEvent *)theEvent;
{
    [super mouseDown:theEvent];
    
    if (!sentAction && [theEvent type] == NSLeftMouseDown && [theEvent clickCount] > 1) {
        [[self window] resignKeyWindow];
    }
    
    sentAction = NO;
}

- (NSDate *)dateValue;
{
    if (ignoreNextDateRequest) {
	return _lastDate;
    }
    return [super dateValue];
}

@end
