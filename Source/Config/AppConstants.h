#define kNetworkTimeoutDuration 12

#define kMinUsernameLength      3
#define kMaxUsernameLength      13
#define kMinPasswordLength      5

#define kMaxSimultaneousMatches 25

#define kFontName               @"Futura-CondensedMedium"
#define kFontSizeHeader         SCALED(24)
#define kFontSizeRegular        SCALED(18)
#define kFontSizeSmall          SCALED(14)
#define kFontSizeButton         SCALED(22)

#define kFontNameHUD            kFontName
#define kFontSizeHUD            SCALED(16)

#define kBoardMaxZoomScale      (ISPAD ? 2.0 : 3.0)
#define BOARDSCALED(x)          ceilf(ISPAD ? (x*2.3) : x)
#define kBoardWidthPoints       BOARDSCALED(440)
#define kBoardHeightPoints      BOARDSCALED(220)

#define kTileColorPlayerOne     [UIColor colorWithRed:0.572 green:0.741 blue:0.479 alpha:1.000]
#define kTileColorPlayerTwo     [UIColor colorWithRed:0.819 green:0.598 blue:0.214 alpha:1.000]
#define kTileTextColorPlayerOne [UIColor colorWithRed:0.286 green:0.369 blue:0.239 alpha:1.000]
#define kTileTextColorPlayerTwo [UIColor colorWithRed:0.329 green:0.251 blue:0.173 alpha:1.000]
#define kTileWidth              BOARDSCALED(40)
#define kTileHeight             (kTileWidth/2.0)
#define kTileHalfWidth          (kTileWidth/2.0)
#define kTileHalfHeight         (kTileHeight/2.0)
#define kTileLetterFontName     @"Futura"
#define kTilePointFontName      @"Futura-CondensedMedium"

#define kDragProxyFingerOffset  (ISPAD ? 33 : 40)

#define kGlossyButtonWidth        SCALED(150)
#define kGlossyButtonHeight       SCALED(45)
#define kGlossyButtonCornerRadius SCALED(10)
#define kButtonMargin             (ISPAD ? 10 : 1)

#define kGlossyBrownColor       [UIColor colorWithRed:0.497 green:0.438 blue:0.333 alpha:1.000]
#define kGlossyGreenColor       [UIColor colorWithRed:0.430 green:0.640 blue:0.121 alpha:1.000]
#define kGlossyRedColor         [UIColor colorWithRed:0.718 green:0.243 blue:0.247 alpha:1.000]
#define kGlossyBlackColor       [UIColor colorWithWhite:0.236 alpha:1.000]
#define kGlossyOrangeColor      [UIColor colorWithRed:0.824 green:0.553 blue:0.369 alpha:1.000]
#define kGlossyBlueColor        [UIColor colorWithRed:0.192 green:0.478 blue:0.812 alpha:1.000]
#define kGlossyGoldColor        [UIColor colorWithRed:0.886 green:0.843 blue:0.412 alpha:1.000]
#define kGlossyPurpleColor      [UIColor colorWithRed:0.678 green:0.424 blue:0.886 alpha:1.000]
#define kGlossyLightBlueColor   [UIColor colorWithRed:0.451 green:0.741 blue:0.780 alpha:1.000]

#define kAlertCoverColor        [UIColor colorWithWhite:0.235 alpha:0.5]

#define kTileDropHighlightColor [[UIColor darkGrayColor] colorWithAlphaComponent:0.5]

extern NSString * const kAppStoreAppID;
extern NSString * const kAppStorePublicURL;
extern NSString * const kAppStoreReviewURL;
extern NSString * const kAppStoreInternalURL;

