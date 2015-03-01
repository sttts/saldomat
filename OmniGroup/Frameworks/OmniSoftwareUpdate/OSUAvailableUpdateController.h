// Copyright 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniSoftwareUpdate/OSUAvailableUpdateController.h 98221 2008-03-04 21:06:19Z kc $

#import <AppKit/NSWindowController.h>

@class WebView;
@class OSUItem;

extern NSString * const OSUAvailableUpdateControllerAvailableItemsBinding;
extern NSString * const OSUAvailableUpdateControllerCheckInProgressBinding;

@interface OSUAvailableUpdateController : NSWindowController
{
    // Outlets
    IBOutlet NSArrayController *_availableItemController;
    IBOutlet NSTextField *_titleTextField;
    IBOutlet NSTextField *_messageTextField;
    IBOutlet NSSplitView *_itemsAndReleaseNotesSplitView;
    IBOutlet NSTableView *_itemTableView;
    IBOutlet WebView *_releaseNotesWebView;
    IBOutlet NSImageView *_appIconImageView;

    // KVC
    NSArray *_itemSortDescriptors;
    NSPredicate *_itemFilterPredicate;
    NSArray *_availableItems;
    NSIndexSet *_selectedItemIndexes;
    OSUItem *_selectedItem;
    BOOL _loadingReleaseNotes;
    BOOL _checkInProgress;
}

+ (OSUAvailableUpdateController *)availableUpdateController;

- (IBAction)installSelectedItem:(id)sender;

// KVC
- (OSUItem *)selectedItem;

@end
