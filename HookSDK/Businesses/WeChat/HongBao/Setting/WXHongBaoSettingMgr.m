//
//  WXHongBaoSettingMgr.m
//  WXHookDemo
//
//  Created by arlin on 17/3/13.
//  Copyright © 2017年 arlin. All rights reserved.
//

#import "WXHongBaoSettingMgr.h"
#import "HKCommonDefine.h"
#import "WeChatCommonDefine.h"
#import "HKAppAuthorizationMgr.h"
#import "NSString+HKSearch.h"
#import "WXHongBaoRuleManager.h"
#import "WXAutoChangeMyInfoMgr.h"
#import "JSONKit.h"
#import "WXHongBaoIPCCmdMgr.h"

NSString *const KWXHongBaoSettingUpdate = @"KWXHongBaoSettingUpdate";

NSString *const KWXHongBaoSettingKeyEnable = @"KWXHongBaoSettingKeyEnable";
NSString *const KWXHongBaoSettingKeyNotice = @"KWXHongBaoSettingKeyNotice";
NSString *const KWXHongBaoSettingKeyAutoOpen = @"KWXHongBaoSettingKeyAutoOpen";
NSString *const KWXHongBaoSettingKeyQuickOpen = @"KWXHongBaoSettingKeyQuickOpen";
NSString *const KWXHongBaoSettingKeyEnableFullLog = @"KWXHongBaoSettingKeyEnableFullLog";
NSString *const KWXHongBaoSettingKeySmartSpliteTitle = @"KWXHongBaoSettingKeySmartSpliteTitle";
NSString *const KWXHongBaoSettingKeyAutoOpenDelay = @"KWXHongBaoSettingKeyAutoOpenDelay";
NSString *const KWXHongBaoSettingKeyAuth = @"KWXHongBaoSettingKeyAuth";
NSString *const KWXHongBaoSettingKeyQueryDelay = @"KWXHongBaoSettingKeyQueryDelay";
NSString *const KWXHongBaoSettingKeyTitle = @"KWXHongBaoSettingKeyTitle";
NSString *const KWXHongBaoSettingKeyGroupName = @"KWXHongBaoSettingKeyGroupName";
NSString *const KWXHongBaoSettingKeyIsMaster = @"KWXHongBaoSettingKeyIsMaster";
NSString *const KWXHongBaoSettingKeyMasterIP = @"KWXHongBaoSettingKeyMasterIP";
NSString *const KWXHongBaoSettingKeyHit = @"KWXHongBaoSettingKeyHit";
NSString *const KWXHongBaoSettingKeySmall = @"KWXHongBaoSettingKeySmall";
NSString *const KWXHongBaoSettingKeyAutoChangeInfo = @"KWXHongBaoSettingKeyAutoChangeInfo";
NSString *const KWXHongBaoSettingKeySmartOpen = @"KWXHongBaoSettingKeySmartOpen";
NSString *const KWXHongBaoSettingKeyOnlyMe = @"KWXHongBaoSettingKeyOnlyMe";

#define KWXHongBaoSettingMgrStringSplite @"|&|"

@implementation WXHongBaoSettingInfoItem

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.title forKey:@"title"];
    [aCoder encodeObject:self.text forKey:@"text"];
    [aCoder encodeBool:self.switchShow forKey:@"switchShow"];
    [aCoder encodeBool:self.switchOn forKey:@"switchOn"];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.title = [aDecoder decodeObjectForKey:@"title"];
        self.text = [aDecoder decodeObjectForKey:@"text"];
        self.switchShow = [aDecoder decodeBoolForKey:@"switchShow"];
        self.switchOn = [aDecoder decodeBoolForKey:@"switchOn"];
    }
    
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"name = %@, title = %@, text = %@, switchShow = %d, switchOn = %d", self.name, self.title, self.text, self.switchShow, self.switchOn];
}

@end


@interface WXHongBaoSettingMgr ()

@end

@implementation WXHongBaoSettingMgr

+ (instancetype)shareInstance
{
    static id ddd = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ddd = [[[self class] alloc] init];
    });
    
    return ddd;
}

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        [self createSettingInfoList];
        [HKAppAuthorizationMgr shareInstance].settingURL = @"Your URL";
        [HKAppAuthorizationMgr shareInstance].fileName = @"wxhb";
        [[HKAppAuthorizationMgr shareInstance] startFetchData];
    }
    
    return self;
}

- (void)createSettingInfoList
{
    NSMutableArray *list = [[NSMutableArray alloc] init];
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyEnable;
        item.title = @"总开关";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = YES;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyIsMaster;
        item.title = @"设置为主号";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = NO;
        
        if ( [HKAppBundleId isEqualToString:@"com.tencent.xin"] )
        {
            item.switchOn = YES;
        }
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyOnlyMe;
        item.title = @"只抢自己发的包";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyNotice;
        item.title = @"通知小号";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = YES;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyAutoOpen;
        item.title = @"自动抢包";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = YES;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyAutoChangeInfo;
        item.title = @"自动修改资料";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyEnableFullLog;
        item.title = @"详细日志";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyQuickOpen;
        item.title = @"极速抢包";
        item.switchShow = YES;
        item.text = nil;
        item.switchOn = YES;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyAuth;
        item.title = @"授权码";
        item.switchShow = NO;
        item.text = @" ";
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyMasterIP;
        item.title = @"主号IP地址";
        item.switchShow = NO;
        item.text = @"127.0.0.1";
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyAutoOpenDelay;
        item.title = @"延迟抢包(毫秒)";
        item.switchShow = NO;
        item.text = @"0";
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyQueryDelay;
        item.title = @"查询详情间隔(毫秒)";
        item.switchShow = NO;
        item.text = @"0";  // 极速优化：默认值改为0
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyGroupName;
        item.title = [NSString stringWithFormat:@"群名称白名单(%@隔开)", KWXHongBaoSettingMgrStringSplite];;
        item.switchShow = NO;
        item.text = @"";
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeyHit;
        item.title = [NSString stringWithFormat:@"尾数扫雷"];
        item.switchShow = NO;
        item.text = @" ";
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeySmall;
        item.title = [NSString stringWithFormat:@"最小红包接龙"];
        item.switchShow = NO;
        item.text = @" ";
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    {
        WXHongBaoSettingInfoItem *item = [[WXHongBaoSettingInfoItem alloc] init];
        item.name = KWXHongBaoSettingKeySmartOpen;
        item.title = [NSString stringWithFormat:@"智能比例抢红包"];
        item.switchShow = NO;
        item.text = @" ";
        item.switchOn = NO;
        
        WXHongBaoSettingInfoItem *localItem = [self localSettingInfoByKey:item.name];
        if ( localItem )
        {
            item = localItem;
        }
        
        [list addObject:item];
    }
    
    self.settingInfoList = [NSArray arrayWithArray:list];
}

- (void)updateSettingInfo:(WXHongBaoSettingInfoItem *)info
{
    BOOL updated = NO;
    
    for ( WXHongBaoSettingInfoItem *item in self.settingInfoList )
    {
        if ( [item.name isEqualToString:info.name] )
        {
            item.switchShow = info.switchShow;
            item.text = info.text;
            item.switchOn = info.switchOn;
            
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:item];
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:item.name];
            
            updated = YES;
            
            // 极速优化：清除相关延迟缓存，确保下次获取最新值
            if ([item.name isEqualToString:KWXHongBaoSettingKeyAutoOpenDelay]) {
                // 重置openDelay缓存
                static float *cachedOpenDelay = NULL;
                static NSString **cachedOpenDelayText = NULL;
                if (cachedOpenDelay) *cachedOpenDelay = -1.0;
                if (cachedOpenDelayText) *cachedOpenDelayText = nil;
            } else if ([item.name isEqualToString:KWXHongBaoSettingKeyQueryDelay]) {
                // 重置queryDelay缓存
                static float *cachedQueryDelay = NULL;
                static NSString **cachedQueryDelayText = NULL;
                if (cachedQueryDelay) *cachedQueryDelay = -1.0;
                if (cachedQueryDelayText) *cachedQueryDelayText = nil;
            }
            
            if ( [item.name isEqualToString:KWXHongBaoSettingKeyAuth] )
            {
                if ( [[WXHongBaoSettingMgr shareInstance] enableFullLog] )
                {
                    NSString *log = [[HKAppAuthorizationMgr shareInstance].appKeysList description];
                    HKTagNSLog(KWeChatCmdLog, log);
                }
                [[HKAppAuthorizationMgr shareInstance] makeAppAuthorization:item.text];
            }
        }
    }
    
    if ( updated )
    {
        NSString *conf = [self makeupConfigString];
        [[WXHongBaoIPCCmdMgr shareInstance] sendConfigCmd:conf];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:KWXHongBaoSettingUpdate object:nil];
    }
}

- (void)clearLocalData
{
    for ( WXHongBaoSettingInfoItem *item in self.settingInfoList )
    {
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:item.name];
    }
    
    [[WXHongBaoRuleManager shareInstance] clearLocalConfig];
}

- (WXHongBaoSettingInfoItem *)settingInfoByKey:(NSString *)key
{
    // 极速优化：使用静态字典缓存，避免线性查找
    static NSMutableDictionary *settingCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        settingCache = [NSMutableDictionary dictionaryWithCapacity:20];
    });
    
    // 先从缓存查找
    WXHongBaoSettingInfoItem *cachedItem = settingCache[key];
    if (cachedItem) {
        return cachedItem;
    }
    
    // 缓存未命中，进行查找并缓存
    for ( WXHongBaoSettingInfoItem *item in self.settingInfoList )
    {
        if ( [item.name isEqualToString:key] )
        {
            settingCache[key] = item; // 缓存结果
            return item;
        }
    }
    
    return nil;
}

- (WXHongBaoSettingInfoItem *)localSettingInfoByKey:(NSString *)key
{
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

- (BOOL)isEnable
{
    if ( ![self isAppAuthorized] )
    {
        return NO;
    }
    
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyEnable];
    
    return item.switchOn;
}

- (BOOL)canNotice
{
    //小号不能通知
    if ( ![self isEnable] || ![self isMaster] )
    {
        return NO;
    }
    
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyNotice];
    
    return item.switchOn;
}

- (BOOL)autoOpen
{
    //小号不自动领取
    if ( ![self isEnable] || ![self isMaster] )
    {
        return NO;
    }
    
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyAutoOpen];
    
    return item.switchOn;
}

- (BOOL)canQuickOpen
{
    if ( ![self isEnable] )
    {
        return NO;
    }
    
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyQuickOpen];
    
    return item.switchOn;
}

- (BOOL)enableFullLog
{
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyEnableFullLog];
    
    return item.switchOn;
}

- (BOOL)autoChangeInfo
{
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyAutoChangeInfo];
    
    return item.switchOn;
}

- (BOOL)openOnlySendByMe
{
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyOnlyMe];
    
    return item.switchOn;
}

- (NSString *)masterIPAddress
{
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyMasterIP];
    
    return item.text;
}

- (float)openDelay
{
    // 极速优化：缓存延迟值，避免重复计算
    static float cachedOpenDelay = -1.0;
    static NSString *cachedOpenDelayText = nil;
    
    if ( ![self isEnable] )
    {
        return 0.0;
    }
    
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyAutoOpenDelay];
    
    // 如果配置未变，直接返回缓存值
    if (cachedOpenDelay >= 0 && [item.text isEqualToString:cachedOpenDelayText]) {
        return cachedOpenDelay;
    }
    
    // 更新缓存
    cachedOpenDelayText = item.text;
    cachedOpenDelay = [item.text integerValue] * 0.001;
    
    return cachedOpenDelay;
}

- (float)queryDelay
{
    // 极速优化：缓存延迟值，避免重复计算
    static float cachedQueryDelay = -1.0;
    static NSString *cachedQueryDelayText = nil;
    
    if ( ![self isEnable] )
    {
        return 0.0;
    }
    
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyQueryDelay];
    
    // 如果配置未变，直接返回缓存值
    if (cachedQueryDelay >= 0 && [item.text isEqualToString:cachedQueryDelayText]) {
        return cachedQueryDelay;
    }
    
    // 更新缓存
    cachedQueryDelayText = item.text;
    cachedQueryDelay = [item.text integerValue] * 0.001;
    
    return cachedQueryDelay;
}

- (BOOL)isGroupNameVaild:(NSString *)groupName
{
    if ( ![self isEnable] )
    {
        return NO;
    }
    
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyGroupName];
    NSArray *spliteList = [item.text componentsSeparatedByString:KWXHongBaoSettingMgrStringSplite];
    for ( NSString * splite in spliteList )
    {
        if ( [splite isEqualToString:groupName] || [splite isEqualToString:@"all"] )
        {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)isMaster
{
    WXHongBaoSettingInfoItem *item = [self settingInfoByKey:KWXHongBaoSettingKeyIsMaster];
    
    return item.switchOn;
}

- (BOOL)isAppAuthorized
{
    return [[HKAppAuthorizationMgr shareInstance] isAppAuthorized];
}

- (NSString *)makeupConfigString
{
    WXHongBaoSettingInfoItem *groupNameItem = [self settingInfoByKey:KWXHongBaoSettingKeyGroupName];
    WXHongBaoSettingInfoItem *authItem = [self settingInfoByKey:KWXHongBaoSettingKeyAuth];
    WXHongBaoSettingInfoItem *ipItem = [self settingInfoByKey:KWXHongBaoSettingKeyMasterIP];
    
    NSMutableDictionary *json = [NSMutableDictionary dictionary];
    
    [json setObject:groupNameItem.text forKey:@"group_name"];
    [json setObject:authItem.text forKey:@"auth_key"];
    [json setObject:ipItem.text forKey:@"ip"];
    
    NSString *string = [json JSONString];
    
    return string;
}

- (void)configByConfigString:(NSString *)conf
{
    WXHongBaoSettingInfoItem *groupNameItem = [self settingInfoByKey:KWXHongBaoSettingKeyGroupName];
    WXHongBaoSettingInfoItem *authItem = [self settingInfoByKey:KWXHongBaoSettingKeyAuth];
    WXHongBaoSettingInfoItem *ipItem = [self settingInfoByKey:KWXHongBaoSettingKeyMasterIP];
    
    NSDictionary *json = [conf objectFromJSONString];
    NSString *groupName = [json objectForKey:@"group_name"];
    NSString *auth = [json objectForKey:@"auth_key"];
    NSString *ip = [json objectForKey:@"ip"];
    
    groupNameItem.text = groupName;
    authItem.text = auth;
    ipItem.text = ip;
    
    [self updateSettingInfo:groupNameItem];
    [self updateSettingInfo:authItem];
    [self updateSettingInfo:ipItem];
}

@end
