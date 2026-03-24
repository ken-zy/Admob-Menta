//
//  GADMentaInterstitialCustomEvent.m
//  GoogleMobileAdsMediationMenta
//
//  Created by jdy on 2024/7/1.
//

#import "GADMentaInterstitialCustomEvent.h"
#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

@interface GADMentaInterstitialCustomEvent () <MentaMediationInterstitialDelegate>

@property (nonatomic, strong) MentaMediationInterstitial *interstitial;

@property (nonatomic, copy) GADMediationInterstitialLoadCompletionHandler loadCompletionHandler;
@property (nonatomic, weak) id<GADMediationInterstitialAdEventDelegate> adEventDelegate;

@end

@implementation GADMentaInterstitialCustomEvent

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

- (void)loadInterstitialForAdConfiguration:(GADMediationInterstitialAdConfiguration *)adConfiguration
                         completionHandler:(GADMediationInterstitialLoadCompletionHandler)completionHandler {
    if (self.interstitial) {
        self.interstitial = nil;
    }
    
    self.loadCompletionHandler = completionHandler;
    
    NSString *jsonStr = adConfiguration.credentials.settings[@"parameter"];
    NSDictionary *jsonDic = [[self class] parseJsonParameters:jsonStr];
    
    self.interstitial = [[MentaMediationInterstitial alloc] initWithPlacementID:jsonDic[@"placementID"]];
    self.interstitial.delegate = self;
    [self.interstitial loadAd];
}

- (void)presentFromViewController:(UIViewController *)viewController {
    if ([self.interstitial isAdReady]) {
        [self.interstitial showAdFromRootViewController:viewController];
    } else {
        NSError *err= [[NSError alloc] initWithDomain:@"menta interstitial custom event"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey : @"The interstitial ad failed to present, because the ad was not loaded."}];
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

#pragma mark - MentaMediationInterstitialDelegate

// 广告素材加载成功
- (void)menta_interstitialDidLoad:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
}

// 广告素材加载失败
- (void)menta_interstitialLoadFailedWithError:(NSError *)error interstitial:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    self.adEventDelegate = self.loadCompletionHandler(nil, error);
}

// 广告素材渲染成功
// 此时可以获取 ecpm
- (void)menta_interstitialRenderSuccess:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    self.adEventDelegate = self.loadCompletionHandler(self, nil);
}

// 广告素材渲染失败
- (void)menta_interstitialRenderFailureWithError:(NSError *)error interstitial:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    [self.adEventDelegate didFailToPresentWithError:error];
}

// 广告即将展示
- (void)menta_interstitialWillPresent:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    [self.adEventDelegate willPresentFullScreenView];
}

// 广告展示失败
- (void)menta_interstitialShowFailWithError:(NSError *)error interstitial:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    self.adEventDelegate = self.loadCompletionHandler(nil, error);
}

// 广告曝光
- (void)menta_interstitialExposed:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportImpression];
}

// 广告点击
- (void)menta_interstitialClicked:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportClick];
}

// 视频播放完成
- (void)menta_interstitialPlayCompleted:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
}

// 广告关闭
-(void)menta_interstitialClosed:(MentaMediationInterstitial *)interstitial {
    NSLog(@"%s", __func__);
    [self.adEventDelegate willDismissFullScreenView];
    [self.adEventDelegate didDismissFullScreenView];
}

@end
