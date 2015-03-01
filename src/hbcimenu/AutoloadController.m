//
//  AutoloadController.m
//  hbci
//
//  Created by Stefan Schimanski on 11.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "AutoloadController.h"

#import "UKLoginItemRegistry.h"

#import "debug.h"


@implementation AutoloadController

- (NSString *)binaryPath
{
	// Pfad unseres Binaries
	NSBundle * bundle = [NSBundle bundleForClass:[self class]];
	return [bundle bundlePath];
}


- (void)updateAutoload
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	BOOL autoload = [[defaults objectForKey:@"autoload"] boolValue];
	if (autoload) {
		NSLog(@"Installiere als StartUp");
		[UKLoginItemRegistry addLoginItemWithPath:[self binaryPath] hideIt:YES];
	} else {
		NSLog(@"Deinstalliere als StartUp");
		int idx = [UKLoginItemRegistry indexForLoginItemWithPath:[self binaryPath]];
		[UKLoginItemRegistry removeLoginItemAtIndex:idx];
	}
}


- (void)awakeFromNib
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// Autoload-Status setzen abhaengig vom wirklich Autoload-Wert
	int idx = [UKLoginItemRegistry indexForLoginItemWithPath:[self binaryPath]];
	[defaults setObject:[NSNumber numberWithBool:idx > 0] forKey:@"autoload"];
	
	// Auf GUI-Aenderungen horchen
	[defaults addObserver:self forKeyPath:@"autoload"
		options:NSKeyValueObservingOptionNew context:@"autoload"];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
			change:(NSDictionary *)change context:(void *)context
{
	[self updateAutoload];
}
	
@end
