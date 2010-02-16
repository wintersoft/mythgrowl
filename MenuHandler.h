/* MenuHandler */

#import <Cocoa/Cocoa.h>

@class GrowlHandler;

@interface MenuHandler : NSObject
{
    IBOutlet NSMenu *theMenu;
	IBOutlet NSMenu *systemMenu;
	IBOutlet NSMenuItem *currentStatus;
	int					pid;
	NSStatusItem		*statusItem;
	NSImage				*mythImage;
	GrowlHandler* gd;
	NSTimer *timer;
}

- (IBAction) openPreferences:(id)sender;
- (NSMenu *) createMenu;
- (void) setImage;
- (void) setLastEncoderStatus: (NSString *) theStatus;
- (void) setIpAddress: (NSString *) theIp;
- (NSString *) getIpAddress;
- (void) setPort: (NSString *) thePort;
- (void)updateRecordEndTimeItem:(NSString *)text;
- (NSString *) getPort;
- (NSString *) getLastEncoderStatus;
- (IBAction) quit:(id)sender;
- (IBAction) checkUpdates:(id)sender;
- (IBAction) showAbout:(id)sender;

@end
