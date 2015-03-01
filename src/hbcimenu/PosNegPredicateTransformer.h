//
//  PosNegPredicateTransformer.h
//  hbci
//
//  Created by Stefan Schimanski on 09.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PositivePredicateTransformer : NSValueTransformer {}
@end

@interface NegativePredicateTransformer : NSValueTransformer {}
@end

@interface NotPositivePredicateTransformer : NSValueTransformer {}
@end

@interface NotNegativePredicateTransformer : NSValueTransformer {}
@end
