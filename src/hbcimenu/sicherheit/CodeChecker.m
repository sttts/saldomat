//
//  CodeChecker.m
//  hbci
//
//  Created by Stefan Schimanski on 12.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "CodeChecker.h"

#import <openssl/sha.h>

#import "checksums.h"
#import "debug.h"

#define ANCHOR_REQ @"-R=anchor H\"6d8729477568aa574daa42f36fab67374f1922cb\""

NSString * keychainPfad()
{
	return [[NSBundle mainBundle] pathForResource:@"Saldomat" ofType:@"keychain"];
}


BOOL validKeychain()
{
	// Schluesselbund pruefen
	NSData * keychain = [NSData dataWithContentsOfFile:keychainPfad()];
	if (keychain == nil) {
		NSLog(@"Saldomat.keychain nicht gefunden");
		return NO;
	}
	
	unsigned char digest[20];
	SHA1([keychain bytes], [keychain length], digest);
	
	char hexDigest[40];
	int i;
	for(i = 0; i < 20; ++i)
		sprintf(hexDigest+i*2,"%02x",digest[i]);
	
	// Signatur korrekt?
	if (strncmp(hexDigest, KEYCHAIN_HASH, 40) != 0) {
		NSLog(@"Saldomat.keychain hat falsche Signature");
		return NO;
	}
	
	return YES;	
}


BOOL validBundle(NSString * path)
{
	// Signatur pruefen: "codesign -v --keychain Saldomat.keychain pid"
	NSTask * codesign = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/codesign" arguments:
			     [NSArray arrayWithObjects:@"-v",
			      ANCHOR_REQ,
			      @"--keychain",
			      keychainPfad(),
			      path,
			      nil]];
	if (!codesign) {
		NSLog(@"Launching codesign failed");
		return NO;
	}
	[codesign waitUntilExit];
	int n = [codesign terminationStatus];
	if (n != 0) {
		NSLog(@"codesign fuer '%@' war ungueltig", path);
		return NO;
	}
	
	// Keychain pruefen
	return validKeychain();
}


BOOL validPid(int pid)
{
	// Signatur pruefen: "codesign -v --keychain Saldomat.keychain pid"
	NSTask * codesign = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/codesign" arguments:
			     [NSArray arrayWithObjects:@"-v", 
			      ANCHOR_REQ,
			      @"--keychain",
			      keychainPfad(),
			      [NSString stringWithFormat:@"%d", pid],
			      nil]];
	if (!codesign) {
		NSLog(@"Launching codesign failed");
		return NO;
	}
	[codesign waitUntilExit];
	if ([codesign terminationStatus] != 0) {
		NSLog(@"codesign fuer pid %d war ungueltig", pid);
		return NO;
	}
	
	// Keychain pruefen
	return validKeychain();
}


BOOL validMainBundle()
{
	// Signatur pruefen: "codesign -v --keychain Saldomat.keychain pid"
	NSTask * codesign = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/codesign" arguments:
			     [NSArray arrayWithObjects:@"-v", 
			      ANCHOR_REQ,
			      @"--keychain",
			      keychainPfad(),
			      [NSString stringWithFormat:@"%d", getpid()],
			      nil]];
	if (!codesign) {
		NSLog(@"Launching codesign failed");
		return NO;
	}
	[codesign waitUntilExit];
	if ([codesign terminationStatus] != 0) {
		NSLog(@"codesign war ungueltig");
		return NO;
	}
	
	// Keychain pruefen
	return validKeychain();
}
