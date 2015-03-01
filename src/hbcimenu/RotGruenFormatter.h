//
//  RotGruenFormatter.h
//  hbci
//
//  Created by Stefan Schimanski on 20.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface RotGruenFormatter : NSNumberFormatter {
	NSColor * rot_;
	NSColor * gruen_;
}

-(void)setDunkel;
-(void)setHell;

@property (copy) NSColor * rot;
@property (copy) NSColor * gruen;

@end
