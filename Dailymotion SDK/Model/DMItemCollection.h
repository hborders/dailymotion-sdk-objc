//
//  DMItemCollection.h
//  Dailymotion SDK iOS
//
//  Created by Olivier Poitrey on 15/06/12.
//
//

#import <Foundation/Foundation.h>
#import "DMItem.h"

@interface DMItemCollection : NSObject <NSCoding>

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, strong) DMAPI *api;

/**
 * Return the current view of the object on the number of item that may be present in the list.
 *
 * This number is an estimation that may be either returned by the server or computed by the class.
 * You may use KVO on this property to know when the collection content has changed so you can refresh
 * the UI.
 */
@property (nonatomic, readonly, assign) NSUInteger currentEstimatedTotalItemsCount;

/**
 * Return an empty local collection of items
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param countLimit The maximum number of item allowed in the collection
 * @param api The DMAPI object to use to retrieve data
 */
+ (id)itemLocalConnectionWithType:(NSString *)type countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api;

/**
 * Return a local collection of items with the given ids
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param ids The list of item ids to store in the collection
 * @param countLimit The maximum number of item allowed in the collection
 * @param api The DMAPI object to use to retrieve data
 */
+ (id)itemLocalConnectionWithType:(NSString *)type withIds:(NSOrderedSet *)ids countLimit:(NSUInteger)countLimit fromAPI:(DMAPI *)api;

/**
 * Instanciate an item collection for a given object type with some optional paramters
 *
 * @param type The item type name (i.e.: video, user, playlist)
 * @param params Parameters to filter or sort the result
 * @param api The DMAPI object to use to retrieve data
 */
+ (id)itemCollectionWithType:(NSString *)type forParams:(NSDictionary *)params fromAPI:(DMAPI *)api;

/**
 * Instanciate an item collection for an item connection
 *
 * @param connection The name of the item's connection (i.e.: videos, playlists, feed)
 * @param item The item to load connection from
 * @param params Optional parameters to filter/sort the result
 * @param api The DMAPI object to use to retrieve data
 */
+ (id)itemCollectionWithConnection:(NSString *)connection forItem:(DMItem *)item withParams:(NSDictionary *)params fromAPI:(DMAPI *)api;

/**
 * Load a collection from a previously archived collection file.
 *
 * NOTE: This method is synchrone, you must not call it from main thread
 *
 * @param filePath Path to the archive file
 * @param api The DMAPI object to use with the unarchived collection
 */
+ (id)itemCollectionFromFile:(NSString *)filePath withAPI:(DMAPI *)api;

/**
 * Persists the collection with currenly cached items data to disk
 *
 * NOTE: This method is synchrone, you must not call it from main thread
 *
 * @param filePath Path to the archive file
 * @return Return YES on success
 */
- (BOOL)saveToFile:(NSString *)filePath;

/**
 * Gather the fields data for the item located at the given index in the collection.
 * @prarm fields A list of object fields names to load
 * @param index The index of the requested item in the collection
 * @param callback The block to call with resulting field data
 *
 * @return A DMItemOperation instance able to cancel the request.
 */
- (DMItemOperation *)withItemFields:(NSArray *)fields atIndex:(NSUInteger)index do:(void (^)(NSDictionary *data, BOOL stalled, NSError *error))callback;

/**
 * Flush all previously loaded cache for this collection (won't flush items cache data)
 */
- (void)flushCache;

/**
 * Indicates if the collection can be edited by adding or deleting items.
 */
- (BOOL)canEdit;

/**
 * Insert an item at the head of the collection if not already present.
 * If the collection hit the `countLimit`, the item at the end of the collection is removed.
 *
 * @param item The item to insert
 * @param callback A block called when the operation is completed
 */
- (DMItemOperation *)addItem:(DMItem *)item done:(void (^)(NSError *error))callback;

/**
 * Remove the item from the collection.
 *
 * @param item The item to remove
 */
- (DMItemOperation *)removeItem:(DMItem *)item done:(void (^)(NSError *error))callback;

/**
 * Remove the item a the given location
 *
 * @param index The index of the item to remove
 * @param callback A block called when the operation is completed
 */
- (DMItemOperation *)removeItemAtIndex:(NSUInteger)index done:(void (^)(NSError *))callback;

/**
 * Indicates if the item if the collection can be reordered using `moveItemAtIndex:toIndex:` method.
 */
- (BOOL)canReorder;

/**
 * Move an item from an index to another
 *
 * @param fromIndex Index of the item to move
 * @param toIndex Index to move the item to
 * @param callback A block called when the operation is completed
 */
- (DMItemOperation *)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex done:(void (^)(NSError *error))callback;

@end
