/*
 *  DockIconControllerProtocol.h
 *  hbci
 *
 *  Created by Stefan Schimanski on 14.04.08.
 *  Copyright 2008 1stein.org. All rights reserved.
 *
 */

@protocol DockIconControllerProtocol

- (void)activate;
- (void)hideWindows;
- (oneway void)preferences;
- (oneway void)about;

@end

@protocol DockAppProtocol

- (oneway void)terminate;
- (void)activate;

@end
