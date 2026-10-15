using System.Net;
using ItsmApi.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.OpenApi.Models;

namespace ItsmApi.Functions;

public class TicketFunctions(ITicketRepository repo)
{
    [Function("GetTicket")]
    [OpenApiOperation("getTicket", "tickets", Summary = "Get a ticket by number",
        Description = "Returns full details of one IT support ticket, including status, priority, customer, assigned agent and SLA due date.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("ticketNumber", In = ParameterLocation.Path, Required = true, Type = typeof(string), Description = "Ticket number, for example INC-000123.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(TicketDetail), Description = "The ticket.")]
    [OpenApiResponseWithBody(HttpStatusCode.NotFound, "application/json", typeof(ErrorResponse), Description = "Ticket not found.")]
    public Task<IActionResult> GetTicket(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "tickets/{ticketNumber}")] HttpRequest req,
        string ticketNumber, CancellationToken ct) =>
        Api.RunAsync(async () =>
            await repo.GetTicketAsync(ticketNumber.ToUpperInvariant(), ct) is { } t
                ? new OkObjectResult(t)
                : new NotFoundObjectResult(new ErrorResponse { Error = "Ticket not found." }));

    [Function("SearchTickets")]
    [OpenApiOperation("searchTickets", "tickets", Summary = "Search tickets",
        Description = "Searches IT support tickets with optional filters and paging (newest first, max 100 per page). Returns total count and the requested page.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("status", In = ParameterLocation.Query, Type = typeof(string), Description = "New, Open, InProgress, Pending, Resolved or Closed.")]
    [OpenApiParameter("priority", In = ParameterLocation.Query, Type = typeof(string), Description = "Critical, High, Medium or Low.")]
    [OpenApiParameter("category", In = ParameterLocation.Query, Type = typeof(string), Description = "Exact category name, for example 'Network & VPN'.")]
    [OpenApiParameter("assignedAgentId", In = ParameterLocation.Query, Type = typeof(int), Description = "Agent id the ticket is assigned to.")]
    [OpenApiParameter("customerId", In = ParameterLocation.Query, Type = typeof(int), Description = "Customer id.")]
    [OpenApiParameter("createdFrom", In = ParameterLocation.Query, Type = typeof(string), Description = "Created on or after this UTC date (yyyy-MM-dd).")]
    [OpenApiParameter("createdTo", In = ParameterLocation.Query, Type = typeof(string), Description = "Created before this UTC date (yyyy-MM-dd).")]
    [OpenApiParameter("searchText", In = ParameterLocation.Query, Type = typeof(string), Description = "Text contained in the ticket title.")]
    [OpenApiParameter("overdueOnly", In = ParameterLocation.Query, Type = typeof(bool), Description = "Only open tickets past their SLA due date.")]
    [OpenApiParameter("pageNumber", In = ParameterLocation.Query, Type = typeof(int), Description = "1-based page number. Default 1.")]
    [OpenApiParameter("pageSize", In = ParameterLocation.Query, Type = typeof(int), Description = "Page size 1-100. Default 20.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(TicketPage), Description = "A page of tickets.")]
    public Task<IActionResult> SearchTickets(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "tickets")] HttpRequest req, CancellationToken ct) =>
        Api.RunAsync(async () =>
        {
            var q = req.Query;
            var criteria = new SearchTicketsCriteria
            {
                Status = q.Str("status"),
                Priority = q.Str("priority"),
                Category = q.Str("category"),
                AssignedAgentId = q.Int("assignedAgentId"),
                CustomerId = q.Int("customerId"),
                CreatedFrom = q.Date("createdFrom"),
                CreatedTo = q.Date("createdTo"),
                SearchText = q.Str("searchText"),
                OverdueOnly = q.Bool("overdueOnly"),
                PageNumber = Math.Max(1, q.Int("pageNumber") ?? 1),
                PageSize = Math.Clamp(q.Int("pageSize") ?? 20, 1, 100)
            };
            return new OkObjectResult(await repo.SearchTicketsAsync(criteria, ct));
        });

    [Function("GetTicketComments")]
    [OpenApiOperation("getTicketComments", "tickets", Summary = "Get ticket comments",
        Description = "Returns the conversation history (customer, agent and system comments) of a ticket, oldest first.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("ticketNumber", In = ParameterLocation.Path, Required = true, Type = typeof(string), Description = "Ticket number, for example INC-000123.")]
    [OpenApiParameter("top", In = ParameterLocation.Query, Type = typeof(int), Description = "Maximum comments to return (1-200). Default 50.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(IEnumerable<TicketComment>), Description = "The comments.")]
    [OpenApiResponseWithBody(HttpStatusCode.NotFound, "application/json", typeof(ErrorResponse), Description = "Ticket not found.")]
    public Task<IActionResult> GetTicketComments(
        [HttpTrigger(AuthorizationLevel.Function, "get", Route = "tickets/{ticketNumber}/comments")] HttpRequest req,
        string ticketNumber, CancellationToken ct) =>
        Api.RunAsync(async () =>
            new OkObjectResult(await repo.GetCommentsAsync(ticketNumber.ToUpperInvariant(), req.Query.Int("top") ?? 50, ct)));

    [Function("CreateTicket")]
    [OpenApiOperation("createTicket", "tickets", Summary = "Create a ticket",
        Description = "Creates a new IT support ticket for a customer. The ticket starts in status New with an SLA due date based on priority.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiRequestBody("application/json", typeof(CreateTicketRequest), Required = true, Description = "The ticket to create.")]
    [OpenApiResponseWithBody(HttpStatusCode.Created, "application/json", typeof(TicketDetail), Description = "The created ticket.")]
    [OpenApiResponseWithBody(HttpStatusCode.BadRequest, "application/json", typeof(ErrorResponse), Description = "Invalid input.")]
    [OpenApiResponseWithBody(HttpStatusCode.NotFound, "application/json", typeof(ErrorResponse), Description = "Customer not found.")]
    public Task<IActionResult> CreateTicket(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "tickets")] HttpRequest req, CancellationToken ct) =>
        Api.RunAsync(async () =>
        {
            var body = await req.ReadFromJsonAsync<CreateTicketRequest>(ct);
            if (body is null || body.CustomerId <= 0 || string.IsNullOrWhiteSpace(body.Title) || string.IsNullOrWhiteSpace(body.Category))
                return new BadRequestObjectResult(new ErrorResponse { Error = "customerId, category and title are required." });
            var created = await repo.CreateTicketAsync(body, ct);
            return new ObjectResult(created) { StatusCode = StatusCodes.Status201Created };
        });

    [Function("UpdateTicketStatus")]
    [OpenApiOperation("updateTicketStatus", "tickets", Summary = "Update ticket status",
        Description = "Changes the status of a ticket, optionally assigning an agent and adding a comment. Resolved and Closed set the resolution time.")]
    [OpenApiSecurity(Api.SecurityScheme, SecuritySchemeType.ApiKey, Name = "x-functions-key", In = OpenApiSecurityLocationType.Header)]
    [OpenApiParameter("ticketNumber", In = ParameterLocation.Path, Required = true, Type = typeof(string), Description = "Ticket number, for example INC-000123.")]
    [OpenApiRequestBody("application/json", typeof(UpdateTicketStatusRequest), Required = true, Description = "The new status.")]
    [OpenApiResponseWithBody(HttpStatusCode.OK, "application/json", typeof(TicketDetail), Description = "The updated ticket.")]
    [OpenApiResponseWithBody(HttpStatusCode.BadRequest, "application/json", typeof(ErrorResponse), Description = "Invalid input.")]
    [OpenApiResponseWithBody(HttpStatusCode.NotFound, "application/json", typeof(ErrorResponse), Description = "Ticket not found.")]
    public Task<IActionResult> UpdateTicketStatus(
        [HttpTrigger(AuthorizationLevel.Function, "patch", Route = "tickets/{ticketNumber}/status")] HttpRequest req,
        string ticketNumber, CancellationToken ct) =>
        Api.RunAsync(async () =>
        {
            var body = await req.ReadFromJsonAsync<UpdateTicketStatusRequest>(ct);
            if (body is null || string.IsNullOrWhiteSpace(body.Status))
                return new BadRequestObjectResult(new ErrorResponse { Error = "status is required." });
            return new OkObjectResult(await repo.UpdateStatusAsync(ticketNumber.ToUpperInvariant(), body, ct));
        });
}
