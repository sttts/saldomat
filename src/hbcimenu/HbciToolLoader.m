//
//  HbciToolLoader.m
//  hbcipref
//
//  Created by Stefan Schimanski on 06.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "HbciToolLoader.h"

#import "../Sparkle.framework/Headers/Sparkle.h"
#import "../Sparkle.framework/Headers/SUConstants.h"
#import "RegexKitLite.h"

#import "UKCrashReporter.h"
#import "AppController.h"
#import "CodeChecker.h"
#import "debug.h"
#import "DockIconController.h"


unsigned alleOffenenHbciToolFenster = 0;


@implementation HbciToolLoader

- (id)init
{
	self = [super init];
	
	delegate_ = nil;
	logViews_ = [NSMutableSet new];
	offeneFenster_ = 0;
	hbcitool_ = 0;
	hbci_ = 0;
	debugMode_ = NO;

	// vorher mal gecrasht?
	UKCrashReporterCheckForCrash(@"Saldomat hbcitool");
	
	// bei Click aufs Dock-Icon das hbcitool aktivieren
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(activate:) 
						     name:DockIconControllerDidActivateNotification
						   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(willTerminate:) 
						     name:NSApplicationWillTerminateNotification
						   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
						 selector:@selector(willTerminate:) 
						     name:SUUpdaterWillRestartNotification
						   object:nil];
	return self;
}


- (void)unload
{
	// Auf die nette Tour versuchen: hbcitool terminate aufrufen
	if (hbci_) {
		@try {
			NSLog(@"HbciToolLoader::unload: terminate");
			[hbci_ terminate];
			[hbci_ release];
		}
		@catch (NSException * e) {
			NSLog(@"Exception during HbciToolLoader::unload: %@", [e description]);
		}
	
		// max 2 Sekunden warten
		time_t start = time(0);
		while (time(0) - start < 2 && [hbcitool_ isRunning]) {
			NSLog(@".");
			[NSThread sleepForTimeInterval:0.1];
		}
		
		hbci_ = nil;
	}
		
	// Jetzt hilft nur noch Gewalt: [NSTask terminate]
	if (hbcitool_ && [hbcitool_ isRunning])
		[hbcitool_ terminate];
	[hbcitool_ release];
	hbcitool_ = nil;
	
	// Fensterzaehler zuruecksetzen
	alleOffenenHbciToolFenster -= offeneFenster_;
	offeneFenster_ = 0;
}


- (void)signaturFalschFehler
{
	NSRunCriticalAlertPanel(
				NSLocalizedString(@"Security error", nil),
				NSLocalizedString(@"Saldomat has detected a modified Saldomat bundle. This can be an attack and a serious security issue. Please get a clean copy of Saldomat and install it over the old one.", nil),
				NSLocalizedString(@"Cancel", nil),
				nil, nil, nil);
}


- (void)load
{
	[self unload];
	
	// hbcitool-Verbindung aufbauen
	@try {
		id proxy = nil;
#ifdef DEBUG
		// Erst zum Debuggen uebern Standard-MachPort zum hbcitool verbinden
		proxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"com.limoia.hbcitool" host:nil];
		debugMode_ = YES;
#endif
		if (proxy == nil) {
			debugMode_ = NO;
			
			// hbcitool starten
			hbcitool_ = [[NSTask alloc] init];
			NSBundle * bundle = [NSBundle bundleForClass:[self class]];
			NSString * path = [bundle bundlePath];
			NSString * hbcitoolBundlePath = [path stringByAppendingPathComponent:@"Contents/Resources/Saldomat hbcitool.app"];
			NSString * hbcitoolBinaryPath = [hbcitoolBundlePath stringByAppendingPathComponent:@"Contents/MacOS/Saldomat hbcitool"];
			if (![[NSFileManager defaultManager] fileExistsAtPath:hbcitoolBinaryPath])
				NSLog(@"Cannot find hbcitool at %@", hbcitoolBinaryPath);
			else if (!validBundle(hbcitoolBundlePath)) {
				// Signature vom Bundle falsch
				[self signaturFalschFehler];
				//[NSApp terminate:self];
			} else {
				NSLog(@"hbcitool Bundle ist ok");
				
				// Prozess aufsetzen
				NSLog(@"Trying to launch %@", hbcitoolBinaryPath);
				[hbcitool_ setLaunchPath:hbcitoolBinaryPath];
				[hbcitool_ setArguments:[NSArray array]];
				NSMutableDictionary * env = [NSMutableDictionary dictionaryWithDictionary:[hbcitool_ environment]];
				[env setObject:@"de_DE.UTF-8" forKey:@"LANG"];
				[hbcitool_ setEnvironment:env];
				
				// Ausgaben umleiten auf unseren Delegate
				NSPipe * outPipe = [NSPipe pipe];
				NSPipe * errPipe = [NSPipe pipe];
				NSFileHandle * outHandle = [outPipe fileHandleForReading];
				NSFileHandle * errHandle = [errPipe fileHandleForReading];
				[hbcitool_ setStandardOutput:outPipe];
				[hbcitool_ setStandardError:errPipe];
				[NSThread detachNewThreadSelector:@selector(readStdOutThread:) toTarget:self withObject:outHandle];
				[NSThread detachNewThreadSelector:@selector(readStdErrThread:) toTarget:self withObject:errHandle];
				
				// Starten des Prozesses
				[hbcitool_ launch];
				
				// CocoaBanking-Objekt bekommen. Unschoenes Polling im 1/10s Takt
				NSString * machName = [NSString stringWithFormat:@"com.limoia.hbcitool-%d-%d",
						       [[NSProcessInfo processInfo] processIdentifier],
						       [hbcitool_ processIdentifier]];
				NSLog(@"Waiting for CocoaBanking object from %@", machName);
				time_t startTime = time(0);
				while (time(0) - startTime < 5 && [hbcitool_ isRunning]) {
					proxy = [NSConnection rootProxyForConnectionWithRegisteredName:machName host:nil];
					if (proxy)
						break;
					NSLog(@".");
					[NSThread sleepForTimeInterval:0.1];
				}
				if (!proxy) {
					NSLog(@"Startup sync with hbcitool failed");
					[hbcitool_ terminate];
					[hbcitool_ release];
					hbcitool_ = nil;
				}
			}
		}
		if (proxy == nil) {
			NSLog(@"Cannot find CocoaBanking object");
			return;
		}
		
		// Verbinden hat geklappt => proxy CocoaBanking-Objekt bekommen
		[proxy setProtocolForProxy:@protocol(CocoaBankingProtocol)];
		hbci_ = [(NSProxy<CocoaBankingProtocol> *)proxy retain];
		if (hbci_ == nil || [hbci_ isValid] == NO) {
			NSLog(@"Invalid hbcitool");
			return;
		}
		
		// der Loader gibt die Log-Nachrichten aus
		[hbci_ setDelegate:self];
		
		NSLog(@"hbcitool successfully started");
	}
	@catch (NSException * e) {
		NSLog(@"Exception when connecting to hbcitool: %@", e);
	}
}


- (void)dealloc
{
	NSLog(@"Telling hbcitool to terminate");
	
	// Fensterzaehler zuruecksetzen
	alleOffenenHbciToolFenster -= offeneFenster_;
	offeneFenster_ = 0;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self 
							name:DockIconControllerDidActivateNotification
						      object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
							name:NSApplicationWillTerminateNotification
						      object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
							name:SUUpdaterWillRestartNotification
						      object:nil];

	// hbcitool-Prozess beenden
	[self unload];
	
	[hbci_ release];
	[hbcitool_ release];
	[logViews_ release];
	[super dealloc];
}


- (void)willTerminate:(NSNotification *)notification
{
	[self unload];
}


- (NSRange)log:(NSString *)s inColor:(NSColor *)color toLogView:(NSTextView *)logView
{
	// Schon zu voll?
	int len = [[logView textStorage] length];
	if (len > 1000000) {
		// ab 1 MB loeschen
		NSRange r;
		r.location = 0;
		r.length = len - 1000000;
		[logView replaceCharactersInRange:r withString:@""];
	}
	
	// Strings von Pfaden saeubern
	NSString * stringToUse = s;
	if (s) {
		NSRange ms = [s rangeOfString:@"/Users/michael/"];
		NSRange sts = [s rangeOfString:@"/Users/sts/"];
		NSRange ms_kl = [s rangeOfString:@"/users/michael/"];
		NSRange sts_kl = [s rangeOfString:@"/users/sts/"];
		if (ms.location != NSNotFound || sts.location != NSNotFound || ms_kl.location != NSNotFound || sts_kl.location != NSNotFound) {
			NSLog(@"Cleaning log");
			NSCharacterSet * cset = [NSCharacterSet characterSetWithCharactersInString:@"/"];
			NSRange foundRange = [s rangeOfCharacterFromSet:cset
								options:NSBackwardsSearch];
			if (foundRange.location != NSNotFound) {
				// Vorderen Teil abschneiden
				int loc = foundRange.location + 1;
				stringToUse = [s substringWithRange:NSMakeRange(loc, [s length] - loc)];
			}
		}
	}
	
	// Zeile einfuegen
	NSRange r;
	r.location = [[logView textStorage] length];
	r.length = 0;
	[logView replaceCharactersInRange:r withString:stringToUse];
	
	// Farbe setzen
	r.length = [[logView textStorage] length] - r.location;
	[logView setTextColor:color range:r];
	
	// nach unten scrollen
	r.location = [[logView textStorage] length];
	r.length = 0;
	[logView scrollRangeToVisible:r];
	
	return r;
}


- (NSColor *)farbeFuer:(NSString *)s mitStandardFarbe:(NSColor *)std
{
	if ([s rangeOfRegex:@"^HBCI: 9[0-9][0-9][0-9] - "].location != NSNotFound)
		return [NSColor redColor];
	else if([s rangeOfRegex:@"^HBCI: 3[0-9][0-9][0-9] - "].location != NSNotFound)
		return [NSColor orangeColor];
	else if([s rangeOfRegex:@"^HBCI: 0[0-9][0-9][0-9] - "].location != NSNotFound)
		return [NSColor colorWithDeviceRed:0.0 green:0.6 blue:0.0 alpha:1.0];
	return std;
}


- (void)logStdErr:(NSString *)s
{	
	NSArray * lines = [s componentsSeparatedByString:@"\n"];
	int i;
	for (i = 0; i < [lines count]; ++i) {
		NSString * l = [lines objectAtIndex:i];
		NSColor * color = [NSColor colorWithDeviceRed:0.2 green:0.0 blue:0.0 alpha:1.0];
		for (NSTextView * logView in logViews_) {
			if (i == [lines count] - 1)
				[self log:[NSString stringWithFormat:@"%@", l] inColor:[self farbeFuer:l mitStandardFarbe:color] toLogView:logView];
			else
				[self log:[NSString stringWithFormat:@"%@\n", l] inColor:[self farbeFuer:l mitStandardFarbe:color] toLogView:logView];
		}
	}
}


- (void)logStdOut:(NSString *)s
{
	NSArray * lines = [s componentsSeparatedByString:@"\n"];
	int i;
	for (i = 0; i < [lines count]; ++i) {
		NSString * l = [lines objectAtIndex:i];
		NSColor * color = [NSColor colorWithDeviceRed:0.0 green:0.2 blue:0.0 alpha:1.0];
		for (NSTextView * logView in logViews_) {
			if (i == [lines count] - 1)
				[self log:[NSString stringWithFormat:@"%@", l] inColor:[self farbeFuer:l mitStandardFarbe:color] toLogView:logView];
			else
				[self log:[NSString stringWithFormat:@"%@\n", l] inColor:[self farbeFuer:l mitStandardFarbe:color] toLogView:logView];
		}
	}
}


- (void)logDirect:(NSString *)s
{
	NSFontManager * fontMan = [NSFontManager sharedFontManager];
	NSString * x = [NSString stringWithFormat:@"%@\n", s]; 
	
	for (NSTextView * logView in logViews_) {
		// groessere und dickere Schrift
		NSFont * boldFont = [logView font];
		boldFont = [fontMan convertFont:boldFont
				    toHaveTrait:NSBoldFontMask];
		boldFont = [fontMan convertFont:boldFont toSize:11.0];
		boldFont = [boldFont screenFontWithRenderingMode:NSFontAntialiasedIntegerAdvancementsRenderingMode];
	
		NSRange r = [self log:x inColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:1.0 alpha:1.0] toLogView:logView];
		[logView setFont:boldFont range:r];
	}
}


- (void)log:(NSString *)str
{
	[delegate_ performSelectorOnMainThread:@selector(logStdOut:) withObject:str waitUntilDone:NO];
	
	if ([logViews_ count] > 0)
		[self performSelectorOnMainThread:@selector(logDirect:) withObject:str waitUntilDone:NO];
}


- (void)readStdOutThread:(NSFileHandle *)stdout
{
	NSAutoreleasePool * pool = [NSAutoreleasePool new];

	// Auf stdout-Ausgaben warten und an den Delegate uebergeben
	NSData * data;
	while ((data = [stdout availableData]) && [data length] != 0) {
		NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
		[delegate_ performSelectorOnMainThread:@selector(logStdOut:) withObject:str waitUntilDone:NO];
		
		if ([logViews_ count] > 0) {
			[self performSelectorOnMainThread:@selector(logStdOut:)	withObject:str waitUntilDone:NO];
		}
		
		[str release];
	}
			
	[pool release];
}


- (void)readStdErrThread:(NSFileHandle *)stderr
{
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
	
	// Auf stderr-Ausgaben warten und an den Delegate uebergeben
	NSData * data;
	while ((data = [stderr availableData]) && [data length] != 0) {
		NSString * str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		
		[delegate_ performSelectorOnMainThread:@selector(logStdErr:) withObject:str waitUntilDone:NO];
		
		if ([logViews_ count] > 0)
			[self performSelectorOnMainThread:@selector(logStdErr:) withObject:str waitUntilDone:NO];
		
		[str release];
	}
	
	[pool release];
}


+ (unsigned)offeneHbciToolFenster
{
	return alleOffenenHbciToolFenster;
}


- (void)willOpenWindow
{
	// hbcitool oeffnet ein Fenster
	offeneFenster_++;
	alleOffenenHbciToolFenster++;
	[DockIconController showDockIcon:self];
}


- (void)closedWindow
{
	// hbcitool hat Fenster geschlossen
	offeneFenster_--;
	alleOffenenHbciToolFenster--;
	[DockIconController dockIconEvtlSchliessen];
}


- (BOOL)isValid
{
	BOOL valid;
	@try {
		valid = (debugMode_ 
			 || (hbcitool_ != nil && [hbcitool_ isRunning]))
		&& hbci_ != nil 
		&& [hbci_ isValid];
	}
	@catch (NSException * e) {
		NSLog(@"Exception during HbciToolLoader::banking: %@", [e description]);
		valid = NO;
	}
	
	return valid;
}


- (NSProxy<CocoaBankingProtocol> *)banking
{	

	// hbcitool laden
	if (![self isValid])
		[self load];
	
	// erfolgreich?
	if (![self isValid]) {
		NSLog(@"load failed.");
		return nil;
	}
	
	// Code-Signature pruefen vom hbcitool
	if (debugMode_ == NO && !validPid([hbcitool_ processIdentifier])) {
		// hbcitool-Signatur ist nicht korrekt.
		[self signaturFalschFehler];
		[self unload];
		return nil;
	}
	NSLog(@"hbcitool-Signaturen ok");
	
	return hbci_;
}


- (void)setDelegate:(NSObject<HbciToolLoaderDelegate> *)delegate
{
	delegate_ = delegate;
}


- (void)addLogView:(NSTextView *)logView
{
	[logViews_ addObject:logView];
}


- (void)removeLogView:(NSTextView *)logView
{
	[logViews_ removeObject:logView];
}	

- (void)activate:(NSNotification *)notification
{
	// hbcitool_ aktivieren, also alle Fenster nach vorne holen
	if (hbcitool_ && [hbcitool_ isRunning] && offeneFenster_ > 0) {
		int pid = [hbcitool_ processIdentifier];
		NSLog(@"Activating hbcitool %d", pid);
		ProcessSerialNumber psn;
		GetProcessForPID(pid, &psn);
		SetFrontProcess(&psn);
	}
}

@end
