/*
 *  UIViewController+TransitionSerializing.m
 *  TransitionSerializing
 *
 *  Created by han9kin on 2015-05-04.
 *
 */

#import <objc/runtime.h>
#import "UIViewController+TransitionSerializing.h"


#define TRANSITION_SERIALIZING_ENABLED 1


#if TRANSITION_SERIALIZING_ENABLED


@interface KRTransitionQueue : NSObject
@end


@implementation KRTransitionQueue


static NSMutableArray *gTransitionBlocks    = nil;
static NSString       *gCurrentTransitionID = nil;


+ (void)initialize
{
    if (!gTransitionBlocks)
    {
        gTransitionBlocks = [[NSMutableArray alloc] init];
    }
}


+ (void)addTransitionBlock:(void (^)(NSString *))aBlock
{
    NSParameterAssert([NSThread isMainThread]);

#if __has_feature(objc_arc)
    aBlock = [aBlock copy];
#else
    aBlock = [[aBlock copy] autorelease];
#endif

    [gTransitionBlocks addObject:aBlock];

    if ([gTransitionBlocks count] == 1)
    {
        [self beginTransitionWithBlock:aBlock];
    }
}


+ (void)beginTransitionWithBlock:(void (^)(NSString *))aBlock
{
    NSParameterAssert([NSThread isMainThread]);
    NSParameterAssert(!gCurrentTransitionID);

    gCurrentTransitionID = [[[NSUUID UUID] UUIDString] copy];

    dispatch_async(dispatch_get_main_queue(), ^{
        aBlock(gCurrentTransitionID);
    });
}


+ (void)endTransitionWithID:(NSString *)aTransitionID
{
    NSParameterAssert([NSThread isMainThread]);
    NSParameterAssert([gCurrentTransitionID isEqualToString:aTransitionID]);

    if ([gCurrentTransitionID isEqualToString:aTransitionID])
    {
        [gTransitionBlocks removeObjectAtIndex:0];
#if !__has_feature(objc_arc)
        [gCurrentTransitionID release];
#endif
        gCurrentTransitionID = nil;

        if ([gTransitionBlocks count])
        {
            void (^sBlock)(NSString *) = [gTransitionBlocks firstObject];

            [self beginTransitionWithBlock:sBlock];
        }
    }
}


@end


@implementation NSObject (MethodOverriding)


+ (void)exchange:(SEL)aOriginal with:(SEL)aOverride
{
    Method sOriginalMethod = class_getInstanceMethod(self, aOriginal);
    Method sOverrideMethod = class_getInstanceMethod(self, aOverride);

    if (class_addMethod(self, aOriginal, method_getImplementation(sOverrideMethod), method_getTypeEncoding(sOverrideMethod)))
    {
        class_replaceMethod(self, aOverride, method_getImplementation(sOriginalMethod), method_getTypeEncoding(sOriginalMethod));
    }
    else
    {
        method_exchangeImplementations(sOriginalMethod, sOverrideMethod);
    }
}


@end


#endif


@implementation UIViewController (TransitionSerializing)


+ (BOOL)isTransitionSerializingEnabled
{
#if TRANSITION_SERIALIZING_ENABLED
    return YES;
#else
    return NO;
#endif
}


static const char * const gTransitionSerializingModalKey = "TransitionSerializingModalKey";


- (BOOL)isModalInTransitionSerializing
{
    return [objc_getAssociatedObject(self, gTransitionSerializingModalKey) boolValue];
}


- (void)setModalInTransitionSerializing:(BOOL)aModal
{
    objc_setAssociatedObject(self, gTransitionSerializingModalKey, [NSNumber numberWithBool:aModal], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#if TRANSITION_SERIALIZING_ENABLED


static const char * const gTransitionSerializingDismissingKey = "TransitionSerializingDismissingKey";


- (BOOL)isDismissingInTransitionSerializing
{
    return [objc_getAssociatedObject(self, gTransitionSerializingDismissingKey) boolValue];
}


- (void)setDismissingInTransitionSerializing:(BOOL)aDismissing
{
    objc_setAssociatedObject(self, gTransitionSerializingDismissingKey, [NSNumber numberWithBool:aDismissing], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


static const char * const gTransitionSerializingIDKey = "TransitionSerializingIDKey";


- (NSString *)transitionSerializingID
{
    return objc_getAssociatedObject(self, gTransitionSerializingIDKey);
}


- (void)setTransitionSerializingID:(NSString *)aTransitionID
{
    objc_setAssociatedObject(self, gTransitionSerializingIDKey, aTransitionID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (void)handleTransitionWithTransitionID:(NSString *)aTransitionID completion:(void (^)(void))aCompletion
{
    id<UIViewControllerTransitionCoordinator> sTransitionCoordinator = [self transitionCoordinator];

    if (sTransitionCoordinator)
    {
        [sTransitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> sContext){} completion:^(id<UIViewControllerTransitionCoordinatorContext> sContext){

            [KRTransitionQueue endTransitionWithID:aTransitionID];

            if (aCompletion)
            {
                aCompletion();
            }
        }];
    }
    else
    {
        [KRTransitionQueue endTransitionWithID:aTransitionID];

        if (aCompletion)
        {
            aCompletion();
        }
    }
}


- (void)_ts_presentViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion
{
    [KRTransitionQueue addTransitionBlock:^(NSString *sTransitionID){
        NSParameterAssert(![self presentedViewController]);

        if ([self presentedViewController])
        {
            [KRTransitionQueue endTransitionWithID:sTransitionID];
        }
        else
        {
            [self _ts_presentViewController:aViewController animated:aAnimated completion:aCompletion];

            if ([aViewController isModalInTransitionSerializing])
            {
                [aViewController setTransitionSerializingID:sTransitionID];
            }
            else
            {
                [self handleTransitionWithTransitionID:sTransitionID completion:nil];
            }
        }
    }];
}


- (void)_ts_dismissViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion
{
    UIViewController *sPresentedViewController = [self presentedViewController];

    if (!sPresentedViewController)
    {
        sPresentedViewController = self;
    }

    if ([sPresentedViewController isModalInTransitionSerializing] && [sPresentedViewController transitionSerializingID])
    {
#if !__has_feature(objc_arc)
        [[sPresentedViewController retain] autorelease];
#endif
        [self _ts_dismissViewControllerAnimated:aAnimated completion:aCompletion];
        [self handleTransitionWithTransitionID:[sPresentedViewController transitionSerializingID] completion:nil];
    }
    else
    {
        if (aAnimated && [self isDismissingInTransitionSerializing])
        {
            /* assume programming error, silently ignore */
        }
        else
        {
            [self setDismissingInTransitionSerializing:YES];

            [KRTransitionQueue addTransitionBlock:^(NSString *sTransitionID){
                UIViewController *sPresentingViewController;

                if ([self presentedViewController])
                {
                    sPresentingViewController = self;
                }
                else
                {
                    sPresentingViewController = [self presentingViewController];
                }

#if !__has_feature(objc_arc)
                [[self retain] autorelease];
#endif

                if (sPresentingViewController)
                {
                    [self _ts_dismissViewControllerAnimated:aAnimated completion:^{
                        [self setDismissingInTransitionSerializing:NO];

                        if (aCompletion)
                        {
                            aCompletion();
                        }
                    }];
                    [self handleTransitionWithTransitionID:sTransitionID completion:nil];
                }
                else
                {
                    [KRTransitionQueue endTransitionWithID:sTransitionID];
                    [self setDismissingInTransitionSerializing:NO];

                    if (aCompletion)
                    {
                        aCompletion();
                    }
                }
            }];
        }
    }
}


+ (void)load
{
    [self exchange:@selector(presentViewController:animated:completion:) with:@selector(_ts_presentViewController:animated:completion:)];
    [self exchange:@selector(dismissViewControllerAnimated:completion:) with:@selector(_ts_dismissViewControllerAnimated:completion:)];
}


#endif


+ (UIViewController *)currentVisibleViewController
{
    UIViewController *sRootViewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];

    while (sRootViewController)
    {
        UIViewController *sViewController = [sRootViewController presentedViewController];

        if (!sViewController)
        {
            break;
        }

        sRootViewController = sViewController;
    }

    return sRootViewController;
}


+ (void)presentViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion
{
#if TRANSITION_SERIALIZING_ENABLED
    [KRTransitionQueue addTransitionBlock:^(NSString *sTransitionID){
        UIViewController *sCurrentViewController = [self currentVisibleViewController];

        [sCurrentViewController _ts_presentViewController:aViewController animated:aAnimated completion:aCompletion];

        if ([aViewController isModalInTransitionSerializing])
        {
            [aViewController setTransitionSerializingID:sTransitionID];
        }
        else
        {
            [sCurrentViewController handleTransitionWithTransitionID:sTransitionID completion:nil];
        }
    }];
#else
    [[self currentVisibleViewController] presentViewController:aViewController animated:aAnimated completion:aCompletion];
#endif
}


@end


#if TRANSITION_SERIALIZING_ENABLED


@implementation UINavigationController (TransitionSerializing)


- (void)_tsc_pushViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion
{
    [KRTransitionQueue addTransitionBlock:^(NSString *sTransitionID){
        [self _ts_pushViewController:aViewController animated:aAnimated];
        [self handleTransitionWithTransitionID:sTransitionID completion:aCompletion];
    }];
}


- (void)_tsc_popViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion
{
    [KRTransitionQueue addTransitionBlock:^(NSString *sTransitionID){
        NSArray    *sViewControllers = [self viewControllers];
        NSUInteger  sCount           = [sViewControllers count];

        if (sCount > 1)
        {
            [self _ts_popViewControllerAnimated:aAnimated];
            [self handleTransitionWithTransitionID:sTransitionID completion:aCompletion];
        }
        else
        {
            [KRTransitionQueue endTransitionWithID:sTransitionID];

            if (aCompletion)
            {
                aCompletion();
            }
        }
    }];
}


- (void)_tsc_popToRootViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion
{
    [KRTransitionQueue addTransitionBlock:^(NSString *sTransitionID){
        NSArray    *sViewControllers = [self viewControllers];
        NSUInteger  sCount           = [sViewControllers count];

        if (sCount > 1)
        {
            [self _ts_popToRootViewControllerAnimated:aAnimated];
            [self handleTransitionWithTransitionID:sTransitionID completion:aCompletion];
        }
        else
        {
            [KRTransitionQueue endTransitionWithID:sTransitionID];

            if (aCompletion)
            {
                aCompletion();
            }
        }
    }];
}


- (void)_tsc_popToViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion
{
    [KRTransitionQueue addTransitionBlock:^(NSString *sTransitionID){
        NSArray    *sViewControllers = [self viewControllers];
        NSUInteger  sCount           = [sViewControllers count];
        NSUInteger  sIndex           = [sViewControllers indexOfObjectIdenticalTo:aViewController];

        if ((sCount > 1) && (sIndex < (sCount - 1)))
        {
            [self _ts_popToViewController:aViewController animated:aAnimated];
            [self handleTransitionWithTransitionID:sTransitionID completion:aCompletion];
        }
        else
        {
            [KRTransitionQueue endTransitionWithID:sTransitionID];

            if (aCompletion)
            {
                aCompletion();
            }
        }
    }];
}


- (void)_ts_pushViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated
{
    [self _tsc_pushViewController:aViewController animated:aAnimated completion:nil];
}


- (UIViewController *)_ts_popViewControllerAnimated:(BOOL)aAnimated
{
    [self _tsc_popViewControllerAnimated:aAnimated completion:nil];
    return nil;
}


- (NSArray *)_ts_popToRootViewControllerAnimated:(BOOL)aAnimated
{
    [self _tsc_popToRootViewControllerAnimated:aAnimated completion:nil];
    return nil;
}


- (NSArray *)_ts_popToViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated
{
    [self _tsc_popToViewController:aViewController animated:aAnimated completion:nil];
    return nil;
}


+ (void)load
{
    [self exchange:@selector(pushViewController:animated:) with:@selector(_ts_pushViewController:animated:)];
    [self exchange:@selector(popViewControllerAnimated:) with:@selector(_ts_popViewControllerAnimated:)];
    [self exchange:@selector(popToRootViewControllerAnimated:) with:@selector(_ts_popToRootViewControllerAnimated:)];
    [self exchange:@selector(popToViewController:animated:) with:@selector(_ts_popToViewController:animated:)];
}


@end


#endif


@implementation UINavigationController (TransitionCompletionHandling)


#if !TRANSITION_SERIALIZING_ENABLED

- (void)handleTransitionCompletion:(void (^)(void))aCompletion
{
    if (aCompletion)
    {
        id<UIViewControllerTransitionCoordinator> sTransitionCoordinator = [self transitionCoordinator];

        if (sTransitionCoordinator)
        {
            [sTransitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> sContext){} completion:^(id<UIViewControllerTransitionCoordinatorContext> sContext){

                aCompletion();
            }];
        }
        else
        {
            aCompletion();
        }
    }
}

#endif


- (void)pushViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
{
#if TRANSITION_SERIALIZING_ENABLED
    [self _tsc_pushViewController:aViewController animated:aAnimated completion:aCompletion];
#else
    [self pushViewController:aViewController animated:aAnimated];
    [self handleTransitionCompletion:aCompletion];
#endif
}



- (void)popViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
{
#if TRANSITION_SERIALIZING_ENABLED
    [self _tsc_popViewControllerAnimated:aAnimated completion:aCompletion];
#else
    [self popViewControllerAnimated:aAnimated];
    [self handleTransitionCompletion:aCompletion];
#endif
}


- (void)popToRootViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
{
#if TRANSITION_SERIALIZING_ENABLED
    [self _tsc_popToRootViewControllerAnimated:aAnimated completion:aCompletion];
#else
    [self popToRootViewControllerAnimated:aAnimated];
    [self handleTransitionCompletion:aCompletion];
#endif
}


- (void)popToViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
{
#if TRANSITION_SERIALIZING_ENABLED
    [self _tsc_popToViewController:aViewController animated:aAnimated completion:aCompletion];
#else
    [self popToViewController:aViewController animated:aAnimated];
    [self handleTransitionCompletion:aCompletion];
#endif
}


@end
