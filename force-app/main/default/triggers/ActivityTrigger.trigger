trigger ActivityTrigger on Activity__c (after insert, after update) {
    if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)) {
        ActivityTriggerHandler.handleAfterSave(Trigger.new, Trigger.oldMap, Trigger.isInsert);
    }
}