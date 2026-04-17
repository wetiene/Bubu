#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "bubu" asset catalog image resource.
static NSString * const ACImageNameBubu AC_SWIFT_PRIVATE = @"bubu";

/// The "bubu-bike" asset catalog image resource.
static NSString * const ACImageNameBubuBike AC_SWIFT_PRIVATE = @"bubu-bike";

/// The "bubu-scooter" asset catalog image resource.
static NSString * const ACImageNameBubuScooter AC_SWIFT_PRIVATE = @"bubu-scooter";

/// The "bubu-skate" asset catalog image resource.
static NSString * const ACImageNameBubuSkate AC_SWIFT_PRIVATE = @"bubu-skate";

/// The "elephant" asset catalog image resource.
static NSString * const ACImageNameElephant AC_SWIFT_PRIVATE = @"elephant";

/// The "giraffe" asset catalog image resource.
static NSString * const ACImageNameGiraffe AC_SWIFT_PRIVATE = @"giraffe";

/// The "lion" asset catalog image resource.
static NSString * const ACImageNameLion AC_SWIFT_PRIVATE = @"lion";

/// The "purse" asset catalog image resource.
static NSString * const ACImageNamePurse AC_SWIFT_PRIVATE = @"purse";

#undef AC_SWIFT_PRIVATE
