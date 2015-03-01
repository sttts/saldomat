//
//  CInvocationGrabber.m
//
//  Created by Jonathan Wight on 03/16/2006.
//  Copyright 2006 Toxic Software, All rights reserved.
//

#import "CInvocationGrabber.h"

@implementation CInvocationGrabber

+ (id)invocationGrabber
{
return([[[self alloc] init] autorelease]);
}

- (void)dealloc
{
[self setTarget:NULL];
[self setInvocation:NULL];
//
[super dealloc];
}

#pragma mark -

- (id)target
{
return(target); 
}

- (void)setTarget:(id)inTarget
{
if (target != inTarget)
	{
	[target autorelease];
	target = [inTarget retain];
	}
}

- (NSInvocation *)invocation
{
return(invocation); 
}

- (void)setInvocation:(NSInvocation *)inInvocation
{
if (invocation != inInvocation)
	{
	[invocation autorelease];
	invocation = [inInvocation retain];
	}
}

#pragma mark -

- (NSMethodSignature *)methodSignatureForSelector:(SEL)inSelector
{
/* Let's see if our super class has a signature for this selector. */
NSMethodSignature *theMethodSignature = [super methodSignatureForSelector:inSelector];
if (theMethodSignature == NULL)
    {
	theMethodSignature = [[self target] methodSignatureForSelector:inSelector];
    }
	

return(theMethodSignature);
}

- (void)forwardInvocation:(NSInvocation *)ioInvocation
{
[ioInvocation setTarget:[self target]];
[self setInvocation:ioInvocation];
}

@end

#pragma mark -

@implementation CInvocationGrabber (CInvocationGrabber_Conveniences)

- (id)prepareWithInvocationTarget:(id)inTarget
{
[self setTarget:inTarget];
return(self);
}

@end