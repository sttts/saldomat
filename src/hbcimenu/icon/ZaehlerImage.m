//
//  ZaehlerImage.m
//  hbci
//
//  Created by Stefan Schimanski on 13.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "ZaehlerImage.h"

#import "Buchung.h"
#import "debug.h"


@implementation ZaehlerImage


- (id)initMitHoehe:(float)hoehe undSchrift:(NSFont *)font pos:(NSString *)pos neg:(NSString *)neg
{
	if (pos == nil && neg == nil) {
		[self autorelease];
		return nil;
	}
	
	// Groesse ermitteln
	float breite = [ZaehlerImage zaehlerBreite:pos undNegZaehler:neg font:font hoehe:hoehe];
	
	// Initialisieren mit der nun bekannten Groesse
	// halbes Pixel mehr unten und oben fuer Anti-Aliasing
	self = [super initWithSize:NSMakeSize(breite + 1, hoehe + 1)];
	
	// zeichen
	[self lockFocus];
	[ZaehlerImage drawZaehler:pos undNegZaehler:neg font:font hoehe:hoehe left:0 top:0];
	[self unlockFocus];
	
	return self;
}


- (void)zaehleBuchungen:(Konto *)konto pos:(NSString **)pos neg:(NSString **)neg
{
	int cpos = 0;
	int cneg = 0;
	
	for (Buchung * b in [konto neueBuchungen]) {
		if ([[b wert] doubleValue] < 0)
			++cneg;
		else
			++cpos;
	}
	
	*pos = (cpos > 0) ? [NSString stringWithFormat:@"%d", cpos] : nil;
	*neg = (cneg > 0) ? [NSString stringWithFormat:@"%d", cneg] : nil;
}


- (id)initMitHoehe:(float)hoehe undSchrift:(NSFont *)font fuerKonto:(Konto *)konto
{
	NSString * pos;
	NSString * neg;
	[self zaehleBuchungen:konto pos:&pos neg:&neg];	
	return [self initMitHoehe:hoehe undSchrift:font pos:pos neg:neg];
}


- (id)initMitHoehe:(float)hoehe pos:(NSString *)pos neg:(NSString *)neg
{
	// Schrift aus Hoehe ermitteln
	float fontH = hoehe / 1.2;
	NSFont * font = [NSFont fontWithName:@"Lucida Grande" size:fontH];
	font = [font screenFontWithRenderingMode:NSFontAntialiasedRenderingMode];
	
	return [self initMitHoehe:hoehe undSchrift:font pos:pos neg:neg];
}


- (id)initMitHoehe:(float)hoehe fuerKonto:(Konto *)konto
{
	NSString * pos;
	NSString * neg;
	[self zaehleBuchungen:konto pos:&pos neg:&neg];	
	return [self initMitHoehe:hoehe pos:pos neg:neg];
}


- (id)initMitPos:(NSString *)pos neg:(NSString *)neg
{
	return [self initMitHoehe:22 * 0.4 * 1.19 pos:pos neg:neg];
}


- (id)initMitKonto:(Konto *)konto
{
	NSString * pos;
	NSString * neg;
	[self zaehleBuchungen:konto pos:&pos neg:&neg];
	return [self initMitPos:pos neg:neg];
}


+ (float)zaehlerBreite:(NSString *)pos undNegZaehler:(NSString *)neg
		  font:(NSFont *)zaehlerFont hoehe:(float)zaehlerH
{
	if (pos == nil && neg == nil)
		return 0;
	
	NSMutableDictionary * zaehlerAttr = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					     zaehlerFont, NSFontAttributeName,
					     [NSColor whiteColor], NSForegroundColorAttributeName,
					     nil];
	
	// einfach gross genug, damit kein Clipping geschieht
	NSSize pseudoSize;
	pseudoSize.width = 1000;
	pseudoSize.height = zaehlerH;
	
	// Groesse des positiven Zaehlertexts
	NSRect posR;
	posR.size.width = 0;
	if (pos != nil)
		posR = [pos boundingRectWithSize:pseudoSize options:0 attributes:zaehlerAttr];
	
	// Groesse des negativen Zaehlertexts
	NSRect negR; 
	negR.size.width = 0;
	if (neg != nil)
		negR = [neg boundingRectWithSize:pseudoSize options:0 attributes:zaehlerAttr];
	
	float randW = 0.3 * zaehlerH;
	float zaehlerW = randW + posR.size.width + negR.size.width + randW;
	float zwischenraum = randW;
	
	// Zwischenraum zwischen den Zaehlern
	if (pos != nil && neg != nil)
		zaehlerW += zwischenraum;
	
	return zaehlerW;
}


+ (void)drawZaehler:(NSString *)pos undNegZaehler:(NSString *)neg
	       font:(NSFont *)zaehlerFont hoehe:(float)zaehlerH
	       left:(float)x top:(float)y
{
	if (pos == nil && neg == nil)
		return;
	
	// halbes Pixel, damit nix abgeschnitten wird durch Rundung.
	x += 0.5;
	y += 0.5;
	
	// Schrift-Attribute
	NSMutableDictionary * zaehlerAttr = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					     zaehlerFont, NSFontAttributeName,
					     [NSColor whiteColor], NSForegroundColorAttributeName,
					     nil];
	
	// einfach gross genug, damit kein Clipping geschieht
	NSSize pseudoSize;
	pseudoSize.width = 1000;
	pseudoSize.height = zaehlerH;
	
	// Groesse des positiven Zaehlertexts
	NSRect posR;
	posR.size.width = 0;
	if (pos != nil)
		posR = [pos boundingRectWithSize:pseudoSize options:0 attributes:zaehlerAttr];
	
	// Groesse des negativen Zaehlertexts
	NSRect negR; 
	negR.size.width = 0;
	if (neg != nil)
		negR = [neg boundingRectWithSize:pseudoSize options:0 attributes:zaehlerAttr];
	
	float radius = zaehlerH / 2.0;
	float randW = 0.3 * zaehlerH;
	float zaehlerW = randW + posR.size.width + negR.size.width + randW;
	float zwischenraum = randW;
	
	// Zwischenraum zwischen den Zaehlern
	if (pos != nil && neg != nil)
		zaehlerW += zwischenraum;
	
	if (pos != nil) {
		float posW = randW + posR.size.width + randW;
		NSColor * light = [NSColor colorWithDeviceRed:0.2 green:0.7 blue:0.2 alpha:1.0];
		NSColor * dark = [NSColor colorWithDeviceRed:0.04 green:0.61 blue:0.04 alpha:1.0];
		
		// Kreis/Oval rechts oben
		NSRect r;
		r.origin.x = x;
		r.origin.y = y;
		r.size.width = posW;
		r.size.height = zaehlerH;
		
		if (neg != nil) {
			[[NSGraphicsContext currentContext] saveGraphicsState];
			
			// der negative Zaehler wird auch noch gezeichnet. Wir
			// clippen in der Mitte
			NSRect clipR;
			clipR.origin.x = 0;
			clipR.origin.y = y - 1;
			clipR.size.width = x + randW + posR.size.width + zwischenraum / 2.0 + 1;
			clipR.size.height = zaehlerH + 2;
			[NSBezierPath clipRect:clipR];
			
			// Etwas breiter zeichnen, damit die Rundung
			// rechts erst nach dem Text anfaengt.
			r.size.width += zwischenraum + zaehlerH;
		}
		
		NSBezierPath * kreis = [NSBezierPath bezierPath];
		[kreis appendBezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
		[light setFill];
		[kreis fill];
		[dark set];
		[kreis stroke];
		
		// Buchungszaehler zeichnen, zentriert im Kreis/Oval
		posR.origin.x = r.origin.x + (posW - posR.size.width) / 2.0 + 1;
		posR.origin.y = y + (zaehlerH - posR.size.height) / 2.0 - 1;
		[zaehlerAttr setObject:dark forKey:NSForegroundColorAttributeName];
		[pos drawInRect:posR withAttributes:zaehlerAttr];
		posR.origin.y = y + (zaehlerH - posR.size.height) / 2.0;
		[zaehlerAttr setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		[pos drawInRect:posR withAttributes:zaehlerAttr];
		
		// Clipping wieder zuruecksetzen
		if (neg != nil) {
			[[NSGraphicsContext currentContext] restoreGraphicsState];
			x += randW + posR.size.width + zwischenraum / 2.0;
		}
	}
	if (neg != nil) {
		float negW = randW + negR.size.width + randW;
		NSColor * light = [NSColor colorWithDeviceRed:0.7 green:0.2 blue:0.2 alpha:1.0];
		NSColor * dark = [NSColor colorWithDeviceRed:0.81 green:0.08 blue:0.06 alpha:1.0];
		
		// Kreis/Oval rechts oben
		NSRect r;
		r.origin.x = x;
		r.origin.y = y;
		r.size.width = negW;
		r.size.height = zaehlerH;
		
		if (pos != nil) {
			[[NSGraphicsContext currentContext] saveGraphicsState];
			
			// der negative Zaehler wurde schon gezeichnet. Wir clippen in der Mitte
			NSRect clipR = r;
			clipR.origin.x = x;
			clipR.origin.y = y - 1;
			clipR.size.height = zaehlerH + 2;		
			clipR.size.width = 1000;
			[NSBezierPath clipRect:clipR];
			
			// Etwas breiter zeichnen, damit die Rundung
			// links vor dem Text aufhoert.
			r.size.width += zwischenraum + zaehlerH;
			r.origin.x -= zwischenraum + zaehlerH;
			
			// Zwischenraum ueberspringen
			x += zwischenraum / 2.0;
			r.origin.x += zwischenraum / 2.0;
			
			// imaginaere Rand fuer Zentrierung
			x -= randW;
			r.origin.x -= randW;
		}
		
		NSBezierPath * kreis = [NSBezierPath bezierPath];
		[kreis appendBezierPathWithRoundedRect:r xRadius:radius yRadius:radius];
		[light setFill];
		[kreis fill];
		[dark set];
		[kreis stroke];
		
		// Buchungszaehler zeichnen, zentriert im Kreis/Oval
		negR.origin.x = x + (negW - negR.size.width) / 2.0 + 1;
		negR.origin.y = y + (zaehlerH - negR.size.height) / 2.0 - 1;
		[zaehlerAttr setObject:dark forKey:NSForegroundColorAttributeName];
		[neg drawInRect:negR withAttributes:zaehlerAttr];
		negR.origin.y = y + (zaehlerH - negR.size.height) / 2.0;
		[zaehlerAttr setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
		[neg drawInRect:negR withAttributes:zaehlerAttr];
		
		// Clipping wieder zuruecksetzen
		if (pos != nil)
			[[NSGraphicsContext currentContext] restoreGraphicsState];
	}
}

@end
