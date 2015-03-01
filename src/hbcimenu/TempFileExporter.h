//
//  TempFileExporter.h
//  hbci
//
//  Created by Stefan Schimanski on 04.06.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Exporter.h"


@interface TempFileExporter : NSObject <Exporter> {
	NSMutableArray * tempDateien_;
}

- (NSString *)tempFileErstellen;

@end
