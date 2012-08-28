#define ISPAD      ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
#define SCALED(x)  (ISPAD ? (x*2) : x)