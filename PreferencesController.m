#import "PreferencesController.h"

@implementation PreferencesController

PreferencesController *sharedPreferenceControllerInstance = nil;


+ (void)showPreferences
{
	NSString *portMyth;
	NSString *alertLiveTV;
	NSString *alertRecording;
	NSString *alertFinishedRecording;
	
	if (!sharedPreferenceControllerInstance) {
		sharedPreferenceControllerInstance = [[PreferencesController alloc] initWithWindowNibName:@"Config"];
		[sharedPreferenceControllerInstance showWindow:NSApp];
		
		//set up some sensible defaults
		NSUserDefaults *defaults;
		defaults = [NSUserDefaults standardUserDefaults];
		portMyth = [defaults stringForKey:@"mythServerPort"];
		alertLiveTV = [defaults stringForKey:@"alertLiveTV"];
		alertRecording = [defaults stringForKey:@"alertRecording"];
		alertFinishedRecording = [defaults stringForKey:@"alertFinishedRecording"];
		
		if (portMyth == nil) [defaults setObject:@"6544" forKey:@"mythServerPort"];
		
		//all alerts on by default
		if (alertLiveTV == nil) [defaults setObject:@"1" forKey:@"alertLiveTV"];
		if (alertRecording == nil) [defaults setObject:@"1" forKey:@"alertRecording"];
		if (alertFinishedRecording == nil) [defaults setObject:@"1" forKey:@"alertFinishedRecording"];
	}
}

+ (BOOL)isShowingPreferences
{
	if (!sharedPreferenceControllerInstance) {
		return FALSE;
	}else {
		return TRUE;
	}

}

- (IBAction)showWindow:(id)sender
{
	[[self window] center];
	[NSApp activateIgnoringOtherApps:YES];
	[super showWindow:sender];
}

- (IBAction)hideWindow:(id)sender
{
	[sharedPreferenceControllerInstance release];
}

- (void)dealloc
{
	sharedPreferenceControllerInstance = nil;
	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[self autorelease];
}

@end
