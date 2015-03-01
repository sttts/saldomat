//
//  KontoMenuItemController.h
//  hbci
//
//  Created by Michael on 13.05.08.
//  Copyright 2008 michaelschimanski.de. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Konto.h"
#import "RotGruenFormatter.h"

@interface KontoMenuItemViewController : NSViewController {
	IBOutlet Konto * konto_;
	IBOutlet NSImageView * zaehlerIcon_;
	IBOutlet NSTextField * tfBezeichnung_;
	IBOutlet NSTextField * tfSaldo_;
	IBOutlet NSTextField * tfSaldoBenenner_;
	IBOutlet NSImageView * dreieck_;
	IBOutlet NSImageView * focusBalken_;
	IBOutlet RotGruenFormatter * saldoFormatter_;
	IBOutlet NSNumberFormatter * saldoHighlightFormatter_;
	IBOutlet NSImageView * fehlerIcon_;
	NSMenu * menu_;
	NSColor * warnFarbe_;
}

- (id)initWithKonto:(Konto *)konto;
- (void)setBalken:(BOOL)highlight;

@property (readonly) Konto * konto;
@property (retain) NSMenu * menu;

@end
