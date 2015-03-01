//
//  main.m
//  hbcitool
//
//  Created by Stefan Schimanski on 24.03.08.
//  Copyright 1stein.org 2008. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <sys/ptrace.h>

#import "CocoaBanking.h"

int main(int argc, char *argv[])
{
#ifndef DEBUG
	ptrace(PT_DENY_ATTACH, 0, 0, 0);
#endif
	return NSApplicationMain(argc,  (const char **) argv);
}
