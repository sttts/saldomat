// Copyright 2002-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspectorRegistry.h 95874 2007-12-11 22:09:59Z bungi $

#import <Foundation/NSObject.h>
#import <AppKit/NSNibDeclarations.h>

@class NSArray, NSMutableArray, NSMutableDictionary, NSSet, NSPredicate;
@class NSButton, NSTableView, NSTextField, NSWindow, NSWindowController, NSMenu, NSMenuItem;
@class OIInspectionSet;

@class OIInspector, OIInspectorController;

#import <OmniAppKit/OAWindowCascade.h> // For the OAWindowCascadeDataSource protocol
#import <OmniFoundation/OFWeakRetainProtocol.h>

@interface OIInspectorRegistry : NSObject <OAWindowCascadeDataSource, OFWeakRetain>
{
    NSWindow *lastWindowAskedToInspect;
    NSWindow *lastMainWindowBeforeAppSwitch;

    OIInspectionSet *inspectionSet;
    
    NSMutableDictionary *workspaceDefaults;
    NSMutableArray *workspaces;
    NSMenu *workspaceMenu;
    struct {
	unsigned int isInspectionQueued:1;
	unsigned int isListeningForNotifications:1;
    } registryFlags;
    
    IBOutlet NSTextField *newWorkspaceTextField;
    IBOutlet NSTableView *editWorkspaceTable;
    IBOutlet NSButtonCell *deleteWorkspaceButton;
    IBOutlet NSButton *restoreWorkspaceButton;
    IBOutlet NSButton *overwriteWorkspaceButton;
    IBOutlet NSButton *workspacesHelpButton;

    NSMutableArray *inspectorControllers;
    float inspectorWidth;
}

// API
+ (void)setInspectorDefaultsVersion:(NSString *)versionString;
+ (void)registerAdditionalPanel:(NSWindowController *)additionalController;
+ (OIInspectorRegistry *)sharedInspector;
+ (Class)sharedInspectorClass;
+ (void)tabShowHidePanels;
+ (BOOL)showAllInspectors;
+ (BOOL)hideAllInspectors;
+ (void)toggleAllInspectors;
+ (void)updateInspector;
+ (void)updateInspectionSetImmediatelyAndUnconditionally;

- (BOOL)hasSingleInspector;

- (BOOL)hasVisibleInspector;
- (void)forceInspectorsVisible:(NSSet *)preferred;

// This method is here so that it can be overridden by app-specific subclasses of OIInspectorRegistry
+ (OIInspectorController *)controllerWithInspector:(OIInspector *)inspector;

- (OIInspectorController *)controllerWithIdentifier:(NSString *)anIdentifier;

- (NSArray *)inspectedObjects;
- (NSArray *)copyObjectsInterestingToInspector:(OIInspector *)anInspector;
- (NSArray *)copyObjectsSatisfyingPredicate:(NSPredicate *)predicate;
- (NSArray *)inspectedObjectsOfClass:(Class)aClass;

- (OIInspectionSet *)inspectionSet;
- (void)inspectionSetChanged;

- (NSMutableDictionary *)workspaceDefaults;
- (void)defaultsDidChange;

- (NSMenu *)workspaceMenu;
- (NSMenuItem *)resetPanelsItem;

- (void)saveWorkspace:sender;
- (void)saveWorkspaceConfirmed:sender;
- (void)editWorkspace:sender;
- (void)deleteWorkspace:sender;
- (IBAction)addWorkspace:(id)sender;
- (IBAction)overwriteWorkspace:(id)sender;
- (IBAction)restoreWorkspace:(id)sender;
- (IBAction)deleteWithoutConfirmation:(id)sender;
- (void)cancelWorkspacePanel:sender;
- (void)switchToWorkspace:sender;
- (void)switchToDefault:sender;
- (IBAction)showWorkspacesHelp:(id)sender;

- (void)restoreInspectorGroups; // called at app startup, defaults change, etc.
- (void)dynamicMenuPlaceholderSet;

- (float)inspectorWidth; // fixed width of inspector window content-views (not window frames)
- (NSPoint)adjustTopLeftDefaultPositioningPoint:(NSPoint)topLeft;  // point is given in screen coordinates

@end

extern NSString *OIInspectorSelectionDidChangeNotification;
extern NSString *OIWorkspacesHelpURLKey;

#import <AppKit/NSView.h>

@interface NSView (OIInspectorExtensions)
- (BOOL)isInsideInspector;
@end
