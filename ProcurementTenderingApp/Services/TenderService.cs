using ProcurementTenderingApp.Models;

namespace ProcurementTenderingApp.Services
{
    public class TenderService
    {
        private static List<Tender> _tenders = new();
        private static int _nextId = 1;

        public TenderService()
        {
            // Initialize with sample data if empty
            if (_tenders.Count == 0)
            {
                InitializeSampleData();
            }
        }

        public List<Tender> GetAllTenders()
        {
            return _tenders.OrderByDescending(t => t.SubmissionDate).ToList();
        }

        public Tender? GetTenderById(int id)
        {
            return _tenders.FirstOrDefault(t => t.Id == id);
        }

        public Tender CreateTender(string name, string submittedBy, string comments, string fileName)
        {
            var tender = new Tender
            {
                Id = _nextId++,
                Name = name,
                SubmissionDate = DateTime.Now,
                SubmittedBy = submittedBy,
                Comments = comments,
                FileName = fileName,
                Status = TenderStatus.New,
                Documents = GenerateSampleDocuments()
            };

            _tenders.Add(tender);
            return tender;
        }

        public async Task<int> AssessTenderPack(int tenderId)
        {
            // Simulate 5-second assessment process
            await Task.Delay(5000);

            var tender = GetTenderById(tenderId);
            if (tender != null)
            {
                // Generate a random score between 5 and 10
                var random = new Random();
                tender.Score = random.Next(5, 11);
                tender.Status = TenderStatus.InProgress;
            }

            return tender?.Score ?? 0;
        }

        public void UpdateTenderStatus(int tenderId, TenderStatus status)
        {
            var tender = GetTenderById(tenderId);
            if (tender != null)
            {
                tender.Status = status;
            }
        }

        private List<TenderDocument> GenerateSampleDocuments()
        {
            return new List<TenderDocument>
            {
                new TenderDocument { Id = 1, DocumentName = "Company Profile.pdf", DocumentType = "PDF", FileSize = 2456789 },
                new TenderDocument { Id = 2, DocumentName = "Financial Statements 2024.xlsx", DocumentType = "Excel", FileSize = 1234567 },
                new TenderDocument { Id = 3, DocumentName = "Technical Proposal.docx", DocumentType = "Word", FileSize = 3456789 },
                new TenderDocument { Id = 4, DocumentName = "Questions and Answers.pdf", DocumentType = "PDF", FileSize = 987654, IsQuestionsAndAnswers = true },
                new TenderDocument { Id = 5, DocumentName = "Health and Safety Policy.pdf", DocumentType = "PDF", FileSize = 567890 },
                new TenderDocument { Id = 6, DocumentName = "Insurance Certificate.pdf", DocumentType = "PDF", FileSize = 345678 },
                new TenderDocument { Id = 7, DocumentName = "References.docx", DocumentType = "Word", FileSize = 678901 },
                new TenderDocument { Id = 8, DocumentName = "Project Timeline.xlsx", DocumentType = "Excel", FileSize = 234567 }
            };
        }

        public List<QuestionAnswer> GetQuestionsAndAnswers()
        {
            return new List<QuestionAnswer>
            {
                new QuestionAnswer
                {
                    Id = 1,
                    Question = "How many years of experience does your organization have in public sector procurement?",
                    Answer = "Our organization has over 15 years of experience delivering procurement solutions to local councils and public sector organizations across the UK.",
                    EvaluationCriteria = "Minimum 10 years experience required. Weight: 10%"
                },
                new QuestionAnswer
                {
                    Id = 2,
                    Question = "What is your approach to ensuring value for money in procurement processes?",
                    Answer = "We implement a comprehensive framework including competitive tendering, whole-life costing analysis, market benchmarking, and continuous supplier performance monitoring.",
                    EvaluationCriteria = "Must demonstrate robust value for money methodology. Weight: 15%"
                },
                new QuestionAnswer
                {
                    Id = 3,
                    Question = "How do you ensure compliance with the Public Contracts Regulations 2015?",
                    Answer = "We maintain a dedicated compliance team, conduct regular audits, use certified procurement software with built-in compliance checks, and provide ongoing staff training on regulatory requirements.",
                    EvaluationCriteria = "Evidence of compliance framework and monitoring. Weight: 20%"
                },
                new QuestionAnswer
                {
                    Id = 4,
                    Question = "Describe your experience with environmental sustainability in procurement.",
                    Answer = "We have implemented green procurement policies across 25+ public sector contracts, achieving average carbon footprint reductions of 30% and promoting circular economy principles.",
                    EvaluationCriteria = "Demonstrable environmental credentials and case studies. Weight: 10%"
                },
                new QuestionAnswer
                {
                    Id = 5,
                    Question = "What systems do you have in place for contract management and monitoring?",
                    Answer = "We utilize an integrated contract management platform with automated KPI tracking, real-time dashboards, milestone alerts, and comprehensive reporting capabilities.",
                    EvaluationCriteria = "Robust contract management system with monitoring capabilities. Weight: 12%"
                },
                new QuestionAnswer
                {
                    Id = 6,
                    Question = "How do you support local SME engagement in procurement processes?",
                    Answer = "We run dedicated SME outreach programs, simplify bidding processes, provide supplier development workshops, and ensure contracts are appropriately sized for SME participation.",
                    EvaluationCriteria = "Evidence of SME engagement strategy and outcomes. Weight: 8%"
                },
                new QuestionAnswer
                {
                    Id = 7,
                    Question = "What is your approach to risk management in procurement?",
                    Answer = "We employ a comprehensive risk management framework including risk registers, regular assessments, mitigation strategies, contingency planning, and insurance requirements.",
                    EvaluationCriteria = "Comprehensive risk management approach. Weight: 10%"
                },
                new QuestionAnswer
                {
                    Id = 8,
                    Question = "How do you ensure transparency and accountability in procurement activities?",
                    Answer = "All procurement activities are documented in our audit-trail system, we publish contract awards in accordance with transparency requirements, and maintain clear governance structures with defined responsibilities.",
                    EvaluationCriteria = "Clear transparency and accountability measures. Weight: 8%"
                },
                new QuestionAnswer
                {
                    Id = 9,
                    Question = "What resources will you dedicate to this contract?",
                    Answer = "We will assign a dedicated account manager, a team of 5 procurement specialists, 2 compliance officers, and access to our technical support team totaling 15 FTE equivalents.",
                    EvaluationCriteria = "Adequate resource allocation and expertise. Weight: 5%"
                },
                new QuestionAnswer
                {
                    Id = 10,
                    Question = "Describe your approach to continuous improvement in procurement services.",
                    Answer = "We conduct quarterly service reviews, benchmark against industry best practices, implement feedback mechanisms, invest in staff development, and maintain ISO 9001 certification for quality management.",
                    EvaluationCriteria = "Evidence of continuous improvement culture and methodology. Weight: 2%"
                }
            };
        }

        private void InitializeSampleData()
        {
            _tenders.Add(new Tender
            {
                Id = _nextId++,
                Name = "IT Infrastructure Upgrade",
                SubmissionDate = DateTime.Now.AddDays(-5),
                SubmittedBy = "TechSolutions Ltd",
                Comments = "Complete infrastructure modernization proposal",
                Status = TenderStatus.Completed,
                Score = 9,
                FileName = "IT_Infrastructure_Tender.zip",
                Documents = GenerateSampleDocuments()
            });

            _tenders.Add(new Tender
            {
                Id = _nextId++,
                Name = "Waste Management Services",
                SubmissionDate = DateTime.Now.AddDays(-3),
                SubmittedBy = "GreenClean Services",
                Comments = "5-year waste management contract proposal",
                Status = TenderStatus.InProgress,
                Score = 7,
                FileName = "Waste_Management_Tender.zip",
                Documents = GenerateSampleDocuments()
            });

            _tenders.Add(new Tender
            {
                Id = _nextId++,
                Name = "Building Maintenance Contract",
                SubmissionDate = DateTime.Now.AddDays(-1),
                SubmittedBy = "PropertyCare Group",
                Comments = "Multi-site building maintenance tender",
                Status = TenderStatus.New,
                FileName = "Building_Maintenance_Tender.zip",
                Documents = GenerateSampleDocuments()
            });
        }
    }
}
