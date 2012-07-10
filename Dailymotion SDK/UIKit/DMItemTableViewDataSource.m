//
//  DMItemTableViewDataSource.m
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 25/06/12.
//
//

#import "DMItemTableViewDataSource.h"
#import "DMItemDataSourceItem.h"
#import "DMItemLocalCollection.h"
#import "DMSubscriptingSupport.h"
#import "objc/runtime.h"
#import "objc/message.h"

static char operationKey;

@interface DMItemTableViewDataSource ()

@property (nonatomic, assign) BOOL _loaded;
@property (nonatomic, strong) NSMutableArray *_operations;

@end

@implementation DMItemTableViewDataSource

- (id)init
{
    if ((self = [super init]))
    {
        [self addObserver:self forKeyPath:@"itemCollection" options:0 context:NULL];
        [self addObserver:self forKeyPath:@"itemCollection.currentEstimatedTotalItemsCount" options:0 context:NULL];
        [self addObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus" options:NSKeyValueObservingOptionOld context:NULL];
    }
    return self;
}

- (void)dealloc
{
    if (self._loaded)
    {
        [self cancelAllOperations];
        [self removeObserver:self forKeyPath:@"itemCollection"];
        [self removeObserver:self forKeyPath:@"itemCollection.api.currentReachabilityStatus"];
    }
}

- (void)cancelAllOperations
{
    [self._operations makeObjectsPerformSelector:@selector(cancel)];
    [self._operations removeAllObjects];
}

#pragma Table Data Source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        if (!self._loaded && self.itemCollection)
        {
            UITableViewCell <DMItemDataSourceItem> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];
            NSAssert(cell, @"DMItemTableViewDataSource: You must set DMItemTableViewDataSource.cellIdentifier to a reusable cell identifier pointing to an instance of UITableViewCell conform to the DMItemTableViewCell protocol");
            NSAssert([cell conformsToProtocol:@protocol(DMItemDataSourceItem)], @"DMItemTableViewDataSource: UITableViewCell returned by DMItemTableViewDataSource.cellIdentifier must comform to DMItemTableViewCell protocol");

            __weak DMItemTableViewDataSource *bself = self;
            DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:0 do:^(NSDictionary *data, BOOL stalled, NSError *error)
            {
                if (error)
                {
                    bself.lastError = error;
                    bself._loaded = NO;
                    [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceErrorNotification object:bself];
                }
            }];
            self._operations = [NSMutableArray array];
            if (!operation.isFinished) // The operation can be synchrone in case the itemCollection was already loaded or restored from disk
            {
                [self._operations addObject:operation];
                [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];

                // Only notify about loading if we have something to load on the network
                [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceLoadingNotification object:self];
            }

            self._loaded = YES;
        }
        return self.itemCollection.currentEstimatedTotalItemsCount;
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    __weak UITableViewCell <DMItemDataSourceItem> *cell = [tableView dequeueReusableCellWithIdentifier:self.cellIdentifier];

    DMItemOperation *previousOperation = objc_getAssociatedObject(cell, &operationKey);
    [previousOperation cancel];

    [cell prepareForLoading];

    __weak DMItemTableViewDataSource *bself = self;
    DMItemOperation *operation = [self.itemCollection withItemFields:cell.fieldsNeeded atIndex:indexPath.row do:^(NSDictionary *data, BOOL stalled, NSError *error)
    {
        __strong UITableViewCell <DMItemDataSourceItem> *scell = cell;
        if (scell)
        {
            objc_setAssociatedObject(scell, &operationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            if (error)
            {
                BOOL notify = !bself.lastError; // prevents from error storms
                bself.lastError = error;
                if (notify)
                {
                    [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceErrorNotification object:bself];
                }
            }
            else
            {
                bself.lastError = nil;
                [scell setFieldsData:data];
            }
        }
    }];

    if (!operation.isFinished)
    {
        [self._operations addObject:operation];
        [operation addObserver:self forKeyPath:@"isFinished" options:0 context:NULL];
        objc_setAssociatedObject(cell, &operationKey, operation, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return cell;
}

#pragma mark - Table Editing

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.itemCollection canEdit] && self.editable;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete && [self.itemCollection canEdit] && self.editable)
    {
        __weak DMItemTableViewDataSource *bself = self;
        [self.itemCollection removeItemAtIndex:indexPath.row done:^(NSError *error)
        {
            if (error)
            {
                bself.lastError = error;
                [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceErrorNotification object:bself];
            }
            else
            {
                bself.lastError = nil;
            }
        }];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.itemCollection canReorder] && self.reorderable;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    if ([self.itemCollection canReorder] && self.reorderable)
    {
        __weak DMItemTableViewDataSource *bself = self;
        [self.itemCollection moveItemAtIndex:fromIndexPath.row toIndex:toIndexPath.row done:^(NSError *error)
        {
            if (error)
            {
                bself.lastError = error;
                [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceErrorNotification object:bself];
            }
            else
            {
                bself.lastError = nil;
            }
        }];
    }
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"itemCollection"] && object == self)
    {
        self._loaded = NO;
        if ([self.itemCollection isKindOfClass:DMItemLocalCollection.class])
        {
            // Local connection doesn't need pre-loading of the list
            self._loaded = YES;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceUpdatedNotification object:self];
    }
    else if ([keyPath isEqualToString:@"itemCollection.currentEstimatedTotalItemsCount"] && object == self)
    {
        if (!self._loaded) return;
        [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceUpdatedNotification object:self];
    }
    else if ([keyPath isEqualToString:@"itemCollection.api.currentReachabilityStatus"] && object == self)
    {
        if (!self._loaded) return;
        DMNetworkStatus previousRechabilityStatus = ((NSNumber *)change[NSKeyValueChangeOldKey]).intValue;
        if (self.itemCollection.api.currentReachabilityStatus != DMNotReachable && previousRechabilityStatus == DMNotReachable)
        {
            // Became recheable: notify table view controller that it should reload table data
            [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceUpdatedNotification object:self];
        }
        else if (self.itemCollection.api.currentReachabilityStatus == DMNotReachable && previousRechabilityStatus != DMNotReachable)
        {
            [[NSNotificationCenter defaultCenter] postNotificationName:DMItemTableViewDataSourceOfflineNotification object:self];
        }
    }
    else if ([keyPath isEqualToString:@"isFinished"] && [object isKindOfClass:DMItemOperation.class])
    {
        if (((DMItemOperation *)object).isFinished)
        {
            [self._operations removeObject:object];
            [object removeObserver:self forKeyPath:@"isFinished"];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
