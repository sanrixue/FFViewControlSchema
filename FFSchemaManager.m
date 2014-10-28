//
//  FFSchemaManager.m
//
//  Created by wujiangwei on 14/10/28.
//  Copyright (c) 2014年 Kevin.Wu. All rights reserved.
//

#import "FFSchemaManager.h"
#import "NSURL+FFURLShemaParse.h"

#import <objc/runtime.h>

NSString * const kFFSchemaName           = @"name";
NSString * const kFFSchemaKeyIsNeedLogin = @"needlogin";
NSString * const kFFSchemaKeyTabIndex    = @"tabitemindex";

@interface FFSchemaManager ()

@property (strong, nonatomic) NSString *appName;
@property (strong, nonatomic) NSDictionary *supportedSchema;

@end

@implementation FFSchemaManager
{
    NSString *_appName;
}

+ (FFSchemaManager *)sharedInstance
{
    static FFSchemaManager *_sharedInstance = nil;
    static dispatch_once_t oncetoken;
    dispatch_once(&oncetoken, ^{
        _sharedInstance = [[FFSchemaManager alloc] init];
    });
    
    return _sharedInstance;
}

- (NSString *)appName
{
    if (_appName == nil) {
        _appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
        _appName = [_appName lowercaseString];
    }
    return _appName;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSString *file = [[NSBundle mainBundle] pathForResource:@"schema" ofType:@"plist"];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:file];
        _supportedSchema = dict;
    }
    return self;
}

- (BOOL)isAppSchema:(NSURL *)url
{
    return [[[url scheme] lowercaseString] isEqualToString:self.appName];
}

- (BOOL)canOpenUrl:(NSURL *)url
{
    if (url != nil) {
        if ([self isAppSchema:url]) {
            NSString *schema = [url host];
            return [[_supportedSchema allKeys] containsObject:schema];
        }else{
            return [[UIApplication sharedApplication] canOpenURL:url];
        }
    }
    return NO;
}

- (BOOL)openURL:(NSURL *)url
{
    if ([self canOpenUrl:url]) {
        if ([self isAppSchema:url]) {
            NSString *schema = [url host];
            NSDictionary *vcParam = [url queryDictionary];

            return [self openSchema:schema params:vcParam];
        }else{
            [[UIApplication sharedApplication] openURL:url];
        }
    }
    return NO;
}

- (BOOL)openSchema:(NSString *)schema params:(NSDictionary *)params {
    NSDictionary *schemaDic = self.supportedSchema[schema];
    NSString *className = schemaDic[kFFSchemaName];
    if (!className) {
        return NO;
    }
    
    NSInteger isTabItem = [schemaDic[kFFSchemaKeyTabIndex] integerValue];
    
    //  登录处理
    BOOL needLogin = [schemaDic[kFFSchemaKeyIsNeedLogin] boolValue];
    if (needLogin) {
        //TODO:
        
    } else {
        [self pushViewController:className withParams:params tabItem:isTabItem];
    }
    return YES;
}

#pragma mark - private method

- (UINavigationController *)currentNavViewController {
    
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    if ([rootViewController isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tabBarController = (UITabBarController *)rootViewController;
        if ([tabBarController.selectedViewController isKindOfClass:[UINavigationController class]]) {
            rootViewController = (UINavigationController *)tabBarController.selectedViewController;
        }
    }
    
    if ([rootViewController isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)rootViewController;
    }
    
    if ([rootViewController isKindOfClass:[UIViewController class]]) {
        return rootViewController.navigationController;
    }
    
    return nil;
}

- (NSArray *)getAppSchemas {
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSArray *dictArray = [infoDict objectForKey:@"CFBundleURLTypes"];
    NSMutableArray *schemaArray = [NSMutableArray array];
    for (NSDictionary *dict in dictArray) {
        NSArray *parts = [dict objectForKey:@"CFBundleURLSchemes"];
        if ([parts count] > 0) {
            [schemaArray addObjectsFromArray:parts];
        }
    }
    
    return schemaArray;
}

- (void)pushViewController:(NSString *)className withParams:(NSDictionary *)params {
    [self pushViewController:className withParams:params tabItem:-1];
}

- (void)pushViewController:(NSString *)className withParams:(NSDictionary *)params tabItem:(NSInteger)tabbarIndex {
    
    //If rootViewController is UITabBarController,do select tabbar Index
    UIViewController *rootViewController = [UIApplication sharedApplication].delegate.window.rootViewController;
    if (tabbarIndex >= 0 && [rootViewController isKindOfClass:[UITabBarController class]]) {

        UINavigationController *navi = (UINavigationController *)[(UITabBarController *)rootViewController selectedViewController];
        if (!navi) {
            return;
        }
        if (navi.topViewController.presentedViewController) {
            [navi.topViewController.presentedViewController dismissViewControllerAnimated:NO completion:nil];
        }
        
        [navi.topViewController dismissViewControllerAnimated:NO completion:nil];
        [navi popToRootViewControllerAnimated:NO];
        
        if (tabbarIndex < ((UITabBarController *)rootViewController).viewControllers.count) {
            [(UITabBarController *)rootViewController setSelectedIndex:tabbarIndex];
        }
        
        ((UITabBarController *)rootViewController).hidesBottomBarWhenPushed = YES;
    }
    
    /* Crash修复
     * Fatal Exception: NSInvalidArgumentException
     *** -[NSProxy doesNotRecognizeSelector:currentViewController] called!
     */
//    if (![[UIApplication sharedApplication].delegate isKindOfClass:[AppDelegate class]]) {
//        return;
//    }
    
    UINavigationController *currentNavViewController = [self currentNavViewController];
    if (!currentNavViewController) {
        return;
    }
    
    Class desVCClass = NSClassFromString(className);
    UIViewController *desViewController = nil;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if (class_respondsToSelector(desVCClass, @selector(initWithScheme:))) {
        desViewController = [[desVCClass alloc] performSelector:@selector(initWithScheme:) withObject:params];
    } else {
        desViewController = [desViewController init];
    }
#pragma clang diagnostic pop
    
    if (!desViewController) {
        return;
    }
    
    [currentNavViewController pushViewController:desViewController animated:YES];
}

@end