@isTest
private class ActivityGeocodingTest {
    @isTest
    static void testGeocodingSuccess() {
        // Setup mock
        Test.setMock(HttpCalloutMock.class, new OpenCageHTTPMock());
        
        // We cannot insert Custom Metadata in test classes without complex mocking, 
        // but assuming the record exists in the org, the query will see it. 
        // For a totally isolated test, consider Dependency Injection for the API Key.
 		Supplier__c supplier = new Supplier__c(Name = 'Test Supplier');
        insert supplier;
        Activity__c testAct = new Activity__c(
            Name = 'Test Tour',
            Street__c = 'Piazza del Colosseo, 1',
            City__c = 'Rome',
            Country__c = 'Italy',
            Supplier_Name__c = supplier.Id
        );
        insert testAct;

        Test.startTest();
        // Manually enqueue to test the exact logic
        System.enqueueJob(new ActivityGeocodingQueueable(new List<Id>{testAct.Id}));
        Test.stopTest();

        // Meaningful Assertion: Verify the exact Lat/Long from the mock was applied
        Activity__c updatedAct = [SELECT Meeting_Point__Latitude__s, Meeting_Point__Longitude__s FROM Activity__c WHERE Id = :testAct.Id];
        System.assertEquals(41.8902, updatedAct.Meeting_Point__Latitude__s, 'Latitude did not map correctly from JSON.');
        System.assertEquals(12.4922, updatedAct.Meeting_Point__Longitude__s, 'Longitude did not map correctly from JSON.');
    }
}