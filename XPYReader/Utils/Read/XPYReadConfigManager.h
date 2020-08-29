//
//  XPYReadConfigManager.h
//  XPYReader
//
//  Created by zhangdu_imac on 2020/8/7.
//  Copyright © 2020 xiang. All rights reserved.
//  阅读配置

#import "XPYBaseModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface XPYReadConfigManager : XPYBaseModel

/// 浅色模式颜色编号
@property (nonatomic, assign, readonly) NSInteger lightColorIndex;
/// 深色模式颜色编号
@property (nonatomic, assign, readonly) NSInteger darkColorIndex;
/// 行间距
@property (nonatomic, strong) NSNumber *lineSpacing;
/// 段落间距
@property (nonatomic, strong) NSNumber *paragraphSpacing;
/// 字号
@property (nonatomic, assign) NSInteger fontSize;
/// 翻页模式
@property (nonatomic, assign, readonly) XPYReadPageType pageType;
/// 是否自动阅读模式（自动阅读每次初始化时默认关闭）
@property (nonatomic, assign) BOOL isAutoRead;
/// 自动阅读模式（滚屏和覆盖）
@property (nonatomic, assign, readonly) XPYAutoReadMode autoReadMode;
/// 自动阅读翻页速度
@property (nonatomic, assign) NSInteger autoReadSpeed;

+ (instancetype)sharedInstance;

/// 是否深色模式
- (BOOL)isDarkMode;

/// 获取当前颜色编号
- (NSInteger)currentColorIndex;

/// 获取当前阅读背景颜色
- (UIColor *)currentBackgroundColor;

/// 获取当前阅读文字颜色
- (UIColor *)currentTextColor;

/// 更新当前颜色编号
/// @param colorIndex 编号
- (void)updateColorIndex:(NSInteger)colorIndex;

/// 更新当前翻页模式
/// @param pageType 翻页模式
- (void)updatePageType:(XPYReadPageType)pageType;

/// 更新当前自动阅读模式
/// @param mode 自动阅读模式
- (void)updateAutoReadMode:(XPYAutoReadMode)mode;

@end

NS_ASSUME_NONNULL_END