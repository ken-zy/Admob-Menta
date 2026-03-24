//
//  GADMentaBannerCustomEvent.m
//  Google-Mobile-Ads-SDK
//
//  Created by jdy on 2024/6/28.
//

#import "GADMentaBannerCustomEvent.h"
#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

@interface GADMentaBannerCustomEvent () <MentaMediationBannerDelegate>

@property (nonatomic, strong) MentaMediationBanner *banner;
@property (nonatomic, strong) UIView *bannerView;

@property (nonatomic, copy) GADMediationBannerLoadCompletionHandler loadCompletionHandler;
@property (nonatomic, weak) id<GADMediationBannerAdEventDelegate> adEventDelegate;

@end

@implementation GADMentaBannerCustomEvent

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
    [menta setLogLevel:kMentaLogLevelError];
    
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

- (void)loadBannerForAdConfiguration:(GADMediationBannerAdConfiguration *)adConfiguration
                   completionHandler:(GADMediationBannerLoadCompletionHandler)completionHandler {
  
    if (self.banner) {
        self.banner = nil;
        self.bannerView = nil;
    }
    
    self.loadCompletionHandler = completionHandler;
    
    NSString *jsonStr = adConfiguration.credentials.settings[@"parameter"];
    NSDictionary *jsonDic = [[self class] parseJsonParameters:jsonStr];
    
    self.banner = [[MentaMediationBanner alloc] initWithPlacementID:jsonDic[@"placementID"]];
    self.banner.delegate = self;
    [self.banner loadAd];
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

#pragma mark - GADMediationBannerAd

- (UIView *)view {
    return self.bannerView;
}

#pragma mark - MentaMediationBannerDelegate

// 广告素材加载成功
- (void)menta_bannerAdDidLoad:(MentaMediationBanner *)banner {
    NSLog(@"%s", __func__);
}

// 广告素材加载失败
- (void)menta_bannerAdLoadFailedWithError:(NSError *)error banner:(MentaMediationBanner *)banner {
    NSLog(@"%s", __func__);
    NSLog(@"%@", error);
    self.adEventDelegate = self.loadCompletionHandler(nil, error);
}

// 广告素材渲染成功
// 此时可以获取 ecpm
- (void)menta_bannerAdRenderSuccess:(MentaMediationBanner *)banner bannerAdView:(UIView *)bannerAdView {
    NSLog(@"%s", __func__);
    self.bannerView = bannerAdView;
    self.adEventDelegate = self.loadCompletionHandler(self, nil);
}

// 广告素材渲染失败
- (void)menta_bannerAdRenderFailureWithError:(NSError *)error banner:(MentaMediationBanner *)banner {
    NSLog(@"%s", __func__);
    NSLog(@"%@", error);
    self.adEventDelegate = self.loadCompletionHandler(nil, error);
}

// 广告曝光
- (void)menta_bannerAdExposed:(MentaMediationBanner *)banner {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportImpression];
}

// 广告点击
- (void)menta_bannerAdClicked:(MentaMediationBanner *)banner {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportClick];
}

// 广告关闭
-(void)menta_bannerAdClosed:(MentaMediationBanner *)banner {
    NSLog(@"%s", __func__);
    self.banner = nil;
    self.bannerView = nil;
}

@end
