@isTest
private class ActivityMapControllerTest {

    @TestSetup
    static void setupData() {
        Supplier__c supplier = new Supplier__c(Name = 'Test Supplier');
        insert supplier;

        List<Activity__c> activities = new List<Activity__c>();

        activities.add(new Activity__c(
            Name = 'Eiffel Tower Tour',
            Supplier_Name__c = supplier.Id,
            City__c = 'Paris',
            Country__c = 'France',
            Street__c = 'Champ de Mars',
            Category__c = 'Sightseeing',
            Good_For__c = 'Couples;Solo',
            Meeting_Point__Latitude__s = 48.8584,
            Meeting_Point__Longitude__s = 2.2945
        ));

        activities.add(new Activity__c(
            Name = 'Colosseum Underground Tour',
            Supplier_Name__c = supplier.Id,
            City__c = 'Rome',
            Country__c = 'Italy',
            Street__c = 'Piazza del Colosseo',
            Category__c = 'History & Culture',
            Good_For__c = 'Couples;Groups',
            Meeting_Point__Latitude__s = 41.8902,
            Meeting_Point__Longitude__s = 12.4922
        ));

        activities.add(new Activity__c(
            Name = 'Seine River Cruise',
            Supplier_Name__c = supplier.Id,
            City__c = 'Paris',
            Country__c = 'France',
            Street__c = 'Port de la Bourdonnais',
            Category__c = 'Sightseeing',
            Good_For__c = 'Families;Couples',
            Meeting_Point__Latitude__s = 48.8600,
            Meeting_Point__Longitude__s = 2.2930
        ));

        insert activities;
    }

    @isTest
    static void testSearchByRadius_ReturnsNearbyActivities() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByRadius(
            48.8584, 2.2945, 5.0, 'All', 'All'
        );

        System.assertEquals(2, result.activities.size(), 'Should find 2 Paris activities within 5km');
        System.assertEquals(2, result.totalCount);

        for (ActivityMapController.ActivityWrapper w : result.activities) {
            System.assertEquals('Paris', w.city);
            System.assertNotEquals(null, w.latitude);
            System.assertNotEquals(null, w.longitude);
        }
    }

    @isTest
    static void testSearchByRadius_CategoryFilter() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByRadius(
            48.8584, 2.2945, 5.0, 'History & Culture', 'All'
        );

        System.assertEquals(0, result.activities.size(), 'No History & Culture activities in Paris radius');
    }

    @isTest
    static void testSearchByRadius_GoodForFilter() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByRadius(
            48.8584, 2.2945, 5.0, 'All', 'Families'
        );

        System.assertEquals(1, result.activities.size(), 'Only Seine River Cruise is good for Families');
        System.assertEquals('Seine River Cruise', result.activities[0].name);
    }

    @isTest
    static void testSearchByRadius_NullParams_ReturnsEmpty() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByRadius(
            null, null, null, null, null
        );

        System.assertEquals(0, result.activities.size());
        System.assertEquals(0, result.totalCount);
    }

    @isTest
    static void testSearchByCity_ReturnsCityActivities() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByCity(
            'Paris', 'All', 'All'
        );

        System.assertEquals(2, result.activities.size(), 'Should find 2 activities in Paris');
    }

    @isTest
    static void testSearchByCity_CategoryFilter() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByCity(
            'Rome', 'History & Culture', 'All'
        );

        System.assertEquals(1, result.activities.size());
        System.assertEquals('Colosseum Underground Tour', result.activities[0].name);
    }

    @isTest
    static void testSearchByCity_EmptyCity_ReturnsEmpty() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByCity(
            '', 'All', 'All'
        );

        System.assertEquals(0, result.activities.size());
    }

    @isTest
    static void testSearchByCity_NoMatch_ReturnsEmpty() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByCity(
            'Tokyo', 'All', 'All'
        );

        System.assertEquals(0, result.activities.size());
    }

    @isTest
    static void testWrapperFieldsPopulated() {
        ActivityMapController.SearchResult result = ActivityMapController.searchByCity(
            'Rome', 'All', 'All'
        );

        System.assertEquals(1, result.activities.size());
        ActivityMapController.ActivityWrapper w = result.activities[0];
        System.assertEquals('Colosseum Underground Tour', w.name);
        System.assertEquals('History & Culture', w.category);
        System.assertEquals('Rome', w.city);
        System.assertEquals('Italy', w.country);
        System.assertEquals(41.8902, w.latitude);
        System.assertEquals(12.4922, w.longitude);
        System.assert(w.goodFor.contains('Couples'));
    }
}
