public class AIExtractionService {

    public class ExtractionRequest {
        @InvocableVariable(label='Activity Id' required=true)
        public Id activityId;
    }

    public class ExtractionResult {
        @InvocableVariable(label='Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Error Message')
        public String errorMessage;

        @InvocableVariable(label='Activity Id')
        public Id activityId;
    }

    @InvocableMethod(label='Enrich Activity with AI' description='Sends supplier notes to Mistral AI and populates structured fields on the Activity record.' category='Activity')
    public static List<ExtractionResult> enrichActivities(List<ExtractionRequest> requests) {
        List<ExtractionResult> results = new List<ExtractionResult>();

        for (ExtractionRequest req : requests) {
            ExtractionResult result = new ExtractionResult();
            result.activityId = req.activityId;

            try {
                GetLLMResponse.processActivity(req.activityId);
                result.isSuccess = true;
                result.errorMessage = null;
            } catch (GetLLMResponse.LLMException e) {
                result.isSuccess = false;
                result.errorMessage = e.getMessage();
            } catch (Exception e) {
                result.isSuccess = false;
                result.errorMessage = 'Unexpected error: ' + e.getMessage();
            }

            results.add(result);
        }

        return results;
    }
}
