//
//  WXHookQueryTaskMgr.m
//  555
//
//  Created by dps on 17/3/14.
//  Copyright © 2017年 dps. All rights reserved.
//

#import "WXHongBaoQueryTaskMgr.h"
#import "HKAsynTickoutTask.h"
#import "WXHongBaoOpeartionMgr.h"
#import "WXHongBaoMessageListMgr.h"
#import "WXHongBaoIPCCmdMgr.h"
#import "HKCommonDefine.h"
#import "WeChatCommonDefine.h"
#import "WXHongBaoSettingMgr.h"

@interface WXHongBaoQueryTaskMgr ()

@property (nonatomic, strong) NSMutableArray<HKAsynTickoutTask *> *taskList;

@end

@implementation WXHongBaoQueryTaskMgr

+ (instancetype)shareInstance
{
    static id ss = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ss = [[[self class] alloc] init];
    });
    
    return ss;
}

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        self.taskList = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (HKAsynTickoutTask *)taskByName:(NSString *)name
{
    for ( HKAsynTickoutTask *task in self.taskList )
    {
        if ( [task.name isEqualToString:name] )
        {
            return task;
        }
    }
    
    return nil;
}

- (void)startQueryHongBaoDetailTask:(CMessageWrap *)wrap
{
    NSString *sendId = [[WXHongBaoMessageListMgr shareInstance] sendIdFromMessage:wrap];
    HKAsynTickoutTask *task = [self taskByName:sendId];
    if ( task != nil )
    {
        return;
    }
    
    // 极速模式 - 减少日志开销
    if ( [[WXHongBaoSettingMgr shareInstance] enableFullLog] )
    {
        [[WXHongBaoIPCCmdMgr shareInstance] sendLogCmdWithFromApp:@"查询领取详情"];
    }
    
    // 预分配参数字典，避免动态创建
    static NSMutableDictionary *staticParams = nil;
    if (!staticParams) {
        staticParams = [[NSMutableDictionary alloc] initWithCapacity:4];
    }
    
    // 预编译URL模板
    static NSString *urlTemplate = @"weixin://weixinhongbao/opendetail?sendid=";
    
    HKAsynTicktockTaskBlock taskBlock = ^(HKAsynTickoutTask *task){
        // 复用字典，清空后重新设置
        [staticParams removeAllObjects];
        
        // 避免stringWithFormat，直接使用字符串拼接
        staticParams[@"msgType"] = @"1";  // 固定值，避免格式化
        staticParams[@"sendId"] = sendId;
        staticParams[@"nativeUrl"] = [urlTemplate stringByAppendingString:sendId];
        
        [[WXHongBaoOpeartionMgr shareInstance] wxQueryRedEnvelopesDetailRequest:staticParams];
    };
    
    HKAsynTickoutTask* newTask = [[HKAsynTickoutTask alloc] init];
    newTask.name = sendId;
    newTask.duration = [[WXHongBaoSettingMgr shareInstance] queryDelay];
    newTask.taskBlock = taskBlock;
    newTask.userInfo = wrap;
    newTask.repeat = YES;
    
    [newTask start];
    [self.taskList addObject:newTask];
}

- (void)stopQueryHongBaoDetailTask:(CMessageWrap *)wrap
{
    NSString *sendId = [[WXHongBaoMessageListMgr shareInstance] sendIdFromMessage:wrap];
    HKAsynTickoutTask *task = [self taskByName:sendId];
    if ( task == nil )
    {
        return;
    }
    
    HKTagNSLog(KWeChatHookSDKLog, @"停止查询领取详情");
    if ( [[WXHongBaoSettingMgr shareInstance] enableFullLog] )
    {
        [[WXHongBaoIPCCmdMgr shareInstance] sendLogCmdWithFromApp:@"停止查询领取详情"];
    }
    
    [task stop];
    [self.taskList removeObject:task];
}

- (BOOL)isRunningQueryTaskOf:(CMessageWrap *)wrap
{
    NSString *sendId = [[WXHongBaoMessageListMgr shareInstance] sendIdFromMessage:wrap];
    HKAsynTickoutTask *task = [self taskByName:sendId];
    
    return task != nil;
}

- (void)startQueryHongBaoStateTask:(NSString *)nativeURL
{
    NSString *sendId = [[WXHongBaoMessageListMgr shareInstance] sendIdFromNativeURL:nativeURL];
    NSString *name = [self nameOfQueryState:nativeURL];
    HKAsynTickoutTask *task = [self taskByName:name];
    if ( task != nil )
    {
        return;
    }
    
    // 极速模式 - 减少字符串格式化和日志
    if ( [[WXHongBaoSettingMgr shareInstance] enableFullLog] )
    {
        [[WXHongBaoIPCCmdMgr shareInstance] sendLogCmdWithFromApp:@"自动查询红包状态"];
    }
    
    HKAsynTickoutTask* newTask = [[HKAsynTickoutTask alloc] init];
    newTask.name = name;
    newTask.duration = 0; // 极速模式，无延迟
    newTask.taskBlock = ^(HKAsynTickoutTask *task){
        // 直接抢包，跳过额外的参数构建
        [[WXHongBaoOpeartionMgr shareInstance] openHongBaoByNativeURL:nativeURL usingCacheTimingId:YES log:NO];
    };
    newTask.userInfo = nativeURL;
    newTask.repeat = NO;
    
    [newTask start];
    [self.taskList addObject:newTask];
}

- (void)stopQueryHongBaoStateTask:(NSString *)nativeURL
{
    NSString *name = [self nameOfQueryState:nativeURL];
    HKAsynTickoutTask *task = [self taskByName:name];
    
    NSString *log = [NSString stringWithFormat:@"停止查询红包状态 task = %d, name = %@", task != nil, name];
    HKTagNSLog(KWeChatHookSDKLog, log);
    
    if ( task == nil )
    {
        return;
    }
    
    if ( [[WXHongBaoSettingMgr shareInstance] enableFullLog] )
    {
        [[WXHongBaoIPCCmdMgr shareInstance] sendLogCmdWithFromApp:@"停止查询红包状态"];
    }
    
    [task stop];
    [self.taskList removeObject:task];
}

- (BOOL)isRunningQueryStateTaskOf:(NSString *)nativeURL
{
    NSString *name = [self nameOfQueryState:nativeURL];
    HKAsynTickoutTask *task = [self taskByName:name];
    
    return task != nil;
}

- (NSString *)nameOfQueryState:(NSString *)nativeURL
{
    NSString *sendId = [[WXHongBaoMessageListMgr shareInstance] sendIdFromNativeURL:nativeURL];
    // 极速优化：避免stringWithFormat，直接拼接
    static NSString *prefix = @"querystate_";
    return [prefix stringByAppendingString:sendId];
}

@end
