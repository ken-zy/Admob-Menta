//
//  GADMentaRewardedVideoCustomEvent.m
//  GoogleMobileAdsMediationMenta
//
//  Created by jdy on 2024/7/1.
//

#import "GADMentaRewardedVideoCustomEvent.h"
#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

@interface GADMentaRewardedVideoCustomEvent () <MentaMediationRewardVideoDelegate>

@property (nonatomic, strong) MentaMediationRewardVideo *rewardedVideo;

@property (nonatomic, copy) GADMediationRewardedLoadCompletionHandler loadCompletionHandler;
@property (nonatomic, weak) id<GADMediationRewardedAdEventDelegate> adEventDelegate;

@end

@implementation GADMentaRewardedVideoCustomEvent

+ (void)setUpWithConfiguration:(nonnull GADMediationServerConfiguration *)configuration
             completionHandler:(nonnull GADMediationAdapterSetUpCompletionBlock)completionHandler {
    // This is where you initialize the SDK that this custom event is built
    // for. Upon finishing the SDK initialization, call the completion handler
    // with success.
    // {"appID":"A0004","appKey":"510cc7cdaabbe7cb975e6f2538bc1e9d","placementID" : "P0026"}
    GADMediationCredentials *credential = configuration.credentials.firstObject;
//    NSLog(@"%@", credential.settings);
//    NSLog(@"%ld", credential.format);
    
    NSString *jsonStr = credential.settings[@"parameter"];
    NSDictionary *jsonDic = [self parseJsonParameters:jsonStr];
    
    MentaAdSDK *menta = [MentaAdSDK shared];
    if (menta.isInitialized) {
        return;
    }
    [menta setLogLevel:kMentaLogLevelDebug];
    
    [menta startWithAppID:jsonDic[@"appID"] appKey:jsonDic[@"appKey"] finishBlock:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            [[MentaLoggerGlobal stdLogger] info:@"menta sdk init success"];
        } else {
            [[MentaLoggerGlobal stdLogger] info:[NSString stringWithFormat:@"menta sdk init failure, %@", error.localizedDescription]];
        }
    }];
    completionHandler(nil);
}

+ (GADVersionNumber)adSDKVersion {
    NSArray *versionComponents = [[MentaAdSDK shared].sdkVersion componentsSeparatedByString:@"."];
    GADVersionNumber version = {0};
    if (versionComponents.count >= 3) {
        version.majorVersion = [versionComponents[0] integerValue];
        version.minorVersion = [versionComponents[1] integerValue];
        version.patchVersion = [versionComponents[2] integerValue];
    }
    return version;
}

+ (GADVersionNumber)adapterVersion {
    NSString *customEventVersion = [NSString stringWithFormat:@"%@.0", [MentaAdSDK shared].sdkVersion];
    NSArray *versionComponents = [customEventVersion componentsSeparatedByString:@"."];
    GADVersionNumber version = {0};
    if (versionComponents.count == 4) {
        version.majorVersion = [versionComponents[0] integerValue];
        version.minorVersion = [versionComponents[1] integerValue];
        version.patchVersion = [versionComponents[2] integerValue] * 100 + [versionComponents[3] integerValue];
    }
    return version;
}

+ (nullable Class<GADAdNetworkExtras>)networkExtrasClass {
    return nil;
}

- (void)loadRewardedAdForAdConfiguration:(GADMediationRewardedAdConfiguration *)adConfiguration
                       completionHandler:(GADMediationRewardedLoadCompletionHandler)completionHandler {
    if (self.rewardedVideo) {
        self.rewardedVideo = nil;
    }
    
    self.loadCompletionHandler = completionHandler;
    
    NSString *jsonStr = adConfiguration.credentials.settings[@"parameter"];
    NSDictionary *jsonDic = [[self class] parseJsonParameters:jsonStr];
    
    self.rewardedVideo = [[MentaMediationRewardVideo alloc] initWithPlacementID:jsonDic[@"placementID"]];
    self.rewardedVideo.delegate = self;
    [self.rewardedVideo loadAd];
}

- (void)presentFromViewController:(UIViewController *)viewController {
    if ([self.rewardedVideo isAdReady]) {
        [self.rewardedVideo showAdFromRootViewController:viewController];
    } else {
        NSError *err= [[NSError alloc] initWithDomain:@"menta rewardedVideo custom event"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey : @"The rewardedVideo ad failed to present, because the ad was not loaded."}];
        [self.adEventDelegate didFailToPresentWithError:err];
    }
}

#pragma mark - private

+ (NSDictionary *)parseJsonParameters:(NSString *)jsonString {
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error) {
        return nil;
    } else {
        return jsonDict.copy;
    }
}

#pragma mark - MentaMediationRewardVideoDelegate

// 广告素材加载成功
- (void)menta_rewardVideoDidLoad:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
}

// 广告素材加载失败
- (void)menta_rewardVideoLoadFailedWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    self.adEventDelegate = self.loadCompletionHandler(nil, error);
}

// 广告素材渲染成功
// 此时可以获取 ecpm
- (void)menta_rewardVideoRenderSuccess:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    self.adEventDelegate = self.loadCompletionHandler(self, nil);
}

// 广告素材渲染失败
- (void)menta_rewardVideoRenderFailureWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    self.adEventDelegate = self.loadCompletionHandler(nil, error);
}

// 激励视频广告即将展示
- (void)menta_rewardVideoWillPresent:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    [self.adEventDelegate willPresentFullScreenView];
}

// 激励视频广告展示失败
- (void)menta_rewardVideoShowFailWithError:(NSError *)error rewardVideo:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    [self.adEventDelegate didFailToPresentWithError:error];
}

// 激励视频广告曝光
- (void)menta_rewardVideoExposed:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportImpression];
    [self.adEventDelegate didStartVideo];
}

// 激励视频广告点击
- (void)menta_rewardVideoClicked:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportClick];
}

// 激励视频广告跳过
- (void)menta_rewardVideoSkiped:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
}

// 激励视频达到奖励节点
- (void)menta_rewardVideoDidEarnReward:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    [self.adEventDelegate didRewardUser];
}

// 激励视频播放完成
- (void)menta_rewardVideoPlayCompleted:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    [self.adEventDelegate didEndVideo];
}

// 激励视频广告关闭
-(void)menta_rewardVideoClosed:(MentaMediationRewardVideo *)rewardVideo {
    NSLog(@"%s", __func__);
    [self.adEventDelegate willDismissFullScreenView];
    [self.adEventDelegate didDismissFullScreenView];
}

@end
