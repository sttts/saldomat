//
//  hbcimenu_AppDelegate.m
//  hbcimenu
//
//  Created by Stefan Schimanski on 11.04.08.
//  Copyright 1stein.org 2008 . All rights reserved.
//

#import "AppDelegate.h"

#import "Sparkle/Sparkle.h"

#import "AppController.h"
#import "debug.h"
#import "svnrevision.h"


@implementation AppDelegate


+ (NSString *)applicationSupportFolder {
	NSArray * paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString * basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
	
#ifdef DEBUG
	return [basePath stringByAppendingPathComponent:
		[NSString stringWithFormat:@"Saldomat-%@-debug", CONFIG_POSTFIX]];
#else
	return [basePath stringByAppendingPathComponent:
		[NSString stringWithFormat:@"Saldomat-%@", CONFIG_POSTFIX]];
#endif
}


- (NSManagedObjectModel *)managedObjectModel {
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];    
    return managedObjectModel;
}


- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {
	if (persistentStoreCoordinator != nil)
		return persistentStoreCoordinator;

	// Dateiname ~/Library/Application Support/Saldomat/konten.xml
	NSFileManager * fileManager = [NSFileManager defaultManager];
	NSString * applicationSupportFolder = [AppDelegate applicationSupportFolder];
	if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
		[fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
	}

#ifdef DEBUG
	NSString * filename = @"konten.xml";
	NSString * type = NSXMLStoreType;
	NSURL * url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: filename]];
#else
	NSString * filename = @"konten.sqlite";
	NSString * type = NSSQLiteStoreType;
	NSURL * url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: filename]];
#endif
	
	// StoreCoordinator laden, mit automatischer Versionskonvertierung des Modells
	NSError * error;
	NSDictionary * opts = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
			       nil];
	persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
	if (![persistentStoreCoordinator addPersistentStoreWithType:type configuration:nil URL:url options:opts error:&error]){
		// automatische Migration klappte nicht. Vermutlich muessen wir
		// mehrere Migrationsschritte machen.
		NSLog(@"Automatic migration failed: %@", [error description]);
		
		// Alle Modellversionen laden
		NSBundle * mainBundle = [NSBundle mainBundle];
		NSArray * modelPaths = [mainBundle pathsForResourcesOfType:@"mom" inDirectory:@"KontoDocument.momd"];
		NSMutableDictionary * models = [NSMutableDictionary dictionary];
		for (NSString * path in modelPaths) {
			NSManagedObjectModel * model = [NSManagedObjectModel alloc];
			model = [[model initWithContentsOfURL:[NSURL fileURLWithPath:path]] autorelease];
			//NSString * filename = [[path lastPathComponent] stringByDeletingPathExtension];
			//NSString * verId = [filename substringFromIndex:[@"KontoDocument " length]];
			NSString * verId = [[model versionIdentifiers] anyObject];
			[models setObject:model forKey:verId];
			NSLog(@"Model %@ found.", verId); 
		}
		
		// Nach Nummer sortieren
		NSMutableArray * modelOrder = [NSMutableArray array];
		for (NSString * verId in models) {
			NSNumber * modelNum = [NSNumber numberWithInt:[verId intValue]];
			[modelOrder addObject:modelNum];
		}
		[modelOrder sortUsingSelector:@selector(compare:)];
		
		// Version des alten Modells ermitteln
		NSDictionary * sourceMetadata 
		= [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:type URL:url error:&error];
		NSManagedObjectModel *sourceModel =
		[NSManagedObjectModel mergedModelFromBundles:nil forStoreMetadata:sourceMetadata];
		if (sourceModel == nil) {
			int ret =
			NSRunCriticalAlertPanel(NSLocalizedString(@"Critical database error", nil),
						NSLocalizedString(@"The database %@ is corrupt or too old to be imported. Should we rename it and create a new one?\n"
								  "This will remove your defined accounts and transactions though! Alternatively you can go back to an old version and report the problem to the developers.", nil),
						NSLocalizedString(@"Rename old and create new database", nil),
						NSLocalizedString(@"Quit", nil),
						nil,
						[url path]);
			if (ret == NSAlertAlternateReturn) {
				[NSApp terminate:self];
				return persistentStoreCoordinator;
			}
			
			// Alte DB umbenennen
			NSString * alt = [[[url path] stringByDeletingLastPathComponent] 
					  stringByAppendingPathComponent:[filename stringByAppendingString:@".backup"]];
			[fileManager movePath:[url path] toPath:alt handler:nil];
			
			// und nochmal probieren
			[persistentStoreCoordinator release];
			persistentStoreCoordinator = nil;
			return [self persistentStoreCoordinator];
		}
		NSString * verId = [[sourceModel versionIdentifiers] anyObject];
		NSLog(@"Source model version: %@", verId);
		
		// Versuchen zum Zielmodell zu kommen
		while (true) {
			// naechste Version finden
			verId = [[sourceModel versionIdentifiers] anyObject];
			NSNumber * sourceNum = [NSNumber numberWithInt:[verId intValue]];
			int i = [modelOrder indexOfObject:sourceNum];
			if (i + 1 >= [modelOrder count]) {
				NSLog(@"No further model version found. Stopping conversion.");
				break;
			}
			NSNumber * destNum = [modelOrder objectAtIndex:i + 1];
			
			// Datenbank-Versionen, die wir ueberspringen, weil sie defekt sind
			if ([destNum intValue] >= 1489 && [destNum intValue] < 1719) {
				NSLog(@"Skipping model %@ because it's broken", destNum);
				destNum = [NSNumber numberWithInt:1719];
			}
				 
			// Zielmodell laden
			NSManagedObjectModel * destModel = [models objectForKey:[destNum stringValue]];
			NSLog(@"Found next model version %@.", destNum);
	
			// Migrieren versuchen
			[persistentStoreCoordinator release];
			persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:destModel];
			if (![persistentStoreCoordinator addPersistentStoreWithType:type configuration:nil URL:url options:opts error:&error]){
				NSLog(@"persistentStoreCoordinator failed: %@", [error description]);
				break;
			}
			sourceModel = destModel;
		}
		
		// Pruefen, ob die Version nun kompatibel ist
		sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:type URL:url error:&error];
		NSManagedObjectModel * destModel = [self managedObjectModel];
		if (![destModel isConfiguration:nil compatibleWithStoreMetadata:sourceMetadata]) {
			int ret =
			NSRunCriticalAlertPanel(NSLocalizedString(@"Critical database error", nil),
						NSLocalizedString(@"The database %@ could not be converted to the latest format. This is a bug. "
								  "Should we rename it and create a new one?\n", nil),
						NSLocalizedString(@"Rename old and create new database", nil),
						NSLocalizedString(@"Search for update", nil),
						NSLocalizedString(@"Quit", nil),
						[url path]);
			if (ret == NSAlertOtherReturn) {
				[NSApp terminate:self];
				return persistentStoreCoordinator;
			} else if (ret == NSAlertAlternateReturn) {
				[updater_ checkForUpdates:self];
				//[NSApp terminate:self];
				return persistentStoreCoordinator;
			}
			
			// Alte DB umbenennen
			NSString * alt = [[[url path] stringByDeletingLastPathComponent] stringByAppendingPathComponent:filename];
			[fileManager movePath:[url path] toPath:alt handler:nil];
		}
		
		// nochmal probieren. Dieses Mal muesste es ja durchgehen
		[persistentStoreCoordinator release];
		persistentStoreCoordinator = nil;
		return [self persistentStoreCoordinator];
	}

	return persistentStoreCoordinator;
}


- (NSManagedObjectContext *) managedObjectContext {
	if (managedObjectContext != nil) {
		return managedObjectContext;
	}
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	if (coordinator != nil) {
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		[managedObjectContext setPersistentStoreCoordinator: coordinator];
		[managedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
	}
	
	return managedObjectContext;
}


- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}


- (IBAction) saveAction:(id)sender {
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}


- (BOOL)storeDatabase
{
	NSError *error = nil;
	
	// Datenbank speichern
	NSLog(@"storeDatabase");
	if (managedObjectContext != nil) {
		NSLog(@"storeDatabase - will store database");
		if (![managedObjectContext commitEditing]) {
			NSLog(@"storeDatabase - commit failed");
		}
		if (![managedObjectContext hasChanges]) {
			NSLog(@"storeDatabase - No changes in database");
			return true;
		}
		if ([managedObjectContext save:&error]) {
			NSLog(@"storeDatabase - success");
			return true;
		}
			
		NSLog(@"storeDatabase - error");
		BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
		if (errorResult == YES)
			return false;
		else {
			int alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?" , @"Quit anyway", @"Cancel", nil);
			if (alertReturn == NSAlertAlternateReturn)
				return false;	
		}
	}

	return true;
}


- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
	NSLog(@"applicationShouldTerminate");
	if (![self storeDatabase])
		return NSTerminateCancel;
	
	return NSTerminateNow;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSLog(@"applicationWillTerminate");
	[self storeDatabase];
	
	[DockIconController hideDockIcon:self];
}


- (void) dealloc {
    [managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
    [super dealloc];
}


- (NSError *)application:(NSApplication *)application willPresentError:(NSError *)error
{
	NSLog(@"willPresentError");
	
	// Detailiertere Core Data Fehler
	NSArray * detailedErrors = [[error userInfo] objectForKey:NSDetailedErrorsKey];
	if (detailedErrors && [detailedErrors count] > 0) {
		for (NSError * e in detailedErrors)
			NSLog(@"Detailed error: %@", [e description]);
	}
	
	NSLog(@"Error code: %d", [error code]);
	[NSApp activateIgnoringOtherApps:YES];
	return error;
}


@end
