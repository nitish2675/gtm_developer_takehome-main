# AI Usage

> This file is **graded**. We assume you used AI — we want to see _how_. Keep it honest and specific; bullet points are fine.

## Tools used

<!-- e.g. Claude Code, Cursor, ChatGPT — and what you used each for -->

1. I used AI ChatGPT to rapidly generate the Salesforce XML metadata files (objects, fields) to save boilerplate setup time.
2. I used standard claude Code for while writing Apex classe and LWC.

## Prompts that worked well

<!-- 2–3 real prompts. Include your Part 3 extraction prompt. -->

1.                            You are a structured data extraction engine. Your ONLY job is to extract facts from supplier notes.

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

2.        I'm building a Salesforce data model for a travel  marketplace. Suppliers list activities
        (tours, attractions, day trips) that happen at a physical meeting point.

        Here's my seed data (CSV headers + 2 sample rows):

        Name,Supplier_Name__c,Street__c,City__c,Country__c,Postal_Code__c,Supplier_Notes__c
        Skip-the-Line Eiffel Tower Summit by Lift,Lumière Tours,"Champ de Mars, 5 Avenue Anatole France",Paris,France,75007,"eiffel tower tour - go to SUMMIT not just 2nd floor!! lift included. meet 15 min before at south pillar..."
        Colosseum Underground & Arena Floor Guided Tour,Roma Antica Experiences,"Piazza del Colosseo, 1",Rome,Italy,00184,"COLOSSEUM - includes underground (hypogeum) + arena floor access... approx 3 hours total. lots of stairs underground NOT wheelchair accessible..."

        Requirements:
        1. I need a Supplier__c parent object and Activity__c child object
        2. Activity needs: address fields, a Geolocation compound field (for SOQL DISTANCE queries),
        and AI-extracted fields: Category (picklist), Duration, Languages (multi-select),
        Accessibility (Yes/No/Partial), Good_For (multi-select), Listing_Summary
        3. The Supplier_Notes__c is raw messy text from suppliers — it will be sent to an LLM for structured extraction

        Give me the complete SFDX field-meta.xml for every field on Activity__c.
        Use Master-Detail (not Lookup) for the relationship.
        Use a Geolocation compound field (not separate lat/lng numbers) so I can use DISTANCE() in SOQL.
        Restricted picklists — I need to validate LLM output against them.

3.           Write an Apex test class for AIExtractionService and GetLLMResponse.
        The service calls Mistral AI's /v1/chat/completions endpoint.
        I need separate HttpCalloutMock inner classes for these scenarios:

        1. Happy path — valid JSON in choices[0].message.content, verify all 6 fields update on Activity\_\_c
        2. Markdown fences — LLM wraps response in `json` despite being told not to
        3. Hallucinated picklist — Category="Ancient Ruins Tour" (invalid) → should default to "Other"
        4. Broken JSON — content is garbage text → isSuccess=false with parse error message
        5. 401 Unauthorized → error message about API key
        6. 429 Rate limited → error message about rate limit
        7. 500 Server error → error about service unavailable
        8. Empty Supplier_Notes → fails before callout with "nothing to extract" message

        Use @TestSetup to create a Supplier + Activity with real supplier notes from the CSV.
        Each test must assert on actual field values or error messages — not just "didn't crash."

## Where the AI was wrong or misleading

<!-- At least one concrete example: what it suggested, why it was wrong, how you caught and fixed it. -->

1. The AI generated code that called `Integration_Setting__mdt.getInstance('MistralKey').API_Key__c` then completely ignored that variable and hardcoded a raw Bearer token `'Bearer ' + 'AQ.Ab8RN6IeuDXBLP5T...'`. I caught it during code review and removed the hardcoded key.

2. The AI assumed the Master-Detail field on `Activity__c` would be called `Supplier__c`(matching the object name). After deployment, the actual field API name was `Supplier_Name__c` — which only became apparent when the test class failed on insert. The AI confidently used the wrong name without checking the deployed metadata. I had to correct it in the test setup data.

3. "Google Gemini/Open AI/Grok grants zero free-tier quota in the EU/EEA — a card-free key there fails with a quota error." The AI's first implementation used Gemini anyway. The error came back as `limit: 0` on the very first call — not a rate limit, a permanent zero allocation. This wasn't a transient issue to retry; it was a fundamentally wrong provider choice for my region. Switched to Mistral which works globally without a card.

## What you chose NOT to delegate to AI, and why

<!-- e.g. secret handling, governor-limit reasoning, security decisions -->

1. AI often suggests putting HTTP callouts in `@future` methods triggered by `after insert`. In a bulk upload scenario (like the 10-record CSV), this shatters governor limits. I architected the `Queueable` chaining logic manually to ensure enterprise-grade scaling.
2. AI often suggests putt API Key in the Apex Code that is not the best practice for Coding, so i decided to go with the custom metadata
