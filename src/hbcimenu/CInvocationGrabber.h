//
//  CInvocationGrabber.h
//
//  Created by Jonathan Wight on 03/16/2006.
//

#import <Cocoa/Cocoa.h>

/**
 * @class CInvocationGrabber
 * @discussion CInvocationGrabber is a helper object that makes it very easy to construct instances of NSInvocation for later use. The object is inspired by NSUndoManager's prepareWithInvocationTarget method. To use a CInvocationGrabber object, you set its target to some object, then send it a message as if it were the target object (the CInvocationGrabber object acts as a proxy), if the target message understands the message the CInvocationGrabber object stores the message invocation.

CInvocationGrabber *theGrabber = [CInvocationGrabber invocationGrabber];
[theGrabber setTarget:someObject]
[theGrabber doSomethingWithParameter:someParameter]; // Send messages to 'theGrabber' as if it were 'someObject'
NSInvocation *theInvocation = [theGrabber invocation];

A slightly more concise version (using the covenience category) follows:

CInvocationGrabber *theGrabber = [CInvocationGrabber invocationGrabber];
[[theGrabber prepareWithInvocationTarget:someObject] doSomethingWithParameter:someParameter];
NSInvocation *theInvocation = [theGrabber invocation];

 */
@interface CInvocationGrabber : NSObject {
	id target;
	NSInvocation *invocation;
}

/**
 * @method invocationGrabber
 * @abstract Returns a newly allocated, inited, autoreleased CInvocationGrabber object.
 */
+ (id)invocationGrabber;

- (id)target;
- (void)setTarget:(id)inTarget;

- (NSInvocation *)invocation;
- (void)setInvocation:(NSInvocation *)inInvocation;

@end

@interface CInvocationGrabber (CInvocationGrabber_Conveniences)

/**
 * @method prepareWithInvocationTarget:
 * @abstract Sets the target object of the receiver and returns itself. The sender can then send a message to the 
 */
- (id)prepareWithInvocationTarget:(id)inTarget;

@end