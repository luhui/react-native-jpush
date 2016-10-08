//
//  RCTJPush.m
//  RCTJPush
//
//  Created by LvBingru on 1/12/16.
//  Copyright © 2016 erica. All rights reserved.
//

#import "RCTJPush.h"
#import "JPUSHService.h"
#import "RCTEventDispatcher.h"
#import "RCTUtils.h"
#import <UserNotifications/UserNotifications.h>

NSString *const kJPFNetworkDidReceiveApnsMessageNotification = @"kJPFNetworkDidReceiveApnsMessageNotification";
NSString *const kJPFNetworkDidOpenApnsMessageNotification = @"kJPFNetworkDidOpenApnsMessageNotification";

@implementation RCTJPush

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
    static dispatch_once_t onceToken;
    static NSArray *events;
    dispatch_once(&onceToken, ^{
        events = @[
                   @"kJPFNetworkDidReceiveCustomMessageNotification",
                   @"kJPFNetworkDidReceiveMessageNotification",
                   @"kJPFNetworkDidOpenMessageNotification"];
    });
    return events;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (instancetype)init
{
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNetworkDidReceiveMessageNotification:)
                                                     name:kJPFNetworkDidReceiveMessageNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNetworkDidReceiveAPNSMessageNotification:)
                                                     name:kJPFNetworkDidReceiveApnsMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNetworkDidOpenAPNSMessageNotification:)
                                                     name:kJPFNetworkDidOpenApnsMessageNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAppEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
        
        [self resetBadge];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSDictionary<NSString *, id> *)constantsToExport
{
    NSDictionary<NSString *, id> *initialNotification = [_bridge.launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] copy];
    return @{@"initialNotification": RCTNullIfNil(initialNotification)};
}

+ (void)setupWithOption:(NSDictionary *)launchingOption
                 appKey:(NSString *)appKey
                channel:(NSString *)channel
       apsForProduction:(BOOL)isProduction
  advertisingIdentifier:(NSString *)advertisingId
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [JPUSHService setupWithOption:launchingOption appKey:appKey channel:channel apsForProduction:isProduction advertisingIdentifier:advertisingId];
    });
    
#ifdef DEBUG
    [JPUSHService setDebugMode];
#endif
}

+ (void)application:(__unused UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    [JPUSHService registerDeviceToken:deviceToken];
}

+ (void)application:(__unused UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)notification
{
    [JPUSHService handleRemoteNotification:notification];
    
    if (application.applicationState == UIApplicationStateInactive) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kJPFNetworkDidOpenApnsMessageNotification object:nil userInfo:notification];
    }
    else {
        [[NSNotificationCenter defaultCenter] postNotificationName:kJPFNetworkDidReceiveApnsMessageNotification object:nil userInfo:notification];
    }
}

+ (void)_requestPermissions:(NSDictionary *)permissions
{
    //Required
    if ([[UIDevice currentDevice].systemVersion floatValue] >= 10.0) {
        NSUInteger types = UNAuthorizationOptionNone;
        if (permissions) {
            if ([permissions[@"alert"] boolValue]) {
                types |= UNAuthorizationOptionAlert;
            }
            if ([permissions[@"badge"] boolValue]) {
                types |= UNAuthorizationOptionBadge;
            }
            if ([permissions[@"sound"] boolValue]) {
                types |= UNAuthorizationOptionSound;
            }
        } else {
            types = UNAuthorizationOptionAlert | UNAuthorizationOptionAlert | UNAuthorizationOptionAlert;
        }
        JPUSHRegisterEntity * entity = [[JPUSHRegisterEntity alloc] init];
        entity.types = types;
        [JPUSHService registerForRemoteNotificationConfig:entity delegate:nil];
    }
    else if ([[UIDevice currentDevice].systemVersion floatValue] >= 8.0) {
        NSUInteger types = UIUserNotificationTypeNone;
        if (permissions) {
            if ([permissions[@"alert"] boolValue]) {
                types |= UIUserNotificationTypeAlert;
            }
            if ([permissions[@"badge"] boolValue]) {
                types |= UIUserNotificationTypeBadge;
            }
            if ([permissions[@"sound"] boolValue]) {
                types |= UIUserNotificationTypeSound;
            }
        } else {
            types = UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound;
        }
        //可以添加自定义categories
        [JPUSHService registerForRemoteNotificationTypes:types
                                              categories:nil];
    }
    else {
        NSUInteger types = UIRemoteNotificationTypeNone;
        if (permissions) {
            if ([permissions[@"alert"] boolValue]) {
                types |= UIRemoteNotificationTypeAlert;
            }
            if ([permissions[@"badge"] boolValue]) {
                types |= UIRemoteNotificationTypeBadge;
            }
            if ([permissions[@"sound"] boolValue]) {
                types |= UIRemoteNotificationTypeSound;
            }
        } else {
            types = UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound;
        }
        //categories 必须为nil
        [JPUSHService registerForRemoteNotificationTypes:types
                                              categories:nil];
    }
}

- (void)handleNetworkDidReceiveMessageNotification:(NSNotification *)notification
{
    [self sendEventWithName:@"kJPFNetworkDidReceiveCustomMessageNotification" body:notification.userInfo];
}

- (void)handleNetworkDidReceiveAPNSMessageNotification:(NSNotification *)notification
{
    [self sendEventWithName:@"kJPFNetworkDidReceiveMessageNotification" body:notification.userInfo];
}
- (void)handleNetworkDidOpenAPNSMessageNotification:(NSNotification *)notification
{
    [self sendEventWithName:@"kJPFNetworkDidOpenMessageNotification" body:notification.userInfo];
}

- (void)handleAppEnterForeground:(NSNotification *)notification
{
    [self resetBadge];
}

RCT_EXPORT_METHOD(setAlias:(NSString *)alias)
{
    [JPUSHService setAlias:alias callbackSelector:NULL object:nil];
}

RCT_EXPORT_METHOD(setTags:(NSArray *)tags alias:(NSString *)alias)
{
    [JPUSHService setTags:[NSSet setWithArray:tags] alias:alias callbackSelector:NULL object:nil];
}

RCT_EXPORT_METHOD(cancelAllLocalNotifications)
{
    [JPUSHService removeNotification:nil];
}

RCT_EXPORT_METHOD(setLocalNotification:(NSDictionary *)notification callback:(RCTResponseSenderBlock) callback)
{
    JPushNotificationRequest *request = [[JPushNotificationRequest alloc] init];
    JPushNotificationContent *content = [[JPushNotificationContent alloc] init];
    JPushNotificationTrigger *trigger = [[JPushNotificationTrigger alloc] init];
    request.content = content;
    request.trigger = trigger;
    void(^setKeyValues)(id, NSDictionary *) = ^(id object, NSDictionary *data) {
        for (NSString *key in data.allKeys) {
            id value = data[key];
            if ([value isKindOfClass:[NSDictionary class]]) {
                if ([object respondsToSelector:@selector(key)]) {
                    setKeyValues([object valueForKey:key], value);
                }
            } else {
                if ([object respondsToSelector:@selector(key)]) {
                    [object setValue:value forKey:key];
                }
            }
        }
    };
    setKeyValues(request, notification);
    request.completionHandler = callback;
    [JPUSHService addNotification:request];
}

RCT_EXPORT_METHOD(resetBadge)
{
    RCTSharedApplication().applicationIconBadgeNumber = 1;
    RCTSharedApplication().applicationIconBadgeNumber = 0;
    [JPUSHService resetBadge];
}

RCT_EXPORT_METHOD(setBadge:(int)badge)
{
    RCTSharedApplication().applicationIconBadgeNumber = badge;
    [JPUSHService setBadge:badge];
}

RCT_EXPORT_METHOD(getBadge:(RCTResponseSenderBlock)callback)
{
    callback(@[@(RCTSharedApplication().applicationIconBadgeNumber)]);
}

RCT_EXPORT_METHOD(getRegistrationID:(RCTResponseSenderBlock)callback)
{
    NSString *registrationID = [JPUSHService registrationID];
    callback(@[RCTNullIfNil(registrationID)]);
}

RCT_EXPORT_METHOD(setLogOFF)
{
    [JPUSHService setLogOFF];
}

RCT_EXPORT_METHOD(crashLogON)
{
    [JPUSHService crashLogON];
}

RCT_EXPORT_METHOD(setLocation:(double)latitude
                  :(double)longitude)
{
    [JPUSHService setLatitude:latitude longitude:longitude];
}

RCT_EXPORT_METHOD(startLogPageView:(NSString *)logPageView)
{
    [JPUSHService startLogPageView:logPageView];
}

RCT_EXPORT_METHOD(stopLogPageView:(NSString *)logPageView)
{
    [JPUSHService stopLogPageView:logPageView];
}

RCT_EXPORT_METHOD(beginLogPageView:(NSString *)logPageView duration:(int)duration)
{
    [JPUSHService beginLogPageView:logPageView duration:duration];
}

RCT_EXPORT_METHOD(requestPermissions:(NSDictionary *)permissions)
{
    if (RCTRunningInAppExtension()) {
        return;
    }
    
    [RCTJPush _requestPermissions:permissions];
}

RCT_EXPORT_METHOD(abandonPermissions)
{
    [RCTSharedApplication() unregisterForRemoteNotifications];
}

@end
