public with sharing class ActivityMapController {

    private static final Integer MAX_RESULTS = 50;

    public class ActivityWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String category;
        @AuraEnabled public String city;
        @AuraEnabled public String street;
        @AuraEnabled public String country;
        @AuraEnabled public Decimal latitude;
        @AuraEnabled public Decimal longitude;
        @AuraEnabled public String duration;
        @AuraEnabled public String accessibility;
        @AuraEnabled public String goodFor;
        @AuraEnabled public String listingSummary;
    }

    public class SearchResult {
        @AuraEnabled public List<ActivityWrapper> activities;
        @AuraEnabled public Integer totalCount;
    }

    @AuraEnabled(cacheable=true)
    public static SearchResult searchByRadius(Decimal lat, Decimal lng, Decimal radiusKm, String category, String goodFor) {
        if (lat == null || lng == null || radiusKm == null) {
            SearchResult empty = new SearchResult();
            empty.activities = new List<ActivityWrapper>();
            empty.totalCount = 0;
            return empty;
        }

        String query = 'SELECT Id, Name, Category__c, City__c, Street__c, Country__c, '
            + 'Meeting_Point__Latitude__s, Meeting_Point__Longitude__s, '
            + 'Duration__c, Accessibility__c, Good_For__c, Listing_Summary__c '
            + 'FROM Activity__c '
            + 'WHERE Meeting_Point__Latitude__s != NULL '
            + 'AND DISTANCE(Meeting_Point__c, GEOLOCATION(:lat, :lng), \'km\') < :radiusKm ';

        if (String.isNotBlank(category) && category != 'All') {
            query += 'AND Category__c = :category ';
        }

        if (String.isNotBlank(goodFor) && goodFor != 'All') {
            query += 'AND Good_For__c INCLUDES (:goodFor) ';
        }

        query += 'ORDER BY DISTANCE(Meeting_Point__c, GEOLOCATION(:lat, :lng), \'km\') ASC '
            + 'LIMIT :MAX_RESULTS';

        List<Activity__c> records = Database.query(query);

        Integer totalCount = countTotalResults(lat, lng, radiusKm, category, goodFor);

        SearchResult result = new SearchResult();
        result.activities = wrapActivities(records);
        result.totalCount = totalCount;
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static SearchResult searchByCity(String city, String category, String goodFor) {
        if (String.isBlank(city)) {
            SearchResult empty = new SearchResult();
            empty.activities = new List<ActivityWrapper>();
            empty.totalCount = 0;
            return empty;
        }

        String cityFilter = '%' + String.escapeSingleQuotes(city.trim()) + '%';

        String query = 'SELECT Id, Name, Category__c, City__c, Street__c, Country__c, '
            + 'Meeting_Point__Latitude__s, Meeting_Point__Longitude__s, '
            + 'Duration__c, Accessibility__c, Good_For__c, Listing_Summary__c '
            + 'FROM Activity__c '
            + 'WHERE Meeting_Point__Latitude__s != NULL '
            + 'AND City__c LIKE :cityFilter ';

        if (String.isNotBlank(category) && category != 'All') {
            query += 'AND Category__c = :category ';
        }

        if (String.isNotBlank(goodFor) && goodFor != 'All') {
            query += 'AND Good_For__c INCLUDES (:goodFor) ';
        }

        query += 'ORDER BY Name ASC LIMIT :MAX_RESULTS';

        List<Activity__c> records = Database.query(query);

        SearchResult result = new SearchResult();
        result.activities = wrapActivities(records);
        result.totalCount = records.size();
        return result;
    }

    private static List<ActivityWrapper> wrapActivities(List<Activity__c> records) {
        List<ActivityWrapper> wrapped = new List<ActivityWrapper>();
        for (Activity__c act : records) {
            ActivityWrapper w = new ActivityWrapper();
            w.id = act.Id;
            w.name = act.Name;
            w.category = act.Category__c;
            w.city = act.City__c;
            w.street = act.Street__c;
            w.country = act.Country__c;
            w.latitude = act.Meeting_Point__Latitude__s;
            w.longitude = act.Meeting_Point__Longitude__s;
            w.duration = act.Duration__c;
            w.accessibility = act.Accessibility__c;
            w.goodFor = act.Good_For__c;
            w.listingSummary = act.Listing_Summary__c;
            wrapped.add(w);
        }
        return wrapped;
    }

    private static Integer countTotalResults(Decimal lat, Decimal lng, Decimal radiusKm, String category, String goodFor) {
        String query = 'SELECT COUNT() FROM Activity__c '
            + 'WHERE Meeting_Point__Latitude__s != NULL '
            + 'AND DISTANCE(Meeting_Point__c, GEOLOCATION(:lat, :lng), \'km\') < :radiusKm ';

        if (String.isNotBlank(category) && category != 'All') {
            query += 'AND Category__c = :category ';
        }

        if (String.isNotBlank(goodFor) && goodFor != 'All') {
            query += 'AND Good_For__c INCLUDES (:goodFor) ';
        }

        return Database.countQuery(query);
    }
}
