// Copyright 2005-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OITabbedInspector.h"

#import <AppKit/AppKit.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniAppKit/OmniAppKit.h>

#import "OIInspectorController.h"
#import "OIInspectorRegistry.h"
#import "OIInspectorTabController.h"
#import "OITabCell.h"
#import "OITabMatrix.h"
#import "OIButtonMatrixBackgroundView.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OITabbedInspector.m 95989 2007-12-13 06:19:16Z bungi $")

@interface OITabbedInspector (Private)
- (OIInspectorTabController *)_tabWithIdentifier:(NSString *)identifier;
- (void)_updateDimmedForTab:(OIInspectorTabController *)tab;
- (void)_updateSubInspectorObjects;
- (void)_createButtonCellForAllTabs;
- (void)_updateTrackingRects;
- (void)_tabTitleDidChange:(NSNotification *)notification;
- (void)_layoutSelectedTabs;
- (void)_updateButtonsToMatchSelection;
@end

#pragma mark -

@implementation OITabbedInspector

- (void)dealloc;
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_tabControllers release];
    [_trackingRectTags release];
    [super dealloc];
}

- (void)awakeFromNib;
{
#ifdef OITabbedInspectorUnifiedLookDefaultsKey
    if ([[NSUserDefaults standardUserDefaults] boolForKey:OITabbedInspectorUnifiedLookDefaultsKey]) {
        NSArray *subviews = [inspectionView subviews];
        for(NSView *aView in subviews) {
            if ([aView isKindOfClass:[NSBox class]]) {
                [aView setHidden:YES];
                break;
            }
        }
    }
#endif
    
    float inspectorWidth = [[OIInspectorRegistry sharedInspector] inspectorWidth];
    
    NSRect inspectionFrame = [inspectionView frame];
    OBASSERT(inspectionFrame.size.width <= inspectorWidth); // OK to make views from nibs wider, but probably indicates a problem if we are making them smaller.
    inspectionFrame.size.width = inspectorWidth;
    [inspectionView setFrame:inspectionFrame];
    
    NSRect contentFrame = [contentView frame];
    OBASSERT(contentFrame.size.width <= inspectorWidth); // OK to make views from nibs wider, but probably indicates a problem if we are making them smaller.
    contentFrame.size.width = inspectorWidth;
    [contentView setFrame:contentFrame];

    [contentView setAutoresizesSubviews:NO]; // Must turn this off, or inspector views can get scrambled when we change the inspectionView size after adding pane views to the contentView
        
    if (_singleSelection) {
        [buttonMatrix setMode:NSRadioModeMatrix];
        [buttonMatrix setAllowsEmptySelection:NO];
    } else {
        // list mode set in nib
        [buttonMatrix setAllowsEmptySelection:YES];
    }
    
    OIButtonMatrixBackgroundView *buttonMatrixBackground = (id)[buttonMatrix superview];
    OBASSERT([buttonMatrixBackground isKindOfClass:[OIButtonMatrixBackgroundView class]]);
#ifdef OITabbedInspectorUnifiedLookDefaultsKey
    if ([[NSUserDefaults standardUserDefaults] boolForKey:OITabbedInspectorUnifiedLookDefaultsKey]) {
        [buttonMatrixBackground setBackgroundColor:nil];
        [(OITabMatrix *)buttonMatrix setTabMatrixHighlightStyle:OITabMatrixDepressionHighlightStyle];
    } else
#endif
    {
        NSColor *toolbarBackgroundColor;
        if ([[NSColor class] respondsToSelector:@selector(toolbarBackgroundColor)])
            toolbarBackgroundColor = [(id)[NSColor class] performSelector:@selector(toolbarBackgroundColor)];
        else
            toolbarBackgroundColor = [NSColor windowBackgroundColor];
        [buttonMatrixBackground setBackgroundColor:toolbarBackgroundColor];
        [(OITabMatrix *)buttonMatrix setTabMatrixHighlightStyle:OITabMatrixCellsHighlightStyle];
    }
    
    [self _createButtonCellForAllTabs];
    [self _layoutSelectedTabs]; // updates the inspection set in the tabs
}

#pragma mark -
#pragma mark API

- (NSAttributedString *)windowTitle;
{
    NSArray *cells = [buttonMatrix cells];
    BOOL addedColon = NO;
    BOOL duringMouseDown = NO;
    
    // If we are the only inspector, don't prefix our window title with the tabbed inspector's name.  Just use the tab names.
    NSString *prefix;
    BOOL hasSingleInspector = [[OIInspectorRegistry sharedInspector] hasSingleInspector];
    if (hasSingleInspector)
        prefix = @"";
    else
        prefix = [self displayName];
    
    NSString *windowTitle = prefix;
    
    unsigned int tabIndex, tabCount = [_tabControllers count];
    for(tabIndex = 0; tabIndex < tabCount; tabIndex++) {
	OITabCell *cell = [cells objectAtIndex:tabIndex];
	if ([cell state]) {
	    if ([cell duringMouseDown])
		duringMouseDown = YES;
	    if (!addedColon) {
                if (!hasSingleInspector) // Only need the colon if we used this inspector's name as a prefix
                    windowTitle = [windowTitle stringByAppendingString:@": "];
		addedColon = YES;
	    } else {
		windowTitle = [windowTitle stringByAppendingString:@", "];
	    }
	    windowTitle = [windowTitle stringByAppendingString:[[_tabControllers objectAtIndex:tabIndex] displayName]];
	}
    }
    
    if (!duringMouseDown && [buttonMatrix window]) {
        NSPoint point = [[buttonMatrix window] mouseLocationOutsideOfEventStream];
        point = [buttonMatrix convertPoint:point fromView:nil];
        int row, column;
        if ([buttonMatrix getRow:&row column:&column forPoint:point]) {
	    OIInspectorTabController *tab = [_tabControllers objectAtIndex:column];
            
            windowTitle = prefix;
            if (!hasSingleInspector)
                windowTitle = [windowTitle stringByAppendingString:@": "];
            
            windowTitle = [windowTitle stringByAppendingString:[tab displayName]];
            if ([[tab shortcutKey] length]) {
                windowTitle = [windowTitle stringByAppendingString:@" ("];
                windowTitle = [windowTitle stringByAppendingString:[NSString stringForKeyEquivalent:[tab shortcutKey] andModifierMask:[tab shortcutModifierFlags]]];
                windowTitle = [windowTitle stringByAppendingString:@")"];
            }
            duringMouseDown = YES;
        }
    }
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont systemFontOfSize:[NSFont labelFontSize]], NSFontAttributeName, nil];
    NSMutableAttributedString *windowTitleAttributedstring = [[NSMutableAttributedString alloc] init];
    [windowTitleAttributedstring replaceCharactersInRange:NSMakeRange(0, [[windowTitleAttributedstring string] length]) withString:windowTitle];
    if (duringMouseDown) {
        int partial = [prefix length];
        [windowTitleAttributedstring setAttributes:textAttributes range:NSMakeRange(0, partial)];
        NSDictionary *italicAttributes = [NSDictionary dictionaryWithObjectsAndKeys:[[NSFontManager sharedFontManager] convertFont:[NSFont userFontOfSize:[NSFont labelFontSize]] toHaveTrait:NSItalicFontMask], NSFontAttributeName, nil];
        [windowTitleAttributedstring setAttributes:italicAttributes range:NSMakeRange(partial, [[windowTitleAttributedstring string] length] - partial)];
    } else {
        [windowTitleAttributedstring setAttributes:textAttributes range:NSMakeRange(0, [[windowTitleAttributedstring string] length])];
    }
    
    [windowTitleAttributedstring autorelease];
    return windowTitleAttributedstring;
}

- (void)loadConfiguration:(NSDictionary *)config;
{    
    NSMutableArray *selectedIdentifiers = [NSMutableArray array];
    NSMutableArray *pinnedIdentifiers = [NSMutableArray array];
    
    unsigned int tabIndex, tabCount = [_tabControllers count];
    for(tabIndex = 0; tabIndex < tabCount; tabIndex++) {
        OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
        id tabIdentifier = [tab identifier];
        [tab loadConfiguration:[config objectForKey:tabIdentifier]];
        
        switch ([tab visibilityState]) {
            case OIPinnedVisibilityState:
                [pinnedIdentifiers addObject:tabIdentifier];
                // Fall through to OIVisibleVisibilityState because all pinned tabs must be visible
            case OIVisibleVisibilityState:
                [selectedIdentifiers addObject:tabIdentifier];
                break;
            default:
                OBASSERT([tab visibilityState] == OIHiddenVisibilityState); // If we get here and the visibility state isn't Hidden, there must be some new visibility state we don't know about or we've been given bad data
                break;  // Nothing to do for hidden tabs
        }
    }
    
    // If we are starting with a fresh configuration, we might not have anything selected in a radio-style inspector.
    if ([selectedIdentifiers count] == 0 && _singleSelection && tabCount > 0)
        selectedIdentifiers = [NSArray arrayWithObject:[[_tabControllers objectAtIndex:0] identifier]];
    
    [self setSelectedTabIdentifiers:selectedIdentifiers pinnedTabIdentifiers:pinnedIdentifiers];
    
    // Force a layout here since -setSelectedTabIdentifiers: will think nothing has changed (since the inspectors and selection are in sync at this point even though the view isn't).
    if (inspectionView)
	[self _layoutSelectedTabs];
    
    if (!config)
        [_nonretained_inspectorController showInspector];
}

- (NSDictionary *)configuration;
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    unsigned int tabIndex, tabCount = [_tabControllers count];
    for(tabIndex = 0; tabIndex < tabCount; tabIndex++) {
	OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
	NSDictionary *config = [tab copyConfiguration];
        [dict setObject:config forKey:[tab identifier]];
	[config release];
    }
    return dict;
}

- (NSArray *)tabIdentifiers;
{
    return [_tabControllers arrayByPerformingSelector:@selector(identifier)];
}

// While the code doesn't currently strictly require it, the expectation is that pinnedIdentifiers is a subset of selectedIdentifiers. Pass in nil for the pinnedIdentifiers if you wish to keep the currently-pinned selection (in which case selectedIdentifiers need not include the
- (void)setSelectedTabIdentifiers:(NSArray *)selectedIdentifiers pinnedTabIdentifiers:(NSArray *)pinnedIdentifiers;
{
    if (pinnedIdentifiers == nil) {
        pinnedIdentifiers = [self pinnedTabIdentifiers];
        NSMutableSet *selectionSet = [NSMutableSet setWithArray:selectedIdentifiers];
        [selectionSet addObjectsFromArray:pinnedIdentifiers];
        selectedIdentifiers = [selectionSet allObjects];
    }
    
    NSSet *pinnedIdentifiersSet = [NSSet setWithArray:pinnedIdentifiers];
    NSSet *selectedIdentifiersSet = [NSSet setWithArray:selectedIdentifiers];
    OBASSERT([pinnedIdentifiersSet isSubsetOfSet:selectedIdentifiersSet]);
    
    BOOL needsLayout = NO;
    unsigned int tabIndex = [_tabControllers count];
    while (tabIndex--) {
        OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
        
        id tabIdentifier = [tab identifier];
        OIVisibilityState visibilityState;
        if ([pinnedIdentifiersSet member:tabIdentifier]) {
            visibilityState = OIPinnedVisibilityState;
        } else if ([selectedIdentifiersSet member:tabIdentifier]) {
            visibilityState = OIVisibleVisibilityState;
        } else {
            visibilityState = OIHiddenVisibilityState;
        }
        if ([tab visibilityState] != visibilityState) {
            if (![tab isVisible]) {
                NSWindow *inspectorPanel = [inspectionView window];
                NSResponder *firstResponder = [inspectorPanel firstResponder];
                if ([firstResponder isKindOfClass:[NSView class]] && [(NSView *)firstResponder isDescendantOf:contentView]) {
                    BOOL result __attribute__((unused));
                    result = [inspectorPanel makeFirstResponder:inspectorPanel];   // make sure that switching to a new tab causes any edits to commit
                    OBASSERT(result);
                }
            }
            [tab setVisibilityState:visibilityState];
            needsLayout = YES;
        }
    }
    
    if (inspectionView && needsLayout)
        [self _layoutSelectedTabs];
}

- (void)updateDimmedForTabWithIdentifier:(NSString *)tabIdentifier;
{
    OIInspectorTabController *tab = [self _tabWithIdentifier:tabIdentifier];
    OBASSERT(tab);
    
    if (tab)
        [self _updateDimmedForTab:tab];
}

- (OIInspector *)inspectorWithIdentifier:(NSString *)tabIdentifier;
{
    return [[self _tabWithIdentifier:tabIdentifier] inspector];
}

- (NSArray *)selectedTabIdentifiers;
{
    NSMutableArray *identifiers = [NSMutableArray array];
    
    unsigned int tabIndex = [_tabControllers count];
    while(tabIndex--) {
	OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
	if ([tab isVisible])
	    [identifiers addObject:[tab identifier]];
    }
    return identifiers;
}

- (NSArray *)pinnedTabIdentifiers;
{
    NSMutableArray *identifiers = [NSMutableArray array];
    unsigned int tabIndex, tabCount = [_tabControllers count];
    for (tabIndex = 0; tabIndex < tabCount; tabIndex++) {
        OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
        if ([tab isPinned]) {
            [identifiers addObject:[tab identifier]];
        }
    }
    return identifiers;
}

- (float)additionalHeaderHeight;
{
    float extraHeightBecauseTheDividerIsNotThere = 0;
#ifdef OITabbedInspectorUnifiedLookDefaultsKey
    if ([[NSUserDefaults standardUserDefaults] boolForKey:OITabbedInspectorUnifiedLookDefaultsKey]) {
        extraHeightBecauseTheDividerIsNotThere = 1;
    }
#endif
    
    if ([buttonMatrix tabMatrixHighlightStyle] == OITabMatrixDepressionHighlightStyle)
        return [buttonMatrix frame].size.height + extraHeightBecauseTheDividerIsNotThere;
    else
        return 0;
}

#pragma mark -
#pragma mark Actions

// Poorly named action of the button ribbon in Tabbed.nib
- (IBAction)selectInspector:(id)sender;
{
    NSArray *selectedCells = [sender selectedCells];
    NSSet *pinnedCellsSet = [NSSet setWithArray:[sender pinnedCells]];
    int count = [selectedCells count];
    NSMutableArray *selectedIdentifiers = [NSMutableArray array];
    NSMutableArray *pinnedIdentifiers = [NSMutableArray array];

    int i;
    for(i=0;i<count;i++) {
        NSCell *cell = [selectedCells objectAtIndex:i];
        OIInspectorTabController *tab = [cell representedObject];
        [selectedIdentifiers addObject:[tab identifier]];
        if ([pinnedCellsSet member:cell]) {
            [pinnedIdentifiers addObject:[tab identifier]];
        }
    }
    [self setSelectedTabIdentifiers:selectedIdentifiers pinnedTabIdentifiers:pinnedIdentifiers];
}

// Not set in nib, We set this up for individual tab menu items in -menuItemsForTarget:action:; the containing group is set up with the selector requested by the caller.
- (IBAction)switchToInspector:(id)sender;
{
    OIInspectorTabController *tab = [sender representedObject];
    OBASSERT([_tabControllers indexOfObjectIdenticalTo:tab] != NSNotFound);
    
    BOOL isVisible = [_nonretained_inspectorController isExpanded] && [_nonretained_inspectorController isVisible];
    
    if (isVisible && [tab isVisible]) {
        NSMutableArray *identifiers = [NSMutableArray arrayWithArray:[self selectedTabIdentifiers]];
        [identifiers removeObject:[tab identifier]];
        [self setSelectedTabIdentifiers:identifiers pinnedTabIdentifiers:nil];
        if ([identifiers count] == 0) {
            [buttonMatrix deselectAllCells];
            return;
        }
    } else if (tab) {
        [self setSelectedTabIdentifiers:[NSArray arrayWithObject:[tab identifier]] pinnedTabIdentifiers:nil];
    } else {
        [buttonMatrix deselectAllCells];
    }
    
    [_nonretained_inspectorController showInspector];
}

#pragma mark -
#pragma mark OIInspector subclass

- initWithDictionary:(NSDictionary *)dict bundle:(NSBundle *)sourceBundle;
{
    if (![super initWithDictionary:dict bundle:sourceBundle])
	return nil;
    
    
    _singleSelection = [dict boolForKey:@"single-selection" defaultValue:NO];
    
    NSMutableArray *tabControllers = [[NSMutableArray alloc] init];
    
    // Read our sub-inspectors from the plist
    NSArray *tabPlists = [dict objectForKey:@"tabs"];
    unsigned int tabIndex, tabCount = [tabPlists count];
    for (tabIndex = 0; tabIndex < tabCount; tabIndex++) {
	NSDictionary *tabPlist = [tabPlists objectAtIndex:tabIndex];
	OIInspectorTabController *tabController = [[OIInspectorTabController alloc] initWithInspectorDictionary:tabPlist containingInspector:self bundle:sourceBundle];
	if (!tabController)
	    continue;

	[tabControllers addObject:tabController];
	[tabController release];
    }
    
    [tabControllers sortUsingFunction:sortByDefaultDisplayOrderInGroup context:NULL];
    
    _tabControllers = [[NSArray alloc] initWithArray:tabControllers];
    [tabControllers release];
    
    _trackingRectTags = [[NSMutableArray alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_tabTitleDidChange:) name:TabTitleDidChangeNotification object:nil];
    return self;
}

- (void)registerInspectorDictionary:(NSDictionary *)tabPlist bundle:(NSBundle *)sourceBundle
{
    OIInspectorTabController *tabController = [[OIInspectorTabController alloc] initWithInspectorDictionary:tabPlist containingInspector:self bundle:sourceBundle];
    if (!tabController)
        return;
    
    NSMutableArray *newTabControllers = [[NSMutableArray alloc] initWithArray:_tabControllers];
    [newTabControllers insertObject:tabController inArraySortedUsingFunction:sortByDefaultDisplayOrderInGroup context:NULL];
    [_tabControllers release];
    _tabControllers = [[NSArray alloc] initWithArray:newTabControllers];
    [newTabControllers release];
    
    if (buttonMatrix)
        [self _createButtonCellForAllTabs];
}

- (NSArray *)menuItemsForTarget:(id)target action:(SEL)action;
{
    // If there is a single tabbed inspector; don't wrap up the menu items for the tabs in a higher level menu item.
    BOOL hasSingleInspector = [[OIInspectorRegistry sharedInspector] hasSingleInspector];

    NSMutableArray *menuItems = [NSMutableArray array];

    if (!hasSingleInspector) {
        // Call -menuItem here too so that we can have shortcuts registered for whole inspectors (OmniOutliner) or for individual tabs (OmniGraffle).
        NSMenuItem *headerItem = [self menuItemForTarget:target action:action];
        [menuItems addObject:headerItem];
    }
    
    unsigned int tabIndex, tabCount = [_tabControllers count];
    for (tabIndex = 0; tabIndex < tabCount; tabIndex++) {
	OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
	NSMenuItem *item = [tab menuItemForTarget:self action:@selector(switchToInspector:)];
	[item setRepresentedObject:tab];
        if (!hasSingleInspector)
            [item setIndentationLevel:2];
	[menuItems addObject:item];
    }
    
    return menuItems;
}

#pragma mark -
#pragma mark OIConcreteInspector protocol

- (NSView *)inspectorView;
{
    if (!contentView)
        [OMNI_BUNDLE loadNibNamed:@"Tabbed" owner:self];

    OBPOSTCONDITION(inspectionView);
    return inspectionView;
}

- (NSPredicate *)inspectedObjectsPredicate;
{
    static NSPredicate *truePredicate = nil;
    if (!truePredicate)
        truePredicate = [[NSPredicate predicateWithValue:YES] retain];
    return truePredicate;
}

- (void)inspectObjects:(NSArray *)list 
{
    // list will be nil when we are collapsed
    _shouldInspectNothing = (list == nil);
    [self _updateSubInspectorObjects];
}


#pragma mark -
#pragma mark NSResponder subclass

- (void)mouseEntered:(NSEvent *)event;
{
    [_nonretained_inspectorController updateTitle];
}

- (void)mouseExited:(NSEvent *)event;
{
    [_nonretained_inspectorController updateTitle];
}


#pragma mark -
#pragma mark NSObject (OIInspectorOptionalMethods)

- (void)setInspectorController:(OIInspectorController *)aController;
{
    _nonretained_inspectorController = aController;
}

#pragma mark -
#pragma mark NSObject (NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)item;
{
    BOOL isVisible = [_nonretained_inspectorController isExpanded] && [_nonretained_inspectorController isVisible];
    
    if  (!isVisible) {
        [item setState:NSOffState];
    } else if ([item action] == @selector(switchToInspector:)) {
	// one of our tabs
	OIInspectorTabController *tab = [item representedObject];
	[item setState:[tab isVisible] ? NSOnState : NSOffState];
    }
    return YES;
}

@end

#pragma mark -

@implementation OITabbedInspector (Private)

- (OIInspectorTabController *)_tabWithIdentifier:(NSString *)identifier;
{
    unsigned int tabIndex = [_tabControllers count];
    while (tabIndex--) {
	OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
        if (OFISEQUAL(identifier, [[tab inspector] identifier]))
            return tab;
    }
    return nil;
}

- (void)_updateDimmedForTab:(OIInspectorTabController *)tab;
{
    BOOL shouldDim = [tab shouldBeDimmed];
    
    unsigned int tabIndex = [_tabControllers indexOfObject:tab];
    OBASSERT(tabIndex != NSNotFound);
    
    OITabCell *cell = [buttonMatrix cellAtRow:0 column:tabIndex];
    if (shouldDim != [cell dimmed]) {
        [cell setDimmed:shouldDim];
        [buttonMatrix setNeedsDisplay:YES];
    }
}

- (void)_updateSubInspectorObjects;
{
    unsigned int tabIndex = [_tabControllers count];
    while (tabIndex--) {
	OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
	[tab inspectObjects:_shouldInspectNothing];
	[self _updateDimmedForTab:tab];
    }
}

- (void)_createButtonCellForAllTabs;
{
    OBPRECONDITION(buttonMatrix);

    unsigned int tabIndex = [_tabControllers count];
    
    [buttonMatrix renewRows:1 columns:tabIndex];
    [buttonMatrix sizeToCells];
    [buttonMatrix deselectAllCells];

    while (tabIndex--) {
	OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];
	NSButtonCell *cell = [buttonMatrix cellAtRow:0 column:tabIndex];
        [cell setImage:[tab image]];
	[cell setRepresentedObject:tab];
	
        if ([tab isVisible])
            [buttonMatrix setSelectionFrom:tabIndex to:tabIndex anchor:tabIndex highlight:YES];
    }
}

- (void)_updateTrackingRects;
{
    int count = [_trackingRectTags count];
    while(count--) {
        [buttonMatrix removeTrackingRect:[[_trackingRectTags objectAtIndex:count] intValue]];
    }
    [_trackingRectTags removeAllObjects];
    count = [_tabControllers count];
    int i;
    for(i=0;i<count;i++) {
        NSRect rect = [buttonMatrix cellFrameAtRow:0 column:i];
        int tag = [buttonMatrix addTrackingRect:rect owner:self userData:nil assumeInside:NO];
        [_trackingRectTags addObject:[NSNumber numberWithInt:tag]];
    }
}

- (void)_tabTitleDidChange:(NSNotification *)notification;
{
    NSArray *cells = [buttonMatrix cells];
    int count = [cells count];
    int i;
    for(i=0;i<count;i++) {
        OITabCell *cell = [cells objectAtIndex:i];
        if (cell == [notification object]) {
            [_nonretained_inspectorController updateTitle];
            break;
        }
    }
}

- (void)_layoutSelectedTabs;
{
    OBPRECONDITION([_tabControllers count] > 0);
    OBPRECONDITION([contentView isFlipped]); // We use an OITabbedInspectorContentView in the nib to make layout easier.
    
    NSSize size = NSMakeSize([contentView frame].size.width, 0);
    
    unsigned int tabIndex, tabCount = [_tabControllers count];
    unsigned int selectedTabCount = 0;
    
    for (tabIndex = 0; tabIndex < tabCount; tabIndex++) {
	OIInspectorTabController *tab = [_tabControllers objectAtIndex:tabIndex];

	if (![tab isVisible]) {
	    if ([tab hasLoadedView]) { // hack to avoid asking for the view before it's needed; don't want to load the nib just to hide it
		[[tab inspectorView] removeFromSuperview];
		[[tab dividerView] removeFromSuperview];
	    }
	    continue;
	}
	
        if (selectedTabCount > 0) {
            NSRect dividerFrame = [contentView frame];
            dividerFrame.origin.y = size.height;
            dividerFrame.size.height = 1;
            NSView *divider = [tab dividerView];
	    [divider setFrame:dividerFrame];
            [contentView addSubview:divider];
            size.height += 1;
        } else {
	    [[tab dividerView] removeFromSuperview];
	}
	
	selectedTabCount++;

        NSView *view = [tab inspectorView];
        NSRect viewFrame = [view frame];
	OBASSERT(viewFrame.size.width <= size.width); // make sure it'll fit
	
        viewFrame.origin.x = floor((size.width - viewFrame.size.width) / 2.0);
        viewFrame.origin.y = size.height;
        viewFrame.size = [view frame].size;
        [view setFrame:viewFrame];
	[contentView addSubview:view];
	
        size.height += [view frame].size.height;
    }
    
    if (selectedTabCount == 0)
	// hide the line underneath our matrix if we have nothing below it
        size.height -= 2;
    
    NSRect contentFrame = [contentView frame];
    contentFrame.size.height = size.height;
    [contentView setFrame:contentFrame];
    
    size.height += [buttonMatrix frame].size.height + 2;
    NSRect frame = [inspectionView frame];
    frame.size.height = size.height;
    [inspectionView setFrame:frame];

    // Have to do this before calling -updateTitle since it reads the button state (needs to for things like mouse down on the buttons)
    [self _updateButtonsToMatchSelection];

    [contentView setNeedsDisplay:YES];
    [_nonretained_inspectorController updateTitle];
    [_nonretained_inspectorController prepareWindowForDisplay];
    [_nonretained_inspectorController updateExpandedness:NO];
    [self _updateTrackingRects];
    
    // Any newly exposed inspectors should start tracking; any newly hidden should stop
    [self _updateSubInspectorObjects];
    
}

- (void)_updateButtonsToMatchSelection;
{
    [buttonMatrix deselectAllCells];

    NSArray *matrixCells = [buttonMatrix cells];
    unsigned int tabIndex, tabCount = [_tabControllers count];
    for (tabIndex = 0; tabIndex < tabCount; tabIndex++) {
        OIInspectorTabController *tabController = [_tabControllers objectAtIndex:tabIndex];
	if ([tabController isVisible])
	    [buttonMatrix setSelectionFrom:tabIndex to:tabIndex anchor:tabIndex highlight:YES];
	if ([tabController isPinned])
            [[matrixCells objectAtIndex:tabIndex] setIsPinned:YES];
    }
    [buttonMatrix setNeedsDisplay:YES];
}

@end
