@protocol MVBuddiesManagerDelegate;

@interface MVBuddiesManager : NSObject

@property (strong, readwrite, nonatomic) XMPPStream *xmppStream;

+ (MVBuddiesManager*)sharedInstance;

- (NSArray*)buddies;
- (NSString*)nameForJid:(XMPPJID*)jid;
- (TUIImage*)avatarForJid:(XMPPJID*)jid;
- (BOOL)isJidOnline:(XMPPJID*)jid;

- (void)addDelegate:(NSObject<MVBuddiesManagerDelegate>*)delegate;
- (void)removeDelegate:(NSObject<MVBuddiesManagerDelegate>*)delegate;

@end

@protocol MVBuddiesManagerDelegate
@optional
- (void)buddiesManagerBuddiesDidChange:(MVBuddiesManager *)buddiesManager;
- (void)buddiesManager:(MVBuddiesManager*)buddiesManager jidDidChangeOnlineStatus:(XMPPJID*)jid;
- (void)buddiesManager:(MVBuddiesManager*)buddiesManager jidDidChangeAvatar:(XMPPJID*)jid;
@end