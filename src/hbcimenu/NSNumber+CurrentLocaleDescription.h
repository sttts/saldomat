//
//  NSNumber+CurrentLocaleDescription.h
//  hbci
//
//  Created by Stefan Schimanski on 10.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSNumber(CurrentLocaleDescription)

- (NSString *)descriptionWithLocale;
- (NSString *)geldBetrag;

@end
