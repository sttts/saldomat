//
//  SicherheitPaneController.m
//  hbci
//
//  Created by Stefan Schimanski on 27.04.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "SicherheitPaneController.h"

#import <Security/Security.h>

#import "debug.h"


@implementation SicherheitPaneController

- (void)awakeFromNib
{
	pins_ = nil;
}

/*
- (void)updateKeychainData
{
	[pins_ release];
	pins_ = [[NSMutableArray array] retain];
	
	// Suche erstellen
	SecKeychainSearchRef searchRef;
	OSStatus oss = SecKeychainSearchCreateFromAttributes(
		0,
		kSecGenericPasswordItemClass,
		NULL,
		&searchRef
	);
	if (oss != 0) {
		NSLog(@"SecKeychainSearchCreateFromAttributes failed (%d)", oss);
		return;
	}
	
	// Items durchgehen
	while (true) {
		SecKeychainItemRef item;
		oss = SecKeychainSearchCopyNext(searchRef, &item);
		if (oss == errSecItemNotFound)
			break;
		else if (oss != 0) {
			NSLog(@"SecKeychainSearchCopyNext failed (%d)", oss);
			return;
		}
		
		// Account und Service bekommen
		UInt32 tag = kSecKeyPrintName;
		SecKeychainAttributeInfo attrInfo;
		attrInfo.count = 1;
		attrInfo.tag = &tag;
		attrInfo.format = NULL;
		SecKeychainAttributeList * attrList = NULL;
		SecKeychainAttribute * attr = NULL;
		oss = SecKeychainItemCopyAttributesAndData(item, &attrInfo, NULL, &attrList, NULL, NULL);
		if (oss != 0) {
			NSLog(@"SecKeychainItemCopyAttributesAndData failed (%d)", oss);
			continue;
		}
		if((attrList == NULL) || (attrList->count != 1)) {
			NSLog(@"Unexpected result from SecKeychainItemCopyAttributesAndData");
			continue;
		}
		
		// String umwandeln
		attr = attrList->attr;
		char cname[attr->length + 1];
		memmove(cname, attr->data, attr->length);
		cname[attr->length] = '\0';
		NSString * name = [NSString stringWithCString:cname encoding:NSUTF8StringEncoding];
		
		// Saldomat-Praefix?
		NSString * pinPrefix = @"Saldomat HBCI-PIN";
		if ([name substringToIndex:
		
		// Item eintragen
		NSMutableDictionary * dict = [NSMutableDictionary dictionary];
		NSLog(@"Item '%@'", name);
		[dict setObject:name forKey:@"name"];
	}

	const char * password;
        UInt32 passwordLength;
        SecKeychainItemRef item = NULL;
	Konto * konto = [cgui currentKonto];
	NSString * account = [cgui keychainAccount:konto];
	NSString * service = [cgui keychainService:konto];
	OSStatus result = errSecNoSuchKeychain;
	SecKeychainRef keychain = [[cgui cocoaBanking] keychain];
	if (keychain != 0)
		result = SecKeychainFindGenericPassword(
							keychain,
							[service length],
							[service UTF8String],
							[account length],
							[account UTF8String],
							&passwordLength,
							(void **) &password,
							&item
							);

}
*/

- (IBAction)oeffneSchluesselbund:(id)sender
{
	NSLog(@"Starting keychain");
	[NSTask launchedTaskWithLaunchPath:@"/usr/bin/open" 
				 arguments:[NSArray arrayWithObjects:
					    @"-b",@"com.apple.keychainaccess",nil]];
}

@end
