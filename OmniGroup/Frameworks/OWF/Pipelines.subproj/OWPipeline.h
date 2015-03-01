// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Pipelines.subproj/OWPipeline.h 68913 2005-10-03 19:36:19Z kc $

#import <OWF/OWTask.h>

@class /* Foundation */ NSArray, NSCountedSet, NSConditionLock, NSLock, NSMutableArray, NSMutableDictionary, NSMutableSet, NSNotificationCenter;
@class /* OmniFoundation */ OFInvocation, OFPreference;
@class /* OWF */ OWAddress, OWCacheSearch, OWContentCacheGroup, OWContentInfo, OWHeaderDictionary, OWProcessor, OWPipelineCoordinator, OWURL;

#import <OmniFoundation/OFWeakRetainConcreteImplementation.h>
#import <OWF/OWTargetProtocol.h>
#import <OWF/FrameworkDefines.h>

#define ASSERT_OWPipeline_Locked() OBASSERT([OWPipeline isLockHeldByCallingThread])

typedef enum {
    OWPipelineFollowAction,    // Following a link, submitting a form, etc.
    OWPipelineHistoryAction,   // Retrieving something previously viewed
    OWPipelineReloadAction     // Reloading something previously (or currently) viewed
} OWPipelineAction;

@protocol OWCacheArc, OWPipelineDeallocationObserver;

@interface OWPipeline : OWTask <OFWeakRetain>
{
    OFWeakRetainConcreteImplementation_IVARS;

    // Unless otherwise noted, instance variables are protected by the global pipeline lock.

    id <OWTarget, OFWeakRetain, NSObject> _target; // protected by displayablesSimpleLock

    struct {
        unsigned int pipelineDidBegin: 1;
        unsigned int pipelineDidEnd: 1;
        unsigned int pipelineTreeDidActivate: 1;
        unsigned int pipelineTreeDidDeactivate: 1;
        unsigned int updateStatusForPipeline: 1;
        unsigned int expectedContentDescriptionString: 1;
        unsigned int pipelineHasNewMetadata: 1;
        unsigned int preferenceForKey: 1;
    } targetRespondsTo;               // initialized in -init, and readonly thereafter

    NSMutableDictionary *costEstimates;  // Maps OWContentType to NSNumber. Lazily filled by _traverseArcFromEntry:.
    OWContentCacheGroup *caches;      // List of (id <OWCacheArcProvider>) instances, in search order
    NSMutableSet *rejectedArcs;       // Arcs we've thought about and rejected
    NSMutableArray *followedArcs;     // Arcs we've traversed, corresponding to entries in followedContent
    NSMutableArray *followedContent;  // Content we've found, in traversal order
    NSMutableArray *activeArcs;       // Arcs we've traversed which have not yet retired
    NSMutableSet *followedArcsWithThreads; // Arcs in followedArcs whose state was Running last we checked
    NSMutableArray *givenArcs;        // Arcs provided to us in -init, and considered to be 'free'
    OWCacheSearch *cacheSearch;       // The state of our search for suitable arcs, or nil
    unsigned firstErrorContent;       // Index of first content that's an error or error-result
    NSDictionary *targetAcceptableContentTypes;  // Read-only after -init; no lock required
    
    OWContent *mostRecentAddress;     // Latest content that represents an OWAddress; prot. by contextLock
    unsigned int addressCount;        // The number of addresses we've seen; protected by contextLock
    OWContent *mostRecentlyOffered;   // To avoid offering the same content repeatedly
    id <OWCacheArc> mostRecentArcProducingSource; // Basis for -workDone, -workToBeDone, protected by contextLock
    
    NSLock *contextLock;              // Protects a few ivars. NOTE: This is a 'leaf' lock. It is vital that no other locks be acquired while this lock is held.
    NSMutableDictionary *context;     // Miscellaneous context information. Protected by contextLock
    NSMutableArray *deallocationObservers; // Protected by contextLock

    struct {
        unsigned int contentError:1;
        unsigned int everHadContentError:1;

        unsigned int processingError:1;
        unsigned int delayedForError:1;
        
        // new
        unsigned int traversingLastArc:1;
        unsigned int delayedNotificationWaitingArc:1;

        unsigned int debug:1;
    } flags;
    OFInvocation *continuationEvent;

    NSString *targetTypeFormatString;
    unsigned int maximumWorkToBeDone;
    unsigned int threadsUsedCount;

    NSString *errorNameString;
    NSString *errorReasonString;
    NSDate *errorDelayDate;
}

// For notification of pipeline fetches. Notifications' objects are a pipeline, their info dictionary keys are listed below. 
+ (void)addObserver:(id)anObserver selector:(SEL)aSelector address:(OWAddress *)anAddress;
- (void)addObserver:(id)anObserver selector:(SEL)aSelector;
+ (void)removeObserver:(id)anObserver address:(OWAddress *)anAddress;
+ (void)removeObserver:(id)anObserver;

// Pipeline target management
+ (void)invalidatePipelinesForTarget:(id <OWTarget>)aTarget;
    // Targets call this when they are freed so no pipeline tries to give them content.
+ (void)abortTreeActivityForTarget:(id <OWTarget>)aTarget;
    // Usually called because of user input
+ (void)abortPipelinesForTarget:(id <OWTarget>)aTarget;
    // Only affects the current pipelines for the target, not the their children
    // You probably want to use +abortTreeActivityForTarget: instead.
+ (OWPipeline *)currentPipelineForTarget:(id <OWTarget>)aTarget;
    // Last pipeline that the target accepted content from, in -pipelineBuilt.
+ (NSArray *)pipelinesForTarget:(id <OWTarget>)aTarget;
+ (OWPipeline *)firstActivePipelineForTarget:(id <OWTarget>)aTarget;
+ (OWPipeline *)lastActivePipelineForTarget:(id <OWTarget>)aTarget;

// For notifying groups of pipelines semi-synchronously (locks and invokes in background)
+ (void)postSelector:(SEL)aSelector toPipelines:(NSArray *)pipelines withObject:(NSObject *)arg;

// Status Monitoring
+ (void)activeTreeHasChanged;
+ (void)startActiveStatusUpdateTimer;
+ (void)stopActiveStatusUpdateTimer;

// For sending notification of permanent redirects
// + (void)notePermanentRedirection:(OWAddress *)redirectFrom to:(OWAddress *)redirectTo;

// We currently have a single global lock for cache management.
+ (void)lock;
+ (void)unlock;
+ (BOOL)isLockHeldByCallingThread;

// Utility methods
+ (NSString *)stringForTargetContentOffer:(OWTargetContentOffer)offer;

// Init and dealloc
+ (void)startPipelineWithAddress:(OWAddress *)anAddress target:(id <OWTarget, OFWeakRetain, NSObject>)aTarget;

- (id)initWithContent:(OWContent *)aContent target:(id <OWTarget, OFWeakRetain, NSObject>)aTarget;
- (id)initWithAddress:(OWAddress *)anAddress target:(id <OWTarget, OFWeakRetain, NSObject>)aTarget;

- (id)initWithCacheGroup:(OWContentCacheGroup *)someCaches content:(NSArray *)someContent arcs:(NSArray *)someArcs target:(id <OWTarget, OFWeakRetain, NSObject>)aTarget;  // Designated initializer

// Pipeline management
- (void)startProcessingContent;
- (void)abortTask;

- (void)fetch;

// Target
- (id <OWTarget, OFWeakRetain, NSObject>)target;
- (void)invalidate;
    // Called in +invalidatePipelinesForTarget:, if the pipeline was pointing at the target that wants to be invalidated.
    // Also called in -pipelineBuilt if our target rejects the content we offer and didn't suggest a new target, and in +_target:acceptedContentFromPipeline: on all pipelines created before the parameter that point at the same target (eg, some other pipeline beat you to the punch, sorry, guys).
- (void)parentContentInfoLostContent;
    // When our parent content info's content calls [OWContentInfo nullifyContent], this method will be called on all of the contentInfo's childTasks.  We call the same method on our target if it implements it.  This is currently unused.
- (void)updateStatusOnTarget;
- (void)setErrorName:(NSString *)newName reason:(NSString *)newReason;

// Content

- (id)contextObjectForKey:(NSString *)key;
- (id)contextObjectForKey:(NSString *)key arc:(id <OWCacheArc>)arc;
- (OFPreference *)preferenceForKey:(NSString *)key arc:(id <OWCacheArc>)arc;
- (void)setContextObject:(id)anObject forKey:(NSString *)key;
    // returns the object that's in the context dictionary, whichever one it turns out to be
- (id)setContextObjectNoReplace:(id)anObject forKey:(NSString *)key;
- (NSDictionary *)contextDictionary;
- (void)setReferringAddress:(OWAddress *)anAddress;
- (void)setReferringContentInfo:(OWContentInfo *)anInfo;
- (NSDate *)fetchDate;

- (OWHeaderDictionary *)headerDictionary;  // inefficient
- (NSArray *)validator;  // Useful for making a value for OWCacheArcConditionalKey. (calls -headerDictionary)

- (OWPipeline *)cloneWithTarget:(id <OWTarget, OFWeakRetain, NSObject>)aTarget;

- (NSNumber *)estimateCostFromType:(OWContentType *)aType;

OFWeakRetainConcreteImplementation_INTERFACE

// Messages sent to us by our arcs

- (void)arcHasStatus:(NSDictionary *)info;
- (void)arcHasResult:(NSDictionary *)info;

// Some objects are interested in knowing when we're about to deallocate
- (void)addDeallocationObserver:(id <OWPipelineDeallocationObserver, OFWeakRetain>)anObserver;
- (void)removeDeallocationObserver:(id <OWPipelineDeallocationObserver, OFWeakRetain>)anObserver;

@end

@interface OWPipeline (SubclassesOnly)

- (void)deactivate;

@end

OWF_EXTERN NSString *OWWebPipelineReferringContentInfoKey;

// For notification of pipeline errors.
// A pipeline posts a HasError notification when it encounters an error. The note's object is the pipeline; other info is available in the user dictionary.
// Currently used by OHDownloader (asks about a specific pipeline) and OWConsoleController (subscribes to all notifications).
OWF_EXTERN NSString *OWPipelineHasErrorNotificationName;
OWF_EXTERN NSString *OWPipelineHasErrorNotificationPipelineKey;
OWF_EXTERN NSString *OWPipelineHasErrorNotificationProcessorKey;
OWF_EXTERN NSString *OWPipelineHasErrorNotificationErrorNameKey;
OWF_EXTERN NSString *OWPipelineHasErrorNotificationErrorReasonKey;

// When a pipeline creates a clone of itself, this notification is posted. The object is the old (parent) pipeline; the new pipeline is available in the user dictionary.
// This notification is not posted if you call -cloneWithTarget:.
// NOTE: This notification is sent with the pipeline lock held. Don't do anything in an observer of this notification that might lead to deadlock.
OWF_EXTERN NSString *OWPipelineHasBuddedNotificationName;
OWF_EXTERN NSString *OWPipelineChildPipelineKey;

// The notifications delivered by +addObserver:selector:address: and friends have the following user info keys
OWF_EXTERN NSString *OWPipelineFetchLastAddressKey;
OWF_EXTERN NSString *OWPipelineFetchNewContentKey;
OWF_EXTERN NSString *OWPipelineFetchNewArcKey;

// Other pipeline notification names.

OWF_EXTERN NSString *OWPipelineTreeActivationNotificationName;
OWF_EXTERN NSString *OWPipelineTreeDeactivationNotificationName;
OWF_EXTERN NSString *OWPipelineTreePeriodicUpdateNotificationName;

@protocol OWPipelineDeallocationObserver
- (void)pipelineWillDeallocate:(OWPipeline *)aPipeline;
@end
