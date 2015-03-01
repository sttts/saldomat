//
//  hbcidockmain.m
//  hbci
//
//  Created by Stefan Schimanski on 14.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <sys/ptrace.h>


int main(int argc, char *argv[])
{
#ifndef DEBUG
	ptrace(PT_DENY_ATTACH, 0, 0, 0);
#endif
	return NSApplicationMain(argc,  (const char **) argv);
}
