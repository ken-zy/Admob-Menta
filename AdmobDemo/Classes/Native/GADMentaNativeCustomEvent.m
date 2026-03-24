//
//  GADMentaNativeCustomEvent.m
//  GoogleMobileAdsMediationMenta
//
//  Created by jdy on 2024/6/28.
//

#import "GADMentaNativeCustomEvent.h"
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <MentaMediationGlobal/MentaMediationGlobal-umbrella.h>

@interface GADMentaNativeCustomEvent () <MentaNativeSelfRenderDelegate>

@property (nonatomic, strong) MentaMediationNativeSelfRender *nativeAd;
@property (nonatomic, strong) MentaMediationNativeSelfRenderModel *nativeAdModel;
@property (nonatomic, strong) UIImage *mainImg;

@property (nonatomic, copy) GADMediationNativeLoadCompletionHandler loadCompletionHandler;
@property (nonatomic, weak) id<GADMediationNativeAdEventDelegate> adEventDelegate;

@end

@implementation GADMentaNativeCustomEvent

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

- (void)loadNativeAdForAdConfiguration:(GADMediationNativeAdConfiguration *)adConfiguration
                     completionHandler:(GADMediationNativeLoadCompletionHandler)completionHandler {
    if (self.nativeAd) {
        self.nativeAd = nil;
        self.nativeAdModel = nil;
        self.mainImg = nil;
    }
    
    self.loadCompletionHandler = completionHandler;
    
    NSString *jsonStr = adConfiguration.credentials.settings[@"parameter"];
    NSDictionary *jsonDic = [[self class] parseJsonParameters:jsonStr];
    
    self.nativeAd = [[MentaMediationNativeSelfRender alloc] initWithPlacementID:jsonDic[@"placementID"]];
    self.nativeAd.delegate = self;
    
    [self.nativeAd loadAd];

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

#pragma mark - MentaNativeSelfRenderDelegate

- (void)menta_nativeSelfRenderLoadSuccess:(NSArray<MentaMediationNativeSelfRenderModel *> *)nativeSelfRenderAds
                         nativeSelfRender:(MentaMediationNativeSelfRender *)nativeSelfRender {
    NSLog(@"%s", __func__);
    if (nativeSelfRenderAds.count <= 0) {
        return;
    }
    
    self.nativeAdModel = nativeSelfRenderAds.firstObject;
    if (self.nativeAdModel.isVideo) {
        self.adEventDelegate = self.loadCompletionHandler(self, nil);
    } else {
        [self downloadImg];
    }
}

- (void)menta_nativeSelfRenderLoadFailure:(NSError *)error
                         nativeSelfRender:(MentaMediationNativeSelfRender *)nativeSelfRender {
    NSLog(@"%s", __func__);
    self.adEventDelegate = self.loadCompletionHandler(nil, error);
}

- (void)menta_nativeSelfRenderViewExposed {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportImpression];
}

- (void)menta_nativeSelfRenderViewClicked {
    NSLog(@"%s", __func__);
    [self.adEventDelegate reportClick];
}

- (void)menta_nativeSelfRenderViewClosed {
    NSLog(@"%s", __func__);
}

// 预加载主图
- (void)downloadImg {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:self.nativeAdModel.materialURL]];
    __weak typeof(self) weakSelf = self;
    [[MentaAFImageDownloader defaultInstance] downloadImageForURLRequest:request
                                                                 success:^(NSURLRequest * _Nonnull request,
                                                                           NSHTTPURLResponse * _Nullable response,
                                                                           UIImage * _Nonnull responseObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        self.mainImg = responseObject;
        strongSelf.adEventDelegate = strongSelf.loadCompletionHandler(strongSelf, nil);
        NSLog(@"%s", __func__);
    }
                                                                 failure:^(NSURLRequest * _Nonnull request,
                                                                           NSHTTPURLResponse * _Nullable response,
                                                                           NSError * _Nonnull error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.adEventDelegate = strongSelf.loadCompletionHandler(nil, error);
    }];
}

#pragma mark - GADMediationNativeAd

/// Indicates whether the ad handles user clicks. If this method returns YES, the ad must handle
/// user clicks and notify the Google Mobile Ads SDK of clicks using
/// -[GADMediationAdEventDelegate reportClick:]. If this method returns NO, the Google Mobile Ads
/// SDK handles user clicks and notifies the ad of clicks using -[GADMediationNativeAd
/// didRecordClickOnAssetWithName:view:viewController:].
- (BOOL)handlesUserClicks {
    return YES;
}

/// Indicates whether the ad handles user impressions tracking. If this method returns YES, the
/// Google Mobile Ads SDK will not track user impressions and the ad must notify the
/// Google Mobile Ads SDK of impressions using -[GADMediationAdEventDelegate
/// reportImpression:]. If this method returns NO, the Google Mobile Ads SDK tracks user impressions
/// and notifies the ad of impressions using -[GADMediationNativeAd didRecordImpression:].
- (BOOL)handlesUserImpressions {
    return YES;
}

/// Tells the receiver that it has been rendered in |view| with clickable asset views and
/// nonclickable asset views. viewController should be used to present modal views for the ad.
- (void)didRenderInView:(nonnull UIView *)view
    clickableAssetViews:(nonnull NSDictionary<GADNativeAssetIdentifier, UIView *> *)clickableAssetViews
 nonclickableAssetViews:(nonnull NSDictionary<GADNativeAssetIdentifier, UIView *> *)nonclickableAssetViews
         viewController:(nonnull UIViewController *)viewController {
    self.nativeAdModel.selfRenderView.frame = view.bounds;
    [view insertSubview:self.nativeAdModel.selfRenderView atIndex:0];
    
    [self.nativeAdModel.selfRenderView menta_registerClickableViews:clickableAssetViews.allValues closeableViews:nil];
}

/// Tells the receiver that an impression is recorded. This method is called only once per mediated
/// native ad.
- (void)didRecordImpression {
    
}

/// Tells the receiver that a user click is recorded on the asset named |assetName|. Full screen
/// actions should be presented from viewController. This method is called only if
/// -[GADMAdNetworkAdapter handlesUserClicks] returns NO.
- (void)didRecordClickOnAssetWithName:(nonnull GADNativeAssetIdentifier)assetName
                                 view:(nonnull UIView *)view
                       viewController:(nonnull UIViewController *)viewController {
    
}

/// Tells the receiver that it has untracked |view|. This method is called when the mediated native
/// ad is no longer rendered in the provided view and the delegate should stop tracking the view's
/// impressions and clicks. The method may also be called with a nil view when the view in which the
/// mediated native ad has rendered is deallocated.
- (void)didUntrackView:(nullable UIView *)view {
    
}

#pragma mark - GADMediatedUnifiedNativeAd

- (nullable NSString *)headline {
    return self.nativeAdModel.title;
}

- (nullable NSArray<GADNativeAdImage *> *)images {
    CGFloat scale = 1;
    if (self.nativeAdModel.materialWidth > 0 && self.nativeAdModel.materialHeight > 0) {
        scale = self.nativeAdModel.materialWidth / self.nativeAdModel.materialHeight;
    }
    GADNativeAdImage *img = [[GADNativeAdImage alloc] initWithImage:self.mainImg];
    if (img) {
        return @[img];
    } else {
        return nil;
    }
}

- (nullable NSString *)body {
    return self.nativeAdModel.des;
}

- (nullable GADNativeAdImage *)icon {
    NSURL *iconURL = [NSURL URLWithString:self.nativeAdModel.iconURL];
    GADNativeAdImage *icon = [[GADNativeAdImage alloc] initWithURL:iconURL scale:1.0];
    if (icon) {
        return icon;
    } else {
        return nil;
    }
}

- (nullable NSString *)callToAction {
    return @"More Detail";
}

- (nullable NSDecimalNumber *)starRating {
//    return [NSDecimalNumber decimalNumberWithString:@"4.8"];
    return nil;
}

- (nullable NSString *)store {
  return nil;
}

- (nullable NSString *)price {
  return self.nativeAdModel.eCPM;
}

- (nullable NSString *)advertiser {
  return nil;
}

- (nullable NSDictionary<NSString *, id> *)extraAssets {
  return nil;
}

- (nullable UIView *)adChoicesView {
  return self.nativeAdModel.adLogo;
}

- (nullable UIView *)mediaView {
  return self.nativeAdModel.selfRenderView.mediaView;
}

- (BOOL)hasVideoContent {
  return self.nativeAdModel.isVideo;
}

@end
