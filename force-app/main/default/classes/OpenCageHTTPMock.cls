@isTest
public with sharing class OpenCageHTTPMock implements HttpCalloutMock {
   
   public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        
        // Ensure we are testing the correct endpoint (Named Credential keeps the callout: prefix)
        System.assert(req.getEndpoint().contains('OpenCage_API') || req.getEndpoint().contains('opencagedata.com'), 'Endpoint must point to OpenCage');
        
        String jsonBody = '{"results": [{"geometry": {"lat": 41.8902, "lng": 12.4922}}]}';
        res.setBody(jsonBody);
        res.setStatusCode(200);
        return res;
    }
}