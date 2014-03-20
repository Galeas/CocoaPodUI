//
//  JMModalOverlay.h
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

#import <Cocoa/Cocoa.h>

#pragma mark -
#pragma mark Type

/*
 modalOVerlay animation direction.
 */
typedef enum {
    JMModalOverlayDirectionNone,
    JMModalOverlayDirectionTop,
    JMModalOverlayDirectionBottom,
    JMModalOverlayDirectionLeft,
    JMModalOverlayDirectionRight,

} JMModalOverlayAnimationDirection;


#pragma mark -
#pragma mark Class JMModalOverlay
@protocol JMModalOverlayDelegate;
/*  A modalOverlay is a unit of content that is positioned above the contentView of a window.
 */
@interface JMModalOverlay : NSObject <NSCoding>

/*  The delegate of the modalOverlay. The delegate is not retained.
 */
@property(assign) IBOutlet id <JMModalOverlayDelegate> delegate;


/*  The view controller that manages the content of the modalOverlay.  The default value is nil.  You must set the content view controller of the modalOverlay to a non-nil value before the modalOverlay is shown.  Changes to the modalOverlay's content view controller while the modalOverlay is shown will animate (provided animates is YES).
 */
@property(strong,nonatomic) IBOutlet NSViewController *contentViewController;

/*  YES if the modalOverlay is being shown, NO otherwise. The modalOverlay is considered to be shown from the point when -showInWindow: is invoked until the modalOverlay is closed in response to an invocation of either -close or -performClose:.
 */
@property(readonly, getter = isShown) BOOL shown;

/*  Should the modalOverlay be animated when it shows or closes.  The default value is YES.
 */
@property() BOOL animates;

/*  Define the animation direction when the contentViewController's view appears. The default value is JMModalOverlayDirectionNone.
 */
@property() JMModalOverlayAnimationDirection animationDirection;

/*  Should the modalOverlay close when user clicks on overlay background. The default value is YES.
 */
@property() BOOL shouldCloseWhenClickOnBackground;

/*  Define the backgroundColor applied on modalOverlay. Set a nil value will turn off the background and make overlay transparent. The default value is [NSColor colorWithCalibratedWhite:0 alpha:0.3].
 */
@property(nonatomic) NSColor *backgroundColor;

/*  Should the modalOverlay draw over title bar. The default value is YES.
 */
@property() BOOL shouldOverlayTitleBar;


/*  Shows the modalOverlay positioned relative to window. The modalOverlay will animate onscreen and eventually animate offscreen when it is closed (unless the property animates is set to NO). This method will throw a NSInvalidArgumentException if window is nil. It will throw a NSInternalInconsistencyException if the modalOverlay's  content view controller (or the view controller's view) is nil. If the modalOverlay is already being shown, this method does nothing.
 */
- (void) showInWindow:(NSWindow *)window;

/*  Attempts to close the modalOverlay.  The modalOverlay will not be closed if it has a delegate and the delegate returns NO to -modalOverlayShouldClose:. The modalOverlay will animate out when closed (unless the animates property is set to NO).
 */
- (IBAction)performClose:(id)sender;

/*  Forces the modalOverlay to close without consulting its delegate.
 */
- (void)close;

@end

#pragma mark -
#pragma mark Notifications
/*  Sent before the modalOverlay is shown.
 */
APPKIT_EXTERN NSString * const JMModalOverlayWillShowNotification;

/*  Sent after the modalOverlay has finished animating onscreen.
 */
APPKIT_EXTERN NSString * const JMModalOverlayDidShowNotification;

/*  Sent before the modalOverlay is closed.
 */
APPKIT_EXTERN NSString * const JMModalOverlayWillCloseNotification;

/*  Sent after the modalOverlay has finished animating offscreen.  
 */
APPKIT_EXTERN NSString * const JMModalOverlayDidCloseNotification;


#pragma mark -
#pragma mark Delegate Methods
@protocol JMModalOverlayDelegate <NSObject>
@optional

/*  Returns YES if the modalOverlay should close, NO otherwise.  The modalOverlay invokes this method on its delegate whenever it is about to close to give the delegate a chance to veto the close.
 */
- (BOOL)modalOverlayShouldClose:(JMModalOverlay *)modalOverlay;


/*  Invoked on the delegate when the JMModalOverlayWillShowNotification notification is sent.  This method will also be invoked on the modalOverlay.
 */
- (void)modalOverlayWillShow:(NSNotification *)notification;

/*  Invoked on the delegate when the JMModalOverlayDidShowNotification notification is sent.  This method will also be invoked on the modalOverlay.
 */
- (void)modalOverlayDidShow:(NSNotification *)notification;

/*  Invoked on the delegate when the JMModalOverlayWillCloseNotification notification is sent.  This method will also be invoked on the modalOverlay.
 */
- (void)modalOverlayWillClose:(NSNotification *)notification;

/*  Invoked on the delegate when the JMModalOverlayDidCloseNotification notification is sent.  This method will also be invoked on the modalOverlay.
 */
- (void)modalOverlayDidClose:(NSNotification *)notification;

@end
