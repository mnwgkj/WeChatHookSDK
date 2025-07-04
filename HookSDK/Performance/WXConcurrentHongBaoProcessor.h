//
//  WXConcurrentHongBaoProcessor.h
//  HookSDK - 多红包极速并发处理
//
//  Created by Performance Optimizer
//  Copyright © 2024 极速抢包. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CMessageWrap;

NS_ASSUME_NONNULL_BEGIN

/**
 * 多红包并发处理器
 * 专门优化多个红包同时到达时的处理速度
 * 确保并发处理时每个红包都保持最快响应
 */
@interface WXConcurrentHongBaoProcessor : NSObject

+ (instancetype)shared;

#pragma mark - 极速并发处理

/**
 * 批量处理红包消息 (最高优先级)
 * @param messages 红包消息数组
 * @param completion 完成回调，返回处理结果
 */
- (void)processBatchHongBaoMessages:(NSArray<CMessageWrap *> *)messages
                         completion:(void(^)(NSArray *results))completion;

/**
 * 单个红包极速处理
 * @param message 红包消息
 * @param completion 完成回调
 */
- (void)processHongBaoMessageUltraFast:(CMessageWrap *)message
                            completion:(void(^)(BOOL success, NSTimeInterval responseTime))completion;

/**
 * 并发查询红包详情
 * @param messages 消息数组
 * @param completion 完成回调
 */
- (void)concurrentQueryHongBaoDetails:(NSArray<CMessageWrap *> *)messages
                           completion:(void(^)(NSDictionary *results))completion;

#pragma mark - 性能优化配置

/**
 * 设置最大并发数 (默认: 10)
 */
@property (nonatomic, assign) NSUInteger maxConcurrentOperations;

/**
 * 设置超时时间 (默认: 5秒)
 */
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

/**
 * 启用极速模式 (跳过非关键验证)
 */
@property (nonatomic, assign) BOOL ultraFastMode;

/**
 * 启用批量优化 (多个红包合并处理)
 */
@property (nonatomic, assign) BOOL batchOptimizationEnabled;

#pragma mark - 实时性能监控

/**
 * 当前并发处理数量
 */
@property (nonatomic, readonly) NSUInteger currentConcurrentCount;

/**
 * 平均响应时间 (毫秒)
 */
@property (nonatomic, readonly) double averageResponseTime;

/**
 * 成功率
 */
@property (nonatomic, readonly) double successRate;

/**
 * 总处理数量
 */
@property (nonatomic, readonly) NSUInteger totalProcessedCount;

/**
 * 重置性能统计
 */
- (void)resetPerformanceStatistics;

/**
 * 获取实时性能报告
 */
- (NSDictionary *)realtimePerformanceReport;

#pragma mark - 内存和资源管理

/**
 * 预热处理器 (预分配资源)
 */
- (void)warmUp;

/**
 * 释放不必要的资源
 */
- (void)releaseUnusedResources;

/**
 * 强制垃圾回收
 */
- (void)forceGarbageCollection;

@end

NS_ASSUME_NONNULL_END