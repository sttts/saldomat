// Copyright 2001-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAPreferencesWindow.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/rcsid.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/Preferences.subproj/OAPreferencesWindow.m 68913 2005-10-03 19:36:19Z kc $");

@implementation OAPreferencesWindow

- (void)runToolbarCustomizationPalette:(id)sender;
{
}

- (BOOL)validateMenuItem:(NSMenuItem *)theItem;
{
    if ([theItem action] == @selector(runToolbarCustomizationPalette:))
        return NO;
    else
        return [super validateMenuItem:theItem];
}

@end