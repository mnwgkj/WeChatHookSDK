//
//  ViewController.m
//  WXHookDemo
//
//  Created by dps on 17/3/13.
//  Copyright © 2017年 dps. All rights reserved.
//

#import "WXHongBaoSettingViewController.h"
#import "WXHongBaoSettingMgr.h"
#import "WXHongBaoHitConfigViewController.h"
#import "HKAlertView.h"
#import "WXHongBaoSmallConfigViewController.h"
#import "UIApplication+TopViewController.h"
#import "WXHongBaoSmartOpenConfigViewController.h"

// 现代化UI设计常量
#define WXHongBaoSettingCellSwitchWidth 50
#define WXHongBaoSettingCellTextViewHeight 80
#define WXHongBaoSettingCellItemSpace 16
#define WXHongBaoSettingCellSpace 20
#define WXHongBaoSettingCellCornerRadius 12
#define WXHongBaoSettingCellHeight 64

// 现代化配色方案
#define WXHongBaoMainColor [UIColor colorWithRed:236/255.0 green:64/255.0 blue:64/255.0 alpha:1.0]
#define WXHongBaoSecondaryColor [UIColor colorWithRed:255/255.0 green:87/255.0 blue:87/255.0 alpha:1.0]
#define WXHongBaoBackgroundColor [UIColor colorWithRed:248/255.0 green:249/255.0 blue:250/255.0 alpha:1.0]
#define WXHongBaoCardColor [UIColor whiteColor]
#define WXHongBaoTextColor [UIColor colorWithRed:28/255.0 green:28/255.0 blue:30/255.0 alpha:1.0]
#define WXHongBaoSubtextColor [UIColor colorWithRed:142/255.0 green:142/255.0 blue:147/255.0 alpha:1.0]

@implementation WXHongBaoSettingCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    
    if ( self )
    {
        self.enableHighlight = NO;
        self.titleContentLabel = [[UILabel alloc] init];
        self.switchControl = [[UISwitch alloc] init];
        
        self.textLabel.font = [UIFont systemFontOfSize:11.0];
        self.titleContentLabel.textColor = [UIColor blackColor];
        
        self.backgroundColor = [UIColor clearColor];
        
        [self.contentView addSubview:self.titleContentLabel];
        [self.contentView addSubview:self.switchControl];
        
        [self.switchControl addTarget:self action:@selector(onSwitchControlChange:) forControlEvents:UIControlEventValueChanged];
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // 极速优化：缓存计算结果，避免重复计算
    static CGFloat switchWidth = WXHongBaoSettingCellSwitchWidth;
    static CGFloat cellSpace = WXHongBaoSettingCellSpace;
    static CGFloat titleHeight = WXHongBaoSettingCellTitleHeight;
    
    CGFloat contentWidth = self.contentView.frame.size.width;
    
    // 优化布局计算，减少frame操作
    self.titleContentLabel.frame = CGRectMake(cellSpace, 0, contentWidth - switchWidth - 2*cellSpace, titleHeight);
    self.switchControl.frame = CGRectMake(contentWidth - switchWidth - cellSpace, 8, switchWidth, titleHeight - 16);
}

- (void)setHighlighted:(BOOL)highlighted
{
    if ( self.enableHighlight )
    {
        [super setHighlighted:highlighted];
    }
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    if ( self.enableHighlight )
    {
        [super setHighlighted:highlighted animated:animated];
    }
}

- (void)setSelected:(BOOL)selected
{
    
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    
}

- (void)onSwitchControlChange:(id)sender
{
    [self.delegate wxHongBaoSettingCell:self switchChanged:self.switchControl.isOn];
}

- (void)onOpenDetailButtonClick:(id)sender
{
    
}

@end



@interface WXHongBaoSettingViewController () <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate, WXHongBaoSettingCellDelegate>

@end

@implementation WXHongBaoSettingViewController

- (instancetype)init
{
    self = [super init];
    if ( self )
    {
        
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"红包助手";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 极速优化：TableView性能优化
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [[UIView alloc] init];
    self.tableView.estimatedRowHeight = WXHongBaoSettingCellTitleHeight; // 预估高度避免重复计算
    self.tableView.rowHeight = WXHongBaoSettingCellTitleHeight; // 固定高度提升性能
    self.tableView.separatorInset = UIEdgeInsetsZero; // 优化分隔线
    
    // 预缓存cell，避免运行时创建
    [self.tableView registerClass:[WXHongBaoSettingCell class] forCellReuseIdentifier:@"WXHongBaoSettingCell"];
    
    UIBarButtonItem * button = [[UIBarButtonItem alloc]initWithTitle:@"清除" style:UIBarButtonItemStyleDone target:self action:@selector(onClearDataButtonClick)];
    button.tintColor = [UIColor whiteColor];
    self.navigationItem.rightBarButtonItem = button;
    
    UIBarButtonItem * leftButton = [[UIBarButtonItem alloc]initWithTitle:@"关闭" style:UIBarButtonItemStyleDone target:self action:@selector(onCloseDataButtonClick:)];
    leftButton.tintColor = [UIColor whiteColor]; // 修复bug：应该是leftButton
    self.navigationItem.leftBarButtonItem = leftButton;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onWXHongBaoSettingMgrSettingUpdate) name:KWXHongBaoSettingUpdate object:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [WXHongBaoSettingMgr shareInstance].settingInfoList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    WXHongBaoSettingCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"WXHongBaoSettingCell"];
    NSArray *settingInfoList = [WXHongBaoSettingMgr shareInstance].settingInfoList;
    WXHongBaoSettingInfoItem *info = [settingInfoList objectAtIndex:indexPath.row];
    
    cell.userInfo = info;
    cell.titleContentLabel.text = info.title;
    cell.switchControl.hidden = !info.switchShow;
    cell.switchControl.on = info.switchOn;
    cell.delegate = self;
    
    if ( info.text != nil )
    {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.enableHighlight = YES;
    }
    else
    {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.enableHighlight = NO;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 极速优化：由于已设置固定高度，这个方法可能不会被调用，但保留以防万一
    return WXHongBaoSettingCellTitleHeight;
}

- (void)onWXHongBaoSettingMgrSettingUpdate
{
    // 极速优化：避免全表刷新，使用批量更新
    if (@available(iOS 11.0, *)) {
        [self.tableView performBatchUpdates:^{
            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
        } completion:nil];
    } else {
        // iOS 11以下版本的优化刷新
        [UIView performWithoutAnimation:^{
            [self.tableView reloadData];
        }];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *settingInfoList = [WXHongBaoSettingMgr shareInstance].settingInfoList;
    WXHongBaoSettingInfoItem *info = [settingInfoList objectAtIndex:indexPath.row];
    if ( info.text == nil )
    {
        return;
    }
    
    if ( [info.name isEqualToString:KWXHongBaoSettingKeyAutoOpenDelay]
        || [info.name isEqualToString:KWXHongBaoSettingKeyQueryDelay]
        || [info.name isEqualToString:KWXHongBaoSettingKeyMasterIP]
        || [info.name isEqualToString:KWXHongBaoSettingKeyAuth]
        || [info.name isEqualToString:KWXHongBaoSettingKeyGroupName] )
    {
        HKAlertView *alert = [[HKAlertView alloc] initWithTitle:@"设置" message:info.title delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        [alert setAlertViewStyle:UIAlertViewStylePlainTextInput];
        UITextField *txtName = [alert textFieldAtIndex:0];
        txtName.text = info.text;
        alert.userInfo = info;
        [alert show];
    }
    else
    {
        if ( [info.name isEqualToString:KWXHongBaoSettingKeyHit] )
        {
            WXHongBaoHitConfigViewController *vc = [[WXHongBaoHitConfigViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        
        if ( [info.name isEqualToString:KWXHongBaoSettingKeySmall] )
        {
            WXHongBaoSmallConfigViewController *vc = [[WXHongBaoSmallConfigViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
        
        if ( [info.name isEqualToString:KWXHongBaoSettingKeySmartOpen] )
        {
            WXHongBaoSmartOpenConfigViewController *vc = [[WXHongBaoSmartOpenConfigViewController alloc] init];
            [self.navigationController pushViewController:vc animated:YES];
        }
    }
}

- (void)onClearDataButtonClick
{
    [[WXHongBaoSettingMgr shareInstance] clearLocalData];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ( buttonIndex == 1 && [alertView isKindOfClass:[HKAlertView class]] )
    {
        HKAlertView *hkAlertView = (HKAlertView *)alertView;
        UITextField *textField = [alertView textFieldAtIndex:0];
        NSString *text = textField.text;
        WXHongBaoSettingInfoItem *info = hkAlertView.userInfo;
        
        info.text = text;
        
        [[WXHongBaoSettingMgr shareInstance] updateSettingInfo:info];
    }
}

- (void)wxHongBaoSettingCell:(WXHongBaoSettingCell *)cell switchChanged:(BOOL)on
{
    WXHongBaoSettingInfoItem *item = cell.userInfo;
    item.switchOn = on;
    
    [[WXHongBaoSettingMgr shareInstance] updateSettingInfo:item];
}

- (void)onCloseDataButtonClick:(id)sender
{
    [self dismiss];
}

+ (void)show
{
    WXHongBaoSettingViewController *settingViewController = [[WXHongBaoSettingViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingViewController];
    nav.view.backgroundColor = [UIColor whiteColor];
    [[[UIApplication sharedApplication] currentTopViewController] presentViewController:nav animated:YES completion:nil];
}

- (void)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
