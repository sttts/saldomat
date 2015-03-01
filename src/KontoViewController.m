//
//  KontoViewController.m
//  hbci
//
//  Created by Michael on 03.06.08.
//  Copyright 2008 michaelschimanski.de. All rights reserved.
//

#import "KontoViewController.h"
#import "RotGruenFormatter.h"


@implementation KontoViewController

- (void)awakeFromNib {
	[SaldoFormatter setCurrencySymbol:@"€"];
}

@end
