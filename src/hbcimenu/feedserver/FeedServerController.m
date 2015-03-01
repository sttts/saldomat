//
//  FeedServerController.m
//  hbci
//
//  Created by Stefan Schimanski on 10.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "FeedServerController.h"

#import "AppController.h"
#import "Buchung.h"
#import "debug.h"
#import "Konto.h"
#import "HTTPServer.h"
#import "TCPServer.h"
#import "urls.h"


@interface HTTPServer (ConvenientMethods)
- (void)sendGetData:(NSData *)data withHeader:(NSDictionary *)headers toRequest:(HTTPServerRequest *)mess;
- (void)sendGetData:(NSData *)data withHeader:(NSDictionary *)headers toRequest:(HTTPServerRequest *)mess
   withResponseCode:(int)responseCode;
@end

@implementation HTTPServer (ConvenientMethods)
- (void)sendGetData:(NSData *)data withHeader:(NSDictionary *)headers toRequest:(HTTPServerRequest *)mess
{
	[self sendGetData:data withHeader:headers toRequest:mess withResponseCode:200];
}

- (void)sendGetData:(NSData *)data withHeader:(NSDictionary *)headers toRequest:(HTTPServerRequest *)mess
   withResponseCode:(int)responseCode
{
	NSLog(@"Sending data of length %d with headers: %@", [data length], headers);
        CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, responseCode, NULL, kCFHTTPVersion1_1); // OK
        CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)@"Content-Length", (CFStringRef)[NSString stringWithFormat:@"%d", [data length]]);
	for (NSString * header in headers)
		CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)header, (CFStringRef)[headers objectForKey:header]);
        CFHTTPMessageSetBody(response, (CFDataRef)data);
        [mess setResponse:response];
        CFRelease(response);
}
@end



@implementation FeedServerController

+ (void)initialize
{
	[FeedServerController setKeys:[NSArray arrayWithObject:@"server"] triggerChangeNotificationsForDependentKey:@"running"];
	[FeedServerController setKeys:[NSArray arrayWithObject:@"server"] triggerChangeNotificationsForDependentKey:@"baseUrl"];
	[super initialize];
}


- (void)setServer:(HTTPServer *)server
{
	[self willChangeValueForKey:@"server"];
	[server retain];
	[server_ stop];
	[server_ release];
	server_ = server;
	
	// baseUrl setzen
	if (server_) {
		[baseUrl_ release];
		baseUrl_ = [[NSString stringWithFormat:LIMOIA_FEED_URL, [server port]] retain];
	} else {
		[baseUrl_ release];
		baseUrl_ = nil;
	}
	
	[self didChangeValueForKey:@"server"];
}


- (void)updateServer
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// durch das Setzen eines neuen Port gibs ne Rekursion. Darum das:
	static BOOL locked = NO;
	if (locked)
		return;

	// Server beenden
	if (server_ != nil) {
		NSLog(@"Beende FeedServer");
		[self setServer:nil];
	}
	
	// Server starten?
	if ([[defaults objectForKey:@"startFeedServer"] boolValue]
		&& ![[theAppCtrl standardVersion] boolValue]) {
		NSLog(@"Versuche FeedServer zu starten");
		
		HTTPServer * server = [HTTPServer new];
		[server setType:@"_http._tcp."];
		[server setName:@"Saldomat"];
		[server setDelegate:self];		
		
		// Server-Port ermitteln
		NSNumber * port = [defaults objectForKey:@"feedServerPort"];
		if (port == nil) {
			NSLog(@"Noch kein Port fuer FeedServer gesetzt");
			
			// noch kein Port gesetzt. Zufaelligen Port suchen > 1024
			int versuche = 100;
			while (port == nil && versuche > 0) {
				int randomPort = 1024 + (rand() % (65535 - 1024));
				NSLog(@"Probiere Port %d", randomPort);
				
				// versuchen, Server zu starten
				[server setPort:randomPort];
				NSError * error = nil;
				if ([server start:&error]) {
					port = [NSNumber numberWithInt:randomPort];
					locked = YES;
					[defaults setObject:port forKey:@"feedServerPort"];
					locked = NO;
					
					NSLog(@"Server laeuft mit Port %d", randomPort);
					[self setServer:server];
				} else
					NSLog(@"Start failed: ", [error description]);
				
				// damit keine Endlosschleife auftritt
				versuche++;
			}
			
			// Zu viele Versuche?
			if (port == nil)
				NSLog(@"Kein Server-Port gefunden, der funktioniert");
		} else {
			[server setPort:[port intValue]];
			NSError * error = nil;
			if ([server start:&error]) {
				NSLog(@"Server laeuft mit Port %d", [port intValue]);
				[self setServer:server];
			} else
				NSLog(@"Serverfehler: %@", [error description]);
		}
		
		[server release];
		
		// Fehler?
		if (port && server_ == nil) {
			NSRunAlertPanel(NSLocalizedString(@"Feed Server Error", nil),
					NSLocalizedString(@"Saldomat could not start the RSS feed server on port %d. You can change the used port in the preferences.", nil),
					NSLocalizedString(@"Ok", nil),
					nil,
					nil,
					[port intValue]);
		}
	}
}


- (id) init
{
	self = [super init];
	server_ = nil;
	baseUrl_ = nil;
	return self;
}


- (void)awakeFromNib 
{	
	NSLog(@"FeedServerController");
	
	// Auf Aenderungen durch die Benutzer-Einstellungen reagieren
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults addObserver:self forKeyPath:@"feedServerPort"
		      options:NSKeyValueObservingOptionNew context:@"feedServerPort"];
	[defaults addObserver:self forKeyPath:@"startFeedServer"
		      options:NSKeyValueObservingOptionNew context:@"startFeedServer"];
	
	// Server starten	
	[self updateServer];
}


- (void) dealloc
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	[defaults removeObserver:self forKeyPath:@"feedServerPort"];
	[defaults removeObserver:self forKeyPath:@"startFeedServer"];

	
	[server_ release];
	[baseUrl_ release];
	[super dealloc];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
			change:(NSDictionary *)change context:(void *)context
{
	NSLog(@"FeedServerController observeValueForKeyPath");
	[self updateServer];
}


- (NSString *)xmlEscape:(NSString *)s
{
	if (!s)
		return @"";
	return (NSString *)CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (CFStringRef)s, NULL );
}


- (NSString *)rfc3339Date:(NSDate *)date
{
	NSLocale * usLocale = [[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease];
	return [date descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%S%z" timeZone:nil locale:usLocale];
}


- (void)kontoFeedSenden:(Konto *)k fuerNachricht:(HTTPServerRequest *)mess
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// Unterkonto bzw. Kennung
	NSString * kontonummer = [[[k unterkonto] konto] bezeichnung];
	if (kontonummer)
		kontonummer = [k kennung];
	
	// Header und Footer
	NSString * title = [NSString stringWithFormat:NSLocalizedString(@"Saldomat '%@'", nil), [k bezeichnung]];
	NSString * subtitle = [NSString stringWithFormat:NSLocalizedString(@"Transaction of Saldomat account '%@'", nil),
			       [k bezeichnung]];
	NSString * header = [NSString stringWithFormat:
			     @"<?xml version=\"1.0\" encoding=\"utf-8\"?>"
			     "<feed xmlns=\"http://www.w3.org/2005/Atom\">"
			     "<title>%@</title>"
			     "<updated>%@</updated>"
			     "<link>%@</link>"
			     "<id>%@</id>"
			     "<subtitle>%@</subtitle>"
			     "<icon>/icon.png</icon>",
			     [self xmlEscape:title],
			     [self rfc3339Date:[NSDate date]],
			     LIMOIA_PRODUKT_URL,
			     [k feedGeheimnis],
			     [self xmlEscape:subtitle]];
	NSString * footer = @"</feed>";
	
	// Buchungen der letzten 30 Tage
	NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
	NSEntityDescription * buchungEntity = [NSEntityDescription entityForName:@"Buchung" inManagedObjectContext:ctx];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(konto == %@) AND (datum > %@)",
				  k,
				  [NSDate dateWithTimeIntervalSinceNow:- 30*24*3600]];
	NSFetchRequest * fetch = [[[NSFetchRequest alloc] init] autorelease];
	fetch.entity = buchungEntity;
	fetch.predicate = predicate;
	NSSortDescriptor * nachDatum = [[[NSSortDescriptor alloc] initWithKey:@"datum" ascending:NO] autorelease];
	NSSortDescriptor * nachDatumGeladen = [[[NSSortDescriptor alloc] initWithKey:@"datumGeladen" ascending:NO] autorelease];
	[fetch setSortDescriptors:[NSArray arrayWithObjects:
				   nachDatum,
				   nachDatumGeladen,
				   nil]];
	
	// Buchungen bekommen, die b entsprechen
	NSArray * buchungen = [ctx executeFetchRequest:fetch error:nil];
	NSString * items = @"";
	BOOL gelesenMarkieren = [[defaults objectForKey:@"feedLadenVerhalten"] intValue] == 1; // tag 1
	for (Buchung * b in buchungen) {
		NSString * wert = [wertFormatter_ stringFromNumber:[b wert]];
		
		// Titel
		NSString * absenderZweck = [b andererNameUndZweck];
		NSString * titel = [NSString stringWithFormat:@"%@ - %@", wert, absenderZweck];
		
		// Feed-Template laden und alles zwischen <body>...</body> ausgeben
		NSString * feedTemplate = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"feed-template" ofType:@"html"]
								    encoding:NSUTF8StringEncoding
								       error:nil];
		NSRange bodyIn;
		NSRange bodyOut;
		bodyIn = [feedTemplate rangeOfString:@"<body>"];
		bodyOut = [feedTemplate rangeOfString:@"</body>"];
		NSRange inner;
		inner.location = bodyIn.location + bodyIn.length;
		inner.length = bodyOut.location - inner.location;
		feedTemplate = [feedTemplate substringWithRange:inner];
		
		BOOL positiv = [[b wert] doubleValue] > 0;
		NSString * xmlWert = [self xmlEscape:[wertFormatter_ stringFromNumber:[b wert]]];
		NSString * text = [NSString stringWithFormat:
				   feedTemplate,
			    positiv ? [NSString stringWithFormat:@"<span style=\"color: #008000\">%@</span>", xmlWert]
				    : [NSString stringWithFormat:@"<span style=\"color: #800000\">%@</span>", xmlWert],
			    [self xmlEscape:[b waehrung]],
			    [self xmlEscape:[dateFormatter_ stringFromDate:[b datum]]],
			    [self xmlEscape:[b effektiverZweck]],
			    [self xmlEscape:positiv ? NSLocalizedString(@"Von", nil)
						     : NSLocalizedString(@"Nach", nil)],
			    [self xmlEscape:[b effektiverAndererName]],
			    [self xmlEscape:[b effektivesAnderesKonto]],
			    [self xmlEscape:[b effektiveAndereBank]],
			    [NSString stringWithFormat:@"%@/%@/%@.png", baseUrl_, [k feedGeheimnis], [b guid]]];
		
		// Item erstellen
		items = [items stringByAppendingString:[NSString stringWithFormat:
			@"<entry>"
			"<title>%@</title>"
			"<id>%@</id>"
			"<updated>%@</updated>"
			"<content type=\"html\"><![CDATA[%@]]></content>"
			"</entry>",
			[self xmlEscape:titel],
			[b guid],
			[self rfc3339Date:[b datum]],
			text]];
		
		// gelesen markieren, wenn so gewaehlt in den Prefs
		if (gelesenMarkieren)
			[b setNeu:[NSNumber numberWithBool:NO]];
	}

	// Feed senden
	NSString * feed = [NSString stringWithFormat:@"%@%@%@", header, items, footer];
	[server_ sendGetData:[feed dataUsingEncoding:NSUTF8StringEncoding]
		  withHeader:[NSDictionary dictionaryWithObjectsAndKeys:
			      @"application/atom+xml", @"content-type",
			      nil]
		   toRequest:mess];
}


- (NSString *)feedPathFuerKonto:(Konto *)konto
{
	return [NSString stringWithFormat:@"/%@/konto.xml", [konto feedGeheimnis]]; 
}


- (NSURL *)feedUrlFuerKonto:(Konto *)konto
{
	NSString * s = [NSString stringWithFormat:@"%@%@",
			baseUrl_, [self feedPathFuerKonto:konto]]; 
	return [NSURL URLWithString:s];
}


- (void)oeffneFeedFuerKonto:(Konto *)konto
{
	// Server laeuft?
	if (!server_) {
		// Frag, ob er gestartet werden soll
		[NSApp activateIgnoringOtherApps:YES];
		int ret = NSRunInformationalAlertPanel(
			NSLocalizedString(@"RSS Feed", nil),
			NSLocalizedString(@"The local webserver for RSS-Feeds is not running. You want to configure it?", nil),
			NSLocalizedString(@"Yes", nil),
			NSLocalizedString(@"Cancel", nil),
			nil);
		if (ret == NSAlertDefaultReturn)
			[theAppCtrl showFeedPreferences:self];
		return;
	}
	
	// Feed oeffnen
	[[NSWorkspace sharedWorkspace] openURL:[self feedUrlFuerKonto:konto]];
}


- (void)HTTPConnection:(HTTPConnection *)conn didReceiveRequest:(HTTPServerRequest *)mess
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];

	// GET-Anfrage?
	CFHTTPMessageRef request = [mess request];
	NSString *vers = [(id)CFHTTPMessageCopyVersion(request) autorelease];
	if (!vers) { // || ![vers isEqual:(id)kCFHTTPVersion1_1]) {
		CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 505, NULL, (CFStringRef)vers); // Version Not Supported
		[mess setResponse:response];
		CFRelease(response);
		return;
	}
	NSString *method = [(id)CFHTTPMessageCopyRequestMethod(request) autorelease];
	if (!method) {
		CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 400, NULL, kCFHTTPVersion1_1); // Bad Request
		[mess setResponse:response];
		CFRelease(response);
		return;
	}
	if (![method isEqual:@"GET"]) {
		CFHTTPMessageRef response = CFHTTPMessageCreateResponse(kCFAllocatorDefault, 405, NULL, kCFHTTPVersion1_1); // Method Not Allowed
		[mess setResponse:response];
		CFRelease(response);
		return;
	}
	
	// Adresse
	NSURL * uri = [(NSURL *)CFHTTPMessageCopyRequestURL(request) autorelease];
        NSString * path = [uri path];
	NSLog(@"GET %@", path);
	if ([path compare:@"/test"] == 0) {
		NSString * nachricht = NSLocalizedString(@"Saldomat RSS-Server is running fine.", nil);
		NSString * antwort = [NSString stringWithFormat:
				      @"<html><head><title>Saldomat RSS-Server</title></head>"
				      "<body style=\"background: #ffffff;\"><center><img src=\"/logo.png\"><br/>%@</center></body>", nachricht];
		[server_ sendGetData:[antwort dataUsingEncoding:NSUTF8StringEncoding]
			  withHeader:[NSDictionary dictionaryWithObjectsAndKeys:
				      @"text/html; charset=utf-8", @"content-type",
				      nil]
			   toRequest:mess];
		return;
	} else if ([path compare:@"/logo.png"] == 0) {
		NSString * logoPath = [[NSBundle mainBundle] pathForImageResource:@"EuroBlau180.png"];
		[server_ sendGetData:[NSData dataWithContentsOfFile:logoPath]
			  withHeader:[NSDictionary dictionaryWithObjectsAndKeys:
				      @"image/png", @"content-type",
				      nil]
			   toRequest:mess];
		return;
	} else if ([path compare:@"/icon.png"] == 0 || [path compare:@"/favicon.ico"] == 0) {
		NSString * logoPath = [[NSBundle mainBundle] pathForImageResource:@"EuroBlauFeedIcon.png"];
		[server_ sendGetData:[NSData dataWithContentsOfFile:logoPath]
			  withHeader:[NSDictionary dictionaryWithObjectsAndKeys:
				      @"image/png", @"content-type",
				      nil]
			   toRequest:mess];
		return;
	}
	
	// Konto-RSS?
	for (Konto * k in [konten_ arrangedObjects]) {
		NSString * kontoPath = [self feedPathFuerKonto:k];
		NSLog(@"Checking %@", kontoPath);
		if ([kontoPath compare:path] == 0) {
			[self kontoFeedSenden:k fuerNachricht:mess];
			return;
		}
		
		// Buchung?
		if ([[path stringByDeletingLastPathComponent] isEqualToString:
		     [NSString stringWithFormat:@"/%@", [k feedGeheimnis]]]) {
			if ([[defaults objectForKey:@"feedLadenVerhalten"] intValue] == 0) {
				NSString * datei = [path lastPathComponent];
				NSString * guid = [datei stringByDeletingPathExtension];
				
				// Buch von Core Date bekommen mit dieser guid
				NSManagedObjectContext * ctx = [[NSApp delegate] managedObjectContext];
				NSFetchRequest * fetch = [[[NSFetchRequest alloc] init] autorelease];
				fetch.entity = [NSEntityDescription entityForName:@"Buchung" inManagedObjectContext:ctx];
				fetch.predicate = [NSPredicate predicateWithFormat:@"guid == %@", guid];
				NSArray * buchungen = [ctx executeFetchRequest:fetch error:nil];
				
				// als nicht mehr neu markieren
				if ([buchungen count] >= 1)
					[[buchungen objectAtIndex:0] setNeu:[NSNumber numberWithBool:NO]];
			}
			
			// Bild liefern
			NSString * logoPath = [[NSBundle mainBundle] pathForImageResource:@"EuroBlauFeedIcon.png"];
			[server_ sendGetData:[NSData dataWithContentsOfFile:logoPath]
				  withHeader:[NSDictionary dictionaryWithObjectsAndKeys:
					      @"image/png", @"content-type",
					      nil]
				   toRequest:mess];
			return;
		}
	}
	
	// Fehlermeldung
	NSLog(@"Sending error 404");
	[server_ sendGetData:[@"Page not found." dataUsingEncoding:NSUTF8StringEncoding]
		  withHeader:[NSDictionary dictionaryWithObjectsAndKeys:
			      @"text/plain", @"content-type",
			      nil]
		   toRequest:mess
	    withResponseCode:404];
}


- (BOOL)running
{
	return server_ != nil;
}

@synthesize server = server_;
@synthesize baseUrl = baseUrl_;

@end
