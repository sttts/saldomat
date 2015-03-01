// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspector.h 95874 2007-12-11 22:09:59Z bungi $

#import <AppKit/NSResponder.h>

@class NSBundle, NSDictionary, NSPredicate; // Foundation
@class NSImage, NSMenuItem, NSView; // AppKit
@class OFEnumNameTable; // OmniFoundation

typedef enum {
    OIHiddenVisibilityState,
    OIVisibleVisibilityState,
    OIPinnedVisibilityState
} OIVisibilityState;

@interface OIInspector : NSResponder
{
@private
    NSString *_identifier;
    NSString *_displayName;
    OIVisibilityState _defaultVisibilityState;
    NSString *_shortcutKey;
    unsigned int _shortcutModifierFlags;
    NSBundle *resourceBundle;
    NSString *_imageName, *tabImageName;
    NSImage  *_image;
    unsigned int _defaultOrderingWithinGroup;
}

+ (OFEnumNameTable *)visibilityStateNameTable;

+ createInspectorWithDictionary:(NSDictionary *)dict bundle:(NSBundle *)sourceBundle;

- initWithDictionary:(NSDictionary *)dict bundle:(NSBundle *)sourceBundle;

- (NSString *)identifier;
- (OIVisibilityState)defaultVisibilityState;
- (NSString *)shortcutKey;
- (unsigned int)shortcutModifierFlags;
- (NSImage *)image;
- (NSImage *)tabImage;
- (NSBundle *)resourceBundle;

- (NSString *)displayName;
- (float)additionalHeaderHeight;

- (unsigned int)defaultOrderingWithinGroup;
- (void)setDefaultOrderingWithinGroup:(unsigned int)defaultOrderingWithinGroup;

// TODO: Get rid of this
- (unsigned int)deprecatedDefaultDisplayGroupNumber;

- (NSMenuItem *)menuItemForTarget:(id)target action:(SEL)action;
- (NSArray *)menuItemsForTarget:(id)target action:(SEL)action;

- (void)setControlsEnabled:(BOOL)enabled;
- (void)setControlsEnabled:(BOOL)enabled inView:(NSView *)view;

@end

@protocol OIConcreteInspector
- (NSView *)inspectorView;
    // Returns the view which will be placed into a grouped Info window

- (NSPredicate *)inspectedObjectsPredicate;
    // Return a predicate to filter the inspected objects down to what this inspector wants sent to its -inspectObjects: method

- (void)inspectObjects:(NSArray *)objects;
    // This method is called whenever the selection changes
@end

@class OITabbedInspector;
@interface NSObject (OITabbedInspectorOptional)
// Tabbed inspectors receive an -inspectObjects: with nil when they are hidden.  If the inspector wants its tab dimmed when there is a non-empty array that *would* be inspected if it were visible, then this method allows it to do that.  The default is for tabs to be dimmed when there are zero objects they could inspect, if visible.
- (BOOL)shouldBeDimmedForObjects:(NSArray *)objects;
- (BOOL)shouldBeDimmed;

- (void)setContainingTabbedInspector:(OITabbedInspector *)containingTabbedInspector;
@end

// This is not implemented; this just allows you to call the concrete methods.  -[OIInspector initWithDictionary:] asserts that the class conforms.
@interface OIInspector (OIConcreteInspector) <OIConcreteInspector>
@end

@class OIInspectorController;
@interface NSObject (OIInspectorOptionalMethods)
- (void)setInspectorController:(OIInspectorController *)aController;
    // If the inspector has any need to know its controller, it can implement this method
- (float)inspectorWillResizeToHeight:(float)height; // height of window content rect, excluding header button view
- (float)inspectorMinimumHeight; // returns minimum height of window content rect
- (id)windowTitle; 
    // If implemented, this will be used instead of -inspectorName, to let the window title be dynamic. NSAttributedString or NSString are ok.

- (NSDictionary *)configuration;
- (void)loadConfiguration:(NSDictionary *)dict;
    // These methods will be called to save and load any configuration information for the inspectors themselves on startup/shutdown and when workspaces are switched

- (BOOL)mayInspectObject:anObject;

@end

