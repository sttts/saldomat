// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OWF/OWContentInfo.h>

#import <Foundation/Foundation.h>
#import <OmniBase/OmniBase.h>
#import <OmniFoundation/OmniFoundation.h>

#import <OWF/OWAddress.h>
#import <OWF/OWContent.h>
#import <OWF/OWPipeline.h>
#import <OWF/OWTask.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Pipelines.subproj/OWContentInfo.m 68913 2005-10-03 19:36:19Z kc $")

@interface OWTopLevelActiveContentInfo : OWContentInfo
@end


@interface OWContentInfo (Private)
- (void)_treeActiveStatusMayHaveChanged;
- (OWTask *)_taskWithLowestPriority;
- (unsigned int)_indexOfTaskWithLowestPriority;
@end

@implementation OWContentInfo

static OWContentInfo *topLevelActiveContentInfo = nil;
static NSLock *headerContentInfoLock = nil;
static NSMutableDictionary *headerContentInfoDictionary = nil;
static NSMutableArray *allActiveTasks = nil;
static NSLock *allActiveTasksLock = nil;

+ (void)initialize;
{
    OBINITIALIZE;

    topLevelActiveContentInfo = [[OWTopLevelActiveContentInfo alloc] initWithContent:nil];
    headerContentInfoLock = [[NSLock alloc] init];
    headerContentInfoDictionary = [[NSMutableDictionary alloc] init];

    allActiveTasks = [[NSMutableArray alloc] initWithCapacity:16];
    allActiveTasksLock = [[NSLock alloc] init];
}

+ (void)registerItemName:(NSString *)itemName bundle:(NSBundle *)bundle description:(NSDictionary *)description;
{
    OWContentInfo *headerContentInfo = [self headerContentInfoWithName:itemName];

    OBASSERT(headerContentInfo != nil);
    headerContentInfo->schedulingInfo.priority = [description intForKey:@"priority"];
    headerContentInfo->schedulingInfo.maximumSimultaneousThreadsInGroup = [description intForKey:@"maximumSimultaneousThreadsInGroup"];
}

+ (OWContentInfo *)topLevelActiveContentInfo;
{
    return topLevelActiveContentInfo;
}

// NB: "name" will be presented to user, and therefore must be a localized string
+ (OWContentInfo *)headerContentInfoWithName:(NSString *)name;
{
    OWContentInfo *newContentInfo;

    OBPRECONDITION(name != nil);
    [headerContentInfoLock lock];
    
    newContentInfo = [headerContentInfoDictionary objectForKey:name];
    if (!newContentInfo) {
        NS_DURING {
            
            newContentInfo = [[self alloc] initWithContent:nil];
    
            // OWTask object is permanent header
            [[OWTask alloc] initWithName:name contentInfo:newContentInfo parentContentInfo:topLevelActiveContentInfo];
    
            newContentInfo->flags.isHeader = YES;
    
            // newContentInfo is permanent, also
            [headerContentInfoDictionary setObject:newContentInfo forKey:name];

        } NS_HANDLER {
            [headerContentInfoLock unlock];
            NSLog(@"%s %@ : %@", _cmd, name, localException);
            [newContentInfo release];
            [localException raise];
        } NS_ENDHANDLER;
        
        [newContentInfo release];
    }
    
    [headerContentInfoLock unlock];

    OBPOSTCONDITION(newContentInfo != nil);
    return newContentInfo;
}


+ (OWContentInfo *)orphanParentContentInfo;
{
    static OWContentInfo *orphanParentContentInfo = nil;
    
    if (orphanParentContentInfo == nil)
        orphanParentContentInfo = [self headerContentInfoWithName:NSLocalizedStringFromTableInBundle(@"Closing", @"OWF", [OWTask bundle], "contentinfo name of processes which have no parents")];

    return orphanParentContentInfo;
}


+ (NSArray *)allActiveTasks;
{
    NSArray *copiedArray;

    [allActiveTasksLock lock];
    copiedArray = [NSArray arrayWithArray:allActiveTasks];
    [allActiveTasksLock unlock];
    
    return copiedArray;
}

// Init and dealloc

- initWithContent:(OWContent *)aContent;
{
    return [self initWithContent:aContent typeString:nil];
}

- initWithContent:(OWContent *)aContent typeString:(NSString *)aType;
{
    if (![super init])
        return nil;

    nonretainedContent = aContent;
    
    typeString = [aType copy];

    tasksLock = [[NSLock alloc] init];
    childTasksLock = [[NSLock alloc] init];
    childFossilsLock = [[NSLock alloc] init];
    activeChildTasksLock = [[NSLock alloc] init];
    addressLock = [[NSLock alloc] init];
    flagsLock = [[NSLock alloc] init];

    tasks = [[NSMutableArray alloc] init];
    childTasks = [[NSMutableArray alloc] init];
    activeChildTasks = [[NSMutableArray alloc] init];

    workToBeDoneIncludingChildren = 0;
    schedulingInfo.group = self;
    schedulingInfo.priority = OFMediumPriority;
    schedulingInfo.maximumSimultaneousThreadsInGroup = 4;

    return self;
}

- (void)dealloc;
{
    OBPRECONDITION(nonretainedContent == nil);
    OBPRECONDITION([tasks count] == 0);
    OBPRECONDITION([childTasks count] == 0);
    OBPRECONDITION([activeChildTasks count] == 0);

    [typeString release];
    [tasksLock release];
    [childTasksLock release];
    [childFossilsLock release];
    [activeChildTasksLock release];
    [addressLock release];
    [flagsLock release];
    [tasks release];
    [childTasks release];
    [activeChildTasks release];
    [childFossils release];

    [address release];

    [super dealloc];
}

// Actions

// Content

- (OWContent *)content;
{
    return [[nonretainedContent retain] autorelease];
}

- (void)nullifyContent;
{
    nonretainedContent = nil;
    [[self childTasks] makeObjectsPerformSelector:@selector(parentContentInfoLostContent)];
    [self _treeActiveStatusMayHaveChanged];
}

// Info

- (NSString *)typeString;
{
    return [[typeString copy] autorelease];
}

- (BOOL)isHeader;
{
    return ( flags.isHeader ? YES : NO );
}

- (void)setAddress:(OWAddress *)newAddress;
{
    [addressLock lock];
    if (address != newAddress) {
        [address release];
        address = [newAddress retain];
    }
    [addressLock unlock];
}

- (OWAddress *)address;
{
    OWAddress *snapshotAddress;

    [addressLock lock];
    snapshotAddress = [address retain];
    [addressLock unlock];
    return [snapshotAddress autorelease];
}



// Pipelines

- (NSArray *)tasks;
{
    NSArray *copiedArray;

    [tasksLock lock];
    copiedArray = [NSArray arrayWithArray:tasks];
    [tasksLock unlock];
    return copiedArray;
}

- (void)addTask:(OWTask *)aTask;
{
    [tasksLock lock];
    OBPRECONDITION([tasks indexOfObjectIdenticalTo:aTask] == NSNotFound);
    [tasks addObject:aTask];
    [tasksLock unlock];
}

- (void)removeTask:(OWTask *)aTask;
{
    unsigned int index;

    [tasksLock lock];
    index = [tasks indexOfObjectIdenticalTo:aTask];
    OBPRECONDITION(index != NSNotFound);
    if (index != NSNotFound) // Belt *and* suspenders.
        [tasks removeObjectAtIndex:index];
    [tasksLock unlock];
}


// Children tasks

- (void)addChildTask:(OWTask *)aTask;
{
    [childTasksLock lock];
    OBPRECONDITION([childTasks indexOfObjectIdenticalTo:aTask] == NSNotFound);
    [childTasks addObject:aTask];
    [childTasksLock unlock];
}

- (void)removeChildTask:(OWTask *)aTask;
{
    unsigned int index;

    [childTasksLock lock];
    index = [childTasks indexOfObjectIdenticalTo:aTask];
    OBPRECONDITION(index != NSNotFound);
    if (index != NSNotFound) // Belt *and* suspenders.
        [childTasks removeObjectAtIndex:index];
    [childTasksLock unlock];
}

- (NSArray *)childTasks;
{
    NSArray *copiedArray;

    [childTasksLock lock];
    copiedArray = [NSArray arrayWithArray:childTasks];
    [childTasksLock unlock];
    return copiedArray;
}

- (OWTask *)childTaskAtIndex:(unsigned int)childIndex;
{
    OWTask *childTask = nil;

    [childTasksLock lock];
    if (childIndex < [childTasks count])
        childTask = [[childTasks objectAtIndex:childIndex] retain];
    [childTasksLock unlock];
    return [childTask autorelease];
}

- (unsigned int)childTasksCount;
{
    unsigned int childTasksCount;

    [childTasksLock lock];
    childTasksCount = [childTasks count];
    [childTasksLock unlock];
    return childTasksCount;
}

- (int)workDoneByChildTasks;
{
    int work;
    
    if (flags.wasActiveOnLastCheck) {
        NSArray *childrenCopy;
        int taskIndex;

        [childTasksLock lock];
        childrenCopy = [[NSArray alloc] initWithArray:childTasks];
        [childTasksLock unlock];

        work = 0;
        taskIndex = [childrenCopy count];
        while (taskIndex--)
            work += [[childrenCopy objectAtIndex:taskIndex] workDoneIncludingChildren];
        [childrenCopy release];
    } else
        work = 0;

    return work;
}

- (int)workToBeDoneByChildTasks;
{
    int work;
    
    if (flags.wasActiveOnLastCheck) {
        NSArray *childrenCopy;
        int taskIndex;

        [childTasksLock lock];
        childrenCopy = [[NSArray alloc] initWithArray:childTasks];
        [childTasksLock unlock];

        work = 0;
        taskIndex = [childrenCopy count];
        while (taskIndex--)
            work += [[childrenCopy objectAtIndex:taskIndex] workToBeDoneIncludingChildren];
        [childrenCopy release];
        workToBeDoneIncludingChildren = work;
    } else
        work = 0;

    return work;
}

- (void)calculateDeadPipelines:(unsigned int *)deadPipelines totalPipelines:(unsigned int *)totalPipelines;
{
    NSArray *childrenCopy;
    unsigned int taskIndex;

    [childTasksLock lock];
    childrenCopy = [[NSArray alloc] initWithArray:childTasks];
    [childTasksLock unlock];

    taskIndex = [childrenCopy count];
    while (taskIndex--)
        [[childrenCopy objectAtIndex:taskIndex] calculateDeadPipelines:deadPipelines totalPipelines:totalPipelines];
    [childrenCopy release];
}

- (void)addChildFossil:(id <NSObject>)childFossil;
{
    [childFossilsLock lock];
    if (childFossils == nil)
        childFossils = [[NSMutableArray alloc] init];
    [childFossils addObject:childFossil];
    [childFossilsLock unlock];
}

// Active tree

- (BOOL)treeHasActiveChildren;
{
    return [self activeChildTasksCount] > 0;
}

- (void)addActiveChildTask:(OWTask *)aTask;
{
    BOOL treeActiveStatusMayHaveChanged;

    [activeChildTasksLock lock];
    OBPRECONDITION([activeChildTasks indexOfObjectIdenticalTo:aTask] == NSNotFound);

    [allActiveTasksLock lock];
    // Note: aTask may already be present in allActiveTasks, but we'll remove all instances later as necessary
    [allActiveTasks addObject:aTask];
    [allActiveTasksLock unlock];
        
    // Member, not subclass
    if ([aTask isMemberOfClass:[OWTask class]])
        // If we're at the top level, sort the OWTask headers by priority so they don't jump around as they appear and disappear.  (eg, "Saving files, Web pages, Downloads,...")
        [activeChildTasks insertObject:aTask inArraySortedUsingSelector:@selector(comparePriority:)];
    else
        [activeChildTasks addObject:aTask];
    treeActiveStatusMayHaveChanged = [activeChildTasks count] == 1;
    [activeChildTasksLock unlock];
    if (treeActiveStatusMayHaveChanged)
        [self _treeActiveStatusMayHaveChanged];
    [OWPipeline activeTreeHasChanged];
}

- (void)removeActiveChildTask:(OWTask *)aTask;
{
    BOOL treeActiveStatusMayHaveChanged;
    unsigned int index;

    [activeChildTasksLock lock];
    
    [allActiveTasksLock lock];
    index = [allActiveTasks indexOfObjectIdenticalTo:aTask];
    OBPRECONDITION(index != NSNotFound);
    if (index != NSNotFound) {
        // We used to assert that index != NSNotFound, but we were getting exceptions.
        [allActiveTasks removeObjectAtIndex:index];
    }
    [allActiveTasksLock unlock];

    index = [activeChildTasks indexOfObjectIdenticalTo:aTask];
    OBPRECONDITION(index != NSNotFound);
    if (index != NSNotFound) {
        // We used to assert that index != NSNotFound, but we were getting exceptions.
        [activeChildTasks removeObjectAtIndex:index];
    }
    treeActiveStatusMayHaveChanged = [activeChildTasks count] == 0;
    [activeChildTasksLock unlock];
    if (treeActiveStatusMayHaveChanged)
        [self _treeActiveStatusMayHaveChanged];
    [OWPipeline activeTreeHasChanged];
}

- (NSArray *)activeChildTasks;
{
    NSArray *childrenCopy;

    [activeChildTasksLock lock];
    childrenCopy = [[NSArray alloc] initWithArray:activeChildTasks];
    [activeChildTasksLock unlock];
    return [childrenCopy autorelease];
}

- (OWTask *)activeChildTaskAtIndex:(unsigned int)childIndex;
{
    OWTask *activeChildTask = nil;

    [activeChildTasksLock lock];
    if (childIndex < [activeChildTasks count])
        activeChildTask = [[activeChildTasks objectAtIndex:childIndex] retain];
    [activeChildTasksLock unlock];
    return [activeChildTask autorelease];
}

- (unsigned int)activeChildTasksCount;
{
    unsigned int activeChildTasksCount;

    [activeChildTasksLock lock];
    activeChildTasksCount = [activeChildTasks count];
    [activeChildTasksLock unlock];
    return activeChildTasksCount;
}

- (void)abortActiveChildTasks;
{
    NSArray *activeChildrenCopy;

    [activeChildTasksLock lock];
    activeChildrenCopy = [[NSArray alloc] initWithArray:activeChildTasks];
    [activeChildTasksLock unlock];

    [activeChildrenCopy makeObjectsPerformSelector:@selector(abortTreeActivity)];
    [activeChildrenCopy release];
}

- (NSTimeInterval)timeSinceTreeActivationIntervalForActiveChildTasks;
{
    NSTimeInterval maxTimeInterval = 0.0;

    if (flags.wasActiveOnLastCheck) {
        NSArray *childrenCopy;
        int taskIndex;

        [childTasksLock lock];
        childrenCopy = [[NSArray alloc] initWithArray:childTasks];
        [childTasksLock unlock];
        
        taskIndex = [childrenCopy count];
        while (taskIndex--)
            maxTimeInterval = MAX(maxTimeInterval, [[childrenCopy objectAtIndex:taskIndex] timeSinceTreeActivationInterval]);
        [childrenCopy release];
    }
    return maxTimeInterval;
}

- (NSTimeInterval)estimatedRemainingTreeTimeIntervalForActiveChildTasks;
{
    NSTimeInterval maxTimeInterval = 0.0;

    if (flags.wasActiveOnLastCheck) {
        NSArray *childrenCopy;
        int taskIndex;

        [childTasksLock lock];
        childrenCopy = [[NSArray alloc] initWithArray:childTasks];
        [childTasksLock unlock];
        
        taskIndex = [childrenCopy count];
        while (taskIndex--)
            maxTimeInterval = MAX(maxTimeInterval, [[childrenCopy objectAtIndex:taskIndex] estimatedRemainingTreeTimeInterval]);
        [childrenCopy release];
    }
    return maxTimeInterval;
}


// OFMessageQueue protocol helpers

- (OFMessageQueueSchedulingInfo)messageQueueSchedulingInfo;
{
    if (!flags.isHeader) {
        OWTask *taskWithLowestPriority = [self _taskWithLowestPriority];
        if (taskWithLowestPriority)
            return [taskWithLowestPriority messageQueueSchedulingInfo];
    }
    return schedulingInfo;
}

// OBObject subclass

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;

    debugDictionary = [super debugDictionary];

    // NOTE: Not thread-safe
    if (nonretainedContent)
        [debugDictionary setObject:[(OBObject *)nonretainedContent shortDescription] forKey:@"nonretainedContent"];
    if (tasks)
        [debugDictionary setObject:[NSString stringWithFormat:@"0x%x", tasks] forKey:@"tasks"];
    if (childTasks)
        [debugDictionary setObject:childTasks forKey:@"childTasks"];
    if (activeChildTasks)
        [debugDictionary setObject:activeChildTasks forKey:@"activeChildTasks"];
    if (typeString)
        [debugDictionary setObject:typeString forKey:@"typeString"];
    if (address)
        [debugDictionary setObject:[address addressString] forKey:@"address"];
    [debugDictionary setBoolValue:flags.isHeader forKey:@"isHeader"];
    [debugDictionary setBoolValue:flags.wasActiveOnLastCheck forKey:@"wasActiveOnLastCheck"];

    return debugDictionary;
}

@end

@implementation OWContentInfo (Private)

- (void)_treeActiveStatusMayHaveChanged;
{
    BOOL treeHasActiveChildren;
    BOOL flagChanged = NO;

    treeHasActiveChildren = [self treeHasActiveChildren];
    [flagsLock lock];
    if (treeHasActiveChildren != flags.wasActiveOnLastCheck) {
        flagChanged = YES;
        flags.wasActiveOnLastCheck = treeHasActiveChildren;
    }
    [flagsLock unlock];
    if (flagChanged) {
        [[self tasks] makeObjectsPerformSelector:@selector(treeActiveStatusMayHaveChanged)];
    }

    // Are we dead, but just don't know it yet?
    if (treeHasActiveChildren && !flags.isHeader && !nonretainedContent && [[self childTasks] count] == 0) {
        NSArray *oldTasks;

        [[self retain] autorelease];
        [tasksLock lock];
        oldTasks = tasks;
        tasks = nil;
        [tasksLock unlock];
        [oldTasks makeObjectsPerformSelector:@selector(nullifyContentInfo)];
        [oldTasks release];
    }
}

- (OWTask *)_taskWithLowestPriority;
{
    unsigned int taskCount;
    OWTask *taskWithLowestPriority;

    [tasksLock lock];
    taskCount = [tasks count];
    switch (taskCount) {
        case 0:
            taskWithLowestPriority = nil;
            break;
        case 1: // Common optimization
            taskWithLowestPriority = [[[tasks objectAtIndex:0] retain] autorelease];
            break;
        default:
            taskWithLowestPriority = [[[tasks objectAtIndex:[self _indexOfTaskWithLowestPriority]] retain] autorelease];
            break;
    }
    [tasksLock unlock];
    return taskWithLowestPriority;
}

- (unsigned int)_indexOfTaskWithLowestPriority;
    // Tasks MUST be locked before entering this routine.
{
    unsigned int lowestPriority;
    unsigned int lowestPriorityTaskIndex;
    unsigned int taskIndex;

    OBPRECONDITION(!flags.isHeader);

    taskIndex = [tasks count];
    if (taskIndex == 1)
        return 0;
    
    lowestPriority = INT_MAX;
    lowestPriorityTaskIndex = NSNotFound;

    while (taskIndex--) {
        OWTask *task = [tasks objectAtIndex:taskIndex];
        unsigned int taskPriority = [task messageQueueSchedulingInfo].priority;
        if (taskPriority < lowestPriority) {
            lowestPriorityTaskIndex = taskIndex;
            lowestPriority = taskPriority;
        }
    }

    return lowestPriorityTaskIndex;
}

@end


@implementation OWTopLevelActiveContentInfo

- (void)_treeActiveStatusMayHaveChanged;
{
    BOOL treeHasActiveChildren;
    BOOL flagChanged = NO;

    [flagsLock lock];
    treeHasActiveChildren = [self treeHasActiveChildren];
    if (treeHasActiveChildren != flags.wasActiveOnLastCheck) {
        flagChanged = YES;
        flags.wasActiveOnLastCheck = treeHasActiveChildren;
    }
    [flagsLock unlock];
    if (flagChanged) {
        if (treeHasActiveChildren) {
            [OWPipeline queueSelector:@selector(startActiveStatusUpdateTimer)];
        } else {
            [OWPipeline queueSelector:@selector(stopActiveStatusUpdateTimer)];
        }
    }
}

@end
