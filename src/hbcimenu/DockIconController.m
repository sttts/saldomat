//
//  DockIconController.m
//  hbci
//
//  Created by Stefan Schimanski on 14.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "DockIconController.h"

#import "Carbon/Carbon.h"
#import "../Sparkle.framework/Headers/Sparkle.h"
#import "../Sparkle.framework/Headers/SUUpdater.h"

#import "AppController.h"
#import "debug.h"
#import "HbciToolLoader.h"


NSString * DockIconControllerDidActivateNotification = @"DockIconControllerDidActivateNotification";
NSString * DockIconControllerWillActivateNotification = @"DockIconControllerWillActivateNotification";

#ifdef DEBUG
NSString * dockId_ = @"com.limoia.Saldomat.Dock-debug";
NSString * dockIconControllerId_ = @"com.limoia.Saldomat.DockIconController-debug";
#else
NSString * dockId_ = @"com.limoia.Saldomat.Dock";
NSString * dockIconControllerId_ = @"com.limoia.Saldomat.DockIconController";
#endif

@implementation DockIconController

- (void)awakeFromNib
{
	// Benachrichtigt werden, wenn eins unserer Fenster keyWindow wird
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(windowDidBecomeKey:)
						     name:NSWindowDidBecomeKeyNotification
						   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(windowWillClose:)
						     name:NSWindowWillCloseNotification
						   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(willTerminate:) 
						     name:SUUpdaterWillRestartNotification
						   object:nil];
	
	// DO-Objekt freigeben
	NSConnection * con = [NSConnection defaultConnection];
	[con setRootObject:self];
	if ([con registerName:dockIconControllerId_] == NO)
		NSLog(@"Could not vend %@ object", dockIconControllerId_);
}


- (void)willTerminate:(NSNotification *)aNotification
{
	[DockIconController hideDockIcon:self];
}


+ (NSProxy<DockAppProtocol> *)dockApp
{
	@try {
		// mit Saldomat verbinden
		id proxy = [NSConnection rootProxyForConnectionWithRegisteredName:dockId_ host:nil];
		if (proxy == nil) {
			NSLog(@"Cannot find %@ object", dockId_);
			return nil;
		}
		
		// Verbinden hat geklappt
		[proxy setProtocolForProxy:@protocol(DockAppProtocol)];
		NSLog(@"Connected to %@", dockId_);
		return (NSProxy<DockAppProtocol> *)proxy;
	}
	@catch (NSException * e) {
		NSLog(@"Exception when connecting to %@: %@", dockId_, e);
	}
	
	return nil;
}


+ (IBAction)showDockIcon:(id)sender
{
#if 0
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	SetSystemUIMode(kUIModeNormal, 0);
	[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.dock" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:nil];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
#else
	@try {
		NSString * path = [[NSBundle bundleForClass:[self class]] bundlePath];
		NSString * hbcidockPath = [NSString stringWithFormat:@"%@/Contents/Resources/Saldomat Dock.app", path];
		[[NSWorkspace sharedWorkspace] openFile:hbcidockPath
					withApplication:nil
					  andDeactivate:NO];
	}
	@catch (NSException * e) { }
#endif
}


+ (IBAction)hideDockIcon:(id)sender
{
	NSLog(@"Trying to hide dock icon");
#if 0
	ProcessSerialNumber psn = { 0, kCurrentProcess };
	TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	SetSystemUIMode(kUIModeAllHidden, 0);
	[[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.apple.dock" options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil launchIdentifier:nil];
	[[NSApplication sharedApplication] activateIgnoringOtherApps:TRUE];
#else
	@try {
		NSProxy<DockAppProtocol> * dock = [self dockApp];
		if (dock)
			[dock terminate];
	}
	@catch (NSException * e) { }
#endif
}

	
- (void)dealloc
{
	[super dealloc];
}


+ (BOOL)isNormalVisibleWindow:(NSWindow *)w
{
	return [w isVisible] && ([w styleMask] & NSTitledWindowMask) != 0 && ![w isSheet];
}


- (void)activate
{
	NSLog(@"DockIconController activate");

	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:DockIconControllerWillActivateNotification object:self]];
	
	[NSApp activateIgnoringOtherApps:YES];
	
	// Key- und MainWindow suchen
	NSWindow * key = nil;
	NSWindow * main = nil;
	for (NSWindow * w in [NSApp windows]) {
		if ([DockIconController isNormalVisibleWindow:w]) {
			if ([w isKeyWindow]) {
				NSLog(@"key window = ", [w title]);
				key = w;
			}
			if ([w isMainWindow]) {
				NSLog(@"main window = ", [w title]);
				main = w;
			}
		}
	}
	
	if (!key)
		NSLog(@"Kein Key-Window gefunden");
	if (!main)
		NSLog(@"Kein Main-Window gefunden");
	
	// alle Fenster nach vorne bringen
	for (NSWindow * w in [NSApp windows]) {
		if ([DockIconController isNormalVisibleWindow:w]) {
			NSLog(@"orderFront of %@", [w title]);
			[w orderFront:self];
		}
	}
	
	[[NSNotificationCenter defaultCenter] postNotification:
	 [NSNotification notificationWithName:DockIconControllerDidActivateNotification object:self]];
}


- (void)hideWindows
{
	NSLog(@"hideWindows");
	for (NSWindow * w in [NSApp windows]) {
		if ([w isKindOfClass:[DockWindow class]])
			[w orderOut:self];
	}
}


- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSLog(@"windowDidBecomeKey");
	// Dock-Icon starten, wenn es nicht schon laeuft
	if ([[notification object] isKindOfClass:[DockWindow class]]
	    && ![DockIconController dockApp]) {
		NSLog(@"Showing dock icon");
		[DockIconController showDockIcon:self];
		
		// folgendes gibt leider Focusprobleme
		//[[DockIconController dockApp] activate];
		//[[notification object] makeKeyWindow];
	}
}


+ (unsigned)anzahlOffeneFenster
{
	unsigned n = 0;
	for (NSWindow * w in [NSApp windows]) {
		if ([DockIconController isNormalVisibleWindow:w]) {
			NSLog(@"%@", [w title]);
			++n;
		}
	}
	
	return n;
}


- (void)windowWillClose:(NSNotification *)notification
{
	// Verzoegert um 0.1s. Dann sollte das Fenster weg sein, und wir
	// erkennen sicher, ob es vielleicht nur ein Sheet war.
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:[DockIconController class]
				       selector:@selector(dockIconEvtlSchliessen)
				       userInfo:nil repeats:NO];	
}


+ (void)dockIconEvtlSchliessen
{
	NSLog(@"hide");
	unsigned n = [DockIconController anzahlOffeneFenster];
	if (n == 0 && [HbciToolLoader offeneHbciToolFenster] == 0 )
		[DockIconController hideDockIcon:self];
}


- (void)preferences
{
	[theAppCtrl showPreferences:self];
}


- (void)about
{
	[theAppCtrl showAbout:self];
}

@end

@implementation DockWindow : NSWindow

- (void)awakeFromNib
{
	if ([self isVisible])
		[DockIconController showDockIcon:self];
}

@end
