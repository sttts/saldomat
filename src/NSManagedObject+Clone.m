//
//  NSManagedObject+Clone.m
//  hbci
//
//  Created by Stefan Schimanski on 12.05.08.
//  Copyright 2008 1stein.org. All rights reserved.
//

#import "NSManagedObject+Clone.h"


@implementation NSManagedObject(Clone)

- (void) cloneAttributes:(NSManagedObject *) clone
{
	NSArray *keys=[[[self entity] attributesByName] allKeys];
	unsigned long i;
	for (i=0;i<[keys count];i++)
	{
		NSString *key=[keys objectAtIndex:i];
		[clone setValue: [self valueForKey:key] forKey:key];
	}
}

/*
- (void)cloneRelationships:(NSManagedObject *)clone
{
	NSDictionary *relationships=[[self entity] relationshipsByName];
	NSArray *keys=[relationships allKeys];
	unsigned long i;
	for (i=0;i<[keys count];i++)
	{
		NSString *key=[keys objectAtIndex:i];
		if (![[relationships objectForKey: key] isToMany] || ![[relationships objectForKey: key] inverseRelationship])
			[clone setValue: [self valueForKey:key] forKey: key];
	}
}
*/

- (NSManagedObject *)cloneOfSelf
{
	NSManagedObject *clone=[NSEntityDescription insertNewObjectForEntityForName: [[self entity] name] inManagedObjectContext: [self managedObjectContext]];
	[self cloneAttributes: clone];
	//[self cloneRelationships: clone];
	return clone;
}

@end
