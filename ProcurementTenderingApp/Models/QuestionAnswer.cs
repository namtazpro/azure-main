namespace ProcurementTenderingApp.Models
{
    public class QuestionAnswer
    {
        public int Id { get; set; }
        public string Question { get; set; } = string.Empty;
        public string Answer { get; set; } = string.Empty;
        public string EvaluationCriteria { get; set; } = string.Empty;
    }
}
