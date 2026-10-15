using System.Net;
using ItsmApi.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.OpenApi.Models;

namespace ItsmApi.Functions;

public class ReportFunctions(ITicketRepository repo)
{
    [Function("SearchCustomers")]
    [OpenApiOperation("searchCustomers", "customers", Summary = "Search customers",
        Description = "Finds customers by name prefix, exact email or company prefix and returns their open ticket count.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("name", In = ParameterLocation.Query, Type = typeof(string), Description = "Customer name starts with.")]
    [OpenApiParameter("email", In = ParameterLocation.Query, Type = typeof(string), Description = "Exact customer email.")]
    [OpenApiParameter("company", In = ParameterLocation.Query, Type = typeof(string), Description = "Company name starts with.")]
    [OpenApiParameter("top", In = ParameterLocation.Query, Type = typeof(int), Description = "Maximum results (1-100). Default 20.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(IEnumerable<Customer>), Description = "Matching customers.")]
    public Task<IActionResult> SearchCustomers(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "customers")] HttpRequest req, CancellationToken ct) =>
        Api.RunAsync(async () =>
            new OkObjectResult(await repo.SearchCustomersAsync(req.Query.Str("name"), req.Query.Str("email"), req.Query.Str("company"), req.Query.Int("top") ?? 20, ct)));

    [Function("GetCustomerTickets")]
    [OpenApiOperation("getCustomerTickets", "customers", Summary = "Get tickets of a customer",
        Description = "Returns the most recent tickets raised by a customer, optionally filtered by status.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("customerId", In = ParameterLocation.Path, Required = true, Type = typeof(int), Description = "Customer id.")]
    [OpenApiParameter("status", In = ParameterLocation.Query, Type = typeof(string), Description = "New, Open, InProgress, Pending, Resolved or Closed.")]
    [OpenApiParameter("top", In = ParameterLocation.Query, Type = typeof(int), Description = "Maximum results (1-100). Default 25.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(IEnumerable<CustomerTicket>), Description = "The customer's tickets.")]
    [OpenApiResponseWithBody(HttpStatusCode.NotFound, "application/json", typeof(ErrorResponse), Description = "Customer not found.")]
    public Task<IActionResult> GetCustomerTickets(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "customers/{customerId:int}/tickets")] HttpRequest req,
        int customerId, CancellationToken ct) =>
        Api.RunAsync(async () =>
            new OkObjectResult(await repo.GetCustomerTicketsAsync(customerId, req.Query.Str("status"), req.Query.Int("top") ?? 25, ct)));

    [Function("GetAgentWorkload")]
    [OpenApiOperation("getAgentWorkload", "agents", Summary = "Get agent workload",
        Description = "Returns open, critical, high-priority and overdue ticket counts per support agent, optionally for one agent or team.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("agentId", In = ParameterLocation.Query, Type = typeof(int), Description = "Agent id.")]
    [OpenApiParameter("team", In = ParameterLocation.Query, Type = typeof(string), Description = "Team name: Service Desk, Network Operations, Infrastructure, Security Operations or Application Support.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(IEnumerable<AgentWorkload>), Description = "Workload per agent, busiest first.")]
    public Task<IActionResult> GetAgentWorkload(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "agents/workload")] HttpRequest req, CancellationToken ct) =>
        Api.RunAsync(async () =>
            new OkObjectResult(await repo.GetAgentWorkloadAsync(req.Query.Int("agentId"), req.Query.Str("team"), ct)));

    [Function("GetTicketSummary")]
    [OpenApiOperation("getTicketSummary", "reports", Summary = "Get ticket summary report",
        Description = "Returns ticket counts and average resolution hours grouped by status, priority and category for a date range (default last 30 days).")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("from", In = ParameterLocation.Query, Type = typeof(string), Description = "Start UTC date (yyyy-MM-dd).")]
    [OpenApiParameter("to", In = ParameterLocation.Query, Type = typeof(string), Description = "End UTC date, exclusive (yyyy-MM-dd).")]
    [OpenApiParameter("team", In = ParameterLocation.Query, Type = typeof(string), Description = "Restrict to tickets assigned to this team.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(IEnumerable<SummaryRow>), Description = "Summary rows by dimension.")]
    public Task<IActionResult> GetTicketSummary(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "reports/summary")] HttpRequest req, CancellationToken ct) =>
        Api.RunAsync(async () =>
            new OkObjectResult(await repo.GetSummaryAsync(req.Query.Date("from"), req.Query.Date("to"), req.Query.Str("team"), ct)));

    [Function("GetSlaBreaches")]
    [OpenApiOperation("getSlaBreaches", "reports", Summary = "Get SLA breaches",
        Description = "Lists open tickets that are past their SLA due date, most critical and most overdue first.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("priority", In = ParameterLocation.Query, Type = typeof(string), Description = "Critical, High, Medium or Low.")]
    [OpenApiParameter("top", In = ParameterLocation.Query, Type = typeof(int), Description = "Maximum results (1-100). Default 25.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(IEnumerable<SlaBreach>), Description = "Overdue tickets.")]
    public Task<IActionResult> GetSlaBreaches(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "reports/sla-breaches")] HttpRequest req, CancellationToken ct) =>
        Api.RunAsync(async () =>
            new OkObjectResult(await repo.GetSlaBreachesAsync(req.Query.Str("priority"), req.Query.Int("top") ?? 25, ct)));
}
