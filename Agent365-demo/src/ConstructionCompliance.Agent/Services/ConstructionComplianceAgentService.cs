using ConstructionCompliance.Agent.Models;
using ConstructionCompliance.Agent.Routing;
using ConstructionCompliance.Agent.Skills;

namespace ConstructionCompliance.Agent.Services;

/// <summary>
/// Orchestrates intent routing and skill execution for compliance analysis.
/// </summary>
public sealed class ConstructionComplianceAgentService(
    IIntentResolver intentResolver,
    IJurisdictionResolverSkill jurisdictionResolver,
    IRegulationRetrievalSkill regulationRetrieval,
    IConstraintEngineSkill constraintEngine,
    IDesignCheckerSkill designChecker,
    ICitationAuditSkill citationAudit)
{
    private const string AdvisoryDisclaimer = "Advisory output only. Final compliance determination must be performed by licensed local professionals.";

    /// <summary>
    /// Processes a request through routing and skill orchestration.
    /// </summary>
    /// <param name="request">The incoming request.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>A normalized response for Agent365 clients.</returns>
    public async Task<AgentResponse> ProcessAsync(AgentRequest request, CancellationToken cancellationToken)
    {
        var intent = intentResolver.Resolve(request);

        var missingFields = ValidateRequiredFields(request);
        if (missingFields.Count > 0)
        {
            return new AgentResponse
            {
                Intent = intent.ToString(),
                CoverageStatus = "unknown",
                Confidence = "low",
                ClarificationRequests = missingFields,
                Disclaimer = AdvisoryDisclaimer,
                Assumptions = ["Missing required context prevented a full regulatory analysis."]
            };
        }

        var jurisdiction = await jurisdictionResolver.ResolveAsync(request, cancellationToken);
        if (!jurisdiction.IsSupported)
        {
            return new AgentResponse
            {
                Intent = intent.ToString(),
                CoverageStatus = jurisdiction.CoverageStatus,
                Confidence = "low",
                ClarificationRequests = ["Requested jurisdiction is not in current v1 coverage. Provide a supported country or extend the regulation corpus."],
                Disclaimer = AdvisoryDisclaimer,
                Assumptions = ["No jurisdiction-specific legal analysis was performed."]
            };
        }

        var regulations = await regulationRetrieval.RetrieveAsync(jurisdiction, intent, cancellationToken);
        var constraints = await constraintEngine.ExtractAsync(request, regulations, cancellationToken);

        var response = new AgentResponse
        {
            Intent = intent.ToString(),
            ApplicableRegulations = [.. regulations],
            Constraints = [.. constraints],
            CoverageStatus = jurisdiction.CoverageStatus,
            Confidence = "medium",
            Disclaimer = AdvisoryDisclaimer,
            Citations = BuildCitations()
        };

        if (intent == IntentType.PrePermitRiskCheck)
        {
            var findings = await designChecker.EvaluateAsync(request, constraints, cancellationToken);
            response.RiskFindings = [.. findings];
        }

        response.Assumptions.Add("This v1 sample uses mock skills and synthetic regulation references for demonstration.");

        return citationAudit.Audit(response);
    }

    private static List<string> ValidateRequiredFields(AgentRequest request)
    {
        var missing = new List<string>();

        if (string.IsNullOrWhiteSpace(request.Country))
        {
            missing.Add("country");
        }

        if (string.IsNullOrWhiteSpace(request.BuildingType))
        {
            missing.Add("buildingType");
        }

        if (string.IsNullOrWhiteSpace(request.OccupancyClass))
        {
            missing.Add("occupancyClass");
        }

        if (string.IsNullOrWhiteSpace(request.DesignStage))
        {
            missing.Add("designStage");
        }

        if (string.IsNullOrWhiteSpace(request.Query))
        {
            missing.Add("query");
        }

        return missing;
    }

    private static List<Citation> BuildCitations()
    {
        return
        [
            new Citation("CIT-001", "Local Building Code Section 10.4", "https://example.org/codes/local-building-code#10-4"),
            new Citation("CIT-002", "Accessibility Standard Clause 5.2", "https://example.org/codes/accessibility#5-2"),
            new Citation("CIT-003", "Energy Performance Standard Clause 7.1", "https://example.org/codes/energy#7-1")
        ];
    }
}
