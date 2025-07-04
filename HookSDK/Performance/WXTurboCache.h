//
//  WXTurboCache.h
//  HookSDK - 极限性能优化
//
//  Created by Performance Optimizer
//  Copyright © 2024 极速抢包. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 超高速缓存系统
 * 专为极速抢包优化，提供毫秒级缓存响应
 */
@interface WXTurboCache : NSObject

+ (instancetype)shared;

#pragma mark - 核心缓存接口

/**
 * 获取缓存对象 (超高速)
 * @param key 缓存键
 * @return 缓存对象，如果不存在返回nil
 */
- (nullable id)objectForKey:(NSString *)key;

/**
 * 设置缓存对象
 * @param obj 要缓存的对象
 * @param key 缓存键
 */
- (void)setObject:(id)obj forKey:(NSString *)key;

/**
 * 批量获取缓存对象
 * @param keys 缓存键数组
 * @return 缓存对象数组，对应keys的顺序
 */
- (NSArray *)objectsForKeys:(NSArray<NSString *> *)keys;

#pragma mark - 红包专用缓存

/**
 * 缓存timingId (极速抢包关键)
 */
- (void)cacheTimingId:(NSString *)timingId forSendId:(NSString *)sendId;
- (nullable NSString *)cachedTimingIdForSendId:(NSString *)sendId;

/**
 * 缓存群名验证结果
 */
- (void)cacheGroupNameValid:(BOOL)valid forGroupName:(NSString *)groupName;
- (BOOL)isGroupNameValidCached:(NSString *)groupName found:(BOOL *)found;

/**
 * 缓存URL模板
 */
- (NSString *)hongBaoDetailURLForSendId:(NSString *)sendId;
- (NSString *)hongBaoOpenURLForSendId:(NSString *)sendId;

#pragma mark - 预加载和预热

/**
 * 预加载红包相关缓存数据
 */
- (void)preloadHongBaoCache;

/**
 * 预加载常用群名
 */
- (void)preloadGroupNames:(NSArray<NSString *> *)groupNames;

/**
 * 清理过期缓存
 */
- (void)clearExpiredCache;

#pragma mark - 性能统计

/**
 * 缓存命中率 (0.0 - 1.0)
 */
@property (nonatomic, readonly) double hitRate;

/**
 * 缓存命中次数
 */
@property (nonatomic, readonly) NSUInteger hitCount;

/**
 * 总查询次数
 */
@property (nonatomic, readonly) NSUInteger totalCount;

/**
 * 当前缓存大小
 */
@property (nonatomic, readonly) NSUInteger cacheSize;

/**
 * 重置统计信息
 */
- (void)resetStatistics;

/**
 * 获取性能报告
 */
- (NSDictionary *)performanceReport;

@end

NS_ASSUME_NONNULL_END