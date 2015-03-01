// Copyright 2003-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OWProcessorCacheArc.h"

#import <OmniBase/rcsid.h>
#import <OmniBase/assertions.h>
#import <Foundation/Foundation.h>
#import <OmniFoundation/OmniFoundation.h>

#import "OWAddress.h"
#import "OWCacheControlSettings.h"
#import "OWContent.h"
#import "OWContentCacheGroup.h"
#import "OWContentInfo.h"
#import "OWContentType.h"
#import "OWContentTypeLink.h"
#import "OWDocumentTitle.h"
#import "OWMemoryCache.h"
#import "OWPipeline.h"
#import "OWProcessor.h"
#import "OWProcessorCache.h"
#import "OWProcessorDescription.h"
#import "OWStaticArc.h"
#import "OWURL.h"

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Pipelines.subproj/OWProcessorCacheArc.m 68913 2005-10-03 19:36:19Z kc $");

@interface OWProcessorCacheArc (Private) <OWPipelineDeallocationObserver>
- (BOOL)_startProcessor;
- (void)_loadAndProcess;
- (id)_contextObjectForKey:(NSString *)key;
- (void)_adjustDates;
- (void)_unlockAndPostInfo:(NSMutableDictionary *)statusInfo;
- (void)_clearContext;
@end

@implementation OWProcessorCacheArc

- (id)initWithSource:(OWContent *)sourceEntry link:(OWContentTypeLink *)aLink inCache:(OWProcessorCache *)aCache forPipeline:(OWPipeline *)owningPipeline;
{
    if (![super init])
        return nil;

    OFWeakRetainConcreteImplementation_INIT;

    OFSimpleLockInit(&displayablesSimpleLock);
    
    cacheControl = [[OWCacheControlSettings alloc] init];
    owner = [aCache retain];
    source = [sourceEntry retain];
    object = nil;
    link = [aLink retain];
    lock = [[NSLock alloc] init];
    processor = nil;
    dependentContext = [[NSMutableDictionary alloc] init];
    cachedTaskInfo = nil;
    auxiliaryContent = [[NSMutableArray alloc] init];
    previousStatus = OWProcessorNotStarted;
    flags.state = ArcStateInitial;
    observers = OFCreateNonOwnedPointerArray();
    context = [owningPipeline weakRetain];
    OBASSERT(context != nil);
    [context addDeallocationObserver:self];

#warning TODO [wiml nov2003] - clumsy
    // We want to know whether the result might be "source" content. This is ugly --- we should probably put a flag on OWContentTypeLink to indicate source-ness.
    NSArray *parallelLinks = [[link sourceContentType] directTargetContentTypes];
    flags.possiblyProducesSource = NO;
    unsigned linkIndex, linkCount = [parallelLinks count];
    for(linkIndex = 0; linkIndex < linkCount; linkIndex ++) {
        OWContentTypeLink *parallelLink = [parallelLinks objectAtIndex:linkIndex];

        if ([parallelLink processorDescription] == [link processorDescription] &&
            [parallelLink targetContentType] == [OWContentType sourceContentType]) {
            flags.possiblyProducesSource = YES;
            break;
        }
    }

    return self;
}

- (void)dealloc;
{
    OFSimpleLockFree(&displayablesSimpleLock);

    [cachedTaskInfo release];
    cachedTaskInfo = nil;

    OBASSERT(processor == nil); // Shouldn't this be true?  Well, just in case it's not, let's go ahead and test...
    if (processor != nil) {
        [processor abortProcessing];
        [processor autorelease];
        processor = nil;
    }

    // We'd better be either unstarted or finished at this point.
    OBASSERT(flags.state == ArcStateInitial || flags.state == ArcStateRetired);

    // Any observers should have already removed themselves from our list by now.
    OBASSERT(CFArrayGetCount((CFMutableArrayRef)observers) == 0);
    CFRelease(observers);

    OBASSERT(context == nil);
    [source release];
    source = nil;
    [object release];
    object = nil;
    [owner release];
    [link release];
    [lock release];
    [dependentContext release];
    [processStarted release];
    [processGotResponse release];
    [cacheControl release];
    [arcCreationDate release];
    OBASSERT(context == nil); // Cleared by _clearContext:
    [firstBytesDate release];
    [auxiliaryContent release];

    [super dealloc];
}

OFWeakRetainConcreteImplementation_IMPLEMENTATION;

- (unsigned)hash
{
    // NB: The pipeline lock is not necesarily held at this point.

    return /* [source hash] ^ */ [link hash];
}

- (BOOL)isEqual:(id)anotherObject;
{
    OWProcessorCacheArc *otherProcCacheArc;

    // NB: The pipeline lock is not necesarily held at this point.

    if (anotherObject == self)
        return YES;
    if (anotherObject == nil)
        return NO;
    if ([anotherObject class] != isa)
        return NO;
    otherProcCacheArc = anotherObject;

    if (![source isEqual:otherProcCacheArc->source])
        return NO;
    if (![link isEqual:(otherProcCacheArc->link)])
        return NO;

    if (processor != nil && otherProcCacheArc->processor != nil && processor != otherProcCacheArc->processor)
        return NO;
    if (object != nil && otherProcCacheArc->object != nil &&
        ![object isEqual:otherProcCacheArc->object])
        return NO;

    return YES;
}

- (OWContentType *)expectedResultType
{
    ASSERT_OWPipeline_Locked();

    if (object != nil)
        return [object contentType];

    return [link targetContentType];
}

- (float)expectedCost
{
    switch([self status]) {
        case OWProcessorNotStarted:
            return [link cost];
        case OWProcessorStarting:
        case OWProcessorQueued:
        default:
            return [link cost] * (15./16.);
        case OWProcessorRunning:
            return [link cost] * 0.5;
        case OWProcessorAborting:
            return 1e6;
        case OWProcessorRetired:
            return [link cost] * (1./16.);
    }
}

- (OWProcessorDescription *)processorDescription
{
    return [link processorDescription];
}

- (unsigned)invalidInPipeline:(OWPipeline *)pipeline
{
    OBPRECONDITION(cacheControl != nil);

    BOOL isOwnedByPipeline;
    id requestedCacheControl;
    unsigned invalidity = 0;
    BOOL complete, amError;

    isOwnedByPipeline = [self isOwnedByPipeline:pipeline];
    requestedCacheControl = [pipeline contextObjectForKey:OWCacheArcCacheBehaviorKey];

    ASSERT_OWPipeline_Locked();

    [lock lock];

    complete = ( flags.state == ArcStateRetired );


    if (requestedCacheControl) {
        if ([requestedCacheControl isEqual:OWCacheArcForbidNetwork]) {
            if ([[link processorDescription] usesNetwork] && !complete)
                invalidity |= OWCacheArcInvalidContext;
        }

        if (!isOwnedByPipeline &&
            ([requestedCacheControl isEqual:OWCacheArcReload] ||
             [requestedCacheControl isEqual:OWCacheArcRevalidate])) {
            // If we were started by another pipeline, but this pipeline is trying to reload/revalidate, we might not be applicable.
#warning not actually the right test to use here I think
#define EPSILON (0.1)
            NSTimeInterval deltaT;
            if (processStarted != nil &&
                ( deltaT = [[pipeline fetchDate] timeIntervalSinceDate:processStarted] ) > EPSILON) {
                //                    NSLog(@"%@ suckage? dT=%.2f owner=%@ caller=%@", OBShortObjectDescription(self), deltaT, OBShortObjectDescription(context), OBShortObjectDescription(pipeline));
                invalidity |= OWCacheArcStale;
            }
        }
    }
    if (isOwnedByPipeline) {
        [lock unlock];
        return invalidity;
    }

    if (cacheControl->noCache && complete)
        invalidity |= OWCacheArcNotReusable;
    if (cacheControl->mustRevalidate)
        invalidity |= OWCacheArcStale;
    amError = flags.objectIsError? YES : NO;

    if (flags.havePassedOn)
        invalidity |= OWCacheArcStale;
    
    OFForEachObject([dependentContext keyEnumerator], NSString *, contextKey) {
        id myValue, pipelineValue;
        BOOL matches = YES;

        myValue = [dependentContext objectForKey:contextKey];
        pipelineValue = [pipeline contextObjectForKey:contextKey arc:self];
        if ([myValue isNull]) {
            if (pipelineValue != nil)
                matches = NO;
        } else {
            if (![myValue isEqual:pipelineValue])
                matches = NO;
        }
        if (!matches) {
            // NSLog(@"-[%@ %s]: rejecting, key=%@, mine=%@, pipeline=%@", [self shortDescription], _cmd, contextKey, myValue, pipelineValue);
            invalidity |= OWCacheArcInvalidContext;
            break;
        }
    }

    [lock unlock];

    if (amError) {
        NSNumber *useCachedErrorContent = [context contextObjectForKey:OWCacheArcUseCachedErrorContentKey];
        if (useCachedErrorContent != nil && ![useCachedErrorContent boolValue])
            invalidity |= OWCacheArcNeverValid;
    }

#warning other validation
    return invalidity;
}

- (OWCacheArcTraversalResult)traverseInPipeline:(OWPipeline *)pipeline
{
    OWCacheArcTraversalResult result;
    
    ASSERT_OWPipeline_Locked();

    [lock lock];
    
    OBASSERT(!flags.havePassedOn);
    OBINVARIANT(flags.state == ArcStateRunning || processor == nil);

    if (object != nil) {
        [lock unlock];
        return OWCacheArcTraversal_HaveResult;
    }

    OWPipeline *oldTask = nil;
    
    if (cachedTaskInfo == nil || cachedTaskPriority > [pipeline messageQueueSchedulingInfo].priority) {
        cachedTaskPriority = [pipeline messageQueueSchedulingInfo].priority;
        
        // Save off old task so that we can release it outside the lock (and avoid a deadlock)
        oldTask = [cachedTaskInfo retain];
        
        [cachedTaskInfo release];
        cachedTaskInfo = [pipeline retain];
    }

    if (flags.state == ArcStateInitial) {
        BOOL started;

        /* Don't let a pipeline that isn't our preferred pipeline start us. Otherwise, we're likely to waste time producing content our 'context' pipeline would want, instead of producing the content that the pipeline that started us would want. */
        if (context != pipeline) {
            [lock unlock];
            [oldTask release];
            return OWCacheArcTraversal_Failed;
        }

        [lock unlock];
        
        started = [self _startProcessor];
        
        if (!started) {
            [oldTask release];
            return OWCacheArcTraversal_Failed;
        }
        [lock lock];
    }

    if (object != nil)
        result = OWCacheArcTraversal_HaveResult;
    else if (flags.state == ArcStateRetired || [processor status] == OWProcessorAborting)
        result = OWCacheArcTraversal_Failed;
    else
        result = OWCacheArcTraversal_WillNotify;

    [lock unlock];
    [oldTask release]; // Retained inside the lock -- we release it outside the lock to avoid recursive deadlocks

    return result;
}

- (BOOL)abortArcTask
{
    OWProcessor *myProcessor;

    [lock lock];
    
    OBINVARIANT(flags.state == ArcStateRunning || processor == nil);

#ifdef DEBUG_wiml
    NSLog(@"%@ %s - state=%d processor=%@", OBShortObjectDescription(self), _cmd, flags.state, processor);
#endif

    if (flags.state == ArcStateLoadingBundle) {
        // Uh, this one is tricky. We've dispatched an invocation to load the bundle and then start the processor; we need to tell it not to run the processor after all. We do that by setting our state directly to Retired.
        flags.state = ArcStateRetired;
        [lock unlock];
        return YES;
    }

    if (processor == nil) {
        [lock unlock];
        return NO;
    }

    OBASSERT(flags.state == ArcStateRunning);  // If we have a processor, we ought to be in the Running state.

#ifdef DEBUG_wiml
    NSLog(@"%@ %s - processor status is %d", OBShortObjectDescription(self), _cmd, [processor status]);
#endif
    switch ([processor status]) {
        case OWProcessorStarting:
        case OWProcessorQueued:
        case OWProcessorRunning:
            myProcessor = [processor retain];
            [lock unlock];
            [myProcessor autorelease];
            [myProcessor abortProcessing];
            return YES;
        default:
            OBASSERT_NOT_REACHED("Unknown processor status");
        case OWProcessorAborting:
        case OWProcessorRetired:
            [lock unlock];
            return NO;
    }
}

- (enum _OWProcessorStatus)status
{
    enum _OWProcessorStatus result;

    [lock lock];
    if (processor) {
        result = [processor status];
    } else {
        switch (flags.state) {
            case ArcStateInitial:
                result = OWProcessorNotStarted;
                break;
            case ArcStateStarting:
            case ArcStateLoadingBundle:
                result = OWProcessorStarting;
                break;
            case ArcStateRetired:
                result = OWProcessorRetired;
                break;
            default: // shouldn't happen
                result = OWProcessorAborting;
                break;
        }
    }
    [lock unlock];

    return result;
}

- (NSString *)statusString;
{
    OWProcessor *myProcessor;
    NSString *processorStatusString;

    myProcessor = nil;

    [lock lock];
    if (processor)
        myProcessor = [processor retain];
    [lock unlock];

    if (myProcessor)
        processorStatusString = [myProcessor statusString];
    else
        processorStatusString = nil;
    [myProcessor release];

    return processorStatusString;
}

- (BOOL)isOwnedByPipeline:(OWPipeline *)aContext
{
    ASSERT_OWPipeline_Locked();
    if (aContext == nil)
        return NO;
    if (aContext != context)
        return NO;
    return YES;
}

// OWProcessorContext methods

- (OFMessageQueueSchedulingInfo)messageQueueSchedulingInfo;
{
    return [cachedTaskInfo messageQueueSchedulingInfo];
}

- (void)processedBytes:(unsigned int)bytes ofBytes:(unsigned int)newTotalBytes;
{
    BOOL alreadyRetired;

    [lock lock];
    alreadyRetired = (flags.state == OWProcessorRetired);
    [lock unlock];

    if (alreadyRetired) {
        // Normally we should lock around an access to 'processor', but for this test it's ok
        OBASSERT(processor == nil);
        return;
    }

    unsigned int oldBytesProcessed;
    unsigned int oldTotalBytes;

    OFSimpleLock(&displayablesSimpleLock);
    oldBytesProcessed = bytesProcessed;
    oldTotalBytes = totalBytes;

    if (newTotalBytes != NSNotFound)
        totalBytes = newTotalBytes;
    if (!firstBytesDate)
        firstBytesDate = [[NSDate date] retain];

    bytesProcessed = bytes;
    OFSimpleUnlock(&displayablesSimpleLock);

    if ((oldBytesProcessed == 0 && bytesProcessed > 0) || (oldTotalBytes < 10 && totalBytes >= 10) || (bytesProcessed == totalBytes))
        [self processorStatusChanged:processor];
}

- (NSDate *)firstBytesDate;
{
    NSDate *aDate;
    
    OFSimpleLock(&displayablesSimpleLock);
    aDate = [[firstBytesDate retain] autorelease];
    OFSimpleUnlock(&displayablesSimpleLock);
    return aDate;
}

- (unsigned int)bytesProcessed;
{
    return bytesProcessed;
}

- (unsigned int)totalBytes;
{
    return totalBytes;
}

- (void)processorStatusChanged:(OWProcessor *)aProcessor
{
    OBPRECONDITION(aProcessor != nil);

    OWProcessorStatus procStatus;
    int hasThreadChange = 0;
    NSMutableDictionary *noteInfo;

    noteInfo = [NSMutableDictionary dictionary];

    [lock lock];

    // Because of the invariants (see below), this is equivalent to calling [self status], except for two things: 1, we don't re-acquire the lock, which isn't recursive; and 2, it produces useful information if processor==nil (but aProcessor != nil).
    procStatus = [aProcessor status];
    
    if (processor == nil) {
        // Consistency check. If we don't have a processor, then it had better be the case that we've already retired one that looks like the one that's talking to us, and that it's still retired.
        OBASSERT(flags.state == ArcStateRetired);
        OBASSERT([NSStringFromClass([aProcessor class]) isEqual:[link processorClassName]]);
        OBASSERT(procStatus == OWProcessorRetired || procStatus == OWProcessorAborting);
    } else {
        OBASSERT(processor == aProcessor);
    }
    
    if (procStatus == OWProcessorRunning) {
        if (previousStatus != OWProcessorRunning)
            hasThreadChange = +1;
    } else if (previousStatus == OWProcessorRunning)
        hasThreadChange = -1;
    previousStatus = procStatus;

    [noteInfo setIntValue:hasThreadChange forKey:OWCacheArcHasThreadChangeInfoKey defaultValue:0];
    // Note: reading status string from aProcessor rather than processor because aProcessor is guaranteed to be non-nil (see precondition), unlike processor (see above consistency check).  Also, it's faster (since aProcessor is likely to be in a register).
    [noteInfo setObject:[aProcessor statusString] forKey:OWCacheArcStatusStringNotificationInfoKey defaultObject:nil];

    [self _unlockAndPostInfo:noteInfo];
}

- (void)processorDidRetire:(OWProcessor *)aProcessor
{
    int hasThreadChange = 0;
    NSMutableDictionary *info;

    [lock lock];

    if (processor != nil) {
        // A running processor has retired. Make sure that's what we expect to be happening.
        OBASSERT(flags.state == ArcStateRunning);
        OBASSERT(processor == aProcessor);
    } else {
        // We retired before we fully started up our processor or "re-retired" after finishing.
        OBASSERT(flags.state == ArcStateStarting ||
                 flags.state == ArcStateLoadingBundle ||
                 flags.state == ArcStateRetired);
    }

    [processor autorelease];
    processor = nil;
    [cachedTaskInfo autorelease];
    cachedTaskInfo = nil;

    flags.state = ArcStateRetired;

#ifdef OMNI_ASSERTIONS_ON
    if (object != nil) {
#ifdef DEBUG
        if (![object endOfData] && ![[link processorClassName] isEqualToString:@"OWUnknownDataStreamProcessor"])
            NSLog(@"-[%@ %s]: [object endOfData] = 0, self=%@, source=%@", OBShortObjectDescription(self), _cmd, self, source);
#endif
        OBASSERT([object endOfData] || [[link processorClassName] isEqualToString:@"OWUnknownDataStreamProcessor"]);
        OBASSERT([object endOfHeaders]);
    }
#endif

    if (previousStatus == OWProcessorRunning)
        hasThreadChange = -1;
    previousStatus = OWProcessorRetired;

    [self retain];

    info = [[NSMutableDictionary alloc] initWithCapacity:3];
    [info setBoolValue:YES forKey:OWCacheArcIsFinishedNotificationInfoKey];
    [info setIntValue:hasThreadChange forKey:OWCacheArcHasThreadChangeInfoKey defaultValue:0];

    [self _unlockAndPostInfo:info];
    [info release];

    // TODO:  We'd like to remove ourselves from our cache immediately when we retire, but unfortunately our replacement static arc may not have been created and registered with its cache yet (and we don't want a cache miss).
    // [owner removeArc:self];
    [self release];
}

- (void)mightAffectResource:(OWURL *)aResourceLocator;
{
    if (aResourceLocator == nil)
        return;
    
    if ([source isAddress] &&
        ![[aResourceLocator hostname] isEqual:[[[source address] url] hostname]]) {
        NSLog(@"Warning: %@ attempt to invalidate %@ ?",
              [[[source address] url] compositeString],
              [aResourceLocator compositeString]);
    }
    
    [OWContentCacheGroup invalidateResource:[aResourceLocator urlWithoutUsernamePasswordOrFragment] beforeDate:processStarted];
}

- (void)addContent:(OWContent *)someContent fromProcessor:(OWProcessor *)aProcessor
{
    unsigned contentFlags;

    contentFlags = 0;
    if ([someContent isSource])
        contentFlags |= OWProcessorContentIsSource;
    if ([[aProcessor class] processorUsesNetwork])
        contentFlags |= OWProcessorTypeRetrieval;
    else
        contentFlags |= OWProcessorTypeDerived;

    [self addContent:someContent fromProcessor:aProcessor flags:contentFlags];
}

- (void)addContent:(OWContent *)someContent fromProcessor:(OWProcessor *)aProcessor flags:(unsigned)contentFlags;
{
    [OWPipeline lock];
    [lock lock];

    if (flags.state == ArcStateRetired) {
        OBASSERT(processor == nil);
        [lock unlock];
        [OWPipeline unlock];
        return;
    }

    OBASSERT(aProcessor == nil || aProcessor == processor);
    OBINVARIANT(flags.state == ArcStateRunning);

    [object autorelease];
    object = [someContent retain];

    flags.objectIsSource = ( contentFlags & OWProcessorContentIsSource ) ? YES : NO;
    OBASSERT(flags.objectIsSource == [object isSource]);
    OBASSERT( !(flags.objectIsError && !(contentFlags & OWProcessorContentIsError) ) );
    flags.objectIsError = ( contentFlags & OWProcessorContentIsError ) ? YES : NO;
    flags.arcShouldNotBeCachedOnDisk = ( contentFlags & OWProcessorContentNoDiskCache ) ? YES : NO;
    if (!processGotResponse)
        processGotResponse = [[NSDate alloc] init];
    [self _adjustDates];

    if (contentFlags & OWProcessorTypeRetrieval) {
        arcType = OWCacheArcRetrievedContent;
    } else if (contentFlags & OWProcessorTypeDerived) {
        arcType = OWCacheArcDerivedContent;
    } else {
        // Handle other arc-type flags, e.g. OWProcessorTypeAuxiliary, here if they get defined
        OBASSERT_NOT_REACHED("No arc type specified");
    }

    if (contentFlags & OWProcessorTypeAction)
        flags.traversalIsAction = 1;

    if (CFArrayGetCount((CFMutableArrayRef)observers) == 0) {
        [lock unlock];
    } else {
        NSMutableDictionary *info = [[NSMutableDictionary alloc] init];

        [info setBoolValue:flags.objectIsSource forKey:OWCacheArcObjectIsSourceNotificationInfoKey];
        [info setBoolValue:flags.objectIsError forKey:OWCacheArcObjectIsErrorNotificationInfoKey];
        [info setBoolValue:flags.arcShouldNotBeCachedOnDisk forKey:OWCacheArcInhibitDiskCacheNotificationInfoKey];
        if (object)
            [info setObject:object forKey:OWCacheArcObjectNotificationInfoKey];
        [info setObject:self forKey:@"arc"];

        NSArray *observerSnapshot = [[NSArray alloc] initWithArray:observers];

        [lock unlock];

        [OWPipeline postSelector:@selector(arcHasResult:) toPipelines:observerSnapshot withObject:info];

        [info release];
        [observerSnapshot release];
    }

    [OWPipeline unlock];
}

- (void)addRedirectionContent:(OWAddress *)newAddress sameURI:(BOOL)sameObject
{
    OWContent *redirect;

    redirect = [OWContent contentWithAddress:newAddress redirectionFlags:(sameObject? OWProcessorRedirectIsSame : 0) interimContent:nil];

    /// TODO
#warning implement this better
    [self addContent:redirect fromProcessor:nil];
}

- (void)addUnknownContent:(OWContent *)someContent fromProcessor:(OWProcessor *)aProcessor;
{
    [self addContent:[OWContent unknownContentFromContent:someContent] fromProcessor:aProcessor];
}

- (void)extraContent:(OWContent *)someContent fromProcessor:(OWProcessor *)aProcessor forAddress:(OWAddress *)anAddress
{
    NSDictionary *auxContent;

    OBPRECONDITION(someContent != nil);
    OBPRECONDITION(anAddress != nil);

    auxContent = [[NSDictionary alloc] initWithObjectsAndKeys:
        someContent, @"content",
        anAddress, @"address",
        nil];
    [lock lock];
    OBINVARIANT(aProcessor == processor);
    [auxiliaryContent addObject:auxContent];
    [lock unlock];
    [auxContent release];
}

- (void)cacheControl:(OWCacheControlSettings *)control;
{
    OBPRECONDITION(cacheControl != nil);

    [lock lock];
    [cacheControl addSettings:control];
    [self _adjustDates];
    [lock unlock];
}

- (BOOL)resultIsSource
{
    if (object != nil)
        return [object isSource];
    else
        return flags.possiblyProducesSource;
}

- (BOOL)resultIsError
{
    return flags.objectIsError;
}

- (BOOL)shouldNotBeCachedOnDisk
{
    return flags.arcShouldNotBeCachedOnDisk;
}

- (id)contextObjectForKey:(NSString *)contextInformationKey
{
    return [self contextObjectForKey:contextInformationKey isDependency:YES];
}

- (id)contextObjectForKey:(NSString *)contextInformationKey isDependency:(BOOL)depends;
{
    id storedValue;

    [lock lock];
    storedValue = [dependentContext objectForKey:contextInformationKey];
    if (storedValue == nil) {
        [lock unlock];
        storedValue = [self _contextObjectForKey:contextInformationKey];
        [lock lock];

        if (storedValue == nil)
            storedValue = [NSNull null];

        if (depends)
            [dependentContext setObject:storedValue forKey:contextInformationKey];
    }
    [lock unlock];

    if (storedValue == [NSNull null])
        return nil;
    else
        return storedValue;
}

- (OFPreference *)preferenceForKey:(NSString *)preferenceKey;
{
    OFPreference *result;

    result = nil;

    [OWPipeline lock];
    if (context != nil)
        result = [[context preferenceForKey:preferenceKey arc:self] retain];
    else
        result = [[OFPreference preferenceForKey:preferenceKey] retain];
    [OWPipeline unlock];

    return [result autorelease];
}

- (NSArray *)tasks
{
    NSArray *result;

    [lock lock];
    result = (NSArray *)CFArrayCreateCopy(kCFAllocatorDefault, (CFMutableArrayRef)observers);
    [lock unlock];

    return [result autorelease];
}

- (id)promptView
{
    NSEnumerator *taskEnumerator;
    OWPipeline *aTask;
    id <OWOptionalTarget,NSObject> taskTarget;
    id promptView;

    taskEnumerator = [[self tasks] objectEnumerator];
    // TODO - sort the available views cleverly, e.g. return onscreen views in preference to iconified views, return the frontmost of several available windows, and so forth

    while ( (aTask = [taskEnumerator nextObject]) != nil ) {
        if (![aTask isKindOfClass:[OWPipeline class]])
            continue;
        taskTarget = (id <OWOptionalTarget,NSObject>)[aTask target];
        if (!taskTarget || ![taskTarget respondsToSelector:@selector(promptViewForPipeline:)])
            continue;
        promptView = [taskTarget promptViewForPipeline:aTask];
        if (promptView != nil)
            return promptView;
    }

    return nil;
}

- (NSArray *)outerContentInfos
{
    NSMutableSet *seen;
    NSMutableArray *queue, *results;

    queue = [[NSMutableArray alloc] initWithArray:[self tasks]];
    seen = [[NSMutableSet alloc] init];
    results = [[NSMutableArray alloc] init];
    [results autorelease];

    while ([queue count] > 0) {
        OWTask *aTask;
        OWContentInfo *someInfo;

        aTask = [[queue objectAtIndex:0] retain];
        [queue removeObjectAtIndex:0];

        if ([seen containsObject:aTask]) {
            [aTask release];
            continue;
        } else {
            [seen addObject:aTask];
            [aTask release];
        }

        someInfo = [aTask parentContentInfo];
        if (!someInfo || [someInfo isHeader] || ![someInfo address]) {
            OWContentInfo *outerInfo = [aTask contentInfo];
            if (outerInfo && ![outerInfo isHeader]) {
                [results addObject:outerInfo];
            }
        } else {
            [queue addObjectsFromArray:[someInfo tasks]];
        }
    }

    [queue release];
    [seen release];

    return results;
}

- (void)noteErrorName:(NSString *)nonLocalizedErrorName reason:(NSString *)localizedErrorDescription;
{
    NSMutableDictionary *userInfo;

    [lock lock];

    userInfo = [[NSMutableDictionary alloc] initWithCapacity:3];
    if (processor)
        [userInfo setObject:processor forKey:OWCacheArcErrorProcessorNotificationInfoKey];
    if ([NSString isEmptyString:nonLocalizedErrorName])
        nonLocalizedErrorName = @"Error";
    [userInfo setObject:nonLocalizedErrorName forKey:OWCacheArcErrorNameNotificationInfoKey];
    if (localizedErrorDescription)
        [userInfo setObject:localizedErrorDescription forKey:OWCacheArcErrorReasonNotificationInfoKey];
        
    flags.objectIsError = YES;

    [self _unlockAndPostInfo:userInfo];
    [userInfo release];
}

- (BOOL)hadError
{
    return flags.objectIsError;
}

- (NSArray *)entriesWithRelation:(OWCacheArcRelationship)relation
{
    id objets[3];
    unsigned objCount = 0;
    NSArray *result;
    
    if (relation & (OWCacheArcSubject | OWCacheArcSource))
        objets[objCount++] = [source retain];
    if (relation & OWCacheArcObject) {
        [lock lock];
        objets[objCount++] = [object retain];
        [lock unlock];
    }

    result = objCount? [NSArray arrayWithObjects:objets count:objCount] : nil;
    while (objCount)
        [objets[--objCount] release];

    return result;
}

- (OWCacheArcType)arcType { return arcType; }
- (OWContent *)source    { return source;  }
- (OWContent *)subject   { return source;  }    // Our subject is the same as our source
- (OWContent *)object    { return object;  }
- (NSDate *)creationDate { return arcCreationDate; }

- (OWStaticArc *)addToCache:(id <OWCacheArcProvider,OWCacheContentProvider>)actualCache
{
    OBPRECONDITION(cacheControl != nil);

    struct OWStaticArcInitialization arcProperties;
    OWStaticArc *newArc, *addedArc;
    NSObject *releaseMe;

    // Check whether our content is acceptable to the target cache
    if (![actualCache canStoreContent:source] || ![actualCache canStoreContent:object])
        return nil;

    releaseMe = nil;
    NS_DURING;

    bzero(&arcProperties, sizeof(arcProperties));
    arcProperties.source = [actualCache storeContent:source];
    arcProperties.object = [actualCache storeContent:object];
    arcProperties.subject = arcProperties.source;    // We only represent arcs whose subject and source are the same

    arcProperties.contextDependencies = dependentContext;

    // Figure out the effective creation and expiration dates of this arc.

    arcProperties.creationDate = [self creationDate];  // use info maintained by _adjustDates
    if (!arcProperties.creationDate)
        arcProperties.creationDate = [NSDate date];

    // Figure out when to expire (or revalidate) this arc
    if (cacheControl->maxAge) {
        // RFC2616 14.9.3 para 2: max-age takes precedence over Expire
        arcProperties.freshUntil = [arcProperties.creationDate addTimeInterval:[cacheControl->maxAge floatValue]];
    } else if (cacheControl->explicitExpire) {
        arcProperties.freshUntil = [cacheControl->explicitExpire addTimeInterval:clockSkew];
    } else
        arcProperties.freshUntil = nil;

    arcProperties.arcType = arcType;
    arcProperties.resultIsSource = flags.objectIsSource;
    arcProperties.resultIsError = flags.objectIsError;
    arcProperties.shouldNotBeCachedOnDisk = flags.arcShouldNotBeCachedOnDisk;
    arcProperties.nonReusable = ( cacheControl->noCache || cacheControl->mustRevalidate );
    if (flags.traversalIsAction && (cacheControl->explicitExpire == nil))
        arcProperties.nonReusable = YES;

    newArc = [[OWStaticArc alloc] initWithArcInitializationProperties:arcProperties];
    [newArc autorelease];
    addedArc = (OWStaticArc *)[actualCache addArc:newArc];

    /* If we're not representing an error result, then create arcs for any auxiliary content that was produced as well. */
    /* Also: Don't create aux. arcs if we're not reusable, since nobody would ever be able to make use of them. */
    if (!flags.objectIsError && !arcProperties.nonReusable) {
        int auxArcCount, auxArcIndex;

        auxArcCount = [auxiliaryContent count];
        for(auxArcIndex = 0; auxArcIndex < auxArcCount; auxArcIndex ++) {
            NSDictionary *auxArcInfo = [auxiliaryContent objectAtIndex:auxArcIndex];
            OWContent *thisObject, *thisSubject;
            OWStaticArc *auxArc;

            thisObject = [auxArcInfo objectForKey:@"content"];
            thisSubject = [OWContent contentWithAddress:[auxArcInfo objectForKey:@"address"]];

            if (![actualCache canStoreContent:thisObject] || ![actualCache canStoreContent:thisSubject])
                continue;

            arcProperties.arcType = OWCacheArcInformationalHint;
            /* arcProperties.source is already set correctly */
            arcProperties.subject = [actualCache storeContent:thisSubject];
            arcProperties.object = [actualCache storeContent:thisObject];
            /* reusing contextDependencies */
            /* reusing creationDate */
            /* reusing expiration date (freshUntil) --- is this correct? TODO */
            arcProperties.resultIsSource = NO;
            arcProperties.resultIsError = NO;

            auxArc = [[OWStaticArc alloc] initWithArcInitializationProperties:arcProperties];
            releaseMe = auxArc;
            [actualCache addArc:auxArc];
            releaseMe = nil;
            [auxArc release];
        }
    }

    NS_HANDLER {
        [releaseMe release];
        NSLog(@"Exception while caching response: %@", [localException description]);
        return nil;
    } NS_ENDHANDLER;

    OBASSERT(releaseMe == nil);

    flags.havePassedOn = YES;

    return addedArc;
}

- (void)removeFromCache;  // Removes the receiver from the processor cache
{
    [lock lock];
    if (!flags.haveRemovedFromCache) {
        flags.haveRemovedFromCache = YES;
        [lock unlock];
        [owner removeArc:self];
    } else {
        [lock unlock];
    }
}

- (void)invalidateWeakRetains
{
#ifdef DEBUG_wiml
    NSLog(@"-[%@ %s]", OBShortObjectDescription(self), _cmd);
#endif
    [self removeFromCache];
    [self _clearContext];
}

// OBObject subclass

- (NSMutableDictionary *)debugDictionary;
{
    NSMutableDictionary *debugDictionary;
    BOOL didLock;
    
    [[self retain] autorelease];

    didLock = [lock tryLock];

    // WARNING/TODO: This debugDictionary method is not completely threadsafe.

    debugDictionary = [super debugDictionary];
    [debugDictionary takeValue:[link processorDescription] forKey:@"link"];
    [debugDictionary takeValue:source forKey:@"source"];
    if (didLock)
        [debugDictionary takeValue:[processor shortDescription] forKey:@"processor"];
    else
        [debugDictionary takeValue:OBShortObjectDescription(processor) forKey:@"processor"];
    if (didLock || 1)
        [debugDictionary takeValue:[[dependentContext allKeys] description] forKey:@"dependentContext"];
    else
        [debugDictionary takeValue:OBShortObjectDescription(dependentContext) forKey:@"dependentContext"];
    if (didLock)
        [debugDictionary takeValue:object forKey:@"object"];
    else
        [debugDictionary takeValue:OBShortObjectDescription(object) forKey:@"object"];
    [debugDictionary setIntValue:flags.state forKey:@"flags.state"];
    [debugDictionary takeValue:flags.objectIsSource ? @"YES" : @"NO" forKey:@"flags.objectIsSource"];
    [debugDictionary takeValue:flags.objectIsError ? @"YES" : @"NO" forKey:@"flags.objectIsError"];
    [debugDictionary takeValue:flags.arcShouldNotBeCachedOnDisk ? @"YES" : @"NO" forKey:@"flags.arcShouldNotBeCachedOnDisk"];
    [debugDictionary takeValue:flags.possiblyProducesSource ? @"YES" : @"NO" forKey:@"flags.possiblyProducesSource"];
    [debugDictionary takeValue:flags.traversalIsAction ? @"YES" : @"NO" forKey:@"flags.traversalIsAction"];
    [debugDictionary takeValue:flags.havePassedOn ? @"YES" : @"NO" forKey:@"flags.havePassedOn"];
    
    if (didLock)
        [lock unlock];

    return debugDictionary;
}

- (NSString *)shortDescription
{
    return [NSString stringWithFormat:@"<%@: %p (%@)>", NSStringFromClass(isa), self, processor ? NSStringFromClass([processor class]) : [[link processorDescription] processorClassName]];
}

- (NSString *)logDescription
{
    OWAddress *logAddress;
    NSString *logAddressStr;

    if ([source isAddress])
        logAddress = [source address];
    else
        logAddress = [context lastAddress];

    if (logAddress != nil) {
        NSString *addressMethod;

        logAddressStr = [[logAddress url] compositeString];
        addressMethod = [logAddress methodString];
        if (![addressMethod isEqualToString:@"GET"])
            logAddressStr = [NSString stringWithStrings:addressMethod, @" ", logAddressStr, nil];
    } else {
        logAddressStr = @"--";
    }

#ifdef DEBUG
    return [NSString stringWithFormat:@"%@ (%@, %@)", [self shortDescription], [context shortDescription], logAddressStr];
#else
    return [NSString stringWithFormat:@"%@ (%@)", logAddressStr, [[self processorDescription] processorClassName]];
#endif
}

- (void)addArcObserver:(OWPipeline *)anObserver
{
    [lock lock];
    CFArrayAppendValue((CFMutableArrayRef)observers, anObserver);
    [lock unlock];
}

- (void)removeArcObserver:(OWPipeline *)anObserver
{
    [lock lock];
    CFIndex observerIndex = CFArrayGetLastIndexOfValue((CFMutableArrayRef)observers, (CFRange){0, CFArrayGetCount((CFMutableArrayRef)observers)}, anObserver);
    OBASSERT(observerIndex != kCFNotFound);
    if (observerIndex != kCFNotFound)
        CFArrayRemoveValueAtIndex((CFMutableArrayRef)observers, observerIndex);
    CFIndex observerCount = CFArrayGetCount((CFMutableArrayRef)observers);
    [lock unlock];

    // If our last observer goes away while our processor is running or starting (e.g. if someone closes a window while it's loading) we should abort the processor early.
    if (observerCount == 0)
        [self abortArcTask];
}

@end

@implementation OWProcessorCacheArc (Private)

- (BOOL)_startProcessor
{
    BOOL locked, pipelineLocked;
    BOOL success;
    NSObject *releaseMe;
    
    /*
     There are two ways we could enter this method: either directly called from -traverseInPipeline:, or invoked after our processor's bundle was loaded.
     In the first case, our state will be Initial.
     In the second case, our state might have been reset to Retired if our pipeline was canceled, otherwise, it will still be LoadingBundle.
     */

    releaseMe = nil;
    [lock lock];
    locked = YES;

    OBPRECONDITION(flags.state == ArcStateInitial || flags.state == ArcStateLoadingBundle || flags.state == ArcStateRetired);
    OBPRECONDITION(processor == nil);

    if (flags.state == ArcStateRetired) {
        [lock unlock];
        locked = NO;
        return NO;
    }

    // Okay, start 'em up.
    OBPRECONDITION(context != nil);
    OBPRECONDITION(processStarted == nil);
    flags.state = ArcStateStarting;
    pipelineLocked = NO;

    NS_DURING {
        OFBundledClass *processorClassBundle = [[link processorDescription] processorClass];

        if (![processorClassBundle isLoaded]) {
            // Bundle loading involves acquiring enough locks that we can deadlock here if we load now.
            // So we queue that operation (in the main thread, where it wants to be anyway) and tell our caller that we'll produce a result later.
            flags.state = ArcStateLoadingBundle;
            [self _unlockAndPostInfo:nil];
            locked = NO;
            [[OFMessageQueue mainQueue] queueSelector:@selector(_loadAndProcess) forObject:self];
            success = YES;
        } else {
            Class processorClass;

            [lock unlock];
            locked = NO;

            processorClass = [processorClassBundle bundledClass];
            OBASSERT([[link processorDescription] usesNetwork] == [processorClass processorUsesNetwork]);

            [OWPipeline lock];
            pipelineLocked = YES;

            OWProcessor *newProcessor;
            newProcessor = [[processorClass alloc] initWithContent:source context:self];
            if (newProcessor == nil)
                [NSException raise:NSInternalInconsistencyException format:@"Cannot allocate processor for %@", processorClass];

            [lock lock];
            processor = [newProcessor retain];
            releaseMe = newProcessor;
            flags.state = ArcStateRunning;
            processStarted = [[NSDate alloc] init];
            [lock unlock];
            
            [newProcessor startProcessing];
            success = YES;
        }
    } NS_HANDLER {
        OWProcessor *myProcessor;
        
        NSLog(@"Exception raised while starting %@: %@", [link processorClassName], localException);
        [self noteErrorName:[localException name] reason:[localException reason]];

        if (!locked)
            [lock lock];
        myProcessor = [[processor retain] autorelease];
        [lock unlock];
        locked = NO;
        [releaseMe release];

        if (myProcessor) {
            [myProcessor handleProcessingException:localException];
            [myProcessor processAbort];
            [self abortArcTask];
        } else {
            [self processorDidRetire:nil];
        }
        success = NO;
    } NS_ENDHANDLER;

    OBASSERT(!locked);
    if (pipelineLocked)
        [OWPipeline unlock];
    [releaseMe release];
    
    return success;
}

// Invoked in the main thread if -traverseInPipeline: discovers that it needs to load a bundle.
- (void)_loadAndProcess
{
    Class processorClass;

    OBPRECONDITION(processor == nil);

    NS_DURING {
        processorClass = [[[link processorDescription] processorClass] bundledClass];
        
        if (processorClass == Nil) {
            NSString *msg = [NSString stringWithFormat:@"Unable to load bundle for %@", [link processorClassName]];
            NSLog(@"%@: %@", [self logDescription], msg);
            [self noteErrorName:@"BundleLoadError" reason:msg];
        }
    } NS_HANDLER {
        NSLog(@"%@: Exception raised while loading bundle for %@: %@", [self logDescription], [link processorClassName], localException);
        [self noteErrorName:@"BundleLoadError" reason:[localException description]];
        processorClass = Nil;
    } NS_ENDHANDLER;

    if (processorClass == Nil) {
        [self processorDidRetire:nil];
    } else {
        // Go back to a background thread for the actual processing.
        [[OWProcessor processorQueue] queueSelector:@selector(_startProcessor) forObject:self];
    }
}

- (void)_unlockAndPostInfo:(NSMutableDictionary *)statusInfo
{
    if (CFArrayGetCount((CFMutableArrayRef)observers) == 0) {
        [lock unlock];
        return;
    } else {
        NSArray *observerSnapshot = [[NSArray alloc] initWithArray:observers];
        [lock unlock];
        if (statusInfo == nil)
            statusInfo = [NSMutableDictionary dictionary];
        [statusInfo setObject:self forKey:@"arc"];
        [OWPipeline postSelector:@selector(arcHasStatus:) toPipelines:observerSnapshot withObject:statusInfo];
        [observerSnapshot release];
        return;
    }
}

- (id)_contextObjectForKey:(NSString *)key
{
    id theValue;

    [OWPipeline lock];

    if (context == nil) {
        OBASSERT(flags.state == ArcStateRetired); // We expect this to be the only reason we would have no context, and this is the basis of the text in the exception below.  If this assertion fails, just change the message.
#ifdef DEBUG
        NSLog(@"-[%@ %s%@]: warning: context == nil", OBShortObjectDescription(self), _cmd, key);
#endif
        [OWPipeline unlock];
        [NSException raise:@"OWProcessorCacheArcHasRetired" format:@"Processor cache arc has retired, and can therefore provide no context"];
    }

    theValue = [context contextObjectForKey:key arc:self];
    [[theValue retain] autorelease];

    [OWPipeline unlock];

    return theValue;
}

- (void)_adjustDates
{
    OBPRECONDITION(cacheControl != nil);

    NSDate *thisDate;
    NSTimeInterval thisClockSkew;

    thisDate = nil;
    thisClockSkew = 0;

    // Use the server's Date: header, but sanity-check it
    if (cacheControl->serverDate) {
        NSDate *service = [cacheControl->serverDate addTimeInterval:clockSkew];
        if (processStarted)
            service = [service laterDate:processStarted];
        if (processGotResponse)
            service = [service earlierDate:processGotResponse];
        thisClockSkew = [service timeIntervalSinceDate:cacheControl->serverDate];
        thisDate = [service retain];
    } else {
        if (processStarted && processGotResponse) {
            // Heuristic: it probably took us longer to resolve and contact the server than it did for the server to start responding once it found the content, hence the 0.8
            thisDate = [processStarted addTimeInterval:(0.8 * [processGotResponse timeIntervalSinceDate:processStarted])];
        } else if (processGotResponse) {
            thisDate = processGotResponse;
        }
        thisClockSkew = 0;
    }
    if (cacheControl->ageAtFetch != nil) {
        thisDate = [thisDate addTimeInterval: - [cacheControl->ageAtFetch floatValue]];
    }

    if (thisDate) {
        [arcCreationDate release];
        arcCreationDate = [thisDate retain];
        clockSkew = thisClockSkew;
    }
}

- (void)_clearContext;
{
    OWPipeline *cachedPipeline;

    [context removeDeallocationObserver:self];

    [lock lock];
    cachedPipeline = context;
    context = nil;
    [lock unlock];

    [cachedPipeline weakRelease];
}

// OWPipelineDeallocationObservers protocol

- (void)pipelineWillDeallocate:(OWPipeline *)aPipeline;
{
    OBPRECONDITION(aPipeline == context); // Note:  not locking around this assertion because it's safe even if the context should somehow change out from underneath us (which should never happen anyway because, well, that's part of the point of this assertion).
    [self _clearContext];
}

@end
