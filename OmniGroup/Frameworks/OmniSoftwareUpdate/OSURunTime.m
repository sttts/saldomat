// Copyright 2007 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OSURunTime.h"

#import <OmniFoundation/OFNull.h> // For OFNOTEQUAL

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniSoftwareUpdate/OSURunTime.m 89476 2007-08-01 23:59:32Z kc $");

static NSString *OSULastRunStartIntervalKey = @"OSULastRunStartInterval";

static NSString *OSURunTimeStatisticsKey = @"OSURunTimeStatistics";

// scopes
static NSString *OSURunTimeStatisticsAllVersionsScopeKey = @"total";
static NSString *OSURunTimeStatisticsCurrentVersionsScopeKey = @"current";

// Subkeys in each of the scope dictionaries.
static NSString *OSUNumberOfRunsKey = @"runCount";
static NSString *OSUNumberOfCrashesKey = @"crashCount";
static NSString *OSUTotalRunTimeKey = @"runTime";
static NSString *OSUVersionKey = @"version";

static BOOL OSUHasHandledTermination = NO;

BOOL OSURunTimeHasHandledApplicationTermination(void)
{
    return OSUHasHandledTermination;
}

void OSURunTimeApplicationStarted(void)
{
    
    // Record the time we started this run of the application.  Also, increment the number of runs.
    // If we crash, OCC will handle calculating how long we ran until we crashed.  If we quit normally, we will do it.
    // Thus, if we launch and a preference exists for the 'last start time', then there is a bug.
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Can't really OBASSERT on this since it'll fire over and over when in the debugger.  So, we just log and only when not building for DEBUG to avoid accumulating log spam.
#ifndef DEBUG
    if ([defaults objectForKey:OSULastRunStartIntervalKey] != nil) {
        NSLog(@"%@ default is non-nil; unless you forcibly killed the app and restarted it it should be nil at launch time.", OSULastRunStartIntervalKey);
    }
#endif
    
    [defaults setObject:[NSNumber numberWithDouble:now] forKey:OSULastRunStartIntervalKey];
    [defaults synchronize]; // Make sure we save in case we crash before -autoSynchronize would fire
}

// All the termination code doesn't bother releasing objects accurately -- we are terminating anyway...

static NSDictionary *_OSURunTimeUpdateStatisticsScope(NSDictionary *oldScope, NSString *version, NSNumber *startTimeNumber, NSTimeInterval now, BOOL crashed)
{
    if (oldScope && ![oldScope isKindOfClass:[NSDictionary class]]) {
        OBASSERT([oldScope isKindOfClass:[NSDictionary class]]);
        oldScope = nil;
    }
    
    // Validate the version.
    NSString *oldVersion = [oldScope objectForKey:OSUVersionKey];
    if (OFNOTEQUAL(version, oldVersion))
        oldScope = nil;
    
    NSMutableDictionary *newScope = [NSMutableDictionary dictionary];
    
    if (version)
        [newScope setObject:version forKey:OSUVersionKey];
    
    // Run time
    if (startTimeNumber) {
        NSTimeInterval startTime = [startTimeNumber doubleValue];
        OBASSERT(startTime < now);
        if (startTime < now) {            
            NSNumber *totalRunTimeNumber = [oldScope objectForKey:OSUTotalRunTimeKey];

            if (totalRunTimeNumber && ![totalRunTimeNumber isKindOfClass:[NSNumber class]]) {
                OBASSERT([totalRunTimeNumber isKindOfClass:[NSNumber class]]);
                totalRunTimeNumber = nil;
            }

            NSTimeInterval totalRunTime = totalRunTimeNumber ? [totalRunTimeNumber doubleValue] : 0.0;
            
            totalRunTime += (now - startTime);
            
            [newScope setObject:[NSNumber numberWithDouble:totalRunTime] forKey:OSUTotalRunTimeKey];
        }
    }

    // Run count
    {
        NSNumber *runCountNumber = [oldScope objectForKey:OSUNumberOfRunsKey];
        if (runCountNumber && ![runCountNumber isKindOfClass:[NSNumber class]]) {
            OBASSERT([runCountNumber isKindOfClass:[NSNumber class]]);
            runCountNumber = nil;
        }
        
        unsigned int runCount = [runCountNumber unsignedIntValue] + 1;
        [newScope setObject:[NSNumber numberWithUnsignedInt:runCount] forKey:OSUNumberOfRunsKey];
    }
    
    // Crash count
    {
        NSNumber *crashCountNumber = [oldScope objectForKey:OSUNumberOfCrashesKey];
        if (crashCountNumber && ![crashCountNumber isKindOfClass:[NSNumber class]]) {
            OBASSERT([crashCountNumber isKindOfClass:[NSNumber class]]);
            crashCountNumber = nil;
        }
        
        unsigned int crashCount = [crashCountNumber unsignedIntValue];
        
        if (crashed)
            crashCount++;
        
        [newScope setObject:[NSNumber numberWithUnsignedInt:crashCount] forKey:OSUNumberOfCrashesKey];
    }
    
    return newScope;
}

// This takes a bundle identifier so that the OmniCrashCatcher app can invoke this for us when we crash.
// Add (now - start) to our total run duration and remove the defaults for the start time.
void OSURunTimeApplicationTerminated(NSString *appIdentifier, NSString *bundleVersion, BOOL crashed)
{
    OBPRECONDITION(appIdentifier);
    OBPRECONDITION(bundleVersion);
    
    OBPRECONDITION(OSUHasHandledTermination == NO);
    if (OSUHasHandledTermination)
        return;
    
    NSNumber *startTimeNumber = (NSNumber *)CFPreferencesCopyAppValue((CFStringRef)OSULastRunStartIntervalKey, (CFStringRef)appIdentifier);
    OBASSERT([startTimeNumber isKindOfClass:[NSNumber class]]);
    if (![startTimeNumber isKindOfClass:[NSNumber class]])
        startTimeNumber = nil;

    NSDictionary *statisticsValue = (NSDictionary *)CFPreferencesCopyAppValue((CFStringRef)OSURunTimeStatisticsKey, (CFStringRef)appIdentifier);
    if (statisticsValue && ![statisticsValue isKindOfClass:[NSDictionary class]]) {
        OBASSERT([statisticsValue isKindOfClass:[NSDictionary class]]);
        statisticsValue = nil;
    }
    
    NSMutableDictionary *statistics = statisticsValue ? [statisticsValue mutableCopy] : [NSMutableDictionary dictionary];

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSDictionary *all = _OSURunTimeUpdateStatisticsScope([statistics objectForKey:OSURunTimeStatisticsAllVersionsScopeKey], nil/*version*/, startTimeNumber, now, crashed);
    NSDictionary *current = _OSURunTimeUpdateStatisticsScope([statistics objectForKey:OSURunTimeStatisticsCurrentVersionsScopeKey], bundleVersion, startTimeNumber, now, crashed);
    
    statistics = [[NSDictionary alloc] initWithObjectsAndKeys:all, OSURunTimeStatisticsAllVersionsScopeKey, current, OSURunTimeStatisticsCurrentVersionsScopeKey, nil];
    CFPreferencesSetAppValue((CFStringRef)OSURunTimeStatisticsKey, (CFDictionaryRef)statistics, (CFStringRef)appIdentifier);

    CFPreferencesSetAppValue((CFStringRef)OSULastRunStartIntervalKey, NULL, (CFStringRef)appIdentifier);
    OSUHasHandledTermination = YES;

    CFPreferencesAppSynchronize((CFStringRef)appIdentifier);
}

// This gets called from within a short-lived tool.  We'll feel free to leak.
static void _OSURunTimeAddStatisticsToInfo(NSMutableDictionary *info, NSDictionary *scope, NSString *prefix)
{
    [info setObject:[NSString stringWithFormat:@"%u", [[scope objectForKey:OSUNumberOfRunsKey] unsignedIntValue]] forKey:[NSString stringWithFormat:@"%@nrun", prefix]];
    [info setObject:[NSString stringWithFormat:@"%u", [[scope objectForKey:OSUNumberOfCrashesKey] unsignedIntValue]] forKey:[NSString stringWithFormat:@"%@ndie", prefix]];
    
    // We'll report integral minutes instead of seconds.  We can go more than 8000 years with this w/o overflowing 32 bits.
    NSNumber *runTimeNumber = [scope objectForKey:OSUTotalRunTimeKey];
    NSTimeInterval runTime = runTimeNumber ? [runTimeNumber doubleValue] : 0.0;
    
    unsigned int runMinutes = floor(runTime / 60.0);
    [info setObject:[NSString stringWithFormat:@"%u", runMinutes] forKey:[NSString stringWithFormat:@"%@runmin", prefix]];
}

void OSURunTimeAddStatisticsToInfo(NSString *appIdentifier, NSMutableDictionary *info)
{
    NSDictionary *statistics = (NSDictionary *)CFPreferencesCopyAppValue((CFStringRef)OSURunTimeStatisticsKey, (CFStringRef)appIdentifier);
    if (!statistics || ![statistics isKindOfClass:[NSDictionary class]])
        statistics = nil;
    
    _OSURunTimeAddStatisticsToInfo(info, [statistics objectForKey:OSURunTimeStatisticsAllVersionsScopeKey], @"t");
    _OSURunTimeAddStatisticsToInfo(info, [statistics objectForKey:OSURunTimeStatisticsCurrentVersionsScopeKey], @"");
}
