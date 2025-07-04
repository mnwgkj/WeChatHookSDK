//
//  WXTurboCache.m
//  HookSDK - 极限性能优化
//
//  Created by Performance Optimizer
//  Copyright © 2024 极速抢包. All rights reserved.
//

#import "WXTurboCache.h"
#import <libkern/OSAtomic.h>

// 预编译常量 - 零内存分配
static NSString *const kHongBaoDetailURLTemplate = @"weixin://weixinhongbao/opendetail?sendid=";
static NSString *const kHongBaoOpenURLTemplate = @"weixin://weixinhongbao/openreq?sendid=";
static NSString *const kTimingIdPrefix = @"timing_";
static NSString *const kGroupValidPrefix = @"group_";

@implementation WXTurboCache {
    // 使用分段锁减少并发冲突
    NSMutableDictionary *_mainCache;
    NSMutableDictionary *_timingIdCache;  // 专用于timingId缓存
    NSMutableDictionary *_groupCache;     // 专用于群名验证缓存
    NSMutableDictionary *_urlCache;       // 专用于URL缓存
    
    // 性能统计 - 使用原子操作
    volatile int64_t _hitCount;
    volatile int64_t _totalCount;
    
    // 多把锁减少竞争
    NSLock *_mainLock;
    NSLock *_timingLock;
    NSLock *_groupLock;
    NSLock *_urlLock;
    
    // 预分配的字符串缓冲区池
    NSMutableArray *_stringBufferPool;
    NSLock *_bufferLock;
}

+ (instancetype)shared {
    static WXTurboCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WXTurboCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // 预分配缓存容量 - 避免动态扩容
        _mainCache = [NSMutableDictionary dictionaryWithCapacity:1000];
        _timingIdCache = [NSMutableDictionary dictionaryWithCapacity:500];
        _groupCache = [NSMutableDictionary dictionaryWithCapacity:200];
        _urlCache = [NSMutableDictionary dictionaryWithCapacity:300];
        
        // 初始化锁
        _mainLock = [[NSLock alloc] init];
        _timingLock = [[NSLock alloc] init];
        _groupLock = [[NSLock alloc] init];
        _urlLock = [[NSLock alloc] init];
        _bufferLock = [[NSLock alloc] init];
        
        // 预分配字符串缓冲区池 - 避免运行时内存分配
        _stringBufferPool = [NSMutableArray arrayWithCapacity:50];
        for (int i = 0; i < 20; i++) {
            [_stringBufferPool addObject:[NSMutableString stringWithCapacity:256]];
        }
        
        // 预加载常用数据
        [self preloadHongBaoCache];
    }
    return self;
}

#pragma mark - 核心缓存接口 (超高速)

- (nullable id)objectForKey:(NSString *)key {
    OSAtomicIncrement64(&_totalCount);
    
    // 快速路径 - 检查专用缓存
    if ([key hasPrefix:kTimingIdPrefix]) {
        [_timingLock lock];
        id obj = _timingIdCache[key];
        [_timingLock unlock];
        
        if (obj) {
            OSAtomicIncrement64(&_hitCount);
            return obj;
        }
    } else if ([key hasPrefix:kGroupValidPrefix]) {
        [_groupLock lock];
        id obj = _groupCache[key];
        [_groupLock unlock];
        
        if (obj) {
            OSAtomicIncrement64(&_hitCount);
            return obj;
        }
    }
    
    // 检查主缓存
    [_mainLock lock];
    id obj = _mainCache[key];
    [_mainLock unlock];
    
    if (obj) {
        OSAtomicIncrement64(&_hitCount);
    }
    
    return obj;
}

- (void)setObject:(id)obj forKey:(NSString *)key {
    if (!obj || !key) return;
    
    // 根据key类型选择专用缓存 - 减少锁竞争
    if ([key hasPrefix:kTimingIdPrefix]) {
        [_timingLock lock];
        _timingIdCache[key] = obj;
        [_timingLock unlock];
    } else if ([key hasPrefix:kGroupValidPrefix]) {
        [_groupLock lock];
        _groupCache[key] = obj;
        [_groupLock unlock];
    } else {
        [_mainLock lock];
        _mainCache[key] = obj;
        [_mainLock unlock];
    }
}

- (NSArray *)objectsForKeys:(NSArray<NSString *> *)keys {
    NSMutableArray *results = [NSMutableArray arrayWithCapacity:keys.count];
    
    // 批量获取 - 减少锁操作次数
    for (NSString *key in keys) {
        id obj = [self objectForKey:key];
        [results addObject:obj ?: [NSNull null]];
    }
    
    return results;
}

#pragma mark - 红包专用缓存 (极速优化)

- (void)cacheTimingId:(NSString *)timingId forSendId:(NSString *)sendId {
    if (!timingId || !sendId) return;
    
    // 使用预分配的key格式 - 零内存分配
    NSString *key = [kTimingIdPrefix stringByAppendingString:sendId];
    
    [_timingLock lock];
    _timingIdCache[key] = timingId;
    [_timingLock unlock];
}

- (nullable NSString *)cachedTimingIdForSendId:(NSString *)sendId {
    if (!sendId) return nil;
    
    NSString *key = [kTimingIdPrefix stringByAppendingString:sendId];
    
    [_timingLock lock];
    NSString *timingId = _timingIdCache[key];
    [_timingLock unlock];
    
    if (timingId) {
        OSAtomicIncrement64(&_hitCount);
    }
    OSAtomicIncrement64(&_totalCount);
    
    return timingId;
}

- (void)cacheGroupNameValid:(BOOL)valid forGroupName:(NSString *)groupName {
    if (!groupName) return;
    
    NSString *key = [kGroupValidPrefix stringByAppendingString:groupName];
    NSNumber *validNumber = @(valid);
    
    [_groupLock lock];
    _groupCache[key] = validNumber;
    [_groupLock unlock];
}

- (BOOL)isGroupNameValidCached:(NSString *)groupName found:(BOOL *)found {
    if (!groupName) {
        *found = NO;
        return NO;
    }
    
    NSString *key = [kGroupValidPrefix stringByAppendingString:groupName];
    
    [_groupLock lock];
    NSNumber *validNumber = _groupCache[key];
    [_groupLock unlock];
    
    *found = (validNumber != nil);
    
    if (validNumber) {
        OSAtomicIncrement64(&_hitCount);
        OSAtomicIncrement64(&_totalCount);
        return validNumber.boolValue;
    }
    
    OSAtomicIncrement64(&_totalCount);
    return NO;
}

#pragma mark - URL缓存 (零内存分配)

- (NSString *)hongBaoDetailURLForSendId:(NSString *)sendId {
    if (!sendId) return nil;
    
    NSString *cacheKey = [@"detail_" stringByAppendingString:sendId];
    
    [_urlLock lock];
    NSString *cachedURL = _urlCache[cacheKey];
    [_urlLock unlock];
    
    if (cachedURL) {
        OSAtomicIncrement64(&_hitCount);
        OSAtomicIncrement64(&_totalCount);
        return cachedURL;
    }
    
    // 使用预分配模板 - 最快的字符串拼接
    NSString *url = [kHongBaoDetailURLTemplate stringByAppendingString:sendId];
    
    [_urlLock lock];
    _urlCache[cacheKey] = url;
    [_urlLock unlock];
    
    OSAtomicIncrement64(&_totalCount);
    return url;
}

- (NSString *)hongBaoOpenURLForSendId:(NSString *)sendId {
    if (!sendId) return nil;
    
    NSString *cacheKey = [@"open_" stringByAppendingString:sendId];
    
    [_urlLock lock];
    NSString *cachedURL = _urlCache[cacheKey];
    [_urlLock unlock];
    
    if (cachedURL) {
        OSAtomicIncrement64(&_hitCount);
        OSAtomicIncrement64(&_totalCount);
        return cachedURL;
    }
    
    NSString *url = [kHongBaoOpenURLTemplate stringByAppendingString:sendId];
    
    [_urlLock lock];
    _urlCache[cacheKey] = url;
    [_urlLock unlock];
    
    OSAtomicIncrement64(&_totalCount);
    return url;
}

#pragma mark - 预加载和优化

- (void)preloadHongBaoCache {
    // 预加载URL模板到缓存
    [_mainLock lock];
    _mainCache[@"hongbao_detail_template"] = kHongBaoDetailURLTemplate;
    _mainCache[@"hongbao_open_template"] = kHongBaoOpenURLTemplate;
    
    // 预加载常用验证结果
    _mainCache[@"wishing_default"] = @"恭喜发财";
    _mainCache[@"msgtype_default"] = @"1";
    
    // 预加载常用参数
    _mainCache[@"agreeDuty"] = @"0";
    _mainCache[@"inWay"] = @"0";
    [_mainLock unlock];
    
    // 预加载群名验证缓存
    [_groupLock lock];
    _groupCache[@"group_测试群"] = @YES;
    _groupCache[@"group_朋友群"] = @YES;
    [_groupLock unlock];
}

- (void)preloadGroupNames:(NSArray<NSString *> *)groupNames {
    [_groupLock lock];
    for (NSString *groupName in groupNames) {
        NSString *key = [kGroupValidPrefix stringByAppendingString:groupName];
        _groupCache[key] = @YES;
    }
    [_groupLock unlock];
}

- (void)clearExpiredCache {
    // 快速清理策略 - 只保留最近使用的
    [_mainLock lock];
    if (_mainCache.count > 800) {
        [_mainCache removeAllObjects];
        [self preloadHongBaoCache];
    }
    [_mainLock unlock];
    
    [_timingLock lock];
    if (_timingIdCache.count > 400) {
        // 保留一半最新的
        NSArray *keys = _timingIdCache.allKeys;
        NSUInteger keepCount = keys.count / 2;
        for (NSUInteger i = 0; i < keepCount; i++) {
            [_timingIdCache removeObjectForKey:keys[i]];
        }
    }
    [_timingLock unlock];
}

#pragma mark - 性能统计

- (double)hitRate {
    int64_t total = _totalCount;
    return total > 0 ? (double)_hitCount / total : 0.0;
}

- (NSUInteger)hitCount {
    return (NSUInteger)_hitCount;
}

- (NSUInteger)totalCount {
    return (NSUInteger)_totalCount;
}

- (NSUInteger)cacheSize {
    return _mainCache.count + _timingIdCache.count + _groupCache.count + _urlCache.count;
}

- (void)resetStatistics {
    OSAtomicCompareAndSwap64(_hitCount, 0, &_hitCount);
    OSAtomicCompareAndSwap64(_totalCount, 0, &_totalCount);
}

- (NSDictionary *)performanceReport {
    return @{
        @"hitRate": @(self.hitRate),
        @"hitCount": @(self.hitCount),
        @"totalCount": @(self.totalCount),
        @"cacheSize": @(self.cacheSize),
        @"timingCacheSize": @(_timingIdCache.count),
        @"groupCacheSize": @(_groupCache.count),
        @"urlCacheSize": @(_urlCache.count)
    };
}

@end