#import <Foundation/Foundation.h>

#import "permissions/PSTPermissionManifest.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PSTPermissionPlanErrorDomain;

typedef NS_ERROR_ENUM(PSTPermissionPlanErrorDomain, PSTPermissionPlanError){
    PSTPermissionPlanErrorMissingService = 1,
};

typedef NSString *_Nullable (^PSTPermissionTargetPathResolver)(
    PSTPermissionTarget *target);

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionOperation : NSObject

@property(nonatomic, strong, readonly) PSTPermissionTarget *target;
@property(nonatomic, strong, readonly) PSTPermissionService *service;
@property(nonatomic, copy, readonly) NSString *applicationPath;

- (instancetype)init NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionPlan : NSObject

@property(nonatomic, copy, readonly) NSArray<PSTPermissionOperation *> *operations;
@property(nonatomic, copy, readonly) NSArray<PSTPermissionTarget *> *missingTargets;
@property(nonatomic, copy, readonly)
    NSArray<PSTPermissionTarget *> *missingRequiredTargets;
@property(nonatomic, copy, readonly)
    NSArray<PSTPermissionTarget *> *missingOptionalTargets;

+ (nullable instancetype)planWithManifest:(PSTPermissionManifest *)manifest
                             pathResolver:(PSTPermissionTargetPathResolver)pathResolver
                                    error:(NSError *_Nullable *_Nullable)error;

- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
