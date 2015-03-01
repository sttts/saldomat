//
//  UniversalQifExporter.h
//  hbci
//
//  Created by Michael on 15.09.09.
//  Copyright 2009 Limoia. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TempFileExporter.h"


@interface UniversalQifExporter : TempFileExporter {
	Konto * konto_;
}

@end
