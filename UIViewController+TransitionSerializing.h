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
+ (BOOL)supportsTransitionSerializing;


/*
 * present a view controller on the current visible view controller
 */
+ (void)presentViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;


/*
 * modalInTransitionSerializing is set on the view controller
 * when you wish to force the view controller should be dismissed before the next transition start.
 */
@property(nonatomic, assign, getter=isModalInTransitionSerializing) BOOL modalInTransitionSerializing;


@end


@interface UINavigationController (TransitionCompletionHandling)


- (void)pushViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
- (void)popViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
- (void)popToRootViewControllerAnimated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;
- (void)popToViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated completion:(void (^)(void))aCompletion;


@end
