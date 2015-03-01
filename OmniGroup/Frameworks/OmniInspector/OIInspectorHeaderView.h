// Copyright 2002-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OIInspectorHeaderView.h 93428 2007-10-25 16:36:11Z kc $

#import <AppKit/NSControl.h>

@protocol OIInspectorHeaderViewDelegateProtocol;

@interface OIInspectorHeaderView : NSView
{
    NSString *title;
    NSImage *image;
    NSString *keyEquivalent;
    NSObject <OIInspectorHeaderViewDelegateProtocol> *delegate;
    BOOL isExpanded, isClicking, isDragging, clickingClose, overClose;
}

- (void)setTitle:(NSString *)aTitle;
- (void)setImage:(NSImage *)anImage;
- (void)setKeyEquivalent:(NSString *)anEquivalent;
- (void)setExpanded:(BOOL)newState;
- (void)setDelegate:(NSObject <OIInspectorHeaderViewDelegateProtocol> *)aDelegate;

- (void)drawBackgroundImageForBounds:(NSRect)backgroundBounds inRect:(NSRect)dirtyRect;

@end

@class NSScreen;

@protocol OIInspectorHeaderViewDelegateProtocol
- (BOOL)headerViewShouldDisplayCloseButton:(OIInspectorHeaderView *)view;
- (float)headerViewDraggingHeight:(OIInspectorHeaderView *)view;
- (void)headerViewDidBeginDragging:(OIInspectorHeaderView *)view;
- (NSRect)headerView:(OIInspectorHeaderView *)view willDragWindowToFrame:(NSRect)aFrame onScreen:(NSScreen *)aScreen;
- (void)headerViewDidEndDragging:(OIInspectorHeaderView *)view toFrame:(NSRect)aFrame;
- (void)headerViewDidToggleExpandedness:(OIInspectorHeaderView *)view;
- (void)headerViewDidClose:(OIInspectorHeaderView *)view;
@end
