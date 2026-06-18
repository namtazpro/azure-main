using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using ProcurementTenderingApp.Models;
using ProcurementTenderingApp.Services;

namespace ProcurementTenderingApp.Pages;

public class IndexModel : PageModel
{
    private readonly TenderService _tenderService;

    public IndexModel(TenderService tenderService)
    {
        _tenderService = tenderService;
    }

    public List<Tender> Tenders { get; set; } = new();
    public Tender? SelectedTender { get; set; }
    public int? SelectedTenderId { get; set; }

    public void OnGet(int? tenderId)
    {
        Tenders = _tenderService.GetAllTenders();
        
        if (tenderId.HasValue)
        {
            SelectedTender = _tenderService.GetTenderById(tenderId.Value);
            SelectedTenderId = tenderId.Value;
        }
    }

    public IActionResult OnGetQuestionsAndAnswers()
    {
        var questionsAndAnswers = _tenderService.GetQuestionsAndAnswers();
        return new JsonResult(questionsAndAnswers);
    }

    public async Task<IActionResult> OnPostAssessTender(int tenderId)
    {
        var score = await _tenderService.AssessTenderPack(tenderId);
        return new JsonResult(new { success = true, score = score });
    }

    public IActionResult OnPostMarkComplete(int tenderId)
    {
        _tenderService.UpdateTenderStatus(tenderId, TenderStatus.Completed);
        return new JsonResult(new { success = true });
    }

    public IActionResult OnPostCreateTender(string tenderName, string submittedBy, string comments, IFormFile zipFile)
    {
        if (string.IsNullOrWhiteSpace(tenderName) || string.IsNullOrWhiteSpace(submittedBy))
        {
            TempData["Error"] = "Tender name and submitter are required";
            return RedirectToPage();
        }

        if (zipFile == null || zipFile.Length == 0)
        {
            TempData["Error"] = "Please upload a ZIP file";
            return RedirectToPage();
        }

        if (!zipFile.FileName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
        {
            TempData["Error"] = "Only ZIP files are allowed";
            return RedirectToPage();
        }

        var tender = _tenderService.CreateTender(tenderName, submittedBy, comments ?? "", zipFile.FileName);
        
        TempData["Success"] = $"Tender '{tenderName}' created successfully!";
        return RedirectToPage(new { tenderId = tender.Id });
    }
}
