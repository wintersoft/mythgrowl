//
//  GrowlHandler.m
//  mythgrowl
//
//  Created by John Winter on 19/11/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "GrowlHandler.h"
#import "Growl-WithInstaller/GrowlApplicationBridge.h"

@implementation GrowlHandler

+ (id) sharedInstance {
	static GrowlHandler* shared = nil;
	if(!shared)
		shared = [GrowlHandler new];
	return shared;
}

- (id) init
{
	if ((self = [super init])) {
		[GrowlApplicationBridge setGrowlDelegate:self];
		[self registrationDictionaryForGrowl];
		return self;
	} else {
		return nil;
	}
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSDictionary *theDict;
	NSArray *notifications;
	NSString *appName = @"MythGrowl";

	notifications = [NSArray arrayWithObjects: @"Started Recording", @"Stopped Recording", @"Connection Problem", nil];
	
	theDict = [NSDictionary dictionaryWithObjectsAndKeys: appName, GROWL_APP_NAME, notifications, 
			   GROWL_NOTIFICATIONS_ALL, notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
	
	return theDict;
}

- (void) dealloc
{
	[super dealloc];
}

- (void) growlNotify: (NSString *) title withDescription: (NSString *) description andNotification: (NSString *) notification 
{
        [GrowlApplicationBridge
            notifyWithTitle: title
                description: description
           notificationName: notification
                   iconData: nil
                   priority: 0
                   isSticky: NO
               clickContext: nil];
}

- (void) growlNotifyDummy: (NSString *) title withDescription: (NSString *) description andNotification: (NSString *) notification 
{

}
	
@end
