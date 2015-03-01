// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OIInspectorTabController.h"

#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>

#import "OITabbedInspector.h"
#import "OIInspectorRegistry.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspectorTabController.m 95874 2007-12-11 22:09:59Z bungi $");

@implementation OIInspectorTabController

- init;
{
    OBRejectUnusedImplementation(isa, _cmd);
    return nil;
}

- initWithInspectorDictionary:(NSDictionary *)tabPlist containingInspector:(OITabbedInspector *)containingInspector bundle:(NSBundle *)fromBundle;
{
    NSString *imageName;
    NSDictionary *inspectorPlist = [tabPlist objectForKey:@"inspector"];
        
    if (!inspectorPlist && [tabPlist objectForKey:@"class"]) {
	inspectorPlist = tabPlist;
	imageName = nil;
    } else {
	if (!inspectorPlist) {
	    OBASSERT_NOT_REACHED("No inspector specified for tab");
	    [self release];
	    return nil;
	}
	imageName = [tabPlist objectForKey:@"image"];
    }
    
    _inspector = [OIInspector createInspectorWithDictionary:inspectorPlist bundle:fromBundle];
    if (!_inspector) {
	// Don't log an error; OIInspector should have already if it is an error (might just be an OS version check)
	[self release];
	return nil;
    }
    
    if ([_inspector respondsToSelector:@selector(setContainingTabbedInspector:)])
        [_inspector setContainingTabbedInspector:containingInspector];
    
    if (imageName)
	_image = [[NSImage imageNamed:imageName inBundle:[_inspector resourceBundle]] retain];
    else
	_image = [[_inspector tabImage] retain];
    if (!_image) {
	OBASSERT_NOT_REACHED("No image specified for tab (or can't find it)");
	[self release];
	return nil;
    }

    //[_inspector setDefaultOrderingWithinGroup:tabIndex]; // Doesn't matter for tabs since tabs can't be re-ordered
    
    _visibilityState = [_inspector defaultVisibilityState];

    /* Inspectors may implement either -shouldBeDimmed, which requires the inspection set to be updated using -inspectObjects:, or they may implement -shouldBeDimmedForObjects:, which does not require -inspectObjects: to be called. */
    _flags.respondsTo_shouldBeDimmedForObjects = [_inspector respondsToSelector:@selector(shouldBeDimmedForObjects:)]? 1 : 0;
    _flags.respondsTo_shouldBeDimmed = [_inspector respondsToSelector:@selector(shouldBeDimmed)]? 1 : 0;
    OBINVARIANT(!(_flags.respondsTo_shouldBeDimmedForObjects && _flags.respondsTo_shouldBeDimmed));
    
    return self;
}

- (void)dealloc;
{
    [_currentlyInspectedObjects release];
    [_inspector release];
    [_image release];
    [_dividerView removeFromSuperview];
    [_dividerView release];
    [super dealloc];
}

- (NSImage *)image;
{
    return _image;
}
    
- (NSView *)inspectorView;
{
    _flags.hasLoadedView = 1;
    NSView *view = [_inspector inspectorView];
    
#if 0 && defined(OMNI_ASSERTIONS_ON)
    if ([view autoresizingMask] != 0) {
	NSLog(@"The view for the inspector %@ is resizable and must not be", [_inspector identifier]);
	OBASSERT([view autoresizingMask] == 0); // Tabbed inspector views can't be resizable since the containing inspector itself is resized to hold all the selected inspector tabs
    }
#endif
    
    return view;
}

- (NSView *)dividerView;
{
    if (!_dividerView) {
	NSRect frame = NSMakeRect(0, 0, 100, 1); // caller will resize & position it
	_dividerView = [[NSBox alloc] initWithFrame:frame];
	[_dividerView setBorderType:NSLineBorder];
	[_dividerView setBoxType:NSBoxSeparator];
    }
    return _dividerView;
}

- (BOOL)isPinned;
{
    return (_visibilityState == OIPinnedVisibilityState);
}

- (BOOL)isVisible;
{
    return (_visibilityState > OIHiddenVisibilityState);
}

- (OIVisibilityState)visibilityState;
{
    return _visibilityState;
}

- (void)setVisibilityState:(OIVisibilityState)newValue;
{
    if (newValue != _visibilityState) {
        if (_visibilityState == OIHiddenVisibilityState) {
            _flags.needsInspectObjects = YES;
        }
        _visibilityState = newValue;
    }
}

- (BOOL)hasLoadedView;
{
    return _flags.hasLoadedView;
}

- (BOOL)shouldBeDimmed;
{
    if (_flags.respondsTo_shouldBeDimmedForObjects)
        return [_inspector shouldBeDimmedForObjects:_currentlyInspectedObjects];
    else if (_flags.respondsTo_shouldBeDimmed) {
        if (_flags.needsInspectObjects)
            [_inspector inspectObjects:_currentlyInspectedObjects];
        return [_inspector shouldBeDimmed];
    } else
        return [_currentlyInspectedObjects count] == 0;
}

- (void)inspectObjects:(BOOL)inspectNothing;
{
    NSArray *newObjectsToInspect;
    if (inspectNothing)
	newObjectsToInspect = nil;
    else
	newObjectsToInspect = [[OIInspectorRegistry sharedInspector] copyObjectsInterestingToInspector:_inspector];
    
    if (!_flags.needsInspectObjects && ((!newObjectsToInspect && !_currentlyInspectedObjects) || [newObjectsToInspect isIdenticalToArray:_currentlyInspectedObjects])) {
	[newObjectsToInspect release];
	return;
    }
    
    [_currentlyInspectedObjects release];
    _currentlyInspectedObjects = newObjectsToInspect;

    if (!_flags.hasLoadedView) {
	// The inspector can't be expected to update itself correctly yet if it has no view!  If we mark this set of objects as our inspected objects, we may miss a later update of the inspection set to this same set of objects. <bug://29685>.
	_flags.needsInspectObjects = YES;
	return;
    }
    
    [_inspector inspectObjects:_currentlyInspectedObjects];
}

- (NSDictionary *)copyConfiguration;
{
    NSMutableDictionary *config = [[NSMutableDictionary alloc] init];
    if ([_inspector respondsToSelector:@selector(configuration)])
	[config addEntriesFromDictionary:[_inspector configuration]];
    [config setObject:[[OIInspector visibilityStateNameTable] nameForEnum:_visibilityState] forKey:@"_visibility"];
    
    return config;
}

- (void)loadConfiguration:(NSDictionary *)config;
{
    if ([_inspector respondsToSelector:@selector(loadConfiguration:)])
	[_inspector loadConfiguration:config];
    if (config) {
        NSString *visibilityString = [[config objectForKey:@"_visibility"] lowercaseString];
        if (visibilityString != nil) {
            _visibilityState = [[OIInspector visibilityStateNameTable] enumForName:[[config objectForKey:@"_visibility"] lowercaseString]];
        } else {    // Backwards compatibility with configurations that predate inspector pinning
            _visibilityState = [config boolForKey:@"_selected"] ? OIVisibleVisibilityState : OIHiddenVisibilityState;
        }
    } else {
        _visibilityState = [_inspector defaultVisibilityState];
    }
}

#pragma mark -
#pragma mark Covers for OIInspector methods

- (OIInspector *)inspector;
{
    return _inspector;
}

- (NSString *)identifier;
{
    return [_inspector identifier];
}

- (NSString *)displayName;
{
    return [_inspector displayName];
}

- (NSString *)shortcutKey;
{
    return [_inspector shortcutKey];
}

- (unsigned int)shortcutModifierFlags;
{
    return [_inspector shortcutModifierFlags];
}

- (NSMenuItem *)menuItemForTarget:(id)target action:(SEL)action;
{
    return [_inspector menuItemForTarget:target action:action];
}

@end
