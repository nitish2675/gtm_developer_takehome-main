public class GetLLMResponse {

    public class LLMException extends Exception {}

    public static void processActivity(Id activityId) {
        Integration_Setting__mdt config = Integration_Setting__mdt.getInstance('MistralKey');
        if (config == null || String.isBlank(config.API_Key__c)) {
            throw new LLMException('Integration Setting "MistralKey" is missing or has no API key configured. Contact your admin.');
        }

        List<Activity__c> activities = [
            SELECT Id, Name, City__c, Supplier_Notes__c
            FROM Activity__c
            WHERE Id = :activityId
            LIMIT 1
        ];

        if (activities.isEmpty()) {
            throw new LLMException('Activity record not found: ' + activityId);
        }

        Activity__c act = activities[0];

        if (String.isBlank(act.Supplier_Notes__c)) {
            throw new LLMException('Supplier Notes is empty — nothing to extract from.');
        }

        String llmContent = callMistralLLM(act, config.API_Key__c);
        parseAndUpdateActivity(act.Id, llmContent);
    }

    private static String callMistralLLM(Activity__c act, String apiKey) {
        String systemPrompt = '''
			 You are a structured data extraction engine. Your ONLY job is to extract facts from supplier notes. 
             STRICT RULES: 
             1. Output ONLY a single JSON object. No markdown, no explanation, no text before or after. 
             2. Extract ONLY what is explicitly stated or directly implied in the notes. NEVER invent, assume, or hallucinate information. 
             3. If a field cannot be determined from the notes, use the default value specified below. 
             4. Every string value MUST be copied exactly from the allowed values list — no paraphrasing, no synonyms. 
                 
             JSON SCHEMA (follow exactly): 
             "Category" — MUST be exactly one of these strings: "Sightseeing", "History & Culture", "Food & Drink", "Outdoor & Adventure", "Family", "Nightlife", "Other". 
             Pick the BEST match based on the primary activity type. Default: "Other". 
             "Duration" — Extract the time mentioned in notes as a human-readable string (e.g. "2 hours", "1.5 hours", "4-5 hours"). If not mentioned, use "Not specified". 
             "Languages" — Array of strings. ONLY use values from: ["English", "Spanish", "French", "German", "Italian", "Other"]. 
             Map: "EN"="English", "DE"="German", "FR"="French", "ES"="Spanish", "IT"="Italian". If no language mentioned, return ["English"]. 
             "Accessibility" — MUST be exactly one of: "Yes", "No", "Partial". 
             "Yes"=fully wheelchair accessible. "No"=not accessible (stairs, no lift). "Partial"=some areas accessible. Default: "Partial". 
             "Good_For" — Array of strings. ONLY use values from: ["Families", "Couples", "Solo", "Groups"]. 
             Include ONLY audiences explicitly mentioned or strongly implied. If unclear, return ["Couples", "Solo"]. 
             "Listing_Summary" — Write exactly 2 sentences. Sentence 1: what the experience is. Sentence 2: what makes it special. 
             Tone: professional, inviting, factual. Do NOT invent features not in the notes. 
             EXAMPLE OUTPUT: 
             {"Category":"History & Culture","Duration":"3 hours","Languages":["English","German"],"Accessibility":"No","Good_For":["Couples","Solo"],"Listing_Summary":"Explore the ancient underground chambers with a licensed historian guide. Skip the public queues with exclusive access to restricted areas."}
             ''';

        String userPrompt = 'Title: ' + act.Name + '\nCity: ' + act.City__c + '\nSupplier Notes: ' + act.Supplier_Notes__c;

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Mistral_AI_API/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);

        Map<String, Object> requestBody = new Map<String, Object>{
            'model' => 'mistral-small-latest',
            'response_format' => new Map<String, String>{'type' => 'json_object'},
            'messages' => new List<Map<String, String>>{
                new Map<String, String>{'role' => 'system', 'content' => systemPrompt},
                new Map<String, String>{'role' => 'user', 'content' => userPrompt}
            },
            'temperature' => 0.1
        };

        req.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        HttpResponse res;

        try {
            res = http.send(req);
        } catch (System.CalloutException e) {
            throw new LLMException('Network error calling Mistral API: ' + e.getMessage());
        }

        Integer statusCode = res.getStatusCode();

        if (statusCode == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) responseMap.get('choices');
            if (choices == null || choices.isEmpty()) {
                throw new LLMException('Mistral returned an empty response — no choices in payload.');
            }
            Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
            Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
            String content = (String) message.get('content');
            if (String.isBlank(content)) {
                throw new LLMException('Mistral returned an empty message content.');
            }
            return content;
        } else if (statusCode == 401) {
            throw new LLMException('Authentication failed (401). Check that the API key in Integration_Setting__mdt "MistralKey" is valid.');
        } else if (statusCode == 429) {
            throw new LLMException('Rate limit exceeded (429). Please wait a moment and try again.');
        } else if (statusCode >= 500) {
            throw new LLMException('Mistral server error (' + statusCode + '). The service may be temporarily unavailable.');
        } else {
            throw new LLMException('Mistral API error (' + statusCode + '): ' + res.getBody());
        }
    }

    private static void parseAndUpdateActivity(Id activityId, String jsonResponse) {
        String cleaned = jsonResponse.trim();
        if (cleaned.startsWith('```')) {
            cleaned = cleaned.substringAfter('\n').substringBeforeLast('```').trim();
        }

        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(cleaned);
        } catch (Exception e) {
            throw new LLMException('Failed to parse AI response as JSON. Raw response: ' + cleaned.left(200));
        }

        Activity__c toUpdate = new Activity__c(Id = activityId);
        toUpdate.Category__c = validatePicklist(
            (String) parsed.get('Category'),
            new Set<String>{'Sightseeing','History & Culture','Food & Drink','Outdoor & Adventure','Family','Nightlife','Other'},
            'Other'
        );
        toUpdate.Duration__c = (String) parsed.get('Duration');
        toUpdate.Languages__c = joinMultiSelect(
            (List<Object>) parsed.get('Languages'),
            new Set<String>{'English','Spanish','French','German','Italian','Other'}
        );
        toUpdate.Accessibility__c = validatePicklist(
            (String) parsed.get('Accessibility'),
            new Set<String>{'Yes','No','Partial'},
            'Partial'
        );
        toUpdate.Good_For__c = joinMultiSelect(
            (List<Object>) parsed.get('Good_For'),
            new Set<String>{'Families','Couples','Solo','Groups'}
        );
        toUpdate.Listing_Summary__c = (String) parsed.get('Listing_Summary');

        try {
            update toUpdate;
        } catch (DmlException e) {
            throw new LLMException('Failed to save extracted data: ' + e.getDmlMessage(0));
        }
    }

    private static String validatePicklist(String value, Set<String> validValues, String defaultValue) {
        if (String.isBlank(value) || !validValues.contains(value)) {
            return defaultValue;
        }
        return value;
    }

    private static String joinMultiSelect(List<Object> values, Set<String> validValues) {
        if (values == null || values.isEmpty()) {
            return null;
        }
        List<String> valid = new List<String>();
        for (Object v : values) {
            String s = String.valueOf(v);
            if (validValues.contains(s)) {
                valid.add(s);
            }
        }
        return valid.isEmpty() ? null : String.join(valid, ';');
    }
}