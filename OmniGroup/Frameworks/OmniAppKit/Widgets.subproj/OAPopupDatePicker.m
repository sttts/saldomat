// Copyright 2006-2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OAPopupDatePicker.h"

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import "NSImage-OAExtensions.h"
#import "OAWindowCascade.h"
#import "OADatePicker.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniAppKit/Widgets.subproj/OAPopupDatePicker.m 90440 2007-08-25 02:04:31Z xmas $");

@interface OAPopupDatePickerWindow : NSWindow
@end

@interface OPDatePickerButton : NSButton 
@end

@implementation OAPopupDatePicker

static NSImage *calendarImage;
static NSSize calendarImageSize;
static int defaultFirstWeekday = 0;

+ (void)initialize;
{
    OBINITIALIZE;
    calendarImage = [[NSImage imageNamed:@"smallcalendar" inBundle:OMNI_BUNDLE] retain];
    calendarImageSize = [calendarImage size];
}

+ (OAPopupDatePicker *)sharedPopupDatePicker;
{
    static OAPopupDatePicker *sharedPopupDatePicker = nil;

    if (sharedPopupDatePicker == nil)
        sharedPopupDatePicker = [[self alloc] init];
    return sharedPopupDatePicker;
}

+ (NSImage *)calendarImage;
{
    return calendarImage;
}

+ (NSButton *)newCalendarButton;
{
    NSButton *button = [[OPDatePickerButton alloc] initWithFrame:NSMakeRect(0.0f, 0.0f, calendarImageSize.width, calendarImageSize.height)];
    [button setButtonType:NSMomentaryPushInButton];
    [button setBordered:NO];
    [button setImage:calendarImage];
    [button setImagePosition:NSImageOnly];
    // [button setRefusesFirstResponder:YES];
    return button;
}

+ (void)showCalendarButton:(NSButton *)button forFrame:(NSRect)calendarRect inView:(NSView *)superview withTarget:(id)aTarget action:(SEL)anAction;
{
    [button setTarget:aTarget];
    [button setAction:anAction];
    [button setFrame:calendarRect];
    [superview addSubview:button];
}

+ (NSRect)calendarRectForFrame:(NSRect)cellFrame;
{
    float verticalEdgeGap = floor((NSHeight(cellFrame) - calendarImageSize.height) / 2.0f);
    const float horizontalEdgeGap = 2.0f;
    
    NSRect imageRect;
    imageRect.origin.x = NSMaxX(cellFrame) - calendarImageSize.width - horizontalEdgeGap;
    imageRect.origin.y = NSMinY(cellFrame) + verticalEdgeGap;
    imageRect.size = calendarImageSize;
    
    return imageRect;
}

- (id)init;
{
    if ([self initWithWindowNibName:@"OAPopupDatePicker"] == nil)
        return nil;

    [self window];
    return self;
}

- (void) dealloc {
    [_datePickerObjectValue release];
    [_boundObject release];
    [_boundObjectKeyPath release];
    [_control release];
    [_controlFormatter release];    
    [super dealloc];
}


- (void)setCalendar:(NSCalendar *)calendar;
{
    [datePicker setCalendar:calendar];
    [timePicker setCalendar:calendar];
}

- (void)startPickingDateWithTitle:(NSString *)title forControl:(NSControl *)aControl stringUpdateSelector:(SEL)stringUpdateSelector defaultDate:(NSDate *)defaultDate;
{
    NSDictionary *bindingInfo = [aControl infoForBinding:@"value"];
    NSString *bindingKeyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
    bindingKeyPath = [bindingKeyPath stringByReplacingAllOccurrencesOfString:@"selectedObjects." withString:@"selection."];
     
    [self startPickingDateWithTitle:title fromRect:[aControl visibleRect] inView:aControl bindToObject:[bindingInfo objectForKey:NSObservedObjectKey] withKeyPath:bindingKeyPath control:aControl controlFormatter:[aControl formatter] stringUpdateSelector:stringUpdateSelector defaultDate:defaultDate];
}

- (void)startPickingDateWithTitle:(NSString *)title fromRect:(NSRect)viewRect inView:(NSView *)emergeFromView bindToObject:(id)bindObject withKeyPath:(NSString *)bindingKeyPath control:(id)control controlFormatter:(NSFormatter* )controlFormatter stringUpdateSelector:(SEL)stringUpdateSelector defaultDate:(NSDate *)defaultDate;
{
    // retain the bound object and keypath
    _boundObject = [bindObject retain];
    _boundObjectKeyPath = [bindingKeyPath retain];
    
    // retain the field editor, its containg view, and optionally formatter so that we can update it as we make changes since we're not pushing values to it each time
    _control = [control retain];
    _controlFormatter = [controlFormatter retain];
    _stringUpdateSelector = stringUpdateSelector;
    
    int firstDayOfWeek = [[OFPreference preferenceForKey:@"FirstDayOfTheWeek"] integerValue];
    NSCalendar *cal = [NSCalendar currentCalendar];
    if (defaultFirstWeekday == 0)
	defaultFirstWeekday = [cal firstWeekday];
    if (firstDayOfWeek == 0) 
	firstDayOfWeek = defaultFirstWeekday;
    [cal setFirstWeekday:firstDayOfWeek];
    [datePicker setCalendar:cal];
    
    NSWindow *emergeFromWindow = [emergeFromView window];
    NSWindow *popupWindow = [self window];    
       
    // set the default date picker value to the bound value
    [_datePickerObjectValue release];
    _datePickerObjectValue = nil;
    id defaultObject = [_boundObject valueForKeyPath:_boundObjectKeyPath];
    if (defaultObject) {
	if ([defaultObject isKindOfClass:[NSDate class]])
	    _datePickerObjectValue = [defaultObject retain]; 
    }
    
    //if there is no value, use the passed in default time
    if (_datePickerObjectValue == nil) 
	_datePickerObjectValue = [defaultDate copy];
	    
    // bind the date picker to our local object value 
    [datePicker bind:NSValueBinding toObject:self withKeyPath:@"datePickerObjectValue" options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSAllowsEditingMultipleValuesSelectionBindingOption]];
    [timePicker bind:NSValueBinding toObject:self withKeyPath:@"datePickerObjectValue" options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:NSAllowsEditingMultipleValuesSelectionBindingOption]];
        
    [self setDatePickerObjectValue:_datePickerObjectValue];
    
    /* Finally, place the editor window on-screen */
    [popupWindow setTitle:title];
    
    NSRect popupWindowFrame = [popupWindow frame];
    NSRect targetWindowRect = [emergeFromView convertRect:viewRect toView:nil];
    NSPoint viewRectCenter = [emergeFromWindow convertBaseToScreen:NSMakePoint(NSMidX(targetWindowRect), NSMidY(targetWindowRect))];
    NSPoint windowOrigin = [emergeFromWindow convertBaseToScreen:NSMakePoint(NSMidX(targetWindowRect), NSMinY(targetWindowRect))];
    windowOrigin.x -= floor(NSWidth(popupWindowFrame) / 2.0);
    windowOrigin.y -= 2.0f;
    
    NSScreen *screen = [OAWindowCascade screenForPoint:viewRectCenter];
    NSRect visibleFrame = [screen visibleFrame];
    if (windowOrigin.x < visibleFrame.origin.x)
	windowOrigin.x = visibleFrame.origin.x;
    else {
	float maxX = NSMaxX(visibleFrame) - NSWidth(popupWindowFrame);
	if (windowOrigin.x > maxX)
	    windowOrigin.x = maxX;
    }
    
    if (windowOrigin.y > NSMaxY(visibleFrame))
	windowOrigin.y = NSMaxY(visibleFrame);
    else {
	float minY = NSMinY(visibleFrame) + NSHeight(popupWindowFrame);
	if (windowOrigin.y < minY)
	    windowOrigin.y = minY;
    }
    
    [popupWindow setFrameTopLeftPoint:windowOrigin];
    [popupWindow makeKeyAndOrderFront:nil];
    [[emergeFromView window] addChildWindow:popupWindow ordered:NSWindowAbove];
}

- (id)destinationObject;
{
    return [[datePicker infoForBinding:@"value"] objectForKey:NSObservedObjectKey];
}

- (NSString *)bindingKeyPath;
{
    return [[datePicker infoForBinding:@"value"] objectForKey:NSObservedKeyPathKey];
}

- (BOOL)isKey;
{
    return [[self window] isKeyWindow];
}

- (void)close;
{
    [[self window] resignKeyWindow];
}

- (NSDatePicker *)datePicker;
{
    OBASSERT(datePicker);
    return datePicker;
}

- (void)setWindow:(NSWindow *)window;
{
    NSView *contentView = [window contentView];
    NSWindow *newWindow = [[OAPopupDatePickerWindow alloc] initWithContentRect:[contentView frame] styleMask:NSBorderlessWindowMask|NSUnifiedTitleAndToolbarWindowMask backing:NSBackingStoreBuffered defer:NO];
    [newWindow setContentView:contentView];
    [newWindow setLevel:NSPopUpMenuWindowLevel];
    [newWindow setDelegate:self];
    [super setWindow:newWindow];
}

#pragma mark -
#pragma mark KVC

// Key value coding accessors for the date picker
- (id)datePickerObjectValue;
{
    return _datePickerObjectValue;
}

- (void)setDatePickerObjectValue:(id)newObjectValue;
{
    if (_datePickerObjectValue == newObjectValue)
	return;
    
    [_datePickerObjectValue release];
    _datePickerObjectValue = [newObjectValue retain];
       
    // update the field editor to display the new value
    NSString *string;
    if (_controlFormatter)
	string = [_controlFormatter stringForObjectValue:_datePickerObjectValue];
    else
	string = [_datePickerObjectValue description];
    
    [_control performSelector:_stringUpdateSelector withObject:string];
}

#pragma mark -
#pragma mark NSObject (NSWindowNotifications)

- (void)windowDidResignKey:(NSNotification *)notification;
{
    // update the object
    if (_boundObject) {
	[_boundObject setValue:_datePickerObjectValue forKeyPath:_boundObjectKeyPath];
    }
    [datePicker unbind:NSValueBinding];
    [timePicker unbind:NSValueBinding];
    
    [_boundObject release];
    _boundObject = nil;
    [_boundObjectKeyPath release];
    _boundObjectKeyPath = nil;
}

@end

@implementation OAPopupDatePickerWindow

- (void)sendEvent:(NSEvent *)theEvent;
{
    if ([theEvent type] == NSKeyDown) {
        NSString *characters = [theEvent characters];
        if ([characters length] == 1 && [characters characterAtIndex:0] == 0x0d) {
            [self resignKeyWindow];
            return;
        }
    }
        
    [super sendEvent:theEvent];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent;
{
    NSString *characters = [theEvent characters];
    if ([characters length] != 1) {
        return [super performKeyEquivalent:theEvent];
    }
    
    unichar character = [characters characterAtIndex:0];
    
    switch (character) {
        case '.':
            if ([theEvent modifierFlags] & NSCommandKeyMask) {
                [self resignKeyWindow];
                return YES;
            }
            break;
        case 0x1b:
        case 0x03:    
            [self resignKeyWindow];
            return YES;
            break;
        default:
            return [super performKeyEquivalent:theEvent];
    }
    
    return NO; // happify the compiler .... you can't get here.
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (void)resignKeyWindow;
{
    [super resignKeyWindow];
    [[self parentWindow] removeChildWindow:self];
    [self close];
}

@end

@implementation OPDatePickerButton

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent;
{
    return YES;
}

- (void)mouseDown:(NSEvent *)theEvent;
{
    [NSApp preventWindowOrdering];
    [super mouseDown:theEvent];
}

@end

