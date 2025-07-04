//
//  WXHongBaoOpeartionMgr.m
//  HookSDK
//
//  Created by arlin on 17/3/13.
//
//

#import "WXHongBaoOpeartionMgr.h"
#import "WeChatRedEnvelop.h"
#import "NSObject+HKMethodSwizzed.h"
#import "WeChatHookSDK.h"
#import "NSObject+HSClassInfo.h"
#import "NSDictionary+HKPrint.h"
#import "WeChatRedEnvelopParam.h"
#import <objc/runtime.h>
#import "NSDictionary+HKPrint.h"
#import "WXHongBaoMessageListMgr.h"
#import "WXHongBaoIPCCmdMgr.h"
#import "WXHongBaoSettingMgr.h"
#import "WXHongBaoRuleManager.h"
#import "WXHongBaoQueryTaskMgr.h"

@implementation WXHongBaoOpeartionMgr

+ (instancetype)shareInstance
{
    static id sss = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sss = [[[self class] alloc] init];
    });
    
    return sss;
}

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
       
    }
    
    return self;
}

- (void)wxQueryRedEnvelopesDetailRequest:(NSDictionary *)arg1
{
    WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("WCRedEnvelopesLogicMgr") class]];
    [logicMgr QueryRedEnvelopesDetailRequest:arg1];
}

- (void)wxOpenRedEnvelopesRequest:(NSDictionary *)params
{
    WCRedEnvelopesLogicMgr *logicMgr = [[NSClassFromString(@"MMServiceCenter") defaultCenter] getService:NSClassFromString(@"WCRedEnvelopesLogicMgr")];
    [logicMgr OpenRedEnvelopesRequest:params];
}

- (void)openHongBaoAccordingToSetting:(CMessageWrap *)wrap
{
    if ( ![[WXHongBaoMessageListMgr shareInstance] isHongBaoMessage:wrap] )
    {
        return; // 极速模式：跳过日志
    }
    
    // 极速验证 - 只检查关键条件
    if ( ![[WXHongBaoSettingMgr shareInstance] autoOpen] || ![[WXHongBaoSettingMgr shareInstance] isEnable] )
    {
        return;
    }
    
    float openDelay = [[WXHongBaoSettingMgr shareInstance] openDelay];
    
    // 零延迟优化：openDelay为0时直接执行，避免dispatch开销
    if (openDelay <= 0.001) { // 小于1ms视为零延迟
        [self openHongBaoByMessageWrap:wrap log:NO];
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(openDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openHongBaoByMessageWrap:wrap log:NO];
        });
    }
}

- (void)openHongBaoByNativeURL:(NSString *)nativeURL usingCacheTimingId:(BOOL)usingCacheTimingId log:(BOOL)log
{
    NSDictionary *dic = [[WXHongBaoMessageListMgr shareInstance] hongBaoParseNativeURL:nativeURL];
    
    NSString *sendId = [dic stringForKey:@"sendid"];
    NSString *timingId = nil;
    CMessageWrap *wrap = nil;
    
    if ( usingCacheTimingId )
    {
        timingId = [[WXHongBaoMessageListMgr shareInstance] timingIdOfName:sendId];
        
        // 极速路径：如果有timingId，立即构建参数并执行
        if ( timingId != nil )
        {
            // 预分配静态参数字典，避免重复创建
            static NSMutableDictionary *fastParams = nil;
            if (!fastParams) {
                fastParams = [[NSMutableDictionary alloc] initWithCapacity:8];
            }
            [fastParams removeAllObjects];
            
            // 直接构建参数，跳过WeChatRedEnvelopParam中间对象
            fastParams[@"agreeDuty"] = @"0";
            fastParams[@"inWay"] = @"0";
            fastParams[@"msgType"] = @"1";
            fastParams[@"nativeUrl"] = nativeURL;
            fastParams[@"sendId"] = sendId;
            fastParams[@"timingIdentifier"] = timingId;
            
            // 极速执行
            [[WXHongBaoOpeartionMgr shareInstance] wxOpenRedEnvelopesRequest:fastParams];
            return;
        }
    }
    
    // 降级到正常流程
    wrap = [[WXHongBaoMessageListMgr shareInstance] hongBaoMessageBySendId:sendId];
    [self openHongBaoByMessageWrap:wrap log:NO];
}

- (void)openHongBaoByMessageWrap:(CMessageWrap *)wrap log:(BOOL)log
{
    // 极速模式：跳过详细日志和验证
    if ( ![[WXHongBaoMessageListMgr shareInstance] isHongBaoMessage:wrap] )
    {
        return;
    }
    
    // 预分配静态参数字典
    static NSMutableDictionary *queryParams = nil;
    if (!queryParams) {
        queryParams = [[NSMutableDictionary alloc] initWithCapacity:6];
    }
    [queryParams removeAllObjects];
    
    // 预缓存LogicMgr，避免重复获取
    static WCRedEnvelopesLogicMgr *cachedLogicMgr = nil;
    if (!cachedLogicMgr) {
        cachedLogicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:[objc_getClass("WCRedEnvelopesLogicMgr") class]];
    }
    
    NSString *nativeUrl = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
    NSDictionary *nativeUrlDict = [[WXHongBaoMessageListMgr shareInstance] hongBaoParseNativeURL:nativeUrl];
    
    // 快速构建参数，避免block和mutableCopy开销
    queryParams[@"agreeDuty"] = @"0";
    queryParams[@"channelId"] = [nativeUrlDict stringForKey:@"channelid"];
    queryParams[@"inWay"] = @"0";
    queryParams[@"msgType"] = [nativeUrlDict stringForKey:@"msgtype"];
    queryParams[@"nativeUrl"] = nativeUrl;
    queryParams[@"sendId"] = [nativeUrlDict stringForKey:@"sendid"];
    
    [[WXHongBaoMessageListMgr shareInstance] addAutoOpenHongBaoMesage:wrap];
    
    // 直接执行，避免block调用开销
    [cachedLogicMgr ReceiverQueryRedEnvelopesRequest:queryParams];
}

- (BOOL)testHongBaoMessageCanAutoOpen:(CMessageWrap *)wrap log:(BOOL)log
{
    HKTagNSLog(KWeChatHookSDKLog, @"WXHongBaoOpeartionMgr::testHongBaoMessageCanAutoOpen");
    
    
    BOOL autoOpen = [[WXHongBaoSettingMgr shareInstance] autoOpen];
    
    if ( !autoOpen )
    {
        HKTagNSLog(KWeChatHookSDKLog, @"自动抢包关闭");
        
        if ( log )
        {
            [[WXHongBaoIPCCmdMgr shareInstance] sendLogCmdWithFromApp:@"自动抢包关闭"];
        }
        
        return NO;
    }
    
    BOOL testHongBaoMessageCanOpen = [self testHongBaoMessageCanOpen:wrap authTitle:YES log:log];
    if ( !testHongBaoMessageCanOpen )
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)testHongBaoMessageCanOpen:(CMessageWrap *)wrap authTitle:(BOOL)authTitle log:(BOOL)log
{
    // 极速验证：只检查关键条件，跳过日志和详细信息
    WXHongBaoSettingMgr *settingMgr = [WXHongBaoSettingMgr shareInstance];
    
    // 快速检查基础条件
    if ( ![settingMgr isAppAuthorized] || ![settingMgr isEnable] ) {
        return NO;
    }
    
    // 群名验证
    NSString *groupName = [[WXHongBaoMessageListMgr shareInstance] groupNameFromMessage:wrap];
    if ( ![settingMgr isGroupNameVaild:groupName] ) {
        return NO;
    }
    
    // 自己发包验证
    if ( [settingMgr openOnlySendByMe] && ![[WXHongBaoMessageListMgr shareInstance] isSendByMe:wrap] ) {
        return NO;
    }
    
    // 标题验证（如果需要）
    if ( authTitle ) {
        return [self testCanOpenHongBao:wrap log:NO]; // 跳过日志提升性能
    }
    
    return YES;
}

- (BOOL)testCanOpenHongBao:(CMessageWrap *)wrap log:(BOOL)log
{
    HKTagNSLog(KWeChatHookSDKLog, @"WXHongBaoOpeartionMgr::testCanOpenHongBao");
    NSString *title = [[WXHongBaoMessageListMgr shareInstance] hongBaoTitleWithMessage:wrap];
    NSMutableArray *logArray = [NSMutableArray array];
    BOOL testCanOpenHongBao = [[WXHongBaoRuleManager shareInstance] testCanOpenHongBao:title log:logArray];
    if ( !testCanOpenHongBao )
    {
        //输出错误日志
        for ( NSString *errorLog in logArray )
        {
            HKTagNSLog(KWeChatHookSDKLog, errorLog);
            if ( log )
            {
                [[WXHongBaoIPCCmdMgr shareInstance] sendLogCmdWithFromApp:errorLog];
            }
        }
        
        return NO;
    }
    
    return YES;
}

- (NSString *)getMyNickName
{
    CContactMgr *contactManager = [[NSClassFromString(@"MMServiceCenter") defaultCenter] getService:[NSClassFromString(@"CContactMgr") class]];
    CContact *selfContact = [contactManager getSelfContact];
    
    return [selfContact getContactDisplayName];
}

- (void)startQueryHongBaoDetailTask:(CMessageWrap *)wrap
{
    BOOL canNotice = [[WXHongBaoSettingMgr shareInstance] canNotice];
    BOOL isMaster = [[WXHongBaoSettingMgr shareInstance] isMaster];
    
    if ( isMaster )
    {
        if ( ![[WXHongBaoOpeartionMgr shareInstance] testHongBaoMessageCanOpen:wrap authTitle:YES log:YES] )
        {
            return;
        }
        
        if ( canNotice )
        {
            [[WXHongBaoQueryTaskMgr shareInstance] startQueryHongBaoDetailTask:wrap];
        }
        else
        {
            [[WXHongBaoIPCCmdMgr shareInstance] sendLogCmdWithFromApp:@"不通知小号"];
        }
    }
}

@end
