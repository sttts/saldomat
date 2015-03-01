//
//  StringFarbeTransformer.h
//  hbci
//
//  Created by Stefan Schimanski on 11.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSColor(NSColorHexadecimalValue)
-(NSString *)hexadecimalValueOfAnNSColor;
@end


@interface NSString(NSColorHexadecimalValue)
-(NSColor *)colorOfAnHexadecimalColorString;
@end


@interface StringFarbeTransformer : NSValueTransformer {

}

@end
