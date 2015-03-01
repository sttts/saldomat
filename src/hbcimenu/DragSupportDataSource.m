
/* 
 Copyright (c) 2004-7, Apple Computer, Inc., all rights reserved.
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
 Apple Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. 
 may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2004-7 Apple Inc. All Rights Reserved.
 */



#import "DragSupportDataSource.h"
#import "AppController.h"
#import "AuthorizationController.h"

NSString*   MyDragType = @"MyDragType";

@implementation DragSupportDataSource

- (void)awakeFromNib
{	
	// Create sort descriptor
	NSSortDescriptor* sortDescriptor;
	sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"order" ascending:YES selector:@selector(compare:)];
	[sortDescriptor autorelease];
	
	// Register for drag and drop
	NSArray *dragTypes;
	dragTypes = [NSArray arrayWithObject:MyDragType];
	
    [myTableView registerForDraggedTypes:dragTypes];
	[myTableView setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];
}

- (BOOL)isGroupTable:(NSTableView*)tableView
{
	if ([[tableView autosaveName] isEqualToString:@"itemGroupTableView"]) {
		return YES;
	}
	return NO;
}

- (BOOL)isItemTable:(NSTableView*)tableView
{
	if ([[tableView autosaveName] isEqualToString:@"itemTableView"]) {
		return YES;
	}
	return NO;
}

- (BOOL)tableView:(NSTableView*)tableView writeRows:(NSArray*)rows  toPasteboard:(NSPasteboard*)pboard
{
	// Get array controller
	NSDictionary *bindingInfo = [tableView infoForBinding:NSContentBinding];
	NSArrayController *arrayController = [bindingInfo valueForKey:NSObservedObjectKey];
    
    // Get arranged objects, they are managed object
    NSArray *arrangedObjects = [arrayController arrangedObjects];
    
    // Collect URI representation of managed objects
    NSMutableArray *objectURIs = [NSMutableArray array];
    NSEnumerator *enumerator = [rows objectEnumerator];
    NSNumber *rowNumber;
	
	int row;
    while (rowNumber = [enumerator nextObject]) {
        row = [rowNumber intValue];
        if (row >= [arrangedObjects count]) {
            continue;
        }
        
        // Get URI representation of managed object
        NSManagedObject *object = [arrangedObjects objectAtIndex:row];
        NSManagedObjectID *objectID = [object objectID];
        NSURL *objectURI = [objectID URIRepresentation];
		
        [objectURIs addObject:objectURI];
    }
    
    // Set them to paste board
    [pboard declareTypes:[NSArray arrayWithObject:MyDragType] owner:nil];
    [pboard setData:[NSArchiver archivedDataWithRootObject:objectURIs] forType:MyDragType];
    
    return YES;
}


- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
	if ([[theAppCtrl authController] verschlossen])
		return NSDragOperationNone;

	//Destination is self
	if ([info draggingSource] == tableView) {
		[tableView setDropRow:row dropOperation:NSTableViewDropAbove];
		return NSDragOperationMove;
	}
	//Destination is itemGroup and source is item
	else if ([self isItemTable:[info draggingSource]]) {
		[tableView setDropRow:row dropOperation:NSTableViewDropOn];
		return NSDragOperationMove;
	}
	
	return NSDragOperationNone;
}


- (BOOL)tableView:(NSTableView*)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	if ([[theAppCtrl authController] verschlossen])
		return NO;

	//Destination is self
	if ([info draggingSource] == tableView) {
		// Get object URIs from paste board
		NSData *data = [[info draggingPasteboard] dataForType:MyDragType];
		NSArray *objectURIs = [NSUnarchiver unarchiveObjectWithData:data];
		
		if (!objectURIs) return NO;
		
		// Get array controller
		NSDictionary *bindingInfo = [tableView infoForBinding:@"content"];
		NSArrayController *arrayController = [bindingInfo valueForKey:NSObservedObjectKey];
		
		// Get managed object context and persistent store coordinator
		NSManagedObjectContext *context = [[NSApp delegate] managedObjectContext];
		NSPersistentStoreCoordinator *coordinator = [context persistentStoreCoordinator];
		
		// Collect manged objects with URIs
		NSMutableArray *draggedObjects = [NSMutableArray array];
		NSEnumerator *enumerator = [objectURIs objectEnumerator];
		NSURL*				objectURI;
		NSManagedObjectID*  objectID;
		NSManagedObject*    object;
		
		;
		while (objectURI = [enumerator nextObject]) {
			// Get managed object
			objectID = [coordinator managedObjectIDForURIRepresentation:objectURI];
			object = [context objectWithID:objectID];
			if (!object) continue;
			
			[draggedObjects addObject:object];
		}
		
		// Get managed objects
		NSMutableArray *objects = [NSMutableArray arrayWithArray:[arrayController arrangedObjects]];;
		
		if (!objects || [objects count] == 0) return NO;
		
		// Replace dragged objects with null objects as placeholder
		enumerator = [draggedObjects objectEnumerator];
		while (object = [enumerator nextObject]) {
			int	index = [objects indexOfObject:object];
			if (index == NSNotFound) {
				// Error
				NSLog(@"Not found dragged link in links");
				continue;
			}
			
			[objects replaceObjectAtIndex:index withObject:[NSNull null]];
		}
		
		// Insert dragged objects at row
		if (row < [objects count]) {
			[objects insertObjects:draggedObjects atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(row, [draggedObjects count])]];
		}
		else {
			[objects addObjectsFromArray:draggedObjects];
		}
		
		// Remove null objeccts
		[objects removeObject:[NSNull null]];
		
		// Re-order objects
		int	i;
		for (i = 0; i < [objects count]; i++) {
			object = [objects objectAtIndex:i];
			[object setValue:[NSNumber numberWithInt:i] forKey:@"order"];
		}
		
		// Reload data
		[arrayController rearrangeObjects];
		
		return YES;
	}
	//Destination is group and source is item
	else if ([self isItemTable:[info draggingSource]]) {
		NSLog(@"%@",[info draggingPasteboard]);
		NSData *sourceData = [[info draggingPasteboard] dataForType:MyDragType];
		NSArray *sourceObjectURIs = [NSUnarchiver unarchiveObjectWithData:sourceData];
		
		if (!sourceObjectURIs) return NO;
		
		// get to the arraycontroller feeding the destination table view
		NSDictionary *destinationContentBindingInfo = [tableView infoForBinding:NSContentBinding];
		NSDictionary *sourceContentBindingInfo = [[info draggingSource] infoForBinding:NSContentBinding];
		if (destinationContentBindingInfo != nil && sourceContentBindingInfo != nil) {
			NSArrayController *destinationArrayController = [destinationContentBindingInfo objectForKey:NSObservedObjectKey];
			NSArrayController *sourceArrayController = [sourceContentBindingInfo objectForKey:NSObservedObjectKey];
			
			if ([[sourceArrayController selectedObjects] count] > 0) {
				NSManagedObjectContext *context = [destinationArrayController managedObjectContext];
				NSManagedObject *serverGroupObject = [[destinationArrayController arrangedObjects] objectAtIndex:row];
				
				int count = [sourceObjectURIs count];
				int i;
				for (i = 0; i < count; i++) {
								
					// take the URL and get the managed object - assume all controllers using the same context
					NSURL *url = [sourceObjectURIs objectAtIndex:i];
					NSManagedObjectID *objectID = [[context persistentStoreCoordinator] managedObjectIDForURIRepresentation:url];
					if (objectID != nil) {
						id object = [context objectRegisteredForID:objectID];
						[object setValue:serverGroupObject forKey:@"itemGroup"];
					}
				}
				if (i > 0) return YES;
			}
		}
		return NO;   
	}
	return NO;  
}



@end


