public class ActivityTriggerHandler {
    
    public static void handleAfterSave(List<Activity__c> newRecords, Map<Id, Activity__c> oldMap, Boolean isInsert) {
        List<Id> activitiesToGeocode = new List<Id>();
        
        for (Activity__c act : newRecords) {
            Boolean addressExists = String.isNotBlank(act.Street__c) || String.isNotBlank(act.City__c);
            Boolean addressChanged = false;
            
            if (!isInsert) {
                Activity__c oldAct = oldMap.get(act.Id);
                // Check if any part of the address was modified
                if (act.Street__c != oldAct.Street__c || 
                    act.City__c != oldAct.City__c || 
                    act.Postal_Code__c != oldAct.Postal_Code__c || 
                    act.Country__c != oldAct.Country__c) {
                    addressChanged = true;
                }
            }
            
            // CRITICAL JUDGMENT CALL: 
            // 1. On insert: If there is an address but NO coordinates yet.
            // 2. On update: If the address changed (we need to wipe and fetch new coordinates).
            if (addressExists && (isInsert || addressChanged)) {
                // If coordinates are already provided manually or by the Queueable's update, skip to prevent infinite loops.
                if (act.Meeting_Point__Latitude__s == null || addressChanged) {
                    activitiesToGeocode.add(act.Id);
                }
            }
        }
        
        // Enqueue the job if we have records that need geocoding
        if (!activitiesToGeocode.isEmpty()) {
            System.enqueueJob(new ActivityGeocodingQueueable(activitiesToGeocode));
        }
    }
}