//
//  LogWindowController.m
//  hbci
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "LogWindowController.h"

#import "debug.h"


@implementation LogWindowController


- (void)awakeFromNib
{
	[logView_ setFont:[NSFont userFixedPitchFontOfSize:9.0]];
}


- (IBAction)clear:(id)sender
{
	NSRange r;
	r.location = 0;
	r.length = [[logView_ textStorage] length];
	[logView_ replaceCharactersInRange:r withString:@""];
}


- (NSData *)RFTDData
{
	// Log kopieren vom Status-Sheet
	NSRange r;
	r.location = 0;
	r.length = [[logView_ textStorage] length];
	return [logView_ RTFDFromRange:r];
}


- (NSTextView *)logView
{
	return logView_;
}

@end
