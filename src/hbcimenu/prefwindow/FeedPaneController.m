//
//  FeedPaneController.m
//  hbci
//
//  Created by Stefan Schimanski on 10.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "FeedPaneController.h"

#import "AppController.h"
#import "debug.h"
#import "FeedServerController.h"

@implementation FeedPaneController


- (void)updateUrlLine
{
	NSLog(@"updateUrlLine");
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	// Url-Label berechnen
	BOOL serverLaeuft = [[theAppCtrl feedServerController] running]
		&& [[defaults objectForKey:@"startFeedServer"] boolValue];
	NSLog(@"Server laeuft: %d", [[theAppCtrl feedServerController] running]);
	NSLog(@"Server soll laufen: %@", [defaults objectForKey:@"startFeedServer"]);
	if (serverLaeuft) {
		NSString * baseUrl = [[theAppCtrl feedServerController] baseUrl];
		NSString * url = [NSString stringWithFormat:@"%@/test", baseUrl];
		
		// String setzen, als Link
		NSMutableAttributedString * mAttr = [[[NSMutableAttributedString alloc] initWithString:url] autorelease];
		NSMutableParagraphStyle * pstyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		//[pstyle setAlignment:NSCenterTextAlignment];
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
				      url, NSLinkAttributeName,
				      pstyle, NSParagraphStyleAttributeName,
				      nil];
		[mAttr addAttributes:dict range:NSMakeRange(0, [mAttr length])];
		[[urlLine_ textStorage] replaceCharactersInRange:NSMakeRange(0, [[urlLine_ textStorage] length])
					    withAttributedString:mAttr];		
	} else {
		// Platzhalterstring setzen
		NSMutableAttributedString * mAttr = [[[NSMutableAttributedString alloc] initWithString:NSLocalizedString(@"Server not running", nil)] autorelease];
		NSMutableParagraphStyle * pstyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		//[pstyle setAlignment:NSCenterTextAlignment];
		NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
				      pstyle, NSParagraphStyleAttributeName,
				      nil];
		[mAttr addAttributes:dict range:NSMakeRange(0, [mAttr length])];
		[[urlLine_ textStorage] replaceCharactersInRange:NSMakeRange(0, [[urlLine_ textStorage] length])
					    withAttributedString:mAttr];
	}
}


- (void)awakeFromNib
{
	NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults addObserver:self forKeyPath:@"startFeedServer"
		      options:NSKeyValueObservingOptionNew context:@"startFeedServer"];
	[[theAppCtrl feedServerController] addObserver:self forKeyPath:@"running"
		options:NSKeyValueObservingOptionNew context:@"baseUrl"];
	[[theAppCtrl feedServerController] addObserver:self forKeyPath:@"baseUrl"
		options:NSKeyValueObservingOptionNew context:@"running"];
	
	[NSTimer scheduledTimerWithTimeInterval:0.1 target:self
				       selector:@selector(updateUrlLine)
				       userInfo:nil repeats:NO];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object 
			change:(NSDictionary *)change context:(void *)context
{
	[self updateUrlLine];
}

@end
