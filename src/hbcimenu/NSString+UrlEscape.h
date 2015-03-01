//
//  NSString+UrlEscape.h
//  hbci
//
//  Created by Stefan Schimanski on 06.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// von hier: http://www.mactech.com/articles/mactech/Vol.19/19.03/HTTPMessages/index.html

@interface NSString (UrlEscape)

- (NSString *) escapedForQueryURL;

@end

@interface NSDictionary (UrlEscape)

- (NSString *) webFormEncoded;

@end