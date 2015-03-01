//
//  NSString+UrlEscape.m
//  hbci
//
//  Created by Stefan Schimanski on 06.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "NSString+UrlEscape.h"


static void InitializePassthrough(BOOL * table)
{
	int      i;
	for (i = '0'; i <= '9'; i++) {
		table[i] = YES;
	}
	for (i = '@'; i <= 'Z'; i++) {
		table[i] = YES;
	}
	for (i = 'a'; i <= 'z'; i++) {
		table[i] = YES;
	}
	table['*'] = YES;
	table['-'] = YES;
	table['.'] = YES;
	table['_'] = YES;
}


@implementation NSString (UrlEscape)

- (NSString *)escapedForQueryURL
{
	NSData *                  utfData = [self dataUsingEncoding:NSUTF8StringEncoding];
	const unsigned char *      source = [utfData bytes];
	const unsigned char *      cursor = source;
	const unsigned char *      limit = source + [utfData length];
	const unsigned char *      startOfRun;
	NSMutableString *   workingString = [NSMutableString stringWithCapacity:2*[self length]];
	
	static BOOL            passThrough[256] = { NO };
	if (! passThrough['A']) {
		//   First time through, initialize the pass-through table.
		InitializePassthrough(passThrough);
	}
	startOfRun = source;
	while (YES) {
		//   Ordinarily, do nothing in this loop but advance the cursor pointer.
		if (cursor == limit || ! passThrough[*cursor]) {
			//   Do something special at end-of-data or at a special character:
			NSString *   escape;
			int            passThruLength = cursor - startOfRun;
			//   First, append the accumulated characters that just pass through.
			if (passThruLength > 0) {
				//[workingString appendString:[NSString stringWithCString:startOfRun length:passThruLength]];
				[workingString appendString:[[NSString alloc] initWithBytes:startOfRun length:passThruLength encoding:NSASCIIStringEncoding]];
			}
			//   Then respond to the end of data...
			if (cursor == limit)
				break;
			//   ... by stopping
			//   ... or to a special character...
			if (*cursor == ' ')
				escape = @"+";
			//   ... by replacing with '+'
			else
				escape = [NSString stringWithFormat:
					  @"%%%02x", *cursor];
			//   ... or by %-escaping
			[workingString appendString: escape];
			startOfRun = cursor+1;
		}
		cursor++;
	}
	return workingString;
}
@end


@implementation NSDictionary (UrlEscape)

- (NSString *) webFormEncoded
{
	NSEnumerator *      keys = [self keyEnumerator];
	NSString *            currKey;
	NSString *            currObject;
	NSMutableString *   retval = [NSMutableString
				      stringWithCapacity: 256];
	BOOL                     started = NO;
	while ((currKey = [keys nextObject]) != nil) {
		//   Chain the key-value pairs, properly escaped, in one string.
		if (started)
			[retval appendString: @"&"];
		else
			started = YES;
		currObject = [[self objectForKey: currKey]
			      escapedForQueryURL];
		currKey = [currKey escapedForQueryURL];
		[retval appendString: [NSString stringWithFormat:
				       @"%@=%@", currKey, currObject]];
	}
	return retval;
}

@end
