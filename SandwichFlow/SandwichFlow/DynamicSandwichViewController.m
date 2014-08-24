//
//  DynamicSandwichViewController.m
//  SandwichFlow
//
//  Created by Joe Kueser on 8/23/14.
//  Copyright (c) 2014 Colin Eberhardt. All rights reserved.
//

#import "DynamicSandwichViewController.h"
#import "SandwichViewController.h"
#import "AppDelegate.h"

@interface DynamicSandwichViewController () <UICollisionBehaviorDelegate>

@end

@implementation DynamicSandwichViewController {
    NSMutableArray *_views;
    
    UIGravityBehavior *_gravity;
    UIDynamicAnimator *_animator;
    CGPoint _previousTouchPoint;
    BOOL _draggingView;
    
    UISnapBehavior *_snap;
    BOOL _viewDocked;
}

- (void)viewDidLoad {
    [super viewDidLoad];


    // 1. add the lower background layer
    UIImageView* backgroundImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Background-LowerLayer.png"]];
    
    backgroundImageView.frame = CGRectInset(self.view.frame, -50.0f, -50.0f);
    [self.view addSubview:backgroundImageView];
    [self addMotionEffectToView:backgroundImageView magnitude:50.0f];
    
    // 2. add the background mid layer
    UIImageView *midLayerImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Backgrond-MidLayer.png"]];
    [self.view addSubview:midLayerImageView];
    
    // 3. add the foreground image
    UIImageView *header = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Sarnie.png"]];
    header.center = CGPointMake(220, 190);
    [self.view addSubview:header];
    [self addMotionEffectToView:header magnitude:-20.0];
    
    _views = [NSMutableArray new];
    
    _animator = [[UIDynamicAnimator alloc] initWithReferenceView:self.view];
    _gravity = [[UIGravityBehavior alloc] init];
    [_animator addBehavior:_gravity];
    _gravity.magnitude = 4.0f;
    
    CGFloat offset = 250.0f;
    for (NSDictionary *sandwich in [self sandwiches]) {
        [_views addObject:[self addRecipeAtOffset:offset forSandwich:sandwich]];
        offset -= 50.0f;
    }
}

- (void)addMotionEffectToView:(UIView *)view magnitude:(CGFloat)magnitude {
    UIInterpolatingMotionEffect *xMotion = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.x" type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    xMotion.minimumRelativeValue = @(-magnitude);
    xMotion.maximumRelativeValue = @(magnitude);

    UIInterpolatingMotionEffect *yMotion = [[UIInterpolatingMotionEffect alloc] initWithKeyPath:@"center.y" type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    yMotion.minimumRelativeValue = @(-magnitude);
    yMotion.maximumRelativeValue = @(magnitude);
    
    UIMotionEffectGroup *group = [[UIMotionEffectGroup alloc] init];
    group.motionEffects = @[xMotion, yMotion];
    [view addMotionEffect:group];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSArray *)sandwiches {
    AppDelegate *appDelegate = (AppDelegate *) [[UIApplication sharedApplication] delegate];
    return appDelegate.sandwiches;
}

- (UIView *)addRecipeAtOffset:(CGFloat)offset forSandwich:(NSDictionary *)sandwich {
    CGRect frameForView = CGRectOffset(self.view.bounds, 0.0, self.view.bounds.size.height - offset);
    
    // 1. create the view controller
    UIStoryboard *mystoryboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    SandwichViewController *viewController = [mystoryboard instantiateViewControllerWithIdentifier:@"SandwichVC"];
    
    // 2. Set the frame and provide some data
    UIView *view = viewController.view;
    view.frame = frameForView;
    viewController.sandwich = sandwich;
    
    // 3. Add as a child
    [self addChildViewController:viewController];
    [self.view addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];
    
    // 1. add a gesture recognizer
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [viewController.view addGestureRecognizer:pan];
    
    // 2. create a collision
    UICollisionBehavior *collision = [[UICollisionBehavior alloc] initWithItems:@[view]];
    [_animator addBehavior:collision];
    
    // 3. lower boundry, where the tab rests
    CGFloat boundry = view.frame.origin.y + view.frame.size.height + 1;
    CGPoint boundryStart = CGPointMake(0.0, boundry);
    CGPoint boundryEnd = CGPointMake(self.view.bounds.size.width, boundry);
    
    [collision addBoundaryWithIdentifier:@1 fromPoint:boundryStart toPoint:boundryEnd];
    
    boundryStart = CGPointMake(0.0, 0.0);
    boundryEnd = CGPointMake(self.view.bounds.size.width, 0.0);
    [collision addBoundaryWithIdentifier:@2 fromPoint:boundryStart toPoint:boundryEnd];
    
    collision.collisionDelegate = self;
    
    // 4. apply some gravity
    [_gravity addItem:view];
    
    UIDynamicBehavior *itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[view]];
    [_animator addBehavior:itemBehavior];
    
    return view;
}

- (UIDynamicItemBehavior *)itemBehaviorForView:(UIView *)view {
    for (UIDynamicItemBehavior *behavior in _animator.behaviors) {
        if (behavior.class == [UIDynamicItemBehavior class] && [behavior.items firstObject] == view) {
            return behavior;
        }
    }
    return nil;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint touchPoint = [gesture locationInView:self.view];
    UIView *draggedView = gesture.view;
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // 1. was the pan initiated from the top of the recipe?
        CGPoint dragStartLocation = [gesture locationInView:draggedView];
        if (dragStartLocation.y < 200.0f) {
            _draggingView = YES;
            _previousTouchPoint = touchPoint;
        }
    } else if (gesture.state == UIGestureRecognizerStateChanged && _draggingView) {
        // 2. Handle dragging
        CGFloat yOffset = _previousTouchPoint.y - touchPoint.y;
        gesture.view.center = CGPointMake(draggedView.center.x, draggedView.center.y - yOffset);
        _previousTouchPoint = touchPoint;
    } else if (gesture.state == UIGestureRecognizerStateEnded && _draggingView) {
        // 3. the gesture was ended
        [self tryDockView:draggedView];
        [self addVelocityToView:draggedView fromGesture:gesture];
        [_animator updateItemUsingCurrentState:draggedView];
        _draggingView = NO;
    }
}

- (void)tryDockView:(UIView *)view {
    BOOL viewHasReachedDockLocation = view.frame.origin.y < 100.0;
    
    if (viewHasReachedDockLocation) {
        if (!_viewDocked) {
            _snap = [[UISnapBehavior alloc] initWithItem:view snapToPoint:self.view.center];
            [_animator addBehavior:_snap];
            [self setAlphaWhenViewDocked:view alpha:0.0];
            _viewDocked = YES;
        }
    } else {
        if (_viewDocked) {
            [_animator removeBehavior:_snap];
            [self setAlphaWhenViewDocked:view alpha:1.0];
            _viewDocked = NO;
        }
    }
}

- (void)setAlphaWhenViewDocked:(UIView *)view alpha:(CGFloat)alpha {
    for (UIView *aView in _views) {
        if (aView != view) {
            aView.alpha = alpha;
        }
    }
}

- (void)addVelocityToView:(UIView *)view fromGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint vel = [gesture velocityInView:self.view];
    vel.x = 0;
    UIDynamicItemBehavior *behavior = [self itemBehaviorForView:view];
    [behavior addLinearVelocity:vel forItem:view];
}

- (void)collisionBehavior:(UICollisionBehavior *)behavior beganContactForItem:(id<UIDynamicItem>)item withBoundaryIdentifier:(id<NSCopying>)identifier atPoint:(CGPoint)p {
    if ([@2 isEqual:identifier]) {
        UIView *view = (UIView *)item;
        [self tryDockView:view];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
