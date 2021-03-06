// Written by Evan Callahan, copyright (c) 2011 Groundwire

/*******************************************************************************************************
* @author Evan Callahan
* @date 01/01/2011
* @description ONEN_DefaultAccount is a class that handles the Individual account, a catch-all Account 
* for all Contacts that aren't associated with any other Account.
*/

global virtual class ONEN_DefaultAccount {

    private static Id individualAccountId; 
    private static Id individualAcctForTests;

	/*******************************************************************************************************
	* @description String that contains the name of the Individual account.
	*/	
    global static final string individualAcctName = ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME;

	/*******************************************************************************************************
	* @description Method that returns the ID of the Individual account (aka bucket accounts).  This newer non-static method should be the one used in all new code.
	*/	
	global id getIndividualAccountIdNonStatic () {
    	
    	// tests should get a separate individual account
    	if (Test.isRunningTest()) {

    		// create a test account if we haven't already
    		if (individualAcctForTests == null) {
		    	Account[] acct = [select id from account where Name =:ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME LIMIT 1];
	            individualAcctForTests = (acct.isEmpty()) ? newAcct() : acct[0].id;     			
    		}
    		return individualAcctForTests;
    			
    	} else {
    			
			if ( individualAccountId == null ) {
	
		        // look up the stored ID if we haven't already done it
		        miscellaneousBaseSettings__c settings = miscellaneousBaseSettings__c.getInstance();
				if (settings != null && settings.Individual_Account_Id__c != null) {
					
					individualAccountId = settings.Individual_Account_Id__c;

				} else {				

		            Account[] acct = [select id from account where Name =:ONEN_Constants.INDIVIDUAL_ACCOUNT_NAME LIMIT 1];
	            	individualAccountId = (acct.isEmpty()) ? newAcct() : acct[0].id; 

				}              
	        }
	        return individualAccountId;
    	}
    }
    
	/*******************************************************************************************************
	* @description Method that returns the ID of the Individual account (aka bucket accounts).  This static method calls the newer instance method above.
	*  We would simply change this method to non-static if we could, but that is not possible for a global static method that has been included in a managed package.
	*  Any new code that needs to fetch the bucket account Id should use the instance method.
	*/	
    global static id getIndividualAccountId () {
 		ONEN_DefaultAccount defAcct = new ONEN_DefaultAccount();
 		return defAcct.getIndividualAccountIdNonStatic(); 	
    }
  
    
	/*******************************************************************************************************
	* @description Called from the Contact before trigger, sets the account of the contact to the individual (bucket) account if no other account was provided.
	*  Note that this method used to be static but was changed to an instance method.
	*/	
	global void SetIndividualAccount() {
		Id DefaultAccountId = getIndividualAccountIdNonStatic();
		if (DefaultAccountId!=null) {
			for (SObject obj: Trigger.New) {
				Contact c = (Contact)obj;
				//if no AccountId was supplied on the inserted or updated contact, use the default one
				if (c.AccountId == NULL) {				
					//set the Account Id value to the default
					c.AccountId = DefaultAccountId;
				} 
			}
		}		
	}


	/*******************************************************************************************************
	* @description Called from the Account before trigger, prevents the individual (bucket) account from being deleted, renamed, or duplicated.
	*  Note that this method used to be static but was changed to an instance method.
	*/	
	global void ProtectIndividualAccount() {
		string indName = ONEN_DefaultAccount.individualAcctName;
	
		// don't allow the default account to be deleted.
		if (trigger.isDelete) {
			for (SObject obj  : trigger.old ) {
				Account thisAccount = (Account)obj;
				if ( thisAccount.Id == getIndividualAccountIdNonStatic() ) {
					thisAccount.addError ('You cannot delete the ' + indName + ' organization.');
				}
			}
		}
		
		// for updates, check renames
		if (trigger.isUpdate) {
			Account[] AcctsRenamedTo = new Account[0];
			Account[] AcctsRenamedFrom = new Account[0];
			
			for (Sobject obj : trigger.new) {
				Account Acct = (Account)obj;
				Account oldAcct = (Account)trigger.oldmap.get(Acct.Id);
				
				// check which are renamed to or from the ind acct
				if (Acct.Name==indName && Acct.Name!=oldAcct.Name) {
					AcctsRenamedTo.add(Acct);
				}
				if (oldAcct.Name==indName && Acct.Name!=oldAcct.Name) {
					AcctsRenamedFrom.add(Acct);
				}
			}
			
			integer count;
			if (AcctsRenamedTo.size()>0 || AcctsRenamedFrom.size()>0) {
				count = ONEN_AccountMaintenance.getIndAcctCount(indName);
				//system.debug ('protectindacct vars  count:' + count + ' acctsrenamedfrom:' + AcctsRenamedFrom.size() + '  acctsrenamedto:' + AcctsRenamedTo.size() );
				
				// if there's already one or more named Ind, reject any renamed to that
				if (AcctsRenamedTo.size()>0 && count>0) {
					for (Account Acct : AcctsRenamedTo) {
						Acct.addError ('There is already an Organization named ' + indName + '.  You cannot have 2 Organizations with that name.');
					}
				}		
				
				// reject renaming Ind acct unless it won't leave us with exactly one
				if ( (count + AcctsRenamedTo.size() - AcctsRenamedFrom.size() ) <> 1) {
					for (Account Acct : AcctsRenamedFrom) {
						Acct.addError ('You cannot change the name of the this Organization because it is required for proper function of the database.');
					}
				}
			}		
		}
		
		// for insert, just make sure there isn't a duplicate (either with existing recs or within set)
		if (trigger.isInsert) {
			Account[] newIndAccts = new Account[0];
			for (SObject obj : trigger.new) {
				Account acct = (Account)obj;
				if (acct.Name==indName) {
					newIndAccts.add (acct);
				}
			}
			if (newIndAccts.size()>0) {
				integer count = ONEN_AccountMaintenance.getIndAcctCount(indName);
				if (count>0 || newIndAccts.size()>1) {
					for (Account acct : newIndAccts) {
						acct.addError('You cannot add a duplicate ' + indName + ' organization.');
					}
				}
			}
		}		
	}    
    
    
	/*******************************************************************************************************
	* @description This method is only used internally in this class, but is global so that it can be overridden (for dupeblocker compatibility, etc.)
	*  It simply creates a new account with the proper name to be used as bucket account either in production or in a test.
	*  Note that this method used to be static but was changed to an instance method.
	*/	
    global virtual id newAcct() {
    	account a = new Account( name = individualAcctName );
	    insert a;
    	return a.id;
    }
    
    // DEPRECATED METHOD
    //public static Id setIndividualAccountForTests(String accountName) { return GetIndividualAccountId(); }

//////////////////////////////////////////////////////////////////////////////////////////////
// TEST CODE
//////////////////////////////////////////////////////////////////////////////////////////////

	static testMethod void TestAccountAdd() {	
				 
		Contact firstContact = new Contact (
			FirstName='Joe',
			LastName='Johanssen_for_tests'			
		);
		insert firstContact;
		
		//the default Account should have been added to the contact
		Contact createdFirstContact = [select Account.Name from Contact where Id =:firstContact.id];
		System.assertEquals('IndividualAccountForTests', createdFirstContact.Account.Name);
	}
	

	static testmethod void TestIndividualAccountDelete () {
		
		Account IndAcct = [SELECT id, Name FROM Account WHERE id =: ONEN_DefaultAccount.getIndividualAccountId() LIMIT 1];

		// first test account can't be deleted		
		string error;
		try {
			delete IndAcct;	
		} catch ( DmlException e ) {
			error = e.getMessage();
			system.debug (error);
		}
		System.Assert ( error.contains('cannot delete') );

		// next test can't create a duplicate via insertion
		Account dupAcct = new Account (	Name = indAcct.name );
		try {
			insert dupAcct;
		} catch  ( DmlException e ) {
			error = e.getMessage();
		}		
		System.Assert ( error.contains('duplicate') );
		
		// finally test can't create dup via rename of other acct
		dupAcct.Name = 'Some Other Name';
		insert dupAcct;
		dupAcct.Name = indAcct.name;
		try {
			update dupAcct;
		} catch  ( DmlException e ) {
			error = e.getMessage();
		}		
		System.Assert ( error.contains('Organization') );

		// next test can't rename it to something else		
		IndAcct.Name = 'Renamed Name';
		try {
			update IndAcct;
		} catch  ( DmlException e ) {
			error = e.getMessage();
		}
		System.Assert ( error.contains('Organization') );		
	}
	
}