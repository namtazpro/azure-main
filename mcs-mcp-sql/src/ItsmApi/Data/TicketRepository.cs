using System.Data;
using Dapper;

namespace ItsmApi.Data;

public interface ITicketRepository
{
    Task<TicketDetail?> GetTicketAsync(string ticketNumber, CancellationToken ct);
    Task<TicketPage> SearchTicketsAsync(SearchTicketsCriteria c, CancellationToken ct);
    Task<IReadOnlyList<TicketComment>> GetCommentsAsync(string ticketNumber, int top, CancellationToken ct);
    Task<IReadOnlyList<Customer>> SearchCustomersAsync(string? name, string? email, string? company, int top, CancellationToken ct);
    Task<IReadOnlyList<CustomerTicket>> GetCustomerTicketsAsync(int customerId, string? status, int top, CancellationToken ct);
    Task<IReadOnlyList<AgentWorkload>> GetAgentWorkloadAsync(int? agentId, string? team, CancellationToken ct);
    Task<IReadOnlyList<SummaryRow>> GetSummaryAsync(DateTime? from, DateTime? to, string? team, CancellationToken ct);
    Task<IReadOnlyList<SlaBreach>> GetSlaBreachesAsync(string? priority, int top, CancellationToken ct);
    Task<TicketDetail> CreateTicketAsync(CreateTicketRequest r, CancellationToken ct);
    Task<TicketDetail> UpdateStatusAsync(string ticketNumber, UpdateTicketStatusRequest r, CancellationToken ct);
}

public sealed class TicketRepository(ISqlConnectionFactory factory) : ITicketRepository
{
    private async Task<IReadOnlyList<T>> QueryAsync<T>(string proc, object? args, CancellationToken ct)
    {
        await using var conn = await factory.OpenAsync(ct);
        var rows = await conn.QueryAsync<T>(new CommandDefinition(proc, args, commandType: CommandType.StoredProcedure, cancellationToken: ct));
        return rows.AsList();
    }

    public async Task<TicketDetail?> GetTicketAsync(string ticketNumber, CancellationToken ct) =>
        (await QueryAsync<TicketDetail>("dbo.usp_GetTicket", new { TicketNumber = ticketNumber }, ct)).FirstOrDefault();

    public async Task<TicketPage> SearchTicketsAsync(SearchTicketsCriteria c, CancellationToken ct)
    {
        var rows = await QueryAsync<SearchRow>("dbo.usp_SearchTickets", new
        {
            c.Status, c.Priority, c.Category, c.AssignedAgentId, c.CustomerId, c.CreatedFrom, c.CreatedTo,
            c.SearchText, c.OverdueOnly, c.PageNumber, c.PageSize
        }, ct);
        return new TicketPage
        {
            PageNumber = c.PageNumber,
            PageSize = c.PageSize,
            TotalCount = rows.Count > 0 ? rows[0].TotalCount : 0,
            Items = rows.Cast<TicketSummaryItem>().ToList()
        };
    }

    public Task<IReadOnlyList<TicketComment>> GetCommentsAsync(string ticketNumber, int top, CancellationToken ct) =>
        QueryAsync<TicketComment>("dbo.usp_GetTicketComments", new { TicketNumber = ticketNumber, Top = top }, ct);

    public Task<IReadOnlyList<Customer>> SearchCustomersAsync(string? name, string? email, string? company, int top, CancellationToken ct) =>
        QueryAsync<Customer>("dbo.usp_SearchCustomers", new { Name = name, Email = email, Company = company, Top = top }, ct);

    public Task<IReadOnlyList<CustomerTicket>> GetCustomerTicketsAsync(int customerId, string? status, int top, CancellationToken ct) =>
        QueryAsync<CustomerTicket>("dbo.usp_GetTicketsByCustomer", new { CustomerId = customerId, Status = status, Top = top }, ct);

    public Task<IReadOnlyList<AgentWorkload>> GetAgentWorkloadAsync(int? agentId, string? team, CancellationToken ct) =>
        QueryAsync<AgentWorkload>("dbo.usp_GetAgentWorkload", new { AgentId = agentId, Team = team }, ct);

    public Task<IReadOnlyList<SummaryRow>> GetSummaryAsync(DateTime? from, DateTime? to, string? team, CancellationToken ct) =>
        QueryAsync<SummaryRow>("dbo.usp_GetTicketSummary", new { From = from, To = to, Team = team }, ct);

    public Task<IReadOnlyList<SlaBreach>> GetSlaBreachesAsync(string? priority, int top, CancellationToken ct) =>
        QueryAsync<SlaBreach>("dbo.usp_GetSlaBreaches", new { Priority = priority, Top = top }, ct);

    public async Task<TicketDetail> CreateTicketAsync(CreateTicketRequest r, CancellationToken ct) =>
        (await QueryAsync<TicketDetail>("dbo.usp_CreateTicket", new { r.CustomerId, r.Category, r.Title, r.Description, r.Priority }, ct)).First();

    public async Task<TicketDetail> UpdateStatusAsync(string ticketNumber, UpdateTicketStatusRequest r, CancellationToken ct) =>
        (await QueryAsync<TicketDetail>("dbo.usp_UpdateTicketStatus", new { TicketNumber = ticketNumber, r.Status, r.AssignedAgentId, r.Comment }, ct)).First();

    private sealed class SearchRow : TicketSummaryItem
    {
        public int TotalCount { get; set; }
    }
}
