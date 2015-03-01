// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspectorTabController.h 95874 2007-12-11 22:09:59Z bungi $

#import <OmniFoundation/OFObject.h>
#import "OIInspector.h"

@class NSArray, NSBundle; // Foundation
@class NSBox, NSImage, NSMenuItem, NSView; // AppKit
@class OITabbedInspector;

@interface OIInspectorTabController : OFObject
{
    NSArray *_currentlyInspectedObjects;
    OIInspector *_inspector;
    NSImage *_image;
    NSBox *_dividerView;
    struct {
        unsigned hasLoadedView: 1;
        unsigned needsInspectObjects: 1;
        unsigned respondsTo_shouldBeDimmedForObjects: 1;
        unsigned respondsTo_shouldBeDimmed: 1;
    } _flags;
    OIVisibilityState _visibilityState;
}

- initWithInspectorDictionary:(NSDictionary *)tabPlist containingInspector:(OITabbedInspector *)containingInspector bundle:(NSBundle *)bundle;

- (OIInspector *)inspector;
- (NSImage *)image;
- (NSView *)inspectorView;
- (NSView *)dividerView;
- (BOOL)isPinned;
- (BOOL)isVisible;
- (OIVisibilityState)visibilityState;
- (void)setVisibilityState:(OIVisibilityState)newValue;
- (BOOL)hasLoadedView;
- (BOOL)shouldBeDimmed;

- (void)inspectObjects:(BOOL)inspectNothing;

- (NSDictionary *)copyConfiguration;
- (void)loadConfiguration:(NSDictionary *)config;

// Covers for OIInspector methods
- (NSString *)identifier;
- (NSString *)displayName;
- (NSString *)shortcutKey;
- (unsigned int)shortcutModifierFlags;
- (NSMenuItem *)menuItemForTarget:(id)target action:(SEL)action;

@end

