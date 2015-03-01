// Copyright 1997-2005, 2007-2008 Omni Development, Inc.  All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniFoundation/NSObject-OFExtensions.h>

#import <OmniFoundation/OFUtilities.h>

RCS_ID("$Header: svn+ssh://source.omnigroup.com/Source/svn/Omni/tags/OmniSourceRelease/2008-03-20/OmniGroup/Frameworks/OmniFoundation/OpenStepExtensions.subproj/NSObject-OFExtensions.m 98770 2008-03-17 22:25:33Z kc $")

@implementation NSObject (OFExtensions)

static BOOL implementsInstanceMethod(Class cls, SEL aSelector)
{
    // In ObjC 2.0, it isn't documented whether class_getInstanceMethod/class_getClassMethod search the superclass or not.  Radar #5063446.
    // class_copyMethodList is documented to NOT look at the superclass, so we'll use that, even though it requires memory allocation/deallocation.
    
    unsigned int methodIndex;
    Method *methods = class_copyMethodList(cls, &methodIndex);
    if (!methods)
        return NO;
    
    BOOL result = NO;
    while (methodIndex--) {
        Method m = methods[methodIndex];
        if (sel_isEqual(method_getName(m), aSelector)) {
            result = YES;
            break;
        }
    }
    
    free(methods);
    return result;
}

+ (Class)classImplementingSelector:(SEL)aSelector;
{
    Class aClass = self;

    while (aClass) {
        if (implementsInstanceMethod(aClass, aSelector))
            return aClass;
        aClass = class_getSuperclass(aClass);
    }

    return Nil;
}

+ (NSBundle *)bundle;
{
    return [NSBundle bundleForClass:self];
}

- (NSBundle *)bundle;
{
    return [isa bundle];
}

#if OF_FAST_ITERATORS_AVAILABLE

- (void)performSelector:(SEL)sel withEachObjectInArray:(NSArray *)array
{
    for (id loopItem in array) {
        [self performSelector:sel withObject:loopItem];
    }
}

- (void)performSelector:(SEL)sel withEachObjectInSet:(NSSet *)set
{
    for (id loopItem in set) {
        [self performSelector:sel withObject:loopItem];
    }
}

#else

- (void)performSelector:(SEL)sel withEachObjectInArray:(NSArray *)array
{
    OFForEachInArray(array, NSObject *, anObject, {
        [self performSelector:sel withObject:anObject];
    });
}

- (void)performSelector:(SEL)sel withEachObjectInSet:(NSSet *)set
{
    OFForEachObject([set objectEnumerator], NSObject *, anObject) {
        [self performSelector:sel withObject:anObject];
    }
}

#endif

typedef char  (*byteImp_t)(id self, SEL _cmd, id arg);
typedef short (*shortImp_t)(id self, SEL _cmd, id arg);
typedef long  (*longImp_t)(id self, SEL _cmd, id arg);

- (BOOL)satisfiesCondition:(SEL)sel withObject:(id)object;
{
    NSMethodSignature *signature = [self methodSignatureForSelector:sel];
    Method method = class_getInstanceMethod([self class], sel);
    
    BOOL selectorResult;
    switch ([signature methodReturnType][0]) {
            // TODO: change this to @encode at some point
        case 'c':
        case 'C': {
            byteImp_t byteImp = (typeof(byteImp))method_getImplementation(method);
            selectorResult = byteImp(self, sel, object) != 0;
            break;
        }
        case 's':
        case 'S': {
            shortImp_t shortImp = (typeof(shortImp))method_getImplementation(method);
            selectorResult = shortImp(self, sel, object) != 0;
            break;
        }
        case '@':
            assert(sizeof(id) == sizeof(long)); // 64-bit pointers may happen someday
        case 'i':
        case 'I': {
            longImp_t longImp = (typeof(longImp))method_getImplementation(method);
            selectorResult = longImp(self, sel, object) != 0;
            break;
        }
        default:
            selectorResult = NO;
            OBASSERT(false);
            ;
    }
    
    return selectorResult;
}

@end
