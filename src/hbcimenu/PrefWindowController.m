//
//  PrefWindowController.m
//  hbcimenu
//
//  Created by Stefan Schimanski on 23.03.08.
//  Copyright (c) 2008 1stein.org. All rights reserved.
//

#import "PrefWindowController.h"

#import <SecurityInterface/SFAuthorizationView.h>
#import <Security/Authorization.h>
#import <QuartzCore/QuartzCore.h>

#import "AppController.h"
#import "AuthorizationController.h"
#import "debug.h"
#import "KontenPaneController.h"
#import "UpdateController.h"
#import "svnrevision.h"
#import "Version.h"
#import "urls.h"

#include <time.h>

@interface NSView(Visible)
- (void)setVisible:(BOOL)visible;
@end
@implementation NSView(Visible)
- (void)setVisible:(BOOL)visible {
	[self setHidden:!visible];
}
@end


@implementation PrefWindowController


- (void)updateProStandard
{
	BOOL std = [[theAppCtrl standardVersion] boolValue];
	BOOL pro = [[theAppCtrl proVersion] boolValue];
	BOOL demo = !std && !pro;
	
	[exportPro_ setVisible:std];
	[exportRechtesPro_ setVisible:demo];
	[exportButton_ setVisible:demo || pro];
	[exportMethode_ setVisible:demo || pro];
	[exportMethodePlacebo_ setVisible:std];
	
	[rssButton_ setVisible:demo || pro];
	
	[feedPro_ setVisible:demo || std];
	[feedPort_ setEnabled:demo || pro];
	if (std && [feedEnabled_ state] == NSOnState)
		[feedEnabled_ performClick:self];
	[feedEnabled_ setEnabled:demo || pro];
	[feedGelesen_ setEnabled:demo || pro];
}


- (id)init
{
	NSLog(@"init");
	self = [super initWithWindowNibName:@"PrefWindow"];
	return self;
}


- (BOOL)verschlossen
{
	return [[theAppCtrl authController] verschlossen];
}


- (BOOL)pseudoSchloss
{
	return [[theAppCtrl authController] pseudoSchloss];
}


- (IBAction)unlock:(id)sender
{
	[[theAppCtrl authController] unlock:sender];
}


- (IBAction)lock:(id)sender
{
	[[theAppCtrl authController] lock:sender];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
			change:(NSDictionary *)change context:(void *)context
{
	if ([(NSString *)context isEqualToString:@"verschlossen"]) {
		[self willChangeValueForKey:@"verschlossen"];
		[self didChangeValueForKey:@"verschlossen"];
		if ([self verschlossen])
			[kontenPane_ lock:self];
		else
			[kontenPane_ unlock:self];
	} else if ([(NSString *)context isEqualToString:@"pseudoSchloss"]) {
		[self willChangeValueForKey:@"pseudoSchloss"];
		[self didChangeValueForKey:@"pseudoSchloss"];
	}
}


- (void)awakeFromNib
{
	NSLog(@"awakeFromNib");
	
	// Version setzen
	[version_ setStringValue:[Version publicVersion]];
	
	// Schloesser setzen
	[allgemeinSchloss_ setAuthorization:[[theAppCtrl authController] authorization]];
	[allgemeinSchloss_ setDelegate:[theAppCtrl authController]];
	[allgemeinSchloss_ setString:"com.limoia.saldomat.unlock"]; // Wieso auskommentiert? Funktioniert so nicht, oder?
	[allgemeinSchloss_ setAutoupdate:YES];
	
	[kontenSchloss_ setAuthorization:[[theAppCtrl authController] authorization]];
	[kontenSchloss_ setDelegate:[theAppCtrl authController]];
	[kontenSchloss_ setString:"com.limoia.saldomat.unlock"];	
	[kontenSchloss_ setAutoupdate:YES];
	
	[feedSchloss_ setAuthorization:[[theAppCtrl authController] authorization]];
	[feedSchloss_ setDelegate:[theAppCtrl authController]];
	[feedSchloss_ setString:"com.limoia.saldomat.unlock"];
	[feedSchloss_ setAutoupdate:YES];

	[[theAppCtrl authController] addObserver:self forKeyPath:@"verschlossen"
					 options:NSKeyValueObservingOptionNew
					 context:@"verschlossen"];
	[[theAppCtrl authController] addObserver:self forKeyPath:@"pseudoSchloss"
					 options:NSKeyValueObservingOptionNew
					 context:@"pseudoSchloss"];
	
	// Toolbar
	toolbarItems_ = [NSArray arrayWithObjects:
			 toolbarItemAbout_,
			 toolbarItemAllgemein_,
			 toolbarItemKonten_,
			 toolbarItemSicherheit_,
			 toolbarItemFeed_,
			 toolbarItemUpdate_,
			 toolbarItemLizenz_,
			 nil];
	[toolbarItems_ retain];
	NSToolbar * toolbar = [[self window] toolbar];
	[toolbar setDelegate:self];
	[toolbar setSelectedItemIdentifier:[toolbarItemAllgemein_ itemIdentifier]];
	
	// Subviews hinzufuegen
	views_ = [NSArray arrayWithObjects:
		  aboutView_,
		  allgemeinView_,
		  kontenView_,
		  sicherheitView_,
		  feedView_,
		  updateView_,
		  nil];
	[views_ retain];
	for (NSView * v in views_)
		[mainView_ addSubview:v];
	
	// Betalogo?
	if (!VERSIONBETA)
		[betaView_ setHidden:YES];	
	
	[self updateProStandard];
	[self clickAbout:self];
	
	// Betaversionen anbieten?
/*
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults boolForKey:@"betaLadenAnzeigen"] && !VERSIONRELEASE) {
		[betaLaden_ setHidden:YES];
		[betaLadenText_ setHidden:YES];
	}
 */
	
	// Drawer einfahren
	[kontenDrawer_ close];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(errorWindowWillClose:)
						     name:NSWindowWillCloseNotification
						   object:[self window]];
}


- (void) dealloc
{
	[super dealloc];
}


- (IBAction)betaLadenClicked
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:YES forKey:@"betaLadenAnzeigen"];
}


- (void)errorWindowWillClose:(NSNotification *)notification
{
	[kontenDrawer_ close];
}


- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar;
{
	// Selektierbare NSToolbarItems
	NSMutableArray * ret = [NSMutableArray array];
	for (NSToolbarItem * item in toolbarItems_)
		[ret addObject:[item itemIdentifier]];
	return ret;
}


- (NSSize)nonContentSize {
	NSRect windowRect = [[self window] frame];
	NSRect contentRect = [[[self window] contentView] frame];
	
	float deltaWidth = NSWidth(windowRect) - NSWidth(contentRect);
	float deltaHeight = NSHeight(windowRect) - NSHeight(contentRect);
	
	return NSMakeSize(deltaWidth,deltaHeight);
}


- (float)toolbarHeight {
	NSRect contentRect = [NSWindow contentRectForFrameRect:[[self window] frame]
						     styleMask:[[self window] styleMask]];
	return NSHeight(contentRect) - NSHeight([[[self window] contentView] frame]);
}


- (float)titlebarHeight {
	return [self nonContentSize].height - [self toolbarHeight];
}


- (IBAction)startUpdate:(id)sender
{
	[[theAppCtrl updateController] updateStarten:self];
}


- (void)toolbarClicked:(NSToolbarItem *)toolbarItem fuerView:(NSView *)view
{
	for (NSView * v in views_)
		if (v != view)
			[v setHidden:YES];
	
	[[self window] setFrame:NSMakeRect([[self window] frame].origin.x,
					 [[self window] frame].origin.y + ([mainView_ frame].size.height - [view frame].size.height),
					 [view frame].size.width,
					 [view frame].size.height+([self toolbarHeight]+[self titlebarHeight]))
		      display:YES animate:YES];
	[view setFrameOrigin:NSMakePoint(0, 0)];
	[view setHidden:NO];
	
	NSToolbar * toolbar = [[self window] toolbar];
	[toolbar setSelectedItemIdentifier:[toolbarItem itemIdentifier]];
	
	if (toolbarItem != toolbarItemKonten_)
		[kontenDrawer_ close];
}


- (IBAction)clickAbout:(id)sender {
	[self toolbarClicked:toolbarItemAbout_ fuerView:aboutView_];
}


- (IBAction)clickAllgemein:(id)sender {
	[self toolbarClicked:toolbarItemAllgemein_ fuerView:allgemeinView_];
}


- (IBAction)clickKonten:(id)sender {
	[self toolbarClicked:toolbarItemKonten_ fuerView:kontenView_];
}


- (IBAction)clickSicherheit:(id)sender {
	[self toolbarClicked:toolbarItemSicherheit_ fuerView:sicherheitView_];
}


- (IBAction)clickFeed:(id)sender {
	[self toolbarClicked:toolbarItemFeed_ fuerView:feedView_];
}


- (IBAction)clickUpdate:(id)sender {
	[self toolbarClicked:toolbarItemUpdate_ fuerView:updateView_];
}


- (IBAction)neuesKonto:(id)sender
{
	[kontenPane_ neuesKonto:self];
}


- (IBAction)geheZurHomepage:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_PRODUKT_URL]];
}


- (IBAction)geheZuHBCIToolQuellen:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_HBCITOOL_QUELLEN]];
}

@end
