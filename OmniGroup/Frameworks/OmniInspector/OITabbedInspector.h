// Copyright 2005-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OITabbedInspector.h 95978 2007-12-13 04:33:07Z bungi $

#import "OIInspector.h"

@class NSAttributedString, NSMutableArray; // Foundation
@class NSMatrix; // AppKit
@class OIInspectorController;
@class OITabMatrix;

#import <AppKit/NSNibDeclarations.h> // For IBOutlet and IBAction

#if defined(MAC_OS_X_VERSION_10_5) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_5 // This uses rendering code that is only available on 10.5
#define OITabbedInspectorUnifiedLookDefaultsKey (@"OITabbedInspectorUnifiedLook")
#endif

@interface OITabbedInspector : OIInspector <OIConcreteInspector> 
{
    IBOutlet NSView *inspectionView;
    IBOutlet NSView *contentView;
    IBOutlet OITabMatrix *buttonMatrix;
    NSArray *_tabControllers;
    NSMutableArray *_trackingRectTags;
    OIInspectorController *_nonretained_inspectorController;
    BOOL _singleSelection;
    BOOL _shouldInspectNothing;
}

// API
- (NSAttributedString *)windowTitle;
- (void)loadConfiguration:(NSDictionary *)dict;
- (NSDictionary *)configuration;

- (void)registerInspectorDictionary:(NSDictionary *)tabPlist bundle:(NSBundle *)sourceBundle;

- (NSArray *)tabIdentifiers;
- (NSArray *)selectedTabIdentifiers;
- (NSArray *)pinnedTabIdentifiers;
- (void)setSelectedTabIdentifiers:(NSArray *)selectedIdentifiers pinnedTabIdentifiers:(NSArray *)pinnedIdentifiers;

- (void)updateDimmedForTabWithIdentifier:(NSString *)tabIdentifier;

- (OIInspector *)inspectorWithIdentifier:(NSString *)tabIdentifier;

// Actions
- (IBAction)selectInspector:(id)sender;
- (IBAction)switchToInspector:(id)sender;

@end
