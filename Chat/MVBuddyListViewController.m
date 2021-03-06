#import "MVBuddyListViewController.h"
#import "MVBuddyViewCell.h"
#import "MVBuddyListView.h"
#import "MVBuddiesManager.h"
#import "MVXMPP.h"

@interface XMPPUserMemoryStorageObject ()

- (id)initWithJID:(XMPPJID*)jid;

@end

@interface MVBuddyListViewController () <TUITableViewDataSource,
                                         TUITableViewDelegate,
                                         MVBuddyListViewDelegate,
                                         MVBuddiesManagerDelegate>

@property (strong, readwrite) MVXMPP *xmpp;
@property (strong, readwrite) MVBuddiesManager *buddiesManager;
@property (strong, readwrite) TUIView *view;
@property (strong, readwrite) MVBuddyListView *buddyListView;
@property (strong, readwrite) TUITableView *tableView;
@property (strong, readwrite) NSArray *users;
@property (strong, readwrite) NSArray *filteredUsers;

- (MVBuddyViewCell*)visibleCellForJid:(XMPPJID*)jid;

@end

@implementation MVBuddyListViewController

@synthesize xmpp = xmpp_,
            buddiesManager = buddiesManager_,
            view = view_,
            buddyListView = buddyListView_,
            tableView = tableView_,
            users = users_,
            filteredUsers = filteredUsers_,
            delegate = delegate_;

- (id)init
{
  self = [super init];
  if(self)
  {
    delegate_ = nil;
    xmpp_ = [MVXMPP xmpp];
    buddiesManager_ = [MVBuddiesManager sharedInstance];
    
    self.view = self.buddyListView = [[MVBuddyListView alloc] initWithFrame:CGRectMake(0, 0, 100, 200)];
    self.tableView = self.buddyListView.tableView;
    self.tableView.maintainContentOffsetAfterReload = YES;
    [self.tableView scrollToTopAnimated:NO];
    self.buddyListView.delegate = self;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    users_ = [NSArray array];
    filteredUsers_ = [NSArray array];
    
    [self reload];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults addObserver:self forKeyPath:kMVPreferencesShowOfflineBuddiesKey
                  options:0 context:NULL];
    
    [buddiesManager_ addDelegate:self];
  }
  return self;
}

- (void)dealloc
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObserver:self forKeyPath:kMVPreferencesShowOfflineBuddiesKey];
  [buddiesManager_ removeDelegate:self];
}

- (void)makeFirstResponder
{
  [self.view makeFirstResponder];
}

- (void)reload
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if([defaults boolForKey:kMVPreferencesShowOfflineBuddiesKey])
    self.users = [self.buddiesManager buddies];
  else
    self.users = [self.buddiesManager onlineBuddies];
  
  if(self.buddyListView.isSearchFieldVisible && self.buddyListView.searchFieldText.length > 0)
  {
    NSMutableString *regex = [NSMutableString stringWithString:@".*"];
    NSString *searchFieldText = self.buddyListView.searchFieldText;
    for (int i=0; i<searchFieldText.length; i++) {
      NSString *searchFieldLetter = [searchFieldText substringWithRange:NSMakeRange(i, 1)];
      [regex appendFormat:@"%@.*",searchFieldLetter];
    }
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                              @"nickname MATCHES[cd] %@ OR jid.bare MATCHES[cd] %@",
                              regex,
                              regex];
    self.filteredUsers = [self.users filteredArrayUsingPredicate:predicate];
  }
  else
    self.filteredUsers = self.users;
  
//  NSMutableArray *tmp = [NSMutableArray array];
//  for(int i=0;i<50;i++) {
//    XMPPJID *jid = [XMPPJID jidWithString:@"blah@gmail.com"];
//    XMPPUserMemoryStorageObject *user = [[XMPPUserMemoryStorageObject alloc] initWithJID:jid];
//    [tmp addObject:user];
//  }
//  self.filteredUsers = tmp;
  
  [self.tableView reloadData];
  
  if(self.buddyListView.isSearchFieldVisible)
  {
    TUIFastIndexPath *indexPath = [TUIFastIndexPath indexPathForRow:0 inSection:0];
    [self.tableView selectRowAtIndexPath:indexPath animated:NO
                          scrollPosition:TUITableViewScrollPositionToVisible];
  }
  else
  {
    TUIFastIndexPath *selectedIndexPath = self.tableView.indexPathForSelectedRow;
    if(selectedIndexPath)
      [self.tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];
  }
}

- (void)setSearchFieldVisible:(BOOL)visible
{
  [self.buddyListView setSearchFieldVisible:visible animated:YES];
  [self.buddyListView makeFirstResponder];
}

#pragma mark Private Methods

- (MVBuddyViewCell*)visibleCellForJid:(XMPPJID*)jid
{
  NSArray *visibleCells = self.tableView.visibleCells;
  for(MVBuddyViewCell *cell in visibleCells)
  {
    XMPPJID *cellJid = (XMPPJID*)cell.representedObject;
    if(cellJid && [cellJid isEqualToJID:jid options:XMPPJIDCompareBare])
      return cell;
  }
  return nil;
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
  if([keyPath isEqualToString:kMVPreferencesShowOfflineBuddiesKey])
  {
    [self reload];
  }
  else
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark TUITableViewDelegate Methods

- (void)tableView:(TUITableView *)tableView
didClickRowAtIndexPath:(TUIFastIndexPath *)indexPath
        withEvent:(NSEvent *)event
{
  NSObject<XMPPUser> *user = [self.filteredUsers objectAtIndex:indexPath.row];
  [self.buddyListView setSearchFieldVisible:NO animated:YES];
  if([self.delegate respondsToSelector:@selector(buddyListViewController:didClickBuddy:)])
    [self.delegate buddyListViewController:self didClickBuddy:user];
}

- (BOOL)tableView:(TUITableView *)tableView shouldSelectRowAtIndexPath:(TUIFastIndexPath *)indexPath
         forEvent:(NSEvent *)event
{
  return [self.buddyListView isSearchFieldVisible];
}

#pragma mark TUITableViewDataSource Methods

- (NSInteger)tableView:(TUITableView *)table numberOfRowsInSection:(NSInteger)section
{
  return self.filteredUsers.count;
}

- (CGFloat)tableView:(TUITableView *)tableView
heightForRowAtIndexPath:(TUIFastIndexPath *)indexPath
{
  return 30;
}

- (TUITableViewCell *)tableView:(TUITableView *)tableView
          cellForRowAtIndexPath:(TUIFastIndexPath *)indexPath
{
  NSObject<XMPPUser> *user = [self.filteredUsers objectAtIndex:indexPath.row];
  
  MVBuddyViewCell *cell = reusableTableCellOfClass(tableView, MVBuddyViewCell);
  cell.email = user.jid.bare;
  cell.fullname = user.nickname;
  cell.online = user.isOnline;
  cell.alternate = indexPath.row % 2 == 1;
  cell.firstRow = indexPath.row == 0;
  cell.lastRow = (indexPath.row == [self tableView:tableView
                             numberOfRowsInSection:indexPath.section] - 1);
  cell.representedObject = user.jid;
  cell.toolTip = cell.email;
  TUIImage *avatar = [self.buddiesManager avatarForJid:user.jid];
  if(avatar)
    cell.avatar = avatar;
  else
    cell.avatar = [TUIImage imageNamed:@"placeholder_avatar.png" cache:YES];
  [cell setNeedsDisplay];
	return cell;
}

#pragma mark MVBuddiesManagerDelegate

- (void)buddiesManagerBuddiesDidChange:(MVBuddiesManager *)buddiesManager
{
  [self reload];
}

- (void)buddiesManager:(MVBuddiesManager *)buddiesManager jidDidChangeOnlineStatus:(XMPPJID *)jid
{
  MVBuddyViewCell *cell = [self visibleCellForJid:jid];
  if(cell)
  {
    BOOL online = [self.buddiesManager isJidOnline:jid];
    if(cell.isOnline != online)
    {
      cell.online = online;
      [cell setNeedsDisplay];
    }
  }
}

- (void)buddiesManager:(MVBuddiesManager *)buddiesManager jidDidChangeAvatar:(XMPPJID *)jid
{
  MVBuddyViewCell *cell = [self visibleCellForJid:jid];
  if(cell)
  {
    TUIImage *avatar = [self.buddiesManager avatarForJid:jid];
    if(avatar)
    {
      cell.avatar = avatar;
      [cell setNeedsDisplay];
    }
  }
}

#pragma mark MVBuddyListViewDelegate Methods

- (void)buddyListViewDidChangeSearchFieldValue:(MVBuddyListView *)buddyListView
{
  [self reload];
}

- (void)buddyListViewDidChangeSearchFieldVisibility:(MVBuddyListView *)buddyListView
{
  [self reload];
}

@end
