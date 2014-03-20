//
//  JMModalOverlay.m
//  JMModalOverlay
//
//  Copyright (c) 2013 Jérémy Marchand (http://www.kodlian.com)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "JMModalOverlay.h"
#import "JMOverlayView.h"
#import <QuartzCore/QuartzCore.h>
#import "JMModalOverlayView.h"



#pragma mark -
#pragma mark Notifications
/*  Sent before the modalOverlay is shown.
 */
NSString * const JMModalOverlayWillShowNotification = @"JMModalOverlayWillShowNotification";
NSString * const JMModalOverlayDidShowNotification = @"JMModalOverlayDidShowNotification";
NSString * const JMModalOverlayWillCloseNotification = @"JMModalOverlayWillCloseNotification";
NSString * const JMModalOverlayDidCloseNotification = @"JMModalOverlayDidCloseNotification";

#pragma mark -
#pragma mark Class interface private
@interface JMModalOverlay()
@property() BOOL shown;
@end
#pragma mark -
#pragma mark Class implementation
@implementation JMModalOverlay{
    NSWindow *_modalWindow;
    JMOverlayView *_overlayView;
    NSView *_containerView;
    
    NSWindow *_parentWindow;   
    BOOL _wasResizable;
}
#pragma mark -
#pragma mark Init

- (id)init{
    self = [super init];
    if (self) {
        
        // Default properties values
        self.shouldCloseWhenClickOnBackground = YES;
        self.shouldOverlayTitleBar = YES;
        
        self.backgroundColor = [NSColor colorWithCalibratedWhite:0 alpha:0.4];
        self.animates = YES;
        
        // Notfication
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modalOverlayWillShow:) name:JMModalOverlayWillShowNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modalOverlayDidShow:) name:JMModalOverlayDidShowNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modalOverlayWillClose:) name:JMModalOverlayWillCloseNotification object:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modalOverlayDidClose:) name:JMModalOverlayDidCloseNotification object:self];
        
        
        
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    
}

#pragma mark -
#pragma mark Coder
- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [self initWithCoder:aDecoder];
    if(self){
        
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder{
    
}
#pragma mark -
#pragma mark Properties
- (void)setContentViewController:(NSViewController *)contentViewController{
    if(_contentViewController != contentViewController){
        contentViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
        
        if(_shown){
            
            id container = self.animates?[_modalWindow.contentView animator]:_modalWindow.contentView;
            
            // Replace
            if(_contentViewController){
                [container replaceSubview:_contentViewController.view with:contentViewController.view];
            }
            // Add
            else{
                [container addSubview:contentViewController.view];
                
            }
            
            // Layout
            NSDictionary *views = @{@"view":contentViewController.view};
            NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[view]-0-|" options:0 metrics:nil views:views];
            [_modalWindow.contentView addConstraints:constraints];
            constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[view]-0-|" options:0 metrics:nil views:views];
            [_modalWindow.contentView addConstraints:constraints];
            
        }
        
        _contentViewController = contentViewController;
        
    }
    
}

- (void)setBackgroundColor:(NSColor *)backgroundColor{
    if(_backgroundColor != backgroundColor){
        _backgroundColor = backgroundColor;
        _overlayView.backgroundColor = backgroundColor;
    }
}
#pragma mark -
#pragma mark window
+ (NSWindow *) _modalWindowForFrame:(NSRect)frame{
    NSWindow *modalWindow = [[NSWindow alloc] initWithContentRect:frame
                                                        styleMask: NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
    [modalWindow setBackgroundColor:[NSColor clearColor]];
    [modalWindow setOpaque:NO];
    [modalWindow setHasShadow:NO];
    JMModalOverlayView *contentView = [[JMModalOverlayView alloc] initWithFrame:[modalWindow.contentView frame]];
    contentView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
    
    [modalWindow setContentView:contentView];
    
    
    
    return modalWindow;
}
#pragma mark -
#pragma mark Operation
- (void) showInWindow:(NSWindow *)window{
    if (!self.shown) {
        
        if(window == nil){
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"window is nil" userInfo:nil];
            return;
        }
        if(self.contentViewController == nil){
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"contentViewController is nil" userInfo:nil];
            return;
        }
        if(self.contentViewController.view == nil){
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"contentViewController.view is nil" userInfo:nil];
            return;
        }
        
        
        [[NSNotificationCenter defaultCenter] postNotificationName:JMModalOverlayWillShowNotification object:self];
        _parentWindow = window;
       self.shown = YES;
        
        // Avoid resize
        _wasResizable = _parentWindow.styleMask&NSResizableWindowMask;
        if(_wasResizable){
            _parentWindow.styleMask &= ~NSResizableWindowMask;
        }
        
        
        // Modal Window
        if(_modalWindow){
            [_modalWindow orderOut:nil];
            
        }
        _modalWindow  = [self.class _modalWindowForFrame:NSInsetRect(window.frame, 0, 0)];
        [_modalWindow setAlphaValue:0.f];
        
        
        // Overlay
        NSRect overlayFrame;
        if(_shouldOverlayTitleBar){
            overlayFrame = [_modalWindow.contentView bounds];
        }
        else{
            overlayFrame = [_parentWindow.contentView frame];
        }
        _overlayView = [[JMOverlayView alloc] initWithFrame:overlayFrame];
        [_overlayView setBackgroundColor:self.backgroundColor];
        _overlayView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        [_modalWindow.contentView addSubview:_overlayView];
        [_overlayView setModalOverlay:self];
        
        // Add container view
        _containerView = [[NSView alloc] initWithFrame:_overlayView.bounds];
        [_overlayView addSubview:_containerView];
        _containerView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        
        // Configure content view
        self.contentViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
        self.contentViewController.view.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
        
        self.contentViewController.view.frame = [_containerView bounds];
        
        
        
        // Make view visible
        // Attach to parent window and make the window modal
        [_parentWindow addChildWindow:_modalWindow ordered:NSAboveTop];
        if(_animates){
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setCompletionHandler:^{
                [self _afterShow];

            }];
            [_containerView setAnimations:@{@"subviews":[self.class _appearAnimationForDirection:self.animationDirection]}];
            [[_containerView animator] addSubview:self.contentViewController.view];
            
            [[_modalWindow animator] setAlphaValue:1.f];
            [NSAnimationContext endGrouping];
        }
        else{
            [_containerView addSubview:self.contentViewController.view];
            [_modalWindow setAlphaValue:1.f];
            [self _afterShow];

        }
        
    }
    
}

- (void) _afterShow{
    [[NSNotificationCenter defaultCenter] postNotificationName:JMModalOverlayDidShowNotification object:self];
    [NSApp runModalForWindow:_modalWindow];
}


- (void)close{
    if(self.shown && _modalWindow == [NSApp modalWindow]){
        [NSApp stopModal];

        [[NSNotificationCenter defaultCenter] postNotificationName:JMModalOverlayWillCloseNotification object:self];
        
        if(_animates){
            [_containerView setAnimations:@{@"subviews":[self.class _dissapearAnimationForDirection:self.animationDirection]}];
            
            [NSAnimationContext beginGrouping];
            [[NSAnimationContext currentContext] setCompletionHandler:^{
                [self _afterClose];
                
            }];
            [[_modalWindow animator] setAlphaValue:0.f];
            [[self.contentViewController.view animator] removeFromSuperview];
            [NSAnimationContext endGrouping];
            
        }
        else{
            [self.contentViewController.view removeFromSuperview];
            [self _afterClose];
            
        }
    }
}
- (void) _afterClose{

        [_parentWindow removeChildWindow:_modalWindow];
        
        // Remove modal
        [_modalWindow orderOut:nil];
        _modalWindow = nil;
    
        _containerView = nil;
        _overlayView = nil;
    
        // Restore window mask
        if(_wasResizable){
            _parentWindow.styleMask |= NSResizableWindowMask;
        }
    
        self.shown = NO;

        [[NSNotificationCenter defaultCenter] postNotificationName:JMModalOverlayDidCloseNotification object:self];


    
}

- (void)performClose:(id)sender{
    BOOL shouldClose = YES;
    
    if([self.delegate respondsToSelector:@selector(modalOverlayShouldClose:)]){
        shouldClose = [self.delegate modalOverlayShouldClose:self];
    }
    
    if(shouldClose){
        [self close];
    }
}
#pragma mark -
#pragma mark direction
+ (CATransition*) _appearAnimationForDirection:(JMModalOverlayAnimationDirection)direction{
    CATransition *transition = [CATransition animation];
    [transition setDuration:0.4];
    [transition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];//kCAMediaTimingFunctionEaseInEaseOut]];
    
    
    transition.type = kCATransitionPush;
    
    
    switch (direction) {
        case JMModalOverlayDirectionTop:
            transition.subtype = kCATransitionFromTop;
            
            break;
        case JMModalOverlayDirectionBottom:
            transition.subtype = kCATransitionFromBottom;
            
            break;
        case JMModalOverlayDirectionLeft:
            transition.subtype = kCATransitionFromLeft;
            
            break;
        case JMModalOverlayDirectionRight:
            transition.subtype = kCATransitionFromRight;
            
            break;
        default:
            transition.type = kCATransitionFade;
            
            break;
    }
    
    return transition;
}
+ (CATransition*) _dissapearAnimationForDirection:(JMModalOverlayAnimationDirection)direction{
    CATransition *transition = [CATransition animation];
    [transition setDuration:0.4];
    [transition setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];//kCAMediaTimingFunctionEaseInEaseOut]];
    transition.type = kCATransitionPush;
    
    switch (direction) {
        case JMModalOverlayDirectionTop:
            transition.subtype = kCATransitionFromBottom;
            
            break;
        case JMModalOverlayDirectionBottom:
            transition.subtype = kCATransitionFromTop;
            
            break;
        case JMModalOverlayDirectionLeft:
            transition.subtype = kCATransitionFromRight;
            
            break;
        case JMModalOverlayDirectionRight:
            transition.subtype = kCATransitionFromLeft;
            
            break;
        default:
            transition.type = kCATransitionFade;
            
            break;
    }
    
    return transition;
    
}


#pragma mark -
#pragma mark notification
- (void)modalOverlayWillShow:(NSNotification *)notification{
    if([self.delegate respondsToSelector:@selector(modalOverlayWillShow:)]){
        [self.delegate modalOverlayWillShow:notification];
    }
}
- (void)modalOverlayDidShow:(NSNotification *)notification{
    if([self.delegate respondsToSelector:@selector(modalOverlayDidShow:)]){
        [self.delegate modalOverlayDidShow:notification];
    }
}
- (void)modalOverlayWillClose:(NSNotification *)notification{
    if([self.delegate respondsToSelector:@selector(modalOverlayWillClose:)]){
        [self.delegate modalOverlayWillClose:notification];
    }
}
- (void)modalOverlayDidClose:(NSNotification *)notification{
    if([self.delegate respondsToSelector:@selector(modalOverlayDidClose:)]){
        [self.delegate modalOverlayDidClose:notification];
    }
}

@end
