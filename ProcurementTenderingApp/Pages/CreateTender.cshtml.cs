using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using ProcurementTenderingApp.Services;

namespace ProcurementTenderingApp.Pages
{
    public class CreateTenderModel : PageModel
    {
        private readonly TenderService _tenderService;

        public CreateTenderModel(TenderService tenderService)
        {
            _tenderService = tenderService;
        }

        public IActionResult OnPost(string tenderName, string submittedBy, string comments, IFormFile zipFile)
        {
            if (string.IsNullOrWhiteSpace(tenderName) || string.IsNullOrWhiteSpace(submittedBy))
            {
                TempData["Error"] = "Tender name and submitter are required";
                return RedirectToPage("/Index");
            }

            if (zipFile == null || zipFile.Length == 0)
            {
                TempData["Error"] = "Please upload a ZIP file";
                return RedirectToPage("/Index");
            }

            if (!zipFile.FileName.EndsWith(".zip", StringComparison.OrdinalIgnoreCase))
            {
                TempData["Error"] = "Only ZIP files are allowed";
                return RedirectToPage("/Index");
            }

            var tender = _tenderService.CreateTender(tenderName, submittedBy, comments ?? "", zipFile.FileName);
            
            TempData["Success"] = $"Tender '{tenderName}' created successfully!";
            return RedirectToPage("/Index", new { tenderId = tender.Id });
        }
    }
}
