//
//  GrowlHandler.h
//  mythgrowl
//
//  Created by John Winter on 19/11/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Growl-WithInstaller/GrowlApplicationBridge.h"

@interface GrowlHandler : NSObject <GrowlApplicationBridgeDelegate> {

}

- (void) growlNotify: (NSString *) title withDescription: (NSString *) description andNotification: (NSString *) notification;
- (NSDictionary *) registrationDictionaryForGrowl;
+ (id) sharedInstance;

@end
