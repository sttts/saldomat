//
//  Aktion.h
//  hbci
//
//  Created by Stefan Schimanski on 04.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface Aktion : NSObject
{
	NSMutableDictionary * options_;
}

- (id)initWithType:(NSString *)type;
- (id)initWithDictionary:(NSDictionary *)dict;

- (void)setOption:(NSString *)option toValue:(id)value;
- (id)option:(NSString *)option;

- (NSMutableDictionary *)options;

@property BOOL aktiv;
@property BOOL einzeln;
@property (readonly) NSString * type;
@property (retain) NSString * name;

@end
