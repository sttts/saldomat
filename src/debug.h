/*
 *  debug.h
 *  hbci
 *
 *  Created by Stefan Schimanski on 27.04.08.
 *  Copyright 2008 1stein.org. All rights reserved.
 *
 */

#ifdef DEBUG
#define NSLog(args...) NSLog( @"%s: %@", __PRETTY_FUNCTION__, [NSString stringWithFormat: args])
#else
#define NSLog(args...)
#endif
