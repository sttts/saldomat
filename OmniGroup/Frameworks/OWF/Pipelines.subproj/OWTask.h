// Copyright 1997-2005 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.
//
// $Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OWF/Pipelines.subproj/OWTask.h 68913 2005-10-03 19:36:19Z kc $

#import <OmniFoundation/OFObject.h>

@class NSCountedSet, NSDate, NSLock, NSMutableArray;
@class OWAddress, OWContentInfo;

#import <Foundation/NSDate.h> // For NSTimeInterval
#import <OmniFoundation/OFSimpleLock.h>
#import <OmniFoundation/OFMessageQueuePriorityProtocol.h>

typedef enum {
    OWPipelineInit,            // pipeline is freshly created
    OWPipelineBuilding,        // pipeline is creating processors & waiting for them to produce results
    OWPipelineRunning,         // pipeline has delivered content & is waiting for processors to finish
    /* PipelinePaused,       || no longer used */
    OWPipelineAborting,        // -abortTask has been called
    OWPipelineInvalidating,    // -invalidate has been called
    OWPipelineDead             // pipeline has completed & is idle
} OWPipelineState;

@interface OWTask : OFObject
{
    OWContentInfo *_contentInfo;
    NSLock *_contentInfoLock;
    OWContentInfo *parentContentInfo;
    NSLock *parentContentInfoLock;
    
    NSTimeInterval lastActivationTimeInterval;

    struct {
        unsigned int wasActiveOnLastCheck:1;
        unsigned int wasOpenedByProcessPanel:2;
    } taskFlags;
    OWPipelineState state;

    OFSimpleLockType displayablesSimpleLock;
    NSString *compositeTypeString;
}

+ (NSString *)HMSStringFromTimeInterval:(NSTimeInterval)interval;

// Init and dealloc
- init;
    // Designated initializer
- initWithName:(NSString *)name contentInfo:(OWContentInfo *)aContentInfo parentContentInfo:(OWContentInfo *)aParentContentInfo;
    // NB: the 'name' string should be localized to the user's language
    
// Task management
- (void)abortTask;

// Active tree
- (BOOL)treeHasActiveChildren;
- (void)treeActiveStatusMayHaveChanged;
- (void)activateInTree;
- (void)deactivateInTree;
- (void)abortTreeActivity;

// State
- (OWPipelineState)state;
- (OWAddress *)lastAddress;

- (NSTimeInterval)timeSinceTreeActivationInterval;
- (NSTimeInterval)estimatedRemainingTimeInterval;
- (NSTimeInterval)estimatedRemainingTreeTimeInterval;

- (BOOL)hadError;
- (BOOL)isRunning;
- (BOOL)hasThread;
- (NSString *)errorNameString;
- (NSString *)errorReasonString;

- (NSString *)compositeTypeString;  // localized string to present to user
- (void)calculateDeadPipelines:(unsigned int *)deadPipelines totalPipelines:(unsigned int *)totalPipelines;
- (unsigned int)workDone;
- (unsigned int)workToBeDone;
- (unsigned int)workDoneIfNotFinished;
- (unsigned int)workToBeDoneIfNotFinished;
- (unsigned int)workDoneIncludingChildren;
- (unsigned int)workToBeDoneIncludingChildren;
- (NSString *)statusString;

// Network activity panel / inspector helper methods
- (BOOL)wasOpenedByProcessPanelIndex:(unsigned int)panelIndex;
- (void)setWasOpenedByProcessPanelIndex:(unsigned int)panelIndex;

// Parent contentInfo
- (void)setParentContentInfo:(OWContentInfo *)aParentContentInfo;
- (OWContentInfo *)parentContentInfo;

// ContentInfo
- (void)setContentInfo:(OWContentInfo *)newContentInfo;
- (OWContentInfo *)contentInfo;
- (void)nullifyContentInfo;

// OFMessageQueue protocol helpers
- (OFMessageQueueSchedulingInfo)messageQueueSchedulingInfo;
- (NSComparisonResult)comparePriority:(OWTask *)aTask;

@end
