//
//  IconController.m
//  hbcipref
//
//  Created by Stefan Schimanski on 06.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "objc/runtime.h"

#import "IconController.h"

#import "AppController.h"
#import "AuthorizationController.h"
#import "Buchung.h"
#import "debug.h"
#import "DockIconController.h"
#import "Konto.h"
#import "Kontoauszug.h"
#import "KontoMenuViewController.h"
#import "KontoMenuItemViewController.h"
#import "MenuIconView.h"
#import "RotGruenFormatter.h"
#import "urls.h"
#import "ZaehlerImage.h"

@interface NSSearchFieldCell(SearchTimer)
@property (readonly) NSTimer * searchTimer;
@end

@implementation NSSearchFieldCell(SearchTimer)
- (NSTimer *)searchTimer {
	Ivar nameIVar = class_getInstanceVariable([NSSearchFieldCell class], "_partialStringTimer");
	return object_getIvar(self, nameIVar);
}
@end


@implementation SearchView

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];

	// oberen 4 Pixel vom Menu blau faerben
	NSView * v = [[self window] contentView];
	[v lockFocus];
	[[NSColor colorWithDeviceRed:79/255.0 green:110/255.0 blue:246/255.0 alpha:1.0] setFill];
	[NSBezierPath fillRect:NSMakeRect(0, [v frame].size.height - 5, 
					  [v frame].size.width, 5)];
	[v unlockFocus];
}

@end


@implementation SearchTextField

- (BOOL)becomeFirstResponder
{
	[(id)[self delegate] showSearchResult];	
	return [super becomeFirstResponder];
}

/*- (void)viewWillDraw
{
	for (NSView * sv in [self subviews]) {
		NSLog(@"FocusRing von SearchField-SubView wird entfernt");
		[sv setFocusRingType:NSFocusRingTypeNone];
	}
}

- (void)textDidBeginEditing:(NSNotification *)aNotification
{
	for (NSView * sv in [self subviews]) {
		NSLog(@"FocusRing von SearchField-SubView wird entfernt");
		[sv setFocusRingType:NSFocusRingTypeNone];
	}
}*/

@end



@interface MehrMenuDummyView : NSView
{
	NSView * button_;
	NSTimer * timer_;
}

- (id)init:(NSView *)button;

@end


@implementation MehrButton

- (void)mouseDown:(NSEvent *)theEvent
{
	[self setState:NSOnState];
	[self highlight:YES];
	[ctrl_ zeigeMehrMenu:self];
}

@end


@implementation MehrMenuDummyView

- (id) init:(NSView *)button
{
	self = [super init];
	button_ = [button retain];
	timer_ = nil;
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[button_ release];
	[timer_ invalidate];
	[super dealloc];
}


- (NSPoint)nebenButtonPosition
{
	NSWindow * win = [self window];
	NSRect r = [win frame];
	NSRect butR = [button_ frame];
	butR.origin = [[button_ window] convertBaseToScreen:butR.origin];
	
	// Fenster unterhalb nach rechts
	r.origin = NSMakePoint(butR.origin.x, butR.origin.y - r.size.height + 5);
	
	// passt auf Screen?
	NSScreen * screen = [win screen];
	NSRect screenR = [screen frame];
	if (screenR.origin.x + screenR.size.width < r.origin.x + r.size.width) {
		// passt nicht => nach links
		r.origin = NSMakePoint(butR.origin.x - r.size.width + butR.size.width, 
				       butR.origin.y - r.size.height + 5);
	}
	
	return r.origin;
}


- (void)positionPruefen:(NSWindow *)win
{
	// an richtiger Position?
	NSPoint ziel = [self nebenButtonPosition];
	NSPoint pos = [win frame].origin;
	//NSLog(@"windowExposed ziel=%f:%f pos=%f:%f", ziel.x, ziel.y, pos.x, pos.y);
	
	// evtl. verschieben
	if (pos.x != ziel.x || pos.y != ziel.y) {
		[win setFrameOrigin:[self nebenButtonPosition]];
	}
}


- (void)positionPruefenObserver:(NSNotification *)notification
{
	NSWindow * win = [self window];
	if ([notification object] == win)
		[self positionPruefen:win];
}


- (void)timer:(NSTimer *)timer {
	if ([self window] != nil)
		[self positionPruefen:[self window]];
	else {
		[timer_ invalidate];
		timer_ = nil;
	}
}


- (void)viewDidMoveToWindow {
	// Fenster verschieben
	NSWindow * win = [self window];
	[win setFrameOrigin:[self nebenButtonPosition]];
	
	// Fenster-Bewegung abfangen
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(positionPruefenObserver:) 
						     name:NSWindowDidBecomeKeyNotification
						   object:nil];
	if (timer_ == nil) {
		timer_ = [NSTimer scheduledTimerWithTimeInterval:0.02
						 target:self 
					       selector:@selector(timer:) 
					       userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:timer_ forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:timer_ forMode:NSEventTrackingRunLoopMode];
	}
}

@end


@implementation ToolbarView

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];
	
	// oberen 4 Pixel vom Menu blau faerben
	NSView * v = [[self window] contentView];
	[v lockFocus];
	[[NSColor colorWithDeviceRed:147/255.0 green:147/255.0 blue:147/255.0 alpha:1.0] setFill];
//	[[NSColor colorWithDeviceRed:223/255.0 green:223/255.0 blue:223/255.0 alpha:1.0] setFill];
	[NSBezierPath fillRect:NSMakeRect(0, 0, [v frame].size.width, 4)];
	[v unlockFocus];
}

@end


@implementation IconController

- (NSNumber *)gesamtSaldo
{
	double saldo = 0;
	for (Konto * k in [konten_ arrangedObjects]) {
		if ([[k saldoImMenu] boolValue])
			saldo += [[k saldo] doubleValue];
	}
	return [NSNumber numberWithDouble:saldo];
}


- (NSString *)gesamtSaldoString
{
	NSNumber * saldo = [self gesamtSaldo];
	if (saldo == nil)
		return nil;
	return [saldoImMenuFormatter_ stringFromNumber:saldo];
}


- (void)drawIcon
{
	int w = [bar_ thickness];
	int h = w;
	float x = 0;
	
	// Zaehler -> String
	NSString * pos = nil;
	NSString * neg = nil;
	if (posBuchungsZaehler_ > 0)
		pos = [NSString stringWithFormat:@"%d", posBuchungsZaehler_];
	if (negBuchungsZaehler_ > 0)
		neg = [NSString stringWithFormat:@"%d", negBuchungsZaehler_];
	
	// Zaehler erzeugen
	ZaehlerImage * zaehler = [[[ZaehlerImage alloc] initMitHoehe:h * 0.4 * 1.19 pos:pos neg:neg]
				  autorelease];
	
	// Platz schaffen fuer Zaehler
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	BOOL zeigeZaehler = [defaults boolForKey:@"showTransactionCounters"]
		&& (posBuchungsZaehler_ > 0 || negBuchungsZaehler_ > 0);
	if (zeigeZaehler)
		w = w * 3.0 / 4.0 + [zaehler size].width + 1;
	
	// Fehlericon?
	if (fehlerIconAnzeigen_) {
		// teilweise ueber dem Euro anzeigen
		x = [fehlerIcon_ size].width / 3.0;
		w += x;
	}
	
	// Schloss
	if ([[theAppCtrl authController] verschlossen]) {
		w += 2;
	}
	
	// Saldo zeichnen?
	NSString * saldo = nil;
	if ([defaults integerForKey:@"saldoInMenuFontSize"] > 0 
	    && ![[theAppCtrl authController] verschlossen])
		saldo = [self gesamtSaldoString];
	NSRect saldoBounds;
	NSFont * saldoFont;
	NSMutableDictionary * saldoAttr;
	double saldoHeight;
	if (saldo) {
		int size = [defaults integerForKey:@"saldoInMenuFontSize"];
		
		// Groesse berechnen
		saldoFont = [NSFont fontWithName:@"Lucida Grande" size:size];
		saldoHeight = [saldoFont boundingRectForGlyph:'1'].size.height;
		saldoAttr = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
			     saldoFont, NSFontAttributeName, nil];
		saldoBounds = [saldo boundingRectWithSize:NSMakeSize(1000, h) 
						  options:0 attributes:saldoAttr];

		w += saldoBounds.size.width + 5;
	}
		
	// Zeichnen starten
	NSImage * image = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
	[image lockFocus];

	// Saldo zeichnen
	if (saldo) {
		x += 5;
		[saldo drawWithRect:NSMakeRect(x, (h - saldoHeight) / 2, 
					       saldoBounds.size.width, h)
			    options:0 attributes:saldoAttr];
		x += saldoBounds.size.width;
	}
	
	// Fehlericon zeichnen
	if (fehlerIconAnzeigen_) {
		NSRect r;
		r.size.width = 16;
		r.size.height = 16;
		r.origin.x = 0;
		r.origin.y = (h - 16) / 2.0;
		[fehlerIcon_ drawInRect:r
			       fromRect:NSZeroRect
			      operation:NSCompositeSourceOver 
			       fraction:1.0];
	}	
	
	// Eurozeichen
	{
		NSString * euro = [NSString stringWithFormat:@"%C",0x20AC];
		NSFont * euroFont = [NSFont fontWithName:@"Lucida Grande" size:h * 17.0 / 22.0];
		NSMutableDictionary * euroAttr 
		= [NSMutableDictionary dictionaryWithObjectsAndKeys: euroFont, NSFontAttributeName, nil];
		if (saldoWarnungAktiv_)
			[euroAttr setValue:[NSColor colorWithDeviceRed:0.874 green:0.03 blue:0.0 alpha:1.0] forKey:NSForegroundColorAttributeName];
		NSRect euroRect = NSMakeRect(-2, 0, 11, 11);
		// die Berechnung passt nicht wirklich unten
		/*[euro boundingRectWithSize:NSMakeSize(h, h) 
						     options:NSStringDrawingDisableScreenFontSubstitution
						  attributes:euroAttr];
		
		euroRect.size.width += euroRect.origin.x;
		euroRect.size.height += euroRect.origin.y;
		euroRect.origin.x = 0;
		euroRect.origin.y = 0;
		*/
		
		// Drehen und Mittelpunkt als Ursprung setzen
		NSAffineTransform* xform = [NSAffineTransform transform];
		[xform translateXBy:x + h / 2 yBy:h / 2];
		[xform rotateByDegrees:iconAngle_]; // counterclockwise rotation
		[xform concat];
				
		// Euro zeichnen
		[euro drawWithRect:NSMakeRect((- euroRect.size.width + euroRect.origin.x) / 2, 
					      (- euroRect.size.height + euroRect.origin.y) / 2, h, h)
			   options:NSStringDrawingDisableScreenFontSubstitution
		    attributes:euroAttr];
		
		// Koordinatensystem zurueckdrehen
		[xform invert];
		[xform concat];
	}
	
	// Saldo-Warnung
#if 0 // wir verwenden ein rotes Icon stattdessen
	if (saldoWarnungAktiv_) {
		NSRect r;
		r.size.width = 16;
		r.size.height = 16;
		r.origin.x = x + (h - 16) / 2.0;
		r.origin.y = (h - 16) / 2.0 - 1;
		[saldoWarnungIcon_ drawInRect:r
				     fromRect:NSZeroRect
				    operation:NSCompositeSourceOver 
				     fraction:1.0];
	}
#endif

	// Schloss zeichnen
	if ([[theAppCtrl authController] verschlossen]) {
		NSRect r;
		r.size.width = [iconSchloss_ size].width;
		r.size.height = [iconSchloss_ size].height;
		r.origin.x = x + 13;
		r.origin.y = 2;
		[iconSchloss_ drawInRect:r
				fromRect:NSZeroRect
			       operation:NSCompositeSourceOver 
				fraction:1.0];
	}		
	
	// die Zaehler zeichnen
	if (zeigeZaehler) {
		x = [image size].width - [zaehler size].width - 2; // links, 1/3 ueber dem Euro
		float y = ([image size].height - [zaehler size].height) / 2;
		[zaehler drawAtPoint:NSMakePoint(x, y) fromRect:NSZeroRect
			   operation:NSCompositeSourceOver fraction:1.0];
	}
	
	[image unlockFocus];
	[iconView_ setImage:image];
	[image release];
}


- (NSImage *)menuKontoIconMitHoehe:(float)h pos:(int)posZaehler neg:(int)negZaehler warnSaldo:(BOOL)warn
{
	// Speziallfaelle Zaehler == 0
	if (posZaehler == 0 && negZaehler == 0) {
		if (warn)
			return saldoWarnungIcon_;
		return nil;
	}
	
	// Zaehler -> String
	NSString * pos = nil;
	NSString * neg = nil;
	if (posZaehler > 0)
		pos = [NSString stringWithFormat:@"%d", posZaehler];
	if (negZaehler > 0)
		neg = [NSString stringWithFormat:@"%d", negZaehler];
	
	// Schriftgroesse fuer den Zaehler
	// Zaehler erzeugen
	ZaehlerImage * zaehler = [[[ZaehlerImage alloc] initMitHoehe:h pos:pos neg:neg]
				  autorelease];
	int w = [zaehler size].width;
	
	// Saldo-Warnungs-Icon davor?
	if (warn)
		w += 9;
	
	// Zeichnen starten
	NSImage * image = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
	[image lockFocus];
	float x = 0;
	
	// Warn-Icon
	if (warn) {
		NSRect r;
		r.size.width = 16;
		r.size.height = 16;
		r.origin.x = -4;
		r.origin.y = (h - 16) / 2.0 - 1;
		[saldoWarnungIcon_ drawInRect:r
				     fromRect:NSZeroRect
				    operation:NSCompositeSourceOver 
				     fraction:1.0];
		x += 8;
	}
	
	// die Zaehler zeichnen
	x += 1;
	float y = ([image size].height - [zaehler size].height ) / 2 - 1;
	[zaehler drawAtPoint:NSMakePoint(x, y) fromRect:NSZeroRect
		   operation:NSCompositeSourceOver fraction:1.0];
	
	[image unlockFocus];
	[image autorelease];
	return image;
}


- (IBAction)updateIcon:(id)sender
{
	// Kontos pruefen
	posBuchungsZaehler_ = 0;
	negBuchungsZaehler_ = 0;
	fehlerIconAnzeigen_ = NO;
	saldoWarnungAktiv_ = NO;
	for (Konto * konto in [konten_ arrangedObjects]) {
		// neue Buchungen zaehlen
		for (Buchung * b in [konto neueBuchungen]) {
			if ([[b wert] doubleValue] < 0)
				negBuchungsZaehler_++;
			else
				posBuchungsZaehler_++;
		}
		
		// Fehlericon anzeigen?
		if ([theAppCtrl kontoHatteKritischenFehler:konto])
			fehlerIconAnzeigen_ = YES;
		
		// Saldo-Warnung anzeigen?
		NSNumber * limit = [konto warnSaldo];
		NSNumber * saldo = [konto saldo];
		if (limit && saldo && [saldo doubleValue] < [limit doubleValue]) 
		    saldoWarnungAktiv_ = YES;
	}

	[self drawIcon];
}


- (void)updateIconTimer:(NSTimer *)timer
{
	NSLog(@"updateIconTimer");

	updateShotTimer_ = nil;
	[self updateIcon:self];
}


- (void)animateIcon:(NSTimer *)Timer
{
	iconAngle_ = iconAngle_ + 12;
	[self drawIcon];
}


- (void)startAnimation
{
	[iconTimer_ invalidate];
	iconTimer_ = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self
		selector:@selector(animateIcon:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:iconTimer_ forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:iconTimer_ forMode:NSEventTrackingRunLoopMode];
}


- (void)stopAnimation
{
	[iconTimer_ invalidate];
	iconTimer_ = nil;
	
	iconAngle_ = 0.0;
	[self drawIcon];
}


- (void)updateMenuViewCtrls
{
	[kontoMenuViewCtrls_ removeAllObjects];
	
	for (Konto * konto in [konten_ arrangedObjects]) {
		// neue KontoMenuViewControllers bauen
		KontoMenuViewController * ctrl;
		ctrl = [[[KontoMenuViewController alloc] initWithKonto:konto] autorelease];
		[ctrl loadView];
		[kontoMenuViewCtrls_ addObject:ctrl];
	}
}


- (void)updateMenuItemViewCtrls
{
	[kontoMenuItemViewCtrls_ removeAllObjects];
	
	for (Konto * konto in [konten_ arrangedObjects]) {
		
		// neue KontoMenuViewControllers bauen
		KontoMenuItemViewController * itemCtrl;
		itemCtrl = [[[KontoMenuItemViewController alloc] initWithKonto:konto] autorelease];
		[itemCtrl loadView];
		[kontoMenuItemViewCtrls_ addObject:itemCtrl];
	}
}


- (void)observeKonten
{
	// sicherstellen, dass wir alle neueBuchungen der Konten beobachten,
	// und aenderung am warnSaldo
	for (Konto * konto in [konten_ arrangedObjects]) {
		[konto addObserver:self forKeyPath:@"neueBuchungen" options:NSKeyValueObservingOptionNew context:nil];
		[konto addObserver:self forKeyPath:@"warnSaldo" options:NSKeyValueObservingOptionNew context:nil];
		[konto addObserver:self forKeyPath:@"saldoImMenu" options:NSKeyValueObservingOptionNew context:nil];
		[konto addObserver:self forKeyPath:@"saldo" options:NSKeyValueObservingOptionNew context:nil];
	}
}

- (void)awakeFromNib
{
	NSLog(@"IconController awakeFromNib");
	
	// KontoMenuViewControllers erstellen
	kontoMenuItemViewCtrls_ = [[NSMutableArray array] retain];
	kontoMenuViewCtrls_ = [[NSMutableArray array] retain];
	[self updateMenuViewCtrls];

	// Observer erstellen, um neue Konten zu sehen
	[konten_ addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionNew context:konten_];
	[konten_ fetchWithRequest:nil merge:NO error:nil];
	[self observeKonten];

	// Observer, um Kontoauszuege mitzubekommen
	[theAppCtrl addObserver:self forKeyPath:@"laufenderKontoauszug" 
		options:NSKeyValueObservingOptionNew context:@"laufenderKontoauszug"];

	// Observer fuer Icon-Optionen in den Settings
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults addObserver:self forKeyPath:@"showTransactionCounters"
		      options:NSKeyValueObservingOptionNew context:nil];
	[defaults addObserver:self forKeyPath:@"saldoInMenuFontSize"
		      options:NSKeyValueObservingOptionNew context:nil];
	
	// Observer, um Sperrungen mitzubekommen
	[[theAppCtrl authController] addObserver:self forKeyPath:@"verschlossen" 
					 options:NSKeyValueObservingOptionNew 
					 context:[theAppCtrl authController]];	
	
	// Observer, um mitzubekommen, ob dem SearchField_ Subviews hinzugefuegt werden
	// -> Zum Entfernen der FocusRinge (erzeugte Grafikfehler)
	/*NSArray * sv = [searchField_ subviews];
	NSLog(@"COUNT: %d", [sv count]);
	[sv addObserver:self forKeyPath:@"count"
		options:NSKeyValueObservingOptionOld
		context:@"searchfield.subviews"];*/
	
	// Menue nur wieder oeffnen nach Lock-Funktion, wenn App aktiv 
	menuOffenHalten_ = NO;
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(aktiviert:) 
						     name:NSApplicationDidBecomeActiveNotification
						   object:nil];
	
	// Icon erstellen fuers Menue
	bar_ = [[NSStatusBar systemStatusBar] retain];
	statusItem_ = [[bar_ statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem_ retain];
	[statusItem_ setHighlightMode:YES];

	iconView_ = [[MenuIconView alloc] initMitStatusItem:statusItem_ undIconCtrl:self];
	[statusItem_ setView:iconView_];

	// Icon initialisieren
	iconAngle_ = 0.0;
	posBuchungsZaehler_ = 0;
	negBuchungsZaehler_ = 0;
	fehlerIconAnzeigen_ = NO;
	updateShotTimer_ = nil;
	alsNichtNeuMarkierTimer_ = nil;
	fehlerIcon_ = [[NSImage imageNamed:@"grauwarnung"] retain];
	[fehlerIcon_ setSize:NSMakeSize(16, 16)];
	saldoWarnungIcon_ = [[NSImage imageNamed:@"saldowarning"] retain];
	saldoWarnungAktiv_ = NO;
	
	iconSchloss_ = [[NSImage imageNamed:@"NSLockLockedTemplate"] copy];
	NSSize s = [iconSchloss_ size];
	[iconSchloss_ setSize:NSMakeSize(6, s.height * 6 / s.width)];
	
	// FIXME: hack, weil hier wohl die Konten noch nicht da sind und auch
	// der observer oben nicht greift:
	[NSTimer scheduledTimerWithTimeInterval:1.0 target:self 
				       selector:@selector(updateIconTimer:)
				       userInfo:nil repeats:NO];
	
	// Menues initialisieren
	[menu_ setDelegate:self];
	
	// Such-Ergebnisse sortieren
	NSSortDescriptor * nachDatum;
	NSSortDescriptor * nachDatumGeladen;
	nachDatum = [[[NSSortDescriptor alloc] initWithKey:@"datum" ascending:NO] autorelease];
	nachDatumGeladen = [[[NSSortDescriptor alloc] initWithKey:@"datumGeladen" ascending:NO] autorelease];
	[searchTable_ setSortDescriptors:[NSArray arrayWithObjects:
					  nachDatum,
					  nachDatumGeladen,
					  nil]];
	
	// Lupe verstecken
	[[searchField_ cell] setSearchButtonCell:nil];
	
	// Formatter fuer Gesamt-Saldo im Menu
	[summenFormatter_ setCurrencySymbol:@"€"];
	[summenFormatter_ setDunkel];
	
	// Hoehen merken
	origSearchSize_ = [searchView_ frame].size;
	origToolbarSize_ = [toolbarView_ frame].size;
}


- (void)dealloc {
	NSLog(@"IconController dealloc");
	[statusItem_ release];
	[iconView_ release];
	[bar_ release];
	[fehlerIcon_ release];
	[saldoWarnungIcon_ release];
	
	[kontoMenuItemViewCtrls_ release];
	[kontoMenuViewCtrls_ release];
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
			change:(NSDictionary *)change context:(void *)context
{
	NSLog(@"observeValueForKeyPath");
	if (context == konten_) {
		[self updateMenuViewCtrls];
		[self observeKonten];
	} else if ([(id)context isKindOfClass:[NSString class]] 
		   && [(id)context isEqualToString:@"laufenderKontoauszug"]) {
		if ([theAppCtrl laufenderKontoauszug])
			[self startAnimation];
		else
			[self stopAnimation];
	}
	
	// neueBuchungen wurde geaendert => Update triggern
	if (updateShotTimer_ == nil) {
		updateShotTimer_ 
		= [NSTimer scheduledTimerWithTimeInterval:0.1
						   target:self 
						 selector:@selector(updateIconTimer:)
						 userInfo:nil 
						  repeats:NO];
		[[NSRunLoop currentRunLoop] addTimer:updateShotTimer_ forMode:NSEventTrackingRunLoopMode];
	}

	if (context == @"searchfield.subviews") {
		NSLog(@"FOOOBAAARRR");
	}
	
}


- (Konto *)kontoForMenu:(NSMenu *)submenu
{
	NSArray * items = [[submenu supermenu] itemArray];
	for (NSMenuItem * item in items) {
		if ([item submenu] == submenu)
			return [item representedObject];
	}
	
	return nil;
}


- (KontoMenuViewController *)kontoMenuViewCtrlForKonto:(Konto *)konto
{
	for (KontoMenuViewController * ctrl in kontoMenuViewCtrls_) {
		if ([ctrl konto] == konto)
			return ctrl;
	}
	
	return nil;
}


- (void)fillKontoMenu:(NSMenu *)menu forKonto:(Konto *)konto
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	// KontoMenuView
	KontoMenuViewController * ctrl = [self kontoMenuViewCtrlForKonto:konto];
	if (!ctrl)
		NSLog(@"Kein KontoMenuViewController gefunden fuer Konto. Da ist was faul.");
	else {
		NSMenuItem * item = [[NSMenuItem new] autorelease];
		[ctrl zuruecksetzen:self];
		
		// FIXME: KontoMenuView im Hauptmenue einfuegen?
		if (menu == menu_) {
			[ctrl setKontoMenuViewDark:NO];
		} else {
			[ctrl setKontoMenuViewDark:YES];
		}
				
		// setze Skalierung
		switch ([[defaults objectForKey:@"FontMenuKontenView"] intValue]) {
			case 0: // klein
				[ctrl setSkalierung:0.84];
				break;
			case 1: // normal
				[ctrl setSkalierung:1.0];
				break;
			case 2: // gross
				[ctrl setSkalierung:1.2];
				break;
			default:
				break;
		}
		
		[[ctrl view] setHidden:NO];
		[item setView:[ctrl view]];
		[[[ctrl view] window] makeFirstResponder:[ctrl view]];
		[[[ctrl view] window] makeKeyWindow];
		[menu addItem:item];
		[ctrl setMenu:menu];
		
		// Menu-Aktion bei Enter: Buchung oeffnen
		[item setTarget:ctrl];
		[item setAction:@selector(buchungOeffnen:)];
	}
	
	// nach einer Zeit als gelesen markieren
	if ([[defaults objectForKey:@"gelesenMarkieren"] boolValue] == YES) {
		[alsNichtNeuMarkierTimer_ invalidate];
		float timeout = [[defaults objectForKey:@"gelesenMarkierenNach"] doubleValue];
		alsNichtNeuMarkierTimer_ = [NSTimer scheduledTimerWithTimeInterval:timeout
									    target:self
									  selector:@selector(alsNichtNeuMarkieren:) 
									  userInfo:menu 
									   repeats:NO];
		[[NSRunLoop currentRunLoop] addTimer:alsNichtNeuMarkierTimer_ forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:alsNichtNeuMarkierTimer_ forMode:NSEventTrackingRunLoopMode];
	}
}


- (void)showSearchResult
{
	NSRect resultWinFrm = [searchResultsWindow_ frame];
	NSRect searchViewFrm = [searchView_ frame];
	NSRect resultViewFrm = [searchScrollView_ frame];
	
	// rechte obere Ecke vom Ergebnis auf dem Bildschirm
	NSPoint resultViewTopRight = NSMakePoint(resultViewFrm.origin.x + resultViewFrm.size.width, 
						 resultViewFrm.origin.y + resultViewFrm.size.height);
	if ([searchScrollView_ superview])
		resultViewTopRight = [[searchScrollView_ superview] convertPoint:resultViewTopRight
									  toView:nil];
	resultViewTopRight = [searchResultsWindow_ convertBaseToScreen:resultViewTopRight];
	
	// linke obere Ecke vom Such-View auf dem Bildschirm
	NSPoint searchTopLeft = 
	NSMakePoint(searchViewFrm.origin.x,
		    searchViewFrm.origin.y + searchViewFrm.size.height);
	if ([searchView_ superview])
		searchTopLeft = [[searchView_ superview] convertPoint:searchTopLeft toView:nil];
	searchTopLeft = [[searchView_ window] convertBaseToScreen:searchTopLeft];
	searchTopLeft.y += 4; // 4 Pixel vom Menu, die blau gefaerbt werden
	
	// Ergebnis-Fenster entsprechend verschieben
	[searchResultsWindow_ setFrameOrigin:
	 NSMakePoint(resultWinFrm.origin.x - resultViewTopRight.x + searchTopLeft.x,
		     resultWinFrm.origin.y - resultViewTopRight.y + searchTopLeft.y)];
	[searchResultsWindow_ orderFront:self];
}


- (void)controlTextDidBeginEditing:(NSNotification *)aNotification {
	if ([[searchField_ stringValue] length] > 0)
		[self showSearchResult];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
	NSLog(@"controlTextDidEndEditing");
	[searchResultsWindow_ orderOut:self];
}


- (void)controlTextDidChange:(NSNotification *)aNotification
{
	// Timer fuer die Suche im Menu erlauben
	[[NSRunLoop currentRunLoop] addTimer:[[searchField_ cell] searchTimer]
				     forMode:NSEventTrackingRunLoopMode];
	
	if ([[searchField_ stringValue] length] == 0)
		[searchResultsWindow_ orderOut:self];
	else
		[searchResultsWindow_ orderFront:self];
}


- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
	// Suchfeld?
	if (control != searchField_)
		return NO;
	
	NSLog(@"selector %@", NSStringFromSelector(command));
	
	// Enter?
	if (command == @selector(insertNewline:)) {
		// Anzeigen im Kontofenster
		int sel = [searchBuchungen_ selectionIndex];
		if (sel != NSNotFound) {
			[menu_ cancelTracking];
			[theAppCtrl zeigeBuchungsFensterMitBuchung:
			 [[searchBuchungen_ arrangedObjects] objectAtIndex:sel]];
		}
		return YES;
	}
	
	// Pfeil runter?
	if (command == @selector(moveDown:)) {
		// Selektierung runter bewegen
		NSLog(@"runter");
		int count = [[searchBuchungen_ arrangedObjects] count];
		if (count) {
			int sel = [searchBuchungen_ selectionIndex];
			if (sel == NSNotFound || sel == count - 1)
				[searchBuchungen_ setSelectionIndex:0];
			else
				[searchBuchungen_ setSelectionIndex:sel + 1];
			[searchTable_ scrollRowToVisible:[searchBuchungen_ selectionIndex]];
		}
		return YES;
	}
	
	// Pfeil hoch?
	if (command == @selector(moveUp:)) {
		// Selektierung hoch bewegen
		NSLog(@"hoch");
		int count = [[searchBuchungen_ arrangedObjects] count];
		if (count) {
			int sel = [searchBuchungen_ selectionIndex];
			if (sel == NSNotFound || sel == 0)
				[searchBuchungen_ setSelectionIndex:count - 1];
			else
				[searchBuchungen_ setSelectionIndex:sel - 1];
			[searchTable_ scrollRowToVisible:[searchBuchungen_ selectionIndex]];
		}
		return YES;
	}

	return NO;
}


- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {
	Buchung * b = [[searchBuchungen_ arrangedObjects] objectAtIndex:rowIndex];
	
	if ([[aTableColumn identifier] isEqualToString:@"zweck"])
		return [b andererNameUndZweck];
	
	return nil;
}



- (IBAction)oeffneMenu:(id)sender
{
	NSLog(@"linksClick");
	[iconView_ setHighlighted:YES];
	[statusItem_ popUpStatusItemMenu:menu_];
}

- (void)aktiviert:(NSNotification *)aNotification
{
	if (!menuOffenHalten_)
		return;
	menuOffenHalten_ = NO;
	NSLog(@"applicationDidBecomeActive");
	
	// Menue oeffnen
	[self oeffneMenu:self];
}

- (void)openMenuByTimer:(NSTimer*)theTimer {
	//[self oeffneMenu:theTimer];
	
	[iconView_ setHighlighted:YES];
	
	// sind wir im Vordergrund?
	if ([NSApp isActive]) {
		// Fenster nach vorne bringen
		[[theAppCtrl dockIconController] activate];
		[self oeffneMenu:self];
	} else {
		// aktivieren und auf Notification warten
		menuOffenHalten_ = YES;
		[[theAppCtrl dockIconController] activate];
	}
}



- (void)menuWillOpen:(NSMenu *)menu
{	
	NSLog(@"menuWillOpen");
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[menu setDelegate:self];
	
	// Schlossen offen halten
	[[theAppCtrl authController] offenHalten];
	
	// Welches Menue?
	if (menu == menu_) {
		while ([[menu_ itemArray] count] > 0)
			[menu_ removeItemAtIndex:0];

		// Wie viele Konten sind sichtbar?
		NSArray * konten = [konten_ arrangedObjects];
		int n = [konten count];
		for (Konto * konto in konten) {
			if ([konto versteckt])
				--n;
		}
		BOOL zeigeViewDirektImMenu = NO;
		if (n == 1 && [[defaults objectForKey:@"alwaysShowSubmenuForAccounts"] boolValue] == NO)
			zeigeViewDirektImMenu = YES;
		
		// Hoehen anpassen
		[searchView_ setFrameSize:origSearchSize_];
		[toolbarView_ setFrameSize:origToolbarSize_];
		if (zeigeViewDirektImMenu || n == 0) {
			[searchView_ setFrameSize:NSMakeSize(origSearchSize_.width, 27)];
			if (n == 1)
				[toolbarView_ setFrameSize:NSMakeSize(origToolbarSize_.width, origToolbarSize_.height - 6)];
		}

		// Details-Filter-Button ist nur an fuer n = 1, sonst MenuItem
		//[detailsFilterButton_ setHidden:YES];
		
		// neue Kontomenues erstellen
		if (n == 0) {
			NSMenuItem * item = [[NSMenuItem new] autorelease];
			[item setTitle:NSLocalizedString(@"Enter your bank account...", nil)];
			[item setTarget:theAppCtrl];
			[item setAction:@selector(showKontoPreferences:)];
			[menu addItem:item];
		} else if ([[theAppCtrl authController] verschlossen]) {
			NSMenuItem * item = [[NSMenuItem new] autorelease];
			[item setView:schlossView_];
			[schlossView_ setHidden:NO];
			[menu addItem:item];
		} else {
			NSMenuItem * item;
			
			// Suchzeile
			item = [[NSMenuItem new] autorelease];
			[searchView_ setHidden:NO];
			[item setView:searchView_];
			[menu addItem:item];
					
			if (zeigeViewDirektImMenu) {
				[self fillKontoMenu:menu forKonto:[konten objectAtIndex:0]];
				//[detailsFilterButton_ setHidden:NO];
			} else {
				// "Alle Transaktionen holen"
				/*
				item = [[NSMenuItem new] autorelease];
				[item setTitle:NSLocalizedString(@"Synchronize all banks", nil)];
				[item setImage:[NSImage imageNamed:@"NSRefreshTemplate"]];
				[item setTarget:theAppCtrl];
				[item setAction:@selector(holeAlleKontoauszuege:)];
				[menu addItem:item];
				 
				// Saldo anzeigen?
				NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
				NSNumber * saldo = [self gesamtSaldo];
				if ([defaults integerForKey:@"saldoInMenuFontSize"] == 0 && saldo) {
					//item = [[NSMenuItem new] autorelease];
					//[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Saldo %@", nil), saldo]];
					//[item setTarget:self];
					//[item setAction:@selector(saldoClicked:)];
					//[menu insertItem:item atIndex:idx++];
					
					item = [[NSMenuItem new] autorelease];
					[item setView:summenView_];
					[summenView_ setHidden:NO];
					[menu addItem:item];
				}
				
				[menu addItem:[NSMenuItem separatorItem]];
				*/
				
				// Gesamt-Saldo setzen
				[summenWert_ setObjectValue:[self gesamtSaldo]];
				
				// Banken eintragen mit Transaktionsuntermenues
				int idZaehler = 1;
				[kontoMenuItemViewCtrls_ removeAllObjects];
				
				for (Konto * konto in konten) {
					if ([konto versteckt])
						continue;
					
					// z.B. "Stadtsparkasse" ins Hauptmenue
					item = [[NSMenuItem new] autorelease];
					NSSet * neueBuchungen = [konto neueBuchungen];
					
					// FIXME: neue KontoMenuItemViews in das Menue bauen...
					KontoMenuItemViewController * itemCtrl;
					itemCtrl = [[[KontoMenuItemViewController alloc] initWithKonto:konto] autorelease];
					[item setView:[itemCtrl view]];
					[kontoMenuItemViewCtrls_ addObject:itemCtrl];
					
					// Id setzen zur Wiedererkennung
					[[[[item view] subviews] objectAtIndex:0] setTag:idZaehler];
					idZaehler++;
					
					int posZaehler = 0;
					int negZaehler = 0;
					if ([neueBuchungen count] > 0) {
						// negative und positive Buchungen zaehlen
						for (Buchung * b in [konto neueBuchungen]) {
							if ([[b wert] doubleValue] < 0)
								negZaehler++;
							else
								posZaehler++;
						}
					}
					
					// Fehler-Icon
					if ([theAppCtrl kontoHatteKritischenFehler:konto])
						[item setImage:fehlerIcon_];
					[menu_ addItem:item];
					
					// Untermenue fuer die Buchungen
					NSMenu * submenu = [[NSMenu new] autorelease];
					[submenu setDelegate:self];
					[menu_ setSubmenu:submenu forItem:item];
					[item setRepresentedObject:konto];
				}
				
				// Buchungsdetails und Filter			
				/*[menu addItem:[NSMenuItem separatorItem]];
				[item = [[NSMenuItem new] autorelease];
				[item setTitle:NSLocalizedString(@"Details and filters", nil)];
				[item setTarget:theAppCtrl];
				[item setAction:@selector(kontoFensterAnzeigen:)];
				[menu addItem:item];*/
			}			
		}
		
		// Toolbar
		NSMenuItem * item = [[NSMenuItem new] autorelease];
		[item setView:toolbarView_];
		[toolbarView_ setHidden:NO];
		[menu addItem:item];
		
		return;
	}
	
	// Toolbar-Mehr-Menu?
	if (menu == mehrMenu_) {
		NSLog(@"Mehr-Menu");
		return;
	}
	
	// eins der Transaktionsmenues?
	Konto * konto = [self kontoForMenu:menu];
	if (konto == nil) {
		NSLog(@"Unknown menu %d", menu);
		return;
	}
	
	// Such-Ergebnis verstecken
	[searchResultsWindow_ orderOut:self];
	
	// alte Eintraege loeschen
	while ([menu numberOfItems] > 0)
		[menu removeItemAtIndex:0];
	
	// neue erstellen
	[self fillKontoMenu:menu forKonto:konto];
}


- (IBAction)saldoClicked:(id)sender
{
	// nichts machen. Nur dazu da, damit das Item nicht disabled ist.
}


- (void)alsNichtNeuMarkieren:(NSTimer*)theTimer
{
	NSLog(@"alsNichtNeuMarkieren:");
	alsNichtNeuMarkierTimer_ = nil;
	
	NSMenu * menu = [theTimer userInfo];
	Konto * konto = [self kontoForMenu:menu];
	if (!konto)
		return;
	
	// neueBuchungen als nicht-neu markieren
	NSMutableSet * neueBuchungen = [konto mutableSetValueForKey:@"neueBuchungen"];
	[neueBuchungen removeAllObjects];
	
	// Zaehler im Hauptmenu zurueck setzen
	NSMenu * mainMenu = [menu supermenu];
	NSArray * items = [mainMenu itemArray];
	for (NSMenuItem * item in items) {
		if ([item menu] == menu) {
			[item setImage:nil];
			break;
		}
	}
}


- (void)removeMehrMenu:(NSTimer *)timer
{
	// Mehr-Menu deaktivieren
	NSLog(@"deaktiviere Mehrmenu");
	NSMenuItem * item = [menu_ itemAtIndex:[[menu_ itemArray] count] - 1];
	[item setSubmenu:nil];
	[menu_ itemChanged:item];
}


- (void)menuDidClose:(NSMenu *)menu
{
	NSLog(@"menuDidClose");
	
	if (menu == menu_) {
		// StatusItem neuzeichnen, um das Blau zu entfernen
		[iconView_ setHighlighted:NO];
		
		// Suche verstecken
		[searchResultsWindow_ orderOut:self];
	}
	
	if (menu == mehrMenu_) {
		// Untermenue zeitversetzt entfernen. Direkt hier verhindert
		// bei Snow Leopard, dass die Menueintraege Effekt zeigen.
		NSTimer * timer;
		timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self 
						       selector:@selector(removeMehrMenu:)
						       userInfo:nil repeats:NO];
		[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
		[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSEventTrackingRunLoopMode];
		
		// Dummy-View entfernen
		if ([[mehrMenu_ itemAtIndex:[[mehrMenu_ itemArray] count] - 1] view] != nil)
			[mehrMenu_ removeItemAtIndex:[[mehrMenu_ itemArray] count] - 1];
		
		// Button auf aus
		[mehrButton_ setState:NSOffState];
		[mehrButton_ highlight:NO];
	}
	
	// Views entfernen aus dem Menue. Kann sonst komische Effekte geben
	for (NSMenuItem * item in [menu itemArray]) {
		NSView * view = [item view];
		if (view) {
			[item setView:nil];
			[view setHidden:YES];
		}
	}
}


- (void)menu:(NSMenu *)menu willHighlightItem:(NSMenuItem *)item {
	if (menu != menu_)
		return;
	
	// fuer alle MenuItemViews evtl. Highlights entfernen
	for (KontoMenuItemViewController * c in kontoMenuItemViewCtrls_) {
		// Highlights aufheben
		[c setBalken:NO];
	}
	
	int i;
	if ([item view]) {
		// Alle MenuItemViews mit aktuellen View vergleichen und ggf. Highlight setzen
		for (i = 0; i < [kontoMenuItemViewCtrls_ count]; ++i) {
			// FIXME: Tag des ersten Subviews dient als Identifizierung
			if ([[[[item view] subviews] objectAtIndex:0] tag] == i+1) {
				[[kontoMenuItemViewCtrls_ objectAtIndex:i] setBalken:YES];
			}
		}
	}
	[[item view] setNeedsDisplay:YES];
}


- (IBAction)geheZurOnlineHilfe:(id)sender
{
	[menu_ cancelTracking];
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:LIMOIA_HILFE_URL]];
}


- (IBAction)zeigePref:(id)sender
{
	[menu_ cancelTracking];
	[theAppCtrl showPreferences:sender];
}


- (IBAction)zeigeDebug:(id)sender
{
	[menu_ cancelTracking];
	[theAppCtrl zeigeDebugWindow:sender];
}


- (IBAction)holeKontoauszuege:(id)sender
{
	[menu_ cancelTracking];
	[theAppCtrl holeAlleKontoauszuege:sender];
}


- (IBAction)zeigeMehrMenu:(id)sender
{
	NSLog(@"zeigeMehrMenu");
	
	// Dummy-View in MehrMenu, um spaeter ans Fenster davon zu kommen
	if ([[mehrMenu_ itemAtIndex:[[mehrMenu_ itemArray] count] - 1] view] == nil) {
		NSMenuItem * item = [[NSMenuItem new] autorelease];
		NSView * view = [[[MehrMenuDummyView alloc] init:mehrButton_] autorelease];
		
		[view setFrameSize:NSMakeSize(1,1)];
		[item setView:view];
		[mehrMenu_ addItem:item];
	}
	
	// MehrMenu als Untermenu setzen
	int i = [[menu_ itemArray] count] - 1;
	NSMenuItem * item = [menu_ itemAtIndex:i];
	[item setSubmenu:mehrMenu_];
	[item setEnabled:YES];
	[menu_ itemChanged:item];
	
	// Maus virtuell rausschieben und wieder ins toolbarView_ schieben
	NSPoint pos = [toolbarView_ convertPointToBase:NSMakePoint(10, 10)]; //[[toolbarView_ window] convertBaseToScreen:];
	NSLog(@"mouse move %f:%f", pos.x, pos.y);
	NSEvent * ev =[NSEvent mouseEventWithType:NSMouseMoved
					       location:NSMakePoint(pos.x, pos.y - [toolbarView_ frame].size.height)
					  modifierFlags:0
					      timestamp:0
					   windowNumber:[[toolbarView_ window] windowNumber]
						context:nil
					    eventNumber:0 
					     clickCount:0
					       pressure:0.0];
	[NSApp postEvent:ev atStart:NO];
	ev =[NSEvent mouseEventWithType:NSMouseMoved
			       location:NSMakePoint(pos.x, pos.y)
			  modifierFlags:0
			      timestamp:0
			   windowNumber:[[toolbarView_ window] windowNumber]
				context:nil
			    eventNumber:0 
			     clickCount:0
			       pressure:0.0];
	[NSApp postEvent:ev atStart:NO];
}


- (IBAction)zeigeKontenUndFilter:(id)sender
{
	[menu_ cancelTracking];
	[theAppCtrl zeigeBuchungsFensterMitKonto:nil];
}


- (IBAction)lock:(id)sender
{
	[menu_ cancelTracking];

	// sperren
	[[theAppCtrl authController] lock:self];
		
	// Menue wieder oeffnen
	[NSTimer scheduledTimerWithTimeInterval:0.2 target:self 
				       selector:@selector(openMenuByTimer:)
				       userInfo:nil repeats:NO];
}


- (IBAction)unlock:(id)sender
{
	[menu_ cancelTracking];
	
	// aufschliessen
	[[theAppCtrl authController] unlock:self];
	
	// Menue wieder oeffnen
	[NSTimer scheduledTimerWithTimeInterval:0.2 target:self 
				       selector:@selector(openMenuByTimer:)
				       userInfo:nil repeats:NO];
}


@synthesize iconView = iconView_;

@end
