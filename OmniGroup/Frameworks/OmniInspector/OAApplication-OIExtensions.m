// Copyright 2005-2006 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAApplication-OIExtensions.h"

#import <Cocoa/Cocoa.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "OIColorInspector.h"
#import "OIInspectorGroup.h"
#import "OIInspectorRegistry.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OAApplication-OIExtensions.m 79095 2006-09-08 00:19:03Z kc $")

@implementation OAApplication (OIExtensions)

- (IBAction)toggleInspectorPanel:(id)sender;
{
    // [OIInspectorRegistry toggleAllInspectors] seems inviting, but it makes _all_ inspectors visible, or hides them all if they were already all visible. We, instead, want to toggle between the user's chosen visible set and hiding them all.
    [OIInspectorRegistry tabShowHidePanels];
}

- (IBAction)toggleFrontColorPanel:(id)sender;
{
    [[NSColorPanel sharedColorPanel] toggleWindow:nil];
}

// NSMenuValidation

- (BOOL)validateMenuItem:(NSMenuItem *)item;
{
    SEL action = [item action];
    
    if (action == @selector(toggleInspectorPanel:)) {
        NSString *showString = NSLocalizedStringFromTableInBundle(@"Show Inspectors", @"OmniInspector", [OIInspectorRegistry bundle], "menu title");
        NSString *hideString = NSLocalizedStringFromTableInBundle(@"Hide Inspectors", @"OmniInspector", [OIInspectorRegistry bundle], "menu title");
	
        if ([[OIInspectorGroup visibleGroups] count] > 0) {
            [item setTitle:hideString];
        } else {
            [item setTitle:showString];
        }
        return YES;
    }
    
    return [super validateMenuItem:item];
}

@end
