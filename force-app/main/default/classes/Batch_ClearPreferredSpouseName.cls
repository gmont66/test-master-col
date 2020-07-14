/**
 * Check for Ex-Spouse relationships and clear Preferred Spouse name on Constituent
 * 
 * @author              Gil Montero
 * @version             1.0
 * @since               July 08 2020
 */ 
global without sharing class Batch_ClearPreferredSpouseName implements Database.Batchable<sObject>, Database.Stateful {    
    
	public String emailAddress = '';
	public String emailMessage = '';
	public Integer updateCount = 0;
    public String initialSOQL = '';
    public Boolean isInitial = false;
    public String query = '';
    
    global Batch_ClearPreferredSpouseName(String batchType){

		initialSOQL = 'select Contact__c, Related_Contact__c, Contact__r.Preferred_Spouse_Name__c, Related_Contact__r.Preferred_Spouse_Name__c from Relationship__c ';
		initialSOQL = initialSOQL + ' where Related_Role__c in (\'Ex-Spouse\', \'Ex-Partner\', \'Ward\', \'Widow\')';
		initialSOQL = initialSOQL + ' AND (Contact__r.Preferred_Spouse_Name__c != null OR Related_Contact__r.Preferred_Spouse_Name__c != null)';

        if (batchType != null && batchType != '' && batchType.trim().toLowerCase() == 'initial') {
			query = initialSOQL;
			isInitial = true;
		}
		else if (batchType != null && batchType != '' && batchType.trim().toLowerCase() == 'daily') {
			query  = initialSOQL + ' AND lastModifiedDate = today';
		}
		else if (batchType != null && batchType != '' && batchType.trim().toLowerCase() != null) {
			query = initialSOQL + batchType.trim();
		}

		Date today = date.Today();

		if (Test.isRunningTest()) {
			today = Date.newInstance(2018, 10, 3);
		}

    }

    global Database.Querylocator start(Database.BatchableContext bc){
        // query for relationships that are Ex-Spouse/Ex-Partner/Widow/Ward
		if (query == null) {
			system.abortJob(bc.getJobId());
			return null;
		}
        return Database.getQueryLocator(query); 
    }
    
    global void execute(Database.BatchableContext bc, list<Relationship__c> relationships){

		//
		//  build a set with each Contact and Related Contact from the query
		//		John
		//		Mary
		//		Paul
		//		Ana
        // 	not all of those contacts will be updated, because some will already have remarried and the Preferred Spouse is correct

		set<Id> constituentsWithExSpouse = new set<Id>();
		
		for (Relationship__c relationship : relationships){
			// check if the contact's Preferred Spouse is still pointing to the ex-spouse
			if (relationship.Contact__r.Preferred_Spouse_Name__c == relationship.Related_Contact__c){
				constituentsWithExSpouse.add(relationship.Contact__c);
			}

			// check if the related contact's Preferred Spouse is still pointing to the ex-spouse
			if (relationship.Related_Contact__r.Preferred_Spouse_Name__c == relationship.Contact__c){
				constituentsWithExSpouse.add(relationship.Related_Contact__c);
			}
		}

		// build list of Constituents whose Ids are in the set 
		// these are the ones that are wrong and need to be updated

		List<Contact> constituentsToBeUpd = [select Id from Contact where Id in :constituentsWithExSpouse];

        // build list to store the updates on the Constituents obj
        List<Contact> constituentUpdates = new List<Contact>();

        for (Contact constituent : constituentsToBeUpd){
            constituentUpdates.add(new Contact(Id = constituent.Id, Preferred_Spouse_Name__c = null));
		}

		update constituentUpdates;

    	
    }
    
    global void finish(Database.BatchableContext bc) {
    }

}