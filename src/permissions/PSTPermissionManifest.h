#import <Foundation/Foundation.h>

#include "permissions/PSTPermissionConfirmationCore.h"
#include "permissions/PSTPermissionTypes.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PSTPermissionManifestErrorDomain;

FOUNDATION_EXPORT PSTPermissionConfirmationDataSource
PSTPermissionManifestConfirmationDataSource(void);

typedef NS_ERROR_ENUM(PSTPermissionManifestErrorDomain, PSTPermissionManifestError){
    PSTPermissionManifestErrorInvalidJSON = 1,
    PSTPermissionManifestErrorUnsupportedVersion,
    PSTPermissionManifestErrorInvalidService,
    PSTPermissionManifestErrorDuplicateService,
    PSTPermissionManifestErrorInvalidPermissionSet,
    PSTPermissionManifestErrorUnknownPermissionSet,
    PSTPermissionManifestErrorInvalidTarget,
    PSTPermissionManifestErrorUnknownService,
};

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionService : NSObject

@property(nonatomic, copy, readonly) NSString *identifier;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly, nullable) NSString *serviceDescription;
@property(nonatomic, copy, readonly) NSString *symbolName;
@property(nonatomic, copy, readonly) NSString *route;
@property(nonatomic, readonly) BOOL requiresAdmin;
@property(nonatomic, copy, readonly) NSString *modeIdentifier;
@property(nonatomic, readonly) PSTPermissionServiceMode mode;

- (instancetype)init NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionTarget : NSObject

@property(nonatomic, copy, readonly) NSString *inventoryIdentifier;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, readonly) PSTPermissionTargetKind kind;
@property(nonatomic, copy, readonly, nullable) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSArray<NSString *> *bundleIdentifiers;
@property(nonatomic, copy, readonly) NSArray<NSString *> *pathCandidates;
@property(nonatomic, readonly, getter=isRequired) BOOL required;
@property(nonatomic, copy, readonly) NSArray<NSString *> *permissionSetIdentifiers;
@property(nonatomic, copy, readonly) NSArray<NSString *> *serviceIdentifiers;

- (instancetype)init NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionManifest : NSObject

@property(nonatomic, copy, readonly) NSArray<PSTPermissionService *> *services;
@property(nonatomic, copy, readonly) NSArray<PSTPermissionTarget *> *targets;
@property(nonatomic, copy, readonly)
    NSDictionary<NSString *, PSTPermissionService *> *servicesByIdentifier;
@property(nonatomic, copy, readonly) NSString *confirmationDescription;

+ (nullable instancetype)
    manifestWithPermissionCatalogData:(NSData *)catalogData
                          targetsData:(NSData *)targetsData
                                error:(NSError *_Nullable *_Nullable)error;
+ (nullable instancetype)bundledCatalogWithError:(NSError *_Nullable *_Nullable)error;
+ (nullable instancetype)bundledManifestWithTargetsData:(NSData *)targetsData
                                                  error:(NSError *_Nullable *_Nullable)
                                                            error;
+ (nullable instancetype)bundledManifestWithTargetsURL:(NSURL *)targetsURL
                                                 error:(NSError *_Nullable *_Nullable)
                                                           error;

- (instancetype)init NS_UNAVAILABLE;
- (nullable PSTPermissionService *)serviceForIdentifier:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
