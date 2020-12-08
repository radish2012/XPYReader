//
//  XPYHorizontalScrollReadViewController.m
//  XPYReader
//
//  Created by zhangdu_imac on 2020/9/7.
//  Copyright © 2020 xiang. All rights reserved.
//

#import "XPYHorizontalScrollReadViewController.h"
#import "XPYHorizontalScrollCollectionViewCell.h"

#import "XPYBookModel.h"
#import "XPYChapterModel.h"
#import "XPYChapterPageModel.h"

#import "XPYReadParser.h"
#import "XPYChapterHelper.h"
#import "XPYReadRecordManager.h"

static NSString * const kXPYHorizontalScrollCollectionViewCellIdentifierKey = @"XPYHorizontalScrollCollectionViewCellIdentifier";

@interface XPYHorizontalScrollReadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) UICollectionView *collectionView;

/// 点击翻页手势
@property (nonatomic, strong) UITapGestureRecognizer *scrollTap;

@property (nonatomic, strong) XPYBookModel *bookModel;

/// 当前正在预加载章节ID数组
@property (nonatomic, strong) NSMutableArray <NSString *> *preloadingChapterIds;
/// 当前阅读章节ID数组
@property (nonatomic, strong) NSMutableArray <NSString *> *chapterIds;
/// 当前阅读章节数组(只保存本次阅读列表)
@property (nonatomic, strong) NSMutableArray <XPYChapterModel *> *chapters;
/// 保存需要更新的indexPath（willDisplayCell时保存）
@property (nonatomic, strong) NSIndexPath *needUpdateIndexPath;
/// 保存滑动开始位置，用于判断是否翻页
@property (nonatomic, assign) CGFloat offsetX;
/// 列表滚动方式是否向左（向后翻页）
@property (nonatomic, assign) BOOL isScrollOrientationLeft;

@end

@implementation XPYHorizontalScrollReadViewController

#pragma mark - Initializer
- (instancetype)initWithBook:(XPYBookModel *)book {
    self = [super init];
    if (self) {
        self.bookModel = book;
        // 初始化数组
        self.preloadingChapterIds = [[NSMutableArray alloc] init];
        self.chapterIds = [@[book.chapter.chapterId] mutableCopy];
        self.chapters = [@[book.chapter] mutableCopy];
    }
    return self;
}

#pragma mark - Life cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    XPYChapterModel *currentChapter = self.chapters.firstObject;
    // 分页(避免横竖屏错位问题)
    NSArray *pageModels = [XPYReadParser parseChapterWithChapterContent:currentChapter.content chapterName:currentChapter.chapterName];
    currentChapter.pageModels = [pageModels copy];
    if (self.bookModel.page >= pageModels.count) {
        // 横竖屏切换可能导致当前页超过总页数
        self.bookModel.page = pageModels.count - 1;
    }
    
    [self configureUI];
    
    // 点击事件（点击翻页）
    self.scrollTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self.view addGestureRecognizer:self.scrollTap];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 预加载
    [self preloadChapters];
}

#pragma mark - UI
- (void)configureUI {
    // 防止页面跳动
    if (@available(iOS 11.0, *)) {
        self.collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    [self.view addSubview:self.collectionView];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    // 设置页面到阅读记录位置
    [self.collectionView setContentOffset:CGPointMake(CGRectGetWidth(self.view.bounds) * self.bookModel.page, 0)];
}

#pragma mark - Private methods
- (void)preloadChapters {
    XPYChapterModel *currentChapter = self.bookModel.chapter;
    if (currentChapter.chapterIndex == 1) {
        // 当前为第一章
        XPYChapterModel *tempChapter = [XPYChapterHelper nextChapterOfCurrentChapter:currentChapter];
        if (!tempChapter || [self.chapterIds containsObject:tempChapter.chapterId] || [self.preloadingChapterIds containsObject:tempChapter.chapterId]) {
            // 章节获取失败或者当前阅读数组已存在或者正在加载
            return;
        }
        // 保存正在加载章节ID
        [self.preloadingChapterIds addObject:tempChapter.chapterId];
        // 加载下一章
        [self preloadNextChapterOfCurrentChapter:currentChapter];
    } else if (currentChapter.chapterIndex == self.bookModel.chapterCount) {
        // 当前为最后一章
        XPYChapterModel *tempChapter = [XPYChapterHelper lastChapterOfCurrentChapter:currentChapter];
        if (!tempChapter || [self.chapterIds containsObject:tempChapter.chapterId] || [self.preloadingChapterIds containsObject:tempChapter.chapterId]) {
            // 章节获取失败或者当前阅读数组已存在或者正在加载
            return;
        }
        // 保存正在加载章节ID
        [self.preloadingChapterIds addObject:tempChapter.chapterId];
        // 加载上一章
        [self preloadLastChapterOfCurrentChapter:currentChapter];
    } else {
        // 当前为中间章节
        XPYChapterModel *tempNextChapter = [XPYChapterHelper nextChapterOfCurrentChapter:currentChapter];
        XPYChapterModel *tempLastChapter = [XPYChapterHelper lastChapterOfCurrentChapter:currentChapter];
        if (tempNextChapter && ![self.chapterIds containsObject:tempNextChapter.chapterId] && ![self.preloadingChapterIds containsObject:tempNextChapter.chapterId]) {
            // 保存正在加载章节ID
            [self.preloadingChapterIds addObject:tempNextChapter.chapterId];
            // 加载下一章
            [self preloadNextChapterOfCurrentChapter:currentChapter];
        }
        if (tempLastChapter && ![self.chapterIds containsObject:tempLastChapter.chapterId] && ![self.chapterIds containsObject:tempLastChapter.chapterId]) {
            // 保存正在加载章节ID
            [self.preloadingChapterIds addObject:tempLastChapter.chapterId];
            // 加载上一章
            [self preloadLastChapterOfCurrentChapter:currentChapter];
        }
    }
}
/// 加载当前章节下一章
/// @param currentChapter 当前章节
- (void)preloadNextChapterOfCurrentChapter:(XPYChapterModel *)currentChapter {
    [XPYChapterHelper preloadNextChapterWithCurrentChapter:currentChapter complete:^(XPYChapterModel * _Nullable    nextChapter) {
        if (nextChapter && !XPYIsEmptyObject(nextChapter.content)) {
            // 保存分页信息
            nextChapter.pageModels = [[XPYReadParser parseChapterWithChapterContent:nextChapter.content chapterName:nextChapter.chapterName] copy];
            // 避免自带动画效果
            [UIView setAnimationsEnabled:NO];
            [self.collectionView performBatchUpdates:^{
                // 插入预加载的下一个章节到当前阅读中
                [self.chapterIds addObject:nextChapter.chapterId];
                [self.chapters addObject:nextChapter];
                [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:self.chapters.count - 1]];
            } completion:^(BOOL finished) {
                // 当前预加载ID数组移除
                [self.preloadingChapterIds removeObject:nextChapter.chapterId];
            }];
            [UIView setAnimationsEnabled:YES];
        } else {
            NSLog(@"预加载失败");
            // 当前预加载ID数组移除
            [self.preloadingChapterIds removeObject:nextChapter.chapterId];
        }
    }];
}

/// 加载当前章节上一章
/// @param currentChapter 当前章节
- (void)preloadLastChapterOfCurrentChapter:(XPYChapterModel *)currentChapter {
    [XPYChapterHelper preloadLastChapterWithCurrentChapter:currentChapter complete:^(XPYChapterModel * _Nullable lastChapter) {
        if (lastChapter && !XPYIsEmptyObject(lastChapter.content)) {
            // 保存分页信息
            lastChapter.pageModels = [[XPYReadParser parseChapterWithChapterContent:lastChapter.content chapterName:lastChapter.chapterName] copy];
            // 避免自带动画效果
            [UIView setAnimationsEnabled:NO];
            [self.collectionView performBatchUpdates:^{
                // 插入预加载的上一个章节到当前阅读章节中
                [self.chapterIds insertObject:lastChapter.chapterId atIndex:0];
                [self.chapters insertObject:lastChapter atIndex:0];
                
                [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:0]];
                // 更新列表位置
                [self.collectionView setContentOffset:CGPointMake(self.collectionView.contentOffset.x + CGRectGetWidth(self.view.bounds) * lastChapter.pageModels.count, 0)];

            } completion:^(BOOL finished) {
                // 当前预加载ID数组移除
                [self.preloadingChapterIds removeObject:lastChapter.chapterId];
            }];
            [UIView setAnimationsEnabled:YES];
        } else {
            NSLog(@"预加载失败");
            // 当前预加载ID数组移除
            [self.preloadingChapterIds removeObject:lastChapter.chapterId];
        }
    }];
}

- (void)updateReadRecord {
    NSArray *indexPaths = [[self.collectionView indexPathsForVisibleItems] copy];
    if (!indexPaths || indexPaths.count == 0) {
        return;
    }
    // indexPath排序
    NSArray *sortedIndexPaths = [[indexPaths sortedArrayUsingSelector:@selector(compare:)] copy];
    // 获取目标IndexPath（滚动方向不同结果不同）
    NSIndexPath *indexPath = _isScrollOrientationLeft ? sortedIndexPaths.lastObject : sortedIndexPaths.firstObject;
    XPYChapterModel *chapter = self.chapters[indexPath.section];
    [self updateReadRecordWithPage:indexPath.item chapter:chapter];
}

- (void)updateReadRecordWithPage:(NSInteger)page chapter:(XPYChapterModel *)chapter {
    if (page == self.bookModel.page && chapter.chapterIndex == self.bookModel.chapter.chapterIndex) {
        // 章节页码都未改变
        return;
    }
    NSLog(@"更新：%@章%@页", @(chapter.chapterIndex), @(page));
    
    self.bookModel.chapter = [chapter copy];
    if (page < self.bookModel.chapter.pageModels.count) {
        self.bookModel.page = page;
    }
    [XPYReadRecordManager updateReadRecordWithModel:self.bookModel];
    
    XPYChapterPageModel *pageModel = self.bookModel.chapter.pageModels[self.bookModel.page];
    if (pageModel.pageIndex == 0 || pageModel.pageIndex == (self.bookModel.chapter.pageModels.count - 1)) {
        // 当前章节第一页或者最后一页时预加载
        [self preloadChapters];
    }
}

/// 滚动
/// @param isNext 是否下一页
- (void)scrollWithDirection:(BOOL)isNext {
    // 当前章节在当前数组中的索引
    NSInteger currentChapterIndex = [self.chapterIds indexOfObject:self.bookModel.chapter.chapterId];
    if (isNext && self.bookModel.page == self.bookModel.chapter.pageModels.count - 1 && currentChapterIndex == self.chapters.count - 1) {
        // 最后一页的下一页
        [MBProgressHUD xpy_showTips:@"当前为本书最后一页"];
        return;
    }
    if (!isNext && self.bookModel.page == 0 && currentChapterIndex == 0) {
        // 第一页的上一页
        [MBProgressHUD xpy_showTips:@"当前为本书第一页"];
        return;
    }
    
    NSInteger needUpdatePage = self.bookModel.page;
    XPYChapterModel *needUpdateChapter = [self.bookModel.chapter copy];
    if (isNext) {
        if (self.bookModel.page < self.bookModel.chapter.pageModels.count - 1) {
            // 章节下一页，page加1，chapter不变
            needUpdatePage = self.bookModel.page + 1;
        } else {
            // 章节最后一页，page为0，chapter设为下一章
            needUpdatePage = 0;
            needUpdateChapter = self.chapters[currentChapterIndex + 1];
        }
    } else {
        if (self.bookModel.page > 0) {
            // 章节上一页，page减1，chapter不变
            needUpdatePage = self.bookModel.page - 1;
        } else {
            // 章节第一页，page设为上一章最后一页，chapter设为上一章
            XPYChapterModel *tempChapter = self.chapters[currentChapterIndex - 1];
            needUpdatePage = tempChapter.pageModels.count - 1;
            needUpdateChapter = tempChapter;
        }
    }
    [self updateReadRecordWithPage:needUpdatePage chapter:needUpdateChapter];
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat contentOffsetX = isNext ? self.collectionView.contentOffset.x + CGRectGetWidth(self.view.bounds) : self.collectionView.contentOffset.x - CGRectGetWidth(self.view.bounds);
        [self.collectionView setContentOffset:CGPointMake(contentOffsetX, 0) animated:NO];
    });
}

#pragma mark - Event response
- (void)tap:(UITapGestureRecognizer *)tap {
    // 点击时走代理方法，隐藏菜单工具栏
    if (self.delegate && [self.delegate respondsToSelector:@selector(horizontalScrollReadViewControllerWillBeginScroll)]) {
        [self.delegate horizontalScrollReadViewControllerWillBeginScroll];
    }
    
    CGPoint point = [tap locationInView:self.view];
    CGFloat edgeWidth = CGRectGetWidth(self.view.bounds) / 4.0;
    if (point.x > edgeWidth && point.x < edgeWidth * 3) {
        // 点击屏幕中间区域直接返回
        return;
    }
    
    if (point.x <= edgeWidth) {
        // 上一页
        [self scrollWithDirection:NO];
    } else {
        // 下一页
        [self scrollWithDirection:YES];
    }
}

#pragma mark - Collection view data source
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    // 每一章节设置成一个section
    return self.chapters.count;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    // 章节的每一页设置成一个item
    XPYChapterModel *chapter = self.chapters[section];
    if (chapter.pageModels) {
        return chapter.pageModels.count;
    }
    return 0;
}
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    XPYHorizontalScrollCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kXPYHorizontalScrollCollectionViewCellIdentifierKey forIndexPath:indexPath];
    XPYChapterModel *chapter = self.chapters[indexPath.section];
    XPYChapterPageModel *pageModel = chapter.pageModels[indexPath.item];
    [cell setupChapter:chapter pageModel:pageModel];
    return cell;
}

#pragma mark - Collection view delegate flow layout
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(XPYScreenWidth, XPYScreenHeight);
}
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsZero;
}

#pragma mark - Colletion view delegate
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    // 保存将要更新的IndexPath
    self.needUpdateIndexPath = indexPath;
}

#pragma mark - Scroll view delegate
/// 开始拖动
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self updateReadRecord];
    // 滑动前走代理方法，隐藏菜单工具栏
    if (self.delegate && [self.delegate respondsToSelector:@selector(horizontalScrollReadViewControllerWillBeginScroll)]) {
        [self.delegate horizontalScrollReadViewControllerWillBeginScroll];
    }
    _offsetX = scrollView.contentOffset.x;
}
/// 拖动结束
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    NSInteger currentChapterIndex = [self.chapterIds indexOfObject:self.bookModel.chapter.chapterId];
    if (currentChapterIndex != 0 && currentChapterIndex != self.chapters.count - 1) {
        // 当前章节数组的中间章节直接返回
        return;
    }
    if (_isScrollOrientationLeft && self.bookModel.page == self.bookModel.chapter.pageModels.count - 1 && self.bookModel.chapter.chapterIndex == self.bookModel.chapterCount) {
        // 本书最后一页
        [MBProgressHUD xpy_showTips:@"当前为本书最后一页"];
        return;
    } else if (!_isScrollOrientationLeft && self.bookModel.page == 0 && self.bookModel.chapter.chapterIndex == 1) {
        // 本书第一页
        [MBProgressHUD xpy_showTips:@"当前为本书第一页"];
        return;
    }
}
/// 动画减速结束
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateReadRecord];
}
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // 获取滚动方向
    CGFloat contentOffsetX = scrollView.contentOffset.x;
    if (_offsetX - contentOffsetX < 0) {
        _isScrollOrientationLeft = YES;
        NSLog(@"left");
    } else if (_offsetX - contentOffsetX > 0) {
        _isScrollOrientationLeft = NO;
        NSLog(@"right");
    }
    _offsetX = contentOffsetX;
}

#pragma mark - Getters
- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
        flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, XPYScreenWidth, XPYScreenHeight) collectionViewLayout:flowLayout];
        _collectionView.backgroundColor = [XPYReadConfigManager sharedInstance].currentBackgroundColor;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.showsVerticalScrollIndicator = NO;
        _collectionView.pagingEnabled = YES;
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        [_collectionView registerClass:[XPYHorizontalScrollCollectionViewCell class] forCellWithReuseIdentifier:kXPYHorizontalScrollCollectionViewCellIdentifierKey];
    }
    return _collectionView;
}

@end
