namespace ProcurementTenderingApp.Models
{
    public class Tender
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public DateTime SubmissionDate { get; set; }
        public string SubmittedBy { get; set; } = string.Empty;
        public string Comments { get; set; } = string.Empty;
        public TenderStatus Status { get; set; }
        public string? FileName { get; set; }
        public int? Score { get; set; }
        public int? MaxScore { get; set; } = 10;
        public List<TenderDocument> Documents { get; set; } = new();
    }
}
