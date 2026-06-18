namespace ProcurementTenderingApp.Models
{
    public class TenderDocument
    {
        public int Id { get; set; }
        public int TenderId { get; set; }
        public string DocumentName { get; set; } = string.Empty;
        public string DocumentType { get; set; } = string.Empty;
        public bool IsQuestionsAndAnswers { get; set; }
        public int FileSize { get; set; }
    }
}
