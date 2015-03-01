//
//  NSManagedObject+Clone.h
//  hbci
//
//  Created by Stefan Schimanski on 12.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSManagedObject(Clone)

- (NSManagedObject *)cloneOfSelf;

@end
