#import <Foundation/Foundation.h>

#include "permissions/PSTPermissionTypes.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const PSTPermissionTargetsDocumentErrorDomain;
FOUNDATION_EXPORT NSString *const PSTPermissionTargetsFilename;

typedef NS_ERROR_ENUM(PSTPermissionTargetsDocumentErrorDomain,
                      PSTPermissionTargetsDocumentError){
    PSTPermissionTargetsDocumentErrorNoTargets = 1,
    PSTPermissionTargetsDocumentErrorInvalidTarget,
    PSTPermissionTargetsDocumentErrorDuplicateIdentifier,
    PSTPermissionTargetsDocumentErrorInvalidPermission,
    PSTPermissionTargetsDocumentErrorSerialization,
};

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionTargetDraft : NSObject

@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@property(nonatomic) PSTPermissionTargetKind kind;
@property(nonatomic, copy) NSArray<NSString *> *bundleIdentifiers;
@property(nonatomic, copy) NSArray<NSString *> *pathCandidates;
@property(nonatomic, getter=isRequired) BOOL required;
@property(nonatomic, copy) NSArray<NSString *> *serviceIdentifiers;

- (instancetype)initWithIdentifier:(NSString *)identifier
                              name:(NSString *)name
                              kind:(PSTPermissionTargetKind)kind
                 bundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                    pathCandidates:(NSArray<NSString *> *)pathCandidates
                          required:(BOOL)required
                serviceIdentifiers:(NSArray<NSString *> *)serviceIdentifiers
    NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionTargetsDocument : NSObject

+ (nullable NSData *)dataWithTargets:(NSArray<PSTPermissionTargetDraft *> *)targets
           allowedServiceIdentifiers:(NSSet<NSString *> *)allowedServiceIdentifiers
                               error:(NSError *_Nullable *_Nullable)error;

- (instancetype)init NS_UNAVAILABLE;

@end

__attribute__((objc_subclassing_restricted))
@interface PSTPermissionTargetsStore : NSObject

@property(nonatomic, copy, readonly) NSURL *targetsURL;

- (instancetype)init;
- (instancetype)initWithDirectoryURL:(NSURL *)directoryURL NS_DESIGNATED_INITIALIZER;
- (nullable NSURL *)existingTargetsURL;
- (BOOL)saveTargetsData:(NSData *)data error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
