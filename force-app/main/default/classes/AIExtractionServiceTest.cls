@isTest
private class AIExtractionServiceTest {

    @TestSetup
    static void setupData() {
        Supplier__c supplier = new Supplier__c(Name = 'Test Supplier');
        insert supplier;

        Activity__c activity = new Activity__c(
            Name = 'Colosseum Underground Tour',
            Supplier_Name__c = supplier.Id,
            City__c = 'Rome',
            Country__c = 'Italy',
            Street__c = 'Piazza del Colosseo, 1',
            Postal_Code__c = '00184',
            Supplier_Notes__c = 'COLOSSEUM - includes underground (hypogeum) + arena floor access. small group max 15. guide is licensed historian. also includes roman forum. approx 3 hours total. lots of stairs underground NOT wheelchair accessible. guide speaks EN + DE.'
        );
        insert activity;
    }

    // --- Happy Path: valid LLM response parses and updates all fields ---
    @isTest
    static void testSuccessfulExtraction() {
        Activity__c act = [SELECT Id FROM Activity__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MistralSuccessMock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = act.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].isSuccess);
        System.assertEquals(null, results[0].errorMessage);

        Activity__c updated = [
            SELECT Category__c, Duration__c, Languages__c, Accessibility__c, Good_For__c, Listing_Summary__c
            FROM Activity__c
            WHERE Id = :act.Id
        ];

        System.assertEquals('History & Culture', updated.Category__c);
        System.assertEquals('3 hours', updated.Duration__c);
        System.assertEquals('English;German', updated.Languages__c);
        System.assertEquals('No', updated.Accessibility__c);
        System.assert(updated.Good_For__c.contains('Couples'));
        System.assert(String.isNotBlank(updated.Listing_Summary__c));
    }

    // --- LLM returns invalid JSON (markdown fences wrapping) ---
    @isTest
    static void testMarkdownWrappedResponse() {
        Activity__c act = [SELECT Id FROM Activity__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MistralMarkdownMock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = act.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);

        Activity__c updated = [SELECT Category__c FROM Activity__c WHERE Id = :act.Id];
        System.assertEquals('History & Culture', updated.Category__c);
    }

    // --- LLM returns hallucinated category → defaults to "Other" ---
    @isTest
    static void testInvalidPicklistValueDefaults() {
        Activity__c act = [SELECT Id FROM Activity__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MistralBadCategoryMock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = act.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(true, results[0].isSuccess);

        Activity__c updated = [SELECT Category__c, Accessibility__c FROM Activity__c WHERE Id = :act.Id];
        System.assertEquals('Other', updated.Category__c);
        System.assertEquals('Partial', updated.Accessibility__c);
    }

    // --- LLM returns completely broken JSON → error surfaces ---
    @isTest
    static void testMalformedJsonResponse() {
        Activity__c act = [SELECT Id FROM Activity__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MistralBrokenJsonMock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = act.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].errorMessage.contains('Failed to parse AI response'));
    }

    // --- API returns 401 Unauthorized ---
    @isTest
    static void testAuthenticationFailure() {
        Activity__c act = [SELECT Id FROM Activity__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new Mistral401Mock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = act.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].errorMessage.contains('Authentication failed'));
    }

    // --- API returns 429 Rate Limited ---
    @isTest
    static void testRateLimitError() {
        Activity__c act = [SELECT Id FROM Activity__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new Mistral429Mock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = act.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].errorMessage.contains('Rate limit exceeded'));
    }

    // --- API returns 500 Server Error ---
    @isTest
    static void testServerError() {
        Activity__c act = [SELECT Id FROM Activity__c LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new Mistral500Mock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = act.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].errorMessage.contains('server error'));
    }

    // --- Empty Supplier Notes → meaningful error ---
    @isTest
    static void testEmptySupplierNotes() {
        Supplier__c supplier = [SELECT Id FROM Supplier__c LIMIT 1];
        Activity__c emptyAct = new Activity__c(
            Name = 'Empty Notes Activity',
            Supplier_Name__c = supplier.Id,
            City__c = 'Berlin',
            Supplier_Notes__c = ''
        );
        insert emptyAct;

        Test.setMock(HttpCalloutMock.class, new MistralSuccessMock());

        AIExtractionService.ExtractionRequest req = new AIExtractionService.ExtractionRequest();
        req.activityId = emptyAct.Id;

        Test.startTest();
        List<AIExtractionService.ExtractionResult> results = AIExtractionService.enrichActivities(
            new List<AIExtractionService.ExtractionRequest>{ req }
        );
        Test.stopTest();

        System.assertEquals(false, results[0].isSuccess);
        System.assert(results[0].errorMessage.contains('Supplier Notes is empty'));
    }

    // ==============================
    // MOCK CLASSES
    // ==============================

    private class MistralSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"cmpl-123","choices":[{"message":{"role":"assistant","content":"{\\"Category\\":\\"History & Culture\\",\\"Duration\\":\\"3 hours\\",\\"Languages\\":[\\"English\\",\\"German\\"],\\"Accessibility\\":\\"No\\",\\"Good_For\\":[\\"Couples\\",\\"Solo\\"],\\"Listing_Summary\\":\\"Explore the ancient Colosseum underground chambers with exclusive access to restricted areas. A licensed historian guide brings Roman history to life in this intimate small-group experience.\\"}"}}]}');
            return res;
        }
    }

    private class MistralMarkdownMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"cmpl-456","choices":[{"message":{"role":"assistant","content":"```json\\n{\\"Category\\":\\"History & Culture\\",\\"Duration\\":\\"3 hours\\",\\"Languages\\":[\\"English\\"],\\"Accessibility\\":\\"No\\",\\"Good_For\\":[\\"Couples\\"],\\"Listing_Summary\\":\\"A guided tour of the Colosseum. See areas closed to the general public.\\"}\\n```"}}]}');
            return res;
        }
    }

    private class MistralBadCategoryMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"cmpl-789","choices":[{"message":{"role":"assistant","content":"{\\"Category\\":\\"Ancient Ruins Tour\\",\\"Duration\\":\\"3 hours\\",\\"Languages\\":[\\"English\\"],\\"Accessibility\\":\\"Mostly No\\",\\"Good_For\\":[\\"Couples\\"],\\"Listing_Summary\\":\\"Visit the Colosseum. Great experience.\\"}"}}]}');
            return res;
        }
    }

    private class MistralBrokenJsonMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"id":"cmpl-000","choices":[{"message":{"role":"assistant","content":"Sure! Here is the data: {broken json{{{"}}]}');
            return res;
        }
    }

    private class Mistral401Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"message":"Unauthorized","request_id":"abc123"}');
            return res;
        }
    }

    private class Mistral429Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(429);
            res.setBody('{"message":"Rate limit reached","request_id":"abc456"}');
            return res;
        }
    }

    private class Mistral500Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"message":"Internal server error"}');
            return res;
        }
    }
}
