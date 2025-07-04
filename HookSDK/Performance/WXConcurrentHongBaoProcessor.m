//
//  WXConcurrentHongBaoProcessor.m
//  HookSDK - 多红包极速并发处理
//
//  Created by Performance Optimizer
//  Copyright © 2024 极速抢包. All rights reserved.
//

#import "WXConcurrentHongBaoProcessor.h"
#import "WXTurboCache.h"
#import "WXHongBaoOpeartionMgr.h"
#import "WXHongBaoMessageListMgr.h"
#import "WXHongBaoSettingMgr.h"
#import "WeChatCommonDefine.h"
#import <libkern/OSAtomic.h>

// 预分配常量
static const NSUInteger kDefaultMaxConcurrentOperations = 10;
static const NSTimeInterval kDefaultTimeoutInterval = 5.0;
static const NSUInteger kBatchSize = 5; // 批量处理大小

@interface WXConcurrentHongBaoProcessor ()

// 高性能并发队列
@property (nonatomic, strong) dispatch_queue_t ultraFastQueue;
@property (nonatomic, strong) dispatch_queue_t batchProcessQueue;
@property (nonatomic, strong) dispatch_semaphore_t concurrencySemaphore;

// 对象池 - 避免频繁分配
@property (nonatomic, strong) NSMutableArray *taskPool;
@property (nonatomic, strong) NSMutableArray *resultPool;
@property (nonatomic, strong) NSLock *poolLock;

// 性能统计 - 原子操作
@property (nonatomic, assign) volatile int64_t totalProcessed;
@property (nonatomic, assign) volatile int64_t successCount;
@property (nonatomic, assign) volatile int64_t totalResponseTime; // 微秒
@property (nonatomic, assign) volatile int32_t currentConcurrent;

// 批量处理缓冲区
@property (nonatomic, strong) NSMutableArray *batchBuffer;
@property (nonatomic, strong) NSLock *batchLock;
@property (nonatomic, strong) NSTimer *batchTimer;

@end

@implementation WXConcurrentHongBaoProcessor

+ (instancetype)shared {
    static WXConcurrentHongBaoProcessor *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WXConcurrentHongBaoProcessor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self setupConcurrentProcessor];
    }
    return self;
}

- (void)setupConcurrentProcessor {
    // 设置默认值
    _maxConcurrentOperations = kDefaultMaxConcurrentOperations;
    _timeoutInterval = kDefaultTimeoutInterval;
    _ultraFastMode = YES; // 默认开启极速模式
    _batchOptimizationEnabled = YES;
    
    // 创建高优先级并发队列
    _ultraFastQueue = dispatch_queue_create("com.wx.hongbao.ultrafast", 
                                          DISPATCH_QUEUE_CONCURRENT);
    _batchProcessQueue = dispatch_queue_create("com.wx.hongbao.batch", 
                                             DISPATCH_QUEUE_SERIAL);
    
    // 设置队列优先级为最高
    dispatch_set_target_queue(_ultraFastQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    
    // 并发控制信号量
    _concurrencySemaphore = dispatch_semaphore_create(_maxConcurrentOperations);
    
    // 初始化对象池
    _taskPool = [NSMutableArray arrayWithCapacity:50];
    _resultPool = [NSMutableArray arrayWithCapacity:50];
    _poolLock = [[NSLock alloc] init];
    
    // 预分配对象池
    for (int i = 0; i < 20; i++) {
        [_taskPool addObject:[NSMutableDictionary dictionaryWithCapacity:10]];
        [_resultPool addObject:[NSMutableDictionary dictionaryWithCapacity:5]];
    }
    
    // 批量处理缓冲区
    _batchBuffer = [NSMutableArray arrayWithCapacity:20];
    _batchLock = [[NSLock alloc] init];
    
    // 预热缓存
    [[WXTurboCache shared] preloadHongBaoCache];
}

#pragma mark - 极速并发处理

- (void)processBatchHongBaoMessages:(NSArray<CMessageWrap *> *)messages
                         completion:(void(^)(NSArray *results))completion {
    
    if (messages.count == 0) {
        if (completion) completion(@[]);
        return;
    }
    
    // 如果只有一个红包，直接用单个处理
    if (messages.count == 1) {
        [self processHongBaoMessageUltraFast:messages.firstObject completion:^(BOOL success, NSTimeInterval responseTime) {
            if (completion) {
                completion(@[@{@"success": @(success), @"responseTime": @(responseTime)}]);
            }
        }];
        return;
    }
    
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:messages.count];
    dispatch_group_t group = dispatch_group_create();
    
    // 批量并发处理
    for (CMessageWrap *message in messages) {
        dispatch_group_enter(group);
        
        [self processHongBaoMessageUltraFast:message completion:^(BOOL success, NSTimeInterval responseTime) {
            @synchronized(results) {
                [results addObject:@{
                    @"success": @(success),
                    @"responseTime": @(responseTime),
                    @"sendId": [[WXHongBaoMessageListMgr shareInstance] sendIdFromMessage:message] ?: @""
                }];
            }
            dispatch_group_leave(group);
        }];
    }
    
    // 等待所有任务完成
    dispatch_group_notify(group, _batchProcessQueue, ^{
        if (completion) {
            completion([results copy]);
        }
    });
}

- (void)processHongBaoMessageUltraFast:(CMessageWrap *)message
                            completion:(void(^)(BOOL success, NSTimeInterval responseTime))completion {
    
    if (!message) {
        if (completion) completion(NO, 0);
        return;
    }
    
    // 记录开始时间 (微秒精度)
    uint64_t startTime = mach_absolute_time();
    
    // 并发控制
    dispatch_semaphore_wait(_concurrencySemaphore, DISPATCH_TIME_FOREVER);
    OSAtomicIncrement32(&_currentConcurrent);
    
    dispatch_async(_ultraFastQueue, ^{
        @autoreleasepool {
            BOOL success = [self processHongBaoMessageInternal:message];
            
            // 计算响应时间
            uint64_t endTime = mach_absolute_time();
            static mach_timebase_info_data_t timebaseInfo;
            if (timebaseInfo.denom == 0) {
                mach_timebase_info(&timebaseInfo);
            }
            
            uint64_t elapsedNano = (endTime - startTime) * timebaseInfo.numer / timebaseInfo.denom;
            NSTimeInterval responseTime = elapsedNano / 1e9; // 转换为秒
            
            // 更新统计
            OSAtomicIncrement64(&self->_totalProcessed);
            if (success) {
                OSAtomicIncrement64(&self->_successCount);
            }
            OSAtomicAdd64((int64_t)(responseTime * 1e6), &self->_totalResponseTime); // 微秒
            
            OSAtomicDecrement32(&self->_currentConcurrent);
            dispatch_semaphore_signal(self->_concurrencySemaphore);
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(success, responseTime);
                });
            }
        }
    });
}

- (BOOL)processHongBaoMessageInternal:(CMessageWrap *)message {
    // 极速模式 - 跳过非关键验证
    if (_ultraFastMode) {
        return [self ultraFastProcessing:message];
    } else {
        return [self normalProcessing:message];
    }
}

- (BOOL)ultraFastProcessing:(CMessageWrap *)message {
    // 使用缓存快速检查
    NSString *sendId = [[WXHongBaoMessageListMgr shareInstance] sendIdFromMessage:message];
    if (!sendId) return NO;
    
    // 检查是否有缓存的timingId (极速抢包)
    NSString *cachedTimingId = [[WXTurboCache shared] cachedTimingIdForSendId:sendId];
    
    if (cachedTimingId) {
        // 极速路径 - 直接使用缓存的timingId
        return [self openHongBaoWithCachedTimingId:cachedTimingId sendId:sendId message:message];
    } else {
        // 正常路径 - 查询后抢包
        return [self openHongBaoNormal:message];
    }
}

- (BOOL)normalProcessing:(CMessageWrap *)message {
    // 完整验证流程
    if (![[WXHongBaoOpeartionMgr shareInstance] testHongBaoMessageCanAutoOpen:message log:NO]) {
        return NO;
    }
    
    return [self openHongBaoNormal:message];
}

- (BOOL)openHongBaoWithCachedTimingId:(NSString *)timingId sendId:(NSString *)sendId message:(CMessageWrap *)message {
    // 从对象池获取参数字典
    NSMutableDictionary *params = [self borrowDictionary];
    
    // 快速设置参数
    params[@"timingIdentifier"] = timingId;
    params[@"sendId"] = sendId;
    params[@"agreeDuty"] = @"0";
    params[@"inWay"] = @"0";
    params[@"msgType"] = @"1";
    
    // 使用缓存的URL
    NSString *nativeUrl = [[WXTurboCache shared] hongBaoDetailURLForSendId:sendId];
    params[@"nativeUrl"] = nativeUrl;
    
    // 执行抢包
    [[WXHongBaoOpeartionMgr shareInstance] wxOpenRedEnvelopesRequest:params];
    
    // 归还对象到池
    [self returnDictionary:params];
    
    return YES;
}

- (BOOL)openHongBaoNormal:(CMessageWrap *)message {
    [[WXHongBaoOpeartionMgr shareInstance] openHongBaoByMessageWrap:message log:NO];
    return YES;
}

#pragma mark - 并发查询红包详情

- (void)concurrentQueryHongBaoDetails:(NSArray<CMessageWrap *> *)messages
                           completion:(void(^)(NSDictionary *results))completion {
    
    if (messages.count == 0) {
        if (completion) completion(@{});
        return;
    }
    
    NSMutableDictionary *results = [NSMutableDictionary dictionaryWithCapacity:messages.count];
    dispatch_group_t group = dispatch_group_create();
    
    for (CMessageWrap *message in messages) {
        dispatch_group_enter(group);
        
        dispatch_async(_ultraFastQueue, ^{
            @autoreleasepool {
                NSString *sendId = [[WXHongBaoMessageListMgr shareInstance] sendIdFromMessage:message];
                if (sendId) {
                    // 快速查询详情
                    NSMutableDictionary *params = [self borrowDictionary];
                    params[@"sendId"] = sendId;
                    params[@"msgType"] = @"1";
                    params[@"nativeUrl"] = [[WXTurboCache shared] hongBaoDetailURLForSendId:sendId];
                    
                    [[WXHongBaoOpeartionMgr shareInstance] wxQueryRedEnvelopesDetailRequest:params];
                    
                    @synchronized(results) {
                        results[sendId] = @{@"status": @"queried", @"timestamp": @([[NSDate date] timeIntervalSince1970])};
                    }
                    
                    [self returnDictionary:params];
                }
                dispatch_group_leave(group);
            }
        });
    }
    
    dispatch_group_notify(group, _batchProcessQueue, ^{
        if (completion) {
            completion([results copy]);
        }
    });
}

#pragma mark - 对象池管理

- (NSMutableDictionary *)borrowDictionary {
    [_poolLock lock];
    NSMutableDictionary *dict = nil;
    if (_taskPool.count > 0) {
        dict = _taskPool.lastObject;
        [_taskPool removeLastObject];
        [dict removeAllObjects];
    }
    [_poolLock unlock];
    
    return dict ?: [NSMutableDictionary dictionaryWithCapacity:10];
}

- (void)returnDictionary:(NSMutableDictionary *)dict {
    if (!dict) return;
    
    [_poolLock lock];
    if (_taskPool.count < 50) {
        [_taskPool addObject:dict];
    }
    [_poolLock unlock];
}

#pragma mark - 性能监控

- (NSUInteger)currentConcurrentCount {
    return (NSUInteger)_currentConcurrent;
}

- (double)averageResponseTime {
    int64_t total = _totalProcessed;
    if (total == 0) return 0.0;
    
    return ((double)_totalResponseTime / 1e6) / total; // 转换为秒
}

- (double)successRate {
    int64_t total = _totalProcessed;
    return total > 0 ? (double)_successCount / total : 0.0;
}

- (NSUInteger)totalProcessedCount {
    return (NSUInteger)_totalProcessed;
}

- (void)resetPerformanceStatistics {
    OSAtomicCompareAndSwap64(_totalProcessed, 0, &_totalProcessed);
    OSAtomicCompareAndSwap64(_successCount, 0, &_successCount);
    OSAtomicCompareAndSwap64(_totalResponseTime, 0, &_totalResponseTime);
}

- (NSDictionary *)realtimePerformanceReport {
    return @{
        @"currentConcurrentCount": @(self.currentConcurrentCount),
        @"averageResponseTime": @(self.averageResponseTime * 1000), // 毫秒
        @"successRate": @(self.successRate),
        @"totalProcessedCount": @(self.totalProcessedCount),
        @"maxConcurrentOperations": @(self.maxConcurrentOperations),
        @"ultraFastMode": @(self.ultraFastMode),
        @"batchOptimizationEnabled": @(self.batchOptimizationEnabled),
        @"cacheHitRate": @([[WXTurboCache shared] hitRate]),
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
}

#pragma mark - 资源管理

- (void)warmUp {
    // 预分配更多对象
    [_poolLock lock];
    for (int i = 0; i < 30; i++) {
        if (_taskPool.count < 50) {
            [_taskPool addObject:[NSMutableDictionary dictionaryWithCapacity:10]];
        }
        if (_resultPool.count < 50) {
            [_resultPool addObject:[NSMutableDictionary dictionaryWithCapacity:5]];
        }
    }
    [_poolLock unlock];
    
    // 预热缓存
    [[WXTurboCache shared] preloadHongBaoCache];
    
    // 预热队列
    for (int i = 0; i < 5; i++) {
        dispatch_async(_ultraFastQueue, ^{
            // 空任务，预热线程
        });
    }
}

- (void)releaseUnusedResources {
    [_poolLock lock];
    // 保留一半对象
    NSUInteger keepCount = _taskPool.count / 2;
    while (_taskPool.count > keepCount) {
        [_taskPool removeLastObject];
    }
    
    keepCount = _resultPool.count / 2;
    while (_resultPool.count > keepCount) {
        [_resultPool removeLastObject];
    }
    [_poolLock unlock];
    
    // 清理缓存
    [[WXTurboCache shared] clearExpiredCache];
}

- (void)forceGarbageCollection {
    // 强制释放自动释放池
    @autoreleasepool {
        [self releaseUnusedResources];
    }
}

#pragma mark - 动态配置

- (void)setMaxConcurrentOperations:(NSUInteger)maxConcurrentOperations {
    _maxConcurrentOperations = maxConcurrentOperations;
    
    // 重新创建信号量
    _concurrencySemaphore = dispatch_semaphore_create(maxConcurrentOperations);
}

@end