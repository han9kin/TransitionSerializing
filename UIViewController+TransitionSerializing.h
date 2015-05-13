/*
 *  UIViewController+TransitionSerializing.h
 *  TransitionSerializing
 *
 *  Created by han9kin on 2015-05-04.
 *
 */

#import <UIKit/UIKit.h>


@interface UIViewController (TransitionSerializing)


/*
 * returns whether the transition serializing is enabled or not
 */
+ (BOOL)isTransitionSerializingEnabled;


/*
 * present a view controller on the current visible view controller
 */
+ (void)presentViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;


@end


@interface UINavigationController (TransitionCompletionHandling)


/*
 * this category provides convenience methods to handle completion of push/pop transitions
 */

- (void)pushViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
- (void)popViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
- (void)popToRootViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
- (void)popToViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;


@end
