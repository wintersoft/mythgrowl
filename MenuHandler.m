#import "MenuHandler.h"
#import "PreferencesController.h"
#import "GrowlHandler.h"
#import "Sparkle/SUUpdater.h"
#import "Growl-WithInstaller/GrowlApplicationBridge.h"
#import "AGRegex/AGRegex.h"

NSString *lastEncoderStatus = @""; 
BOOL hasShownConnectionError = FALSE;
BOOL isBackendCurrentlyRecording = FALSE;
BOOL _canMakeNextRequest;
NSString *ipAddy = @""; 
NSString *port = @"6544";
NSMutableData *receivedData;
NSMenuItem *endTimeItem;
int failWithErrorAttempts = 0;

@implementation MenuHandler
- (void)establishMenu {

}
		
- (NSMenu *) createMenu {
	NSZone *menuZone = [NSMenu menuZone];
	NSMenu *m = [[NSMenu allocWithZone:menuZone] init];
	return m;
}

- (void) setImage:(BOOL)isRecording {
	NSBundle *bundle = [NSBundle mainBundle];
	
	if (isRecording){
		mythImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"growlmenu1" ofType:@"png"]];
	}else{
		mythImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"growlmenu" ofType:@"png"]];
	}
	
	if (hasShownConnectionError)  mythImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForResource:@"growlmenu2" ofType:@"png"]];

	[statusItem setImage:mythImage];
}

- (IBAction) openPreferences:(id)sender {
	[PreferencesController showPreferences];
}

- (IBAction) checkUpdates:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	SUUpdater *updater = [SUUpdater alloc];
    [updater checkForUpdates:sender];
}

- (IBAction) quit:(id)sender {
	[NSApp terminate:sender];
}

- (IBAction) showAbout:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}

- (void) awakeFromNib
{

	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
	[statusItem setToolTip:@"MythGrowl"];
	[self setImage:false];
	[statusItem setHighlightMode:YES]; 
	[statusItem setMenu:theMenu];
	[NSApp setMainMenu:systemMenu];
	[statusItem setEnabled:YES];
	_canMakeNextRequest = true;
	
	int checkInterval = 3;

	NSUserDefaults *defaults;
	defaults = [NSUserDefaults standardUserDefaults];
	[self setIpAddress:[defaults stringForKey:@"mythServerHostname"]];
	if ([self getIpAddress] == nil) [PreferencesController showPreferences];
	
	// if hidden pref 'checkInterval' exists then use it to set handleTimer delay
	if ([defaults stringForKey:@"checkInterval"] != nil) checkInterval = [defaults integerForKey:@"checkInterval"];
	
	timer = [[NSTimer scheduledTimerWithTimeInterval: checkInterval
                 target: self
                 selector: @selector(handleTimer:)
                 userInfo: nil
                 repeats: YES] retain];
}

- (id) init
{
	// setup growl
	gd = [GrowlHandler sharedInstance];
	return (self);
}

- (void) dealloc {
    [gd release];
	[statusItem release];
	[mythImage release];
	[lastEncoderStatus release];
	[super dealloc];
}

- (void) handleTimer: (NSTimer *) timer
{
	NSString *finalUrl;
	if (![PreferencesController isShowingPreferences]) {
		NSUserDefaults *defaults;
		defaults = [NSUserDefaults standardUserDefaults];
		[self setIpAddress:[defaults stringForKey:@"mythServerHostname"]];
		if ([self getIpAddress] == nil) [PreferencesController showPreferences];
		[self setPort:[defaults stringForKey:@"mythServerPort"]];
	}
	if ([self getPort] == nil) [self setPort:@"6544"];
		
	// build connection url from user preferences
	if ([self getIpAddress] != nil){
		finalUrl = @"http://";
		finalUrl = [finalUrl stringByAppendingString:[self getIpAddress]];
		finalUrl = [finalUrl stringByAppendingString:@":"];
		finalUrl = [finalUrl stringByAppendingString:[self getPort]];

		if (_canMakeNextRequest){
			NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:finalUrl]
									cachePolicy:NSURLRequestReloadIgnoringCacheData
									timeoutInterval:5.0];
			NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
			
			_canMakeNextRequest = FALSE;
			
			if (theConnection) receivedData=[[NSMutableData data] retain];
		}
	}
} 

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response

{
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data

{
    [receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection

{
	if (hasShownConnectionError){
		[currentStatus setTitle:@"Backend Idle"];
		hasShownConnectionError = FALSE;
		[self setImage:FALSE];
	}

	_canMakeNextRequest = TRUE;
	if ([receivedData length] == 0) return; 
	
	NSData *data;

	data = receivedData;
	failWithErrorAttempts = 0;

	NSString *statusPageData;
	NSString *encoderStatus;
	int i;
	
	statusPageData = [[NSString alloc] initWithData: data encoding: NSASCIIStringEncoding];

	AGRegex *regex = [[AGRegex alloc] initWithPattern:@"</h2>(.*?)<br />" options:AGRegexDotAll];
	AGRegexMatch *match = [regex findInString:statusPageData]; 
	[regex release];
	
	encoderStatus = [match groupAtIndex:1];
	encoderStatus = [encoderStatus stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	regex = [[AGRegex alloc] initWithPattern:@"not recording" options:AGRegexDotAll];
	match = [regex findInString:encoderStatus];
	[regex release];
	
	// STARTED RECORDING NOTIFICATIONS
	// if text 'not recording' is not found in encoderStatus string
	if ([match groupAtIndex:0] == nil) {
		if ([encoderStatus compare: [self getLastEncoderStatus] options:NSLiteralSearch] == NSOrderedSame){
			// exit
		}else {
			[self setImage:true];
			isBackendCurrentlyRecording = TRUE;
			NSArray *encoderStatusSplit = [encoderStatus componentsSeparatedByString:@"and"];
			NSString *finalStatus = @"MythTV";
			for (i = 1; i < [encoderStatusSplit count]; i++) {
				finalStatus = [finalStatus stringByAppendingString:[encoderStatusSplit objectAtIndex:i]];
			}
			// get settings
			NSUserDefaults *defaults;
			defaults = [NSUserDefaults standardUserDefaults];
			// see if we are watching LiveTV or if this is a recording
			NSArray *finalStatusSplit = [finalStatus componentsSeparatedByString:@" "];
			if (([[finalStatusSplit objectAtIndex:1] compare:@"is" options:NSLiteralSearch] == NSOrderedSame) && 
				([[finalStatusSplit objectAtIndex:2] compare:@"watching" options:NSLiteralSearch] == NSOrderedSame)){
				// only show if watching tv alerts are enabled
				NSString *alertLiveTV = [defaults stringForKey:@"alertLiveTV"];
				if ([alertLiveTV compare:@"1" options:NSLiteralSearch] == NSOrderedSame) 
					[gd growlNotify:@"MythTV Started Recording" withDescription:finalStatus andNotification:@"Started Recording"];
					
					// get shortened status for NSMenuItem like Watching <program name>
					AGRegex *regex2 = [[AGRegex alloc] initWithPattern:@"MythTV is watching Live TV: " options:AGRegexDotAll];
					NSString *frontRemoved = [regex2 replaceWithString:@"" inString:finalStatus];
					NSArray *frontRemovedSplit = [frontRemoved componentsSeparatedByString:@"' on "];

					NSString *shortStatus = [frontRemovedSplit objectAtIndex:0];
					shortStatus = [shortStatus stringByAppendingString:@"'"];
					[currentStatus setTitle:[@"Watching " stringByAppendingString:shortStatus]];
					
					// get recording end time
					NSString *lastPart = [frontRemovedSplit objectAtIndex:1];
					NSArray *recordingWillEndSplit = [lastPart componentsSeparatedByString:@"This recording is scheduled to end at "];
					NSString *endTime = [recordingWillEndSplit objectAtIndex:1];
					
					endTime = [@"This program will end at " stringByAppendingString:endTime];
					endTime = [endTime substringToIndex:[endTime length] - 1];
					[self updateRecordEndTimeItem:endTime];
			}else {
				// only show if recording alerts are enabled
				NSString *alertRecording = [defaults stringForKey:@"alertRecording"];
				if ([alertRecording compare:@"1" options:NSLiteralSearch] == NSOrderedSame)  
					[gd growlNotify:@"MythTV Started Recording" withDescription:finalStatus andNotification:@"Started Recording"];
					
				// get shortened status for NSMenuItem like Recording <program name>
				AGRegex *regex2 = [[AGRegex alloc] initWithPattern:@"MythTV is recording: " options:AGRegexDotAll];
				NSString *frontRemoved = [regex2 replaceWithString:@"" inString:finalStatus];
				NSArray *frontRemovedSplit = [frontRemoved componentsSeparatedByString:@"' on "];

				NSString *shortStatus = [frontRemovedSplit objectAtIndex:0];
				shortStatus = [shortStatus stringByAppendingString:@"'"];
				[currentStatus setTitle:[@"Recording " stringByAppendingString:shortStatus]];
				
				// get recording end time
				NSString *lastPart = [frontRemovedSplit objectAtIndex:1];
				NSArray *recordingWillEndSplit = [lastPart componentsSeparatedByString:@"This recording is scheduled to end at "];
				NSString *endTime = [recordingWillEndSplit objectAtIndex:1];
				
				endTime = [@"This recording is scheduled to end at " stringByAppendingString:endTime];
				endTime = [endTime substringToIndex:[endTime length] - 1];
				[self updateRecordEndTimeItem:endTime];
			}
		}
	}
	
	// STOPPED RECORDING NOTIFICATIONS
	if ([match groupAtIndex:0] && [self getLastEncoderStatus] != nil && 
		[@"" compare: [self getLastEncoderStatus] options:NSLiteralSearch] != NSOrderedSame) {
		// see if the last encoder status was not recording
		regex = [[AGRegex alloc] initWithPattern:@"not recording" options:AGRegexDotAll];
		match = [regex findInString:[self getLastEncoderStatus]];
		[regex release];
		if ([match groupAtIndex:0] == nil){
			[self setImage:false];
			isBackendCurrentlyRecording = FALSE;
			// myth was recording but is not now, so growl with stopped recording message
			NSArray *encoderStatusSplit = [[self getLastEncoderStatus] componentsSeparatedByString:@"and is"];
			NSString *finalStatus = @"";
			for (i = 1; i < [encoderStatusSplit count]; i++) {
				finalStatus = [finalStatus stringByAppendingString:[encoderStatusSplit objectAtIndex:i]];
			}
			// remove 'This recording is scheduled to end at...' info off the end
			NSArray *endStatusSplit = [finalStatus componentsSeparatedByString:@" This recording is scheduled to end at"];
			finalStatus = @"MythTV stopped";
			for (i = 0; i < [endStatusSplit count] - 1; i++) {
				finalStatus = [finalStatus stringByAppendingString:[endStatusSplit objectAtIndex:i]];
			}
			// get settings
			NSUserDefaults *defaults;
			defaults = [NSUserDefaults standardUserDefaults];
			// see if we stopped watching LiveTV or finished recording
			NSArray *finalStatusSplit = [[encoderStatusSplit objectAtIndex:1] componentsSeparatedByString:@" "];
			if (([[finalStatusSplit objectAtIndex:1] compare:@"watching" options:NSLiteralSearch] == NSOrderedSame)){
				// only show if watching tv alerts are enabled
				NSString *alertLiveTV = [defaults stringForKey:@"alertLiveTV"];
				if ([alertLiveTV compare:@"1" options:NSLiteralSearch] == NSOrderedSame) 
					[gd growlNotify:@"MythTV Stopped Recording" withDescription:finalStatus andNotification:@"Stopped Recording"];
					
					// get shortened status for NSMenuItem like Stopped Watching <program name>
					AGRegex *regex2 = [[AGRegex alloc] initWithPattern:@" watching Live TV: " options:AGRegexDotAll];
					NSString *frontRemoved = [regex2 replaceWithString:@"" inString:[encoderStatusSplit objectAtIndex:1]];
					NSArray *frontRemovedSplit = [frontRemoved componentsSeparatedByString:@"' on "];

					NSString *shortStatus = [frontRemovedSplit objectAtIndex:0];
					shortStatus = [shortStatus stringByAppendingString:@"'"];
					[currentStatus setTitle:[@"Stopped Watching " stringByAppendingString:shortStatus]];
					
					[theMenu removeItemAtIndex:1];
					endTimeItem = nil;
			}else {
				// only show if finished recording alerts are enabled
				NSString *alertFinishedRecording = [defaults stringForKey:@"alertFinishedRecording"];
				if ([alertFinishedRecording compare:@"1" options:NSLiteralSearch] == NSOrderedSame)  
					[gd growlNotify:@"MythTV Stopped Recording" withDescription:finalStatus andNotification:@"Stopped Recording"];
					
				// get shortened status for NSMenuItem like Stopped Watching <program name>
				AGRegex *regex2 = [[AGRegex alloc] initWithPattern:@" recording: " options:AGRegexDotAll];
				NSString *frontRemoved = [regex2 replaceWithString:@"" inString:[encoderStatusSplit objectAtIndex:1]];
				NSArray *frontRemovedSplit = [frontRemoved componentsSeparatedByString:@"' on "];
				
				NSString *shortStatus = [frontRemovedSplit objectAtIndex:0];
				shortStatus = [shortStatus stringByAppendingString:@"'"];
				[currentStatus setTitle:[@"Stopped Recording " stringByAppendingString:shortStatus]];
				
				[theMenu removeItemAtIndex:1];
				endTimeItem = nil;
			}
		}
	}
	
	[statusPageData release];
	[self setLastEncoderStatus: encoderStatus];
    [connection release];
    [receivedData release];
}

- (void)connection:(NSURLConnection *)connection 

  didFailWithError:(NSError *)error

{	
	if (!hasShownConnectionError && failWithErrorAttempts >= 3) {
		[self setLastEncoderStatus: nil];
		[gd growlNotify:@"MythGrowl Connection Error" 
			withDescription:@"There was a problem connecting to your MythTV Server" 
			andNotification:@"Connection Problem"];
		hasShownConnectionError = TRUE;
		[currentStatus setTitle:@"Connection Problem"];
		if (isBackendCurrentlyRecording) [theMenu removeItemAtIndex:1];
		[self setImage:FALSE];
		endTimeItem = nil;
		failWithErrorAttempts = 0;
	}else{
		failWithErrorAttempts++;
	}
	_canMakeNextRequest = TRUE;
    [connection release];
	receivedData = nil;
    [receivedData release];
}

- (void)updateRecordEndTimeItem: (NSString *)text
{
	if (!endTimeItem){
		endTimeItem = [theMenu insertItemWithTitle:text action:nil keyEquivalent:@"" atIndex:1];
	}else {
		[endTimeItem setTitle:text];
	}
}


-(NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse

{
    NSCachedURLResponse *newCachedResponse=cachedResponse;
	// don't cache
	newCachedResponse = nil;
    return newCachedResponse;
}


// ACCESSOR METHODS BELOW
- (void) setLastEncoderStatus: (NSString*) theStatus {
	[theStatus retain];
	[lastEncoderStatus release];
	lastEncoderStatus = theStatus;
}

- (NSString*) getLastEncoderStatus {
	return lastEncoderStatus;
}

- (void) setPort: (NSString*) thePort {
	[thePort retain];
	[port release];
	port = thePort;
}

- (NSString*) getPort {
	return port;
}

- (void) setIpAddress: (NSString*) theIp {
	[theIp retain];
	[ipAddy release];
	ipAddy = theIp;
}

- (NSString*) getIpAddress {
	return ipAddy;
}



@end
