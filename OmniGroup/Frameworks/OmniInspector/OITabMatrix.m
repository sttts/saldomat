// Copyright 2005-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OITabMatrix.h"

#import <OmniAppKit/OmniAppKit.h>
#import <OmniFoundation/OmniFoundation.h>
#import <OmniBase/OmniBase.h>

#import "OITabCell.h"
#import "OIInspector.h"
#import "OIInspectorTabController.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniInspector/OITabMatrix.m 95874 2007-12-11 22:09:59Z bungi $");

@implementation OITabMatrix

static NSImage *plasticDepression;
static CGFloat depressionLeftMargin, depressionRightMargin;
static void initializeDepressionImages(void)
{
    if (plasticDepression != nil)
        return;
    
    plasticDepression = [[NSImage imageNamed:@"OITabDepressionBackground" inBundle:OMNI_BUNDLE] retain];
    NSSize sizes = [plasticDepression size];
    int pix = sizes.width;
    if (pix%2 == 1) {
        depressionLeftMargin = depressionRightMargin = ( pix - 1 ) / 2;
    } else {
        depressionLeftMargin = depressionRightMargin = ( pix - 2 ) / 2;
    }
}

- (void)setTabMatrixHighlightStyle:(enum OITabMatrixHighlightStyle)newHighlightStyle;
{
    if (newHighlightStyle != highlightStyle) {
        highlightStyle = newHighlightStyle;
        if (highlightStyle == OITabMatrixDepressionHighlightStyle)
            initializeDepressionImages();
        [self setNeedsDisplay];
    }
}

- (enum OITabMatrixHighlightStyle)tabMatrixHighlightStyle;
{
    return highlightStyle;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
{
    return YES;
}

- (NSArray *)pinnedCells;
{
    NSArray *allCells = [self cells];
    NSMutableArray *pinnedCells = [NSMutableArray array];
    int cellCount = [allCells count];
    int cellIndex;
    for (cellIndex = 0; cellIndex < cellCount; cellIndex++) {
        OITabCell *cell = [allCells objectAtIndex:cellIndex];
        if ([cell isPinned]) {
            [pinnedCells addObject:cell];
        }
    }
    return pinnedCells;
}

- (NSArray *)selectedCells;
{
    // NSMatrix doesn't know about pinned cells, and thus the matrix's idea of what cells are selected doesn't necessarily include the pinned cells. Overriding -selectedCells to make sure the result includes the pinned cells.
    NSMutableArray *selectedCells = [NSMutableArray arrayWithArray:[super selectedCells]];
    NSArray *allCells = [self cells];
    int cellCount = [allCells count];
    int cellIndex;
    for (cellIndex = 0; cellIndex < cellCount; cellIndex++) {
        OITabCell *cell = [allCells objectAtIndex:cellIndex];
        if ([cell isPinned] && ([selectedCells indexOfObjectIdenticalTo:cell] == NSNotFound)) {
            [selectedCells addObject:cell];
        }
    }
    return selectedCells;
}

- (BOOL)sendAction;
{
    // If only one tab is currently selected, and the user clicked on it, deselect it (unless it's pinned or we are in single-selection mode)
    if (oldSelection && [self mode] != NSRadioModeMatrix) {
        NSArray *newSelection = [self selectedCells];

        NSMutableArray *oldUnpinnedSelection = [NSMutableArray array];
        NSMutableArray *newUnpinnedSelection = [NSMutableArray array];
        int count, i;
        count = [oldSelection count];
        for(i=0;i<count;i++) {
            OITabCell *cell = [oldSelection objectAtIndex:i];
            if (![cell isPinned])
                [oldUnpinnedSelection addObject:cell];
        }
        count = [newSelection count];
        for(i=0;i<count;i++) {
            OITabCell *cell = [newSelection objectAtIndex:i];
            if (![cell isPinned])
                [newUnpinnedSelection addObject:cell];
        }
        if ([oldUnpinnedSelection count] == 1 && [newUnpinnedSelection count] == 1) {
            if ([oldUnpinnedSelection objectAtIndex:0] == [newUnpinnedSelection objectAtIndex:0]) {
                [self deselectAllCells];
            }
        }
    } else if ([oldSelection count] > 0 && [self mode] == NSRadioModeMatrix) {
        // Even in radio mode, we were getting zero cells selected if you clicked and then dragged out of one of the tabs.
        // In any case, do some extra work to avoid empty selection whenever possible.
        if ([[self selectedCells] count] == 0) {
            [self selectCell:[oldSelection objectAtIndex:0]];
        }
    }
    return [super sendAction];
}

- (void)mouseDown:(NSEvent *)event;
{
    [self setAllowsEmptySelection:YES];
    [self setNeedsDisplay:YES];
    oldSelection = [[self selectedCells] retain];
    [[self cells] makeObjectsPerformSelector:@selector(saveState)];
    
    if ([event clickCount] == 1) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        float doubleClickTime = 0.25;
        id object = [defaults objectForKey: @"com.apple.mouse.doubleClickThreshold"];
        if (object && [object floatValue] < 0.25)
            doubleClickTime = [object floatValue];
        NSEvent *nextEvent = [[self window] nextEventMatchingMask:NSLeftMouseDownMask untilDate:[NSDate dateWithTimeIntervalSinceNow:doubleClickTime] inMode:NSEventTrackingRunLoopMode dequeue:YES];
        if (nextEvent)
            event = nextEvent;
    }
    if ([event clickCount] == 2 && [self mode] != NSRadioModeMatrix) {  // double-click pins/unpins an inspector, unless we are in single-selection mode
        NSInteger row, column;
        if ([self getRow:&row column:&column forPoint:[self convertPoint:[event locationInWindow] fromView:nil]]) {
            OITabCell *tabCell = [self cellAtRow:row column:column];
            OBASSERT(tabCell != nil);   // -getRow:column:forPoint: would return NO if the point didn't hit a cell, right?
            BOOL isPinned = ![tabCell isPinned];
            [tabCell setIsPinned:isPinned]; // The action method is responsible for checking the pinnedness of the tabs and making sure that attribute gets propagated to the inspector tab controllers as appropriate
        }
    }
    [super mouseDown:event];
    [[self cells] makeObjectsPerformSelector:@selector(clearState)];
    [self  setNeedsDisplay:YES];
    [oldSelection release];
    oldSelection = nil;
}

- (void)drawRect:(NSRect)rect;
{
    NSArray *tabCells = [self cells];
    unsigned cellCount = [tabCells count];
    
    if (highlightStyle == OITabMatrixDepressionHighlightStyle) {
        unsigned cellIndex;
        for(cellIndex=0; cellIndex<cellCount; cellIndex++) {
            if (![[tabCells objectAtIndex:cellIndex] drawState])
                continue;
            
            /* Find a contiguous span of selected cells */
            NSRect contiguousFrameRect = [self cellFrameAtRow:0 column:cellIndex];
            while (cellIndex+1 < cellCount && [[tabCells objectAtIndex:cellIndex+1] drawState]) {
                cellIndex ++;
                contiguousFrameRect = NSUnionRect(contiguousFrameRect, [self cellFrameAtRow:0 column:cellIndex]);
            }
            
            /* Draw the three-part gradient behind the selected cells */
            NSRect stretchRect = contiguousFrameRect;
            NSSize imageSize = [plasticDepression size];
            stretchRect.origin.x += depressionLeftMargin;
            stretchRect.size.width -= depressionLeftMargin + depressionRightMargin;
            float fraction = 0.7;
            [plasticDepression drawFlippedInRect:stretchRect
                                        fromRect:(NSRect){{depressionLeftMargin, 0}, {imageSize.width-depressionLeftMargin-depressionRightMargin, imageSize.height}}
                                       operation:NSCompositePlusDarker
                                        fraction:fraction];
            [plasticDepression drawFlippedInRect:(NSRect){{NSMinX(contiguousFrameRect), contiguousFrameRect.origin.y}, {depressionLeftMargin, contiguousFrameRect.size.height}}
                                        fromRect:(NSRect){{0, 0}, {depressionLeftMargin, imageSize.height}}
                                       operation:NSCompositePlusDarker
                                        fraction:fraction];
            [plasticDepression drawFlippedInRect:(NSRect){{NSMaxX(contiguousFrameRect)-depressionRightMargin, contiguousFrameRect.origin.y}, {depressionRightMargin, contiguousFrameRect.size.height}}
                                        fromRect:(NSRect){{imageSize.width-depressionRightMargin, 0}, {depressionRightMargin, imageSize.height}}
                                       operation:NSCompositePlusDarker
                                        fraction:fraction];
        }
    } else {
        // Used to be done by OITabCell; now we draw all the backgrounds first before drawing any cells, and all the foregrounds after drawing all cells
        unsigned cellIndex;
        [[NSColor colorWithCalibratedWhite:.85 alpha:1.0] set];
        for(cellIndex=0; cellIndex<cellCount; cellIndex++) {
            if ([[tabCells objectAtIndex:cellIndex] drawState]) {
                NSRectFill([self cellFrameAtRow:0 column:cellIndex]);
            }
        }
    }
    
    [super drawRect:rect];
    
    if (highlightStyle == OITabMatrixCellsHighlightStyle) {
        /* Simply draw a frame around each selected cell */
        unsigned cellIndex;
        for(cellIndex=0; cellIndex<cellCount; cellIndex++) {
            if ([[tabCells objectAtIndex:cellIndex] drawState]) {
                NSRect cellFrame = [self cellFrameAtRow:0 column:cellIndex];
                [[NSColor lightGrayColor] set];
                NSRect foo = cellFrame;
                foo.size.width = 1;
                NSFrameRect(foo);
                foo.origin.x = NSMaxX(cellFrame) - 1;
                NSFrameRect(foo);
            }
        }
    }
    
}

@end
