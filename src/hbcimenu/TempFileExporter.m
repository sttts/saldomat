//
//  TempFileExporter.m
//  hbci
//
//  Created by Stefan Schimanski on 04.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "TempFileExporter.h"

#include <unistd.h>


@implementation TempFileExporter

- (id) init
{
	self = [super init];
	tempDateien_ = [NSMutableArray new];
	
	// Darauf warten, dass die App terminiert, um die herumliegenden Temp-Dateien zu loeschen
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(willTerminate:) 
						     name:NSApplicationWillTerminateNotification
						   object:nil];
	
	return self;
}


- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[tempDateien_ release];
	[super dealloc];
}


- (NSString *)tempFileErstellen
{
	// temporaeren QIF-Dateinamen erzeugen
	char cfname[] = "/tmp/saldomatXXXXX.qif";
	int fd = mkstemps(cfname, 4);
	if (!fd) {
		NSLog(@"Export could not create temporary file");
		return nil;
	}
	close(fd);
	NSString * fname = [NSString stringWithUTF8String:cfname];
	NSFileManager * fm = [NSFileManager defaultManager];
	if (![fm fileExistsAtPath:fname]) {
		NSLog(@"Export filename does not exist");
		return nil;
	}
	
	// Wir geben iBank 30 Sek Zeit, die QIF zu laden. Und wir merken
	// uns die Datei fuer den appTerminates notifier.
	[tempDateien_ addObject:fname];
	[NSTimer scheduledTimerWithTimeInterval:30 target:self 
				       selector:@selector(tempDateiLoeschen:) 
				       userInfo:fname repeats:NO];
	
	return fname;
}


- (void)tempDateiLoeschen:(NSTimer *)timer
{
	// Datei loeschen
	NSString * fname = [timer userInfo];
	NSLog(@"Loesche Tempdatei vom iBank-Export: %@", fname);
	NSFileManager * fm = [NSFileManager defaultManager];
	BOOL ok = [fm removeItemAtPath:fname error:nil];
	
	// wenn nicht erfolgreich, beim Programmende zumindest nochmal probieren
	if (ok)
		[tempDateien_ removeObject:fname];
	else
		NSLog(@"Konnte %@ nicht loeschen.", fname);
}


- (void)willTerminate:(NSNotification *)notification
{
	NSFileManager * fm = [NSFileManager defaultManager];
	for (NSString * fname in tempDateien_) {
		NSLog(@"Loesche iBank-Export Tempdateien %@.", fname);
		[fm removeItemAtPath:fname error:nil];
	}
}


- (void)export:(Konto *)konto {
}

@end
