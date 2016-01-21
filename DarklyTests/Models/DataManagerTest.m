//
//  Copyright © 2015 Catamorphic Co. All rights reserved.
//

#import "DarklyXCTestCase.h"
#import <BlocksKit/BlocksKit.h>
#import "LDFlagConfig.h"
#import <Blockskit/BlocksKit.h>
#import "LDFeatureFlag.h"
#import "LDDataManager.h"
#import "LDUser.h"
#import "LDFlagConfig.h"
#import "LDEvent.h"
#import "LDClient.h"
#import <OCMock.h>
#import "NSArray+UnitTests.h"
#import "UserEntity.h"

@interface DataManagerTest : DarklyXCTestCase
@property (nonatomic) id clientMock;
@property (nonnull) LDUser *user;

@end

@implementation DataManagerTest
@synthesize clientMock;
@synthesize user;

- (void)setUp {
    [super setUp];
    user = [[LDUser alloc] init];
    user.firstName = @"Bob";
    user.lastName = @"Giffy";
    user.email = @"bob@gmail.com";
    user.updatedAt = [NSDate date];
    
    
    LDClient *client = [LDClient sharedInstance];
    clientMock = OCMPartialMock(client);
    OCMStub([clientMock user]).andReturn(user);
    
    LDFlagConfig *config = [[LDFlagConfig alloc] init];
    config.featuresJsonDictionary = [NSDictionary dictionaryWithObjects:@[@{@"value": @YES}, @{@"value": @NO}]
                                                                forKeys: @[@"ipaduser", @"iosuser"]];
    user.config = config;
}

- (void)tearDown {
    [clientMock stopMocking];
    [super tearDown];
}

- (void)testisFlagOnForKey {
    LDClient *client = [LDClient sharedInstance];
    LDUser * theUser = client.user;
    
    BOOL ipaduserFlag = [theUser isFlagOn: @"ipaduser"];
    BOOL iosuserFlag = [theUser isFlagOn: @"iosuser"];
    
    XCTAssertFalse(iosuserFlag);
    XCTAssertTrue(ipaduserFlag);
    
    NSLog(@"Stop");
}

-(void)testCreateFeatureEvent {
    [[LDDataManager sharedManager] createFeatureEvent:@"afeaturekey" keyValue:NO defaultKeyValue:NO];
    
    LDEvent *lastEvent = [self lastCreatedEvent];
    
    XCTAssertEqualObjects(lastEvent.key, @"afeaturekey");
}

-(LDEvent *)lastCreatedEvent {
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:[NSEntityDescription entityForName:@"EventEntity"
                                   inManagedObjectContext: [self.dataManagerMock managedObjectContext]]];
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"key = 'afeaturekey'"];
    request.predicate = predicate;
    request.fetchLimit = 1;
    
    NSError *error = nil;
    NSManagedObject *eventMo = [[[self.dataManagerMock managedObjectContext] executeFetchRequest:request                                                                          error:&error] objectAtIndex:0];
    
    return [MTLManagedObjectAdapter modelOfClass:[LDEvent class]
                               fromManagedObject: eventMo
                                           error: &error];
    
    
}

-(void)testAllEvents {
    LDEvent *event1 = [[LDEvent alloc] init];
    LDEvent *event2 = [[LDEvent alloc] init];
    
    event1.key = @"foo";
    event2.key = @"fi";
    
    [self.dataManagerMock createCustomEvent:@"foo" withCustomValuesDictionary:nil];
    [self.dataManagerMock createCustomEvent:@"fi" withCustomValuesDictionary:nil];
    
    NSArray *eventArray = [self.dataManagerMock allEvents];
    NSArray *eventKeys = [eventArray bk_map:^id(LDEvent *event) {
        return event.key;
    }];
    XCTAssertTrue([eventKeys containsObject:event1.key]);
    XCTAssertTrue([eventKeys containsObject:event2.key]);
}

-(void)testCreateCustomEvent {
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    
    LDEvent *event = [self.dataManagerMock allEvents].firstObject;

    XCTAssertTrue([[event.data allKeys] containsObject: @"carrot"]);
    XCTAssertTrue([event.key isEqualToString: @"aKey"]);    
}

-(void)testAllEventsJsonData {
    LDEvent *event1 = [[LDEvent alloc] init];
    LDEvent *event2 = [[LDEvent alloc] init];
    
    event1.key = @"foo";
    event2.key = @"fi";
    
    LDClient *client = [LDClient sharedInstance];
    LDUserModel *theUser = client.user;
    
    [self.dataManagerMock createCustomEvent:@"foo" withCustomValuesDictionary:nil];
    [self.dataManagerMock createCustomEvent:@"fi" withCustomValuesDictionary:nil];
    
    NSData *eventData = [self.dataManagerMock allEventsJsonData];
    
    NSArray *eventsArray = [NSJSONSerialization JSONObjectWithData:eventData                                                        options:kNilOptions error:nil];

    NSArray *allValues = [eventsArray bk_map:^id(NSDictionary *eventDict) {
        return [eventDict allValues];
    }];
    
    allValues = [allValues flatten];
    
    XCTAssertTrue([allValues containsObject: @"foo"]);
    XCTAssertTrue([allValues containsObject: @"fi"]);
    
    NSDictionary *userDict = (NSDictionary *)eventsArray.firstObject[@"user"];
    NSString *eventUserKey = [userDict objectForKey:@"email"];

    XCTAssertTrue([eventUserKey isEqualToString: theUser.email]);    
}


-(void)testFindOrCreateUser {
    NSString *userKey = @"thisisgus";
    LDUser *aUser = [[LDUser alloc] init];
    aUser.key = userKey;
    aUser.email = @"gus@anemail.com";
    aUser.updatedAt = [NSDate date];
    aUser.config = user.config;
        
    XCTAssertNotNil(aUser);
    
    LDUser *foundAgainUser = [[LDDataManager sharedManager] findUserWithkey: userKey];
    
    XCTAssertNotNil(foundAgainUser);
    XCTAssertEqual(aUser.email, foundAgainUser.email);
}

-(void) testPurgeUsers {
    NSDate *now = [NSDate date];
    
    for(int index = 0; index < kUserCacheSize + 3; index++) {
        LDUser *aUser = [[LDUser alloc] init];
        aUser.key = [NSString stringWithFormat: @"gus%d", index];
        aUser.email = @"gus@anemail.com";
        
        NSTimeInterval secondsInXHours = index * 60 * 60;
        NSDate *dateInXHours = [now dateByAddingTimeInterval:secondsInXHours];
        aUser.updatedAt = dateInXHours;
    
        NSError *error;
    }
    
    NSString *userKey = @"gus0";

    // TODO add test for removing users
}

-(void)testCreateEventAfterCapacityReached{
    LDConfigBuilder *builder = [[LDConfigBuilder alloc] init];
    builder = [builder withCapacity: 2];
    builder = [builder withApiKey: @"AnApiKey"];
    LDConfig *config = [builder build];
    
    OCMStub([clientMock ldConfig]).andReturn(config);
    
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [self.dataManagerMock createCustomEvent:@"aKey" withCustomValuesDictionary: @{@"carrot": @"cake"}];
    [self.dataManagerMock createFeatureEvent: @"anotherKet" keyValue: YES defaultKeyValue: NO];
    
    
    // TODO ADD TEST FOR checking if events are not created after capacity reached
}

@end
