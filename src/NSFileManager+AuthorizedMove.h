//
//  NSFileManager+AuthorizedMove.h
//  hbci
//
//  Created by Stefan Schimanski on 29.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSFileManager (AuthorizedMove)
- (BOOL)authorizedMovePath:(NSString *)source toPath:(NSString *)destination;
@end
