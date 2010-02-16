/* PreferencesController */

#import <Cocoa/Cocoa.h>

@interface PreferencesController : NSWindowController{

    IBOutlet NSTextField *ipAddress;
    IBOutlet NSTextField *port;
    IBOutlet NSWindow *window;
	IBOutlet NSMenu *theMenu;
}
- (IBAction)showWindow:(id)sender;
+ (void)showPreferences;
+ (BOOL)isShowingPreferences;

@end
