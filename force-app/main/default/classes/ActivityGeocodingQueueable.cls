/**
 * ActivityGeocodingQueueable
 * Queueable Apex class that performs geocoding for Activity__c records using the OpenCage API.
 * Allows callouts and updates Activity__c records with latitude and longitude values.
 */
public Without Sharing class ActivityGeocodingQueueable implements Queueable, Database.AllowsCallouts {
    private List<Id> activityIds;

    /**
     * Constructor for the queueable that accepts a list of Activity record Ids to process.
     * @param activityIds List<Id> - Ids of Activity__c records to geocode
     */
    public ActivityGeocodingQueueable(List<Id> activityIds) {
        this.activityIds = activityIds;
    }

    public void execute(QueueableContext context) {
        // Query the records
        List<Activity__c> activities = [
            SELECT Id, Street__c, City__c, Country__c, Postal_Code__c 
            FROM Activity__c 
            WHERE Id IN :activityIds
        ];

        // Fetch API Key from Custom Metadata
        Integration_Setting__mdt settings = Integration_Setting__mdt.getInstance('OpenCage');
        if (settings == null || String.isBlank(settings.API_Key__c)) {
            System.debug('Error: OpenCage API Key not found.');
            return;
        }

        List<Activity__c> recordsToUpdate = new List<Activity__c>();

        // We can make up to 100 callouts per transaction.
        for (Activity__c act : activities) {
            String fullAddress = String.format('{0}, {1}, {2}, {3}', new List<String>{
                act.Street__c != null ? act.Street__c : '',
                act.City__c != null ? act.City__c : '',
                act.Postal_Code__c != null ? act.Postal_Code__c : '',
                act.Country__c != null ? act.Country__c : ''
            }).replaceAll(' ,', '').trim(); // Clean up empty fields

            if (String.isBlank(fullAddress)){
                continue;
            } 

            String encodedAddress = EncodingUtil.urlEncode(fullAddress, 'UTF-8');
            String endpoint = 'callout:OpenCage_API/geocode/v1/json?q=' + encodedAddress + '&key=' + settings.API_Key__c + '&limit=1';

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(10000); // 10 seconds

            Http http = new Http();
            try {
                HttpResponse res = http.send(req);
                if (res.getStatusCode() == 200) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> results = (List<Object>) responseMap.get('results');
                    
                    if (!results.isEmpty()) {
                        Map<String, Object> firstResult = (Map<String, Object>) results[0];
                        Map<String, Object> geometry = (Map<String, Object>) firstResult.get('geometry');
                        
                        act.Meeting_Point__Latitude__s = (Decimal) geometry.get('lat');
                        act.Meeting_Point__Longitude__s = (Decimal) geometry.get('lng');
                        recordsToUpdate.add(act);
                    }
                } else {
                    System.debug('Callout failed with status: ' + res.getStatusCode() + ' body: ' + res.getBody());
                }
            } catch (Exception e) {
                System.debug('Exception during geocoding: ' + e.getMessage());
            }
        }

        if (!recordsToUpdate.isEmpty()) {
            update recordsToUpdate;
        }
    }
}