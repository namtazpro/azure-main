using ItsmApi;
using ItsmApi.Data;
using ItsmApi.Functions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Primitives;

namespace ItsmApi.Tests;

public class TicketFunctionsTests
{
    private static HttpRequest RequestWithQuery(Dictionary<string, StringValues>? query = null)
    {
        var ctx = new DefaultHttpContext();
        if (query is not null) ctx.Request.QueryString = QueryString.Create(query.Select(p => new KeyValuePair<string, string?>(p.Key, p.Value.ToString())));
        return ctx.Request;
    }

    [Fact]
    public async Task SearchTickets_ClampsPagingAndParsesFilters()
    {
        var repo = new FakeRepository();
        var sut = new TicketFunctions(repo);

        var result = await sut.SearchTickets(RequestWithQuery(new()
        {
            ["status"] = "Open", ["priority"] = "High", ["pageSize"] = "5000", ["pageNumber"] = "-3",
            ["overdueOnly"] = "true", ["createdFrom"] = "2026-01-15", ["assignedAgentId"] = "7"
        }), CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
        var c = repo.LastSearch!;
        Assert.Equal("Open", c.Status);
        Assert.Equal("High", c.Priority);
        Assert.Equal(100, c.PageSize);
        Assert.Equal(1, c.PageNumber);
        Assert.True(c.OverdueOnly);
        Assert.Equal(7, c.AssignedAgentId);
        Assert.Equal(new DateTime(2026, 1, 15, 0, 0, 0, DateTimeKind.Utc), c.CreatedFrom!.Value.ToUniversalTime());
    }

    [Fact]
    public async Task SearchTickets_UsesDefaultsWhenNoQuery()
    {
        var repo = new FakeRepository();
        await new TicketFunctions(repo).SearchTickets(RequestWithQuery(), CancellationToken.None);

        Assert.Equal(20, repo.LastSearch!.PageSize);
        Assert.Equal(1, repo.LastSearch.PageNumber);
        Assert.Null(repo.LastSearch.Status);
    }

    [Fact]
    public async Task GetTicket_ReturnsNotFoundWhenMissing()
    {
        var result = await new TicketFunctions(new FakeRepository()).GetTicket(RequestWithQuery(), "inc-000001", CancellationToken.None);

        Assert.IsType<NotFoundObjectResult>(result);
    }

    [Fact]
    public async Task GetTicket_NormalisesTicketNumberToUpperCase()
    {
        var repo = new FakeRepository { Ticket = new TicketDetail { TicketNumber = "INC-000001" } };
        var result = await new TicketFunctions(repo).GetTicket(RequestWithQuery(), "inc-000001", CancellationToken.None);

        Assert.IsType<OkObjectResult>(result);
        Assert.Equal("INC-000001", repo.LastTicketNumber);
    }

    [Fact]
    public async Task CreateTicket_RejectsMissingFields()
    {
        var ctx = new DefaultHttpContext();
        ctx.Request.ContentType = "application/json";
        ctx.Request.Body = new MemoryStream("""{"customerId":0,"title":"","category":""}"""u8.ToArray());

        var result = await new TicketFunctions(new FakeRepository()).CreateTicket(ctx.Request, CancellationToken.None);

        Assert.IsType<BadRequestObjectResult>(result);
    }

    [Fact]
    public async Task CreateTicket_Returns201WithCreatedTicket()
    {
        var repo = new FakeRepository { Ticket = new TicketDetail { TicketNumber = "INC-100001" } };
        var ctx = new DefaultHttpContext();
        ctx.Request.ContentType = "application/json";
        ctx.Request.Body = new MemoryStream("""{"customerId":1,"category":"Hardware","title":"Laptop dead","description":"Will not boot"}"""u8.ToArray());

        var result = await new TicketFunctions(repo).CreateTicket(ctx.Request, CancellationToken.None);

        var created = Assert.IsType<ObjectResult>(result);
        Assert.Equal(201, created.StatusCode);
        Assert.Equal("Medium", repo.LastCreate!.Priority);
    }

    [Fact]
    public async Task RunAsync_MapsSqlErrorNumbersToHttpStatus()
    {
        var notFound = await Api.RunAsync(() => throw SqlExceptionFactory.Create(50001, "Ticket not found."));
        var badRequest = await Api.RunAsync(() => throw SqlExceptionFactory.Create(50002, "Invalid status."));

        Assert.IsType<NotFoundObjectResult>(notFound);
        Assert.IsType<BadRequestObjectResult>(badRequest);
    }

    private sealed class FakeRepository : ITicketRepository
    {
        public TicketDetail? Ticket { get; set; }
        public string? LastTicketNumber { get; private set; }
        public SearchTicketsCriteria? LastSearch { get; private set; }
        public CreateTicketRequest? LastCreate { get; private set; }

        public Task<TicketDetail?> GetTicketAsync(string ticketNumber, CancellationToken ct)
        {
            LastTicketNumber = ticketNumber;
            return Task.FromResult(Ticket);
        }

        public Task<TicketPage> SearchTicketsAsync(SearchTicketsCriteria c, CancellationToken ct)
        {
            LastSearch = c;
            return Task.FromResult(new TicketPage());
        }

        public Task<TicketDetail> CreateTicketAsync(CreateTicketRequest r, CancellationToken ct)
        {
            LastCreate = r;
            return Task.FromResult(Ticket ?? new TicketDetail());
        }

        public Task<IReadOnlyList<TicketComment>> GetCommentsAsync(string ticketNumber, int top, CancellationToken ct) => throw new NotImplementedException();
        public Task<IReadOnlyList<Customer>> SearchCustomersAsync(string? name, string? email, string? company, int top, CancellationToken ct) => throw new NotImplementedException();
        public Task<IReadOnlyList<CustomerTicket>> GetCustomerTicketsAsync(int customerId, string? status, int top, CancellationToken ct) => throw new NotImplementedException();
        public Task<IReadOnlyList<AgentWorkload>> GetAgentWorkloadAsync(int? agentId, string? team, CancellationToken ct) => throw new NotImplementedException();
        public Task<IReadOnlyList<SummaryRow>> GetSummaryAsync(DateTime? from, DateTime? to, string? team, CancellationToken ct) => throw new NotImplementedException();
        public Task<IReadOnlyList<SlaBreach>> GetSlaBreachesAsync(string? priority, int top, CancellationToken ct) => throw new NotImplementedException();
        public Task<TicketDetail> UpdateStatusAsync(string ticketNumber, UpdateTicketStatusRequest r, CancellationToken ct) => throw new NotImplementedException();
    }
}

// SqlException has no public constructor; build one with reflection so error mapping can be tested.
internal static class SqlExceptionFactory
{
    public static SqlException Create(int number, string message)
    {
        var errorCtor = typeof(SqlError).GetConstructors(System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Public)
            .OrderByDescending(c => c.GetParameters().Length).First();
        var args = errorCtor.GetParameters().Select(p =>
            p.ParameterType == typeof(int) ? (object)(p.Name == "infoNumber" ? number : 0) :
            p.ParameterType == typeof(byte) ? (object)(byte)0 :
            p.ParameterType == typeof(string) ? (object)(p.Name == "errorMessage" ? message : "") :
            p.ParameterType == typeof(uint) ? (object)0u :
            p.ParameterType == typeof(Exception) ? null! :
            p.ParameterType.IsValueType ? Activator.CreateInstance(p.ParameterType)! : null!).ToArray();
        var error = (SqlError)errorCtor.Invoke(args);

        var collectionCtor = typeof(SqlErrorCollection).GetConstructors(System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Public)[0];
        var collection = (SqlErrorCollection)collectionCtor.Invoke(null);
        typeof(SqlErrorCollection).GetMethod("Add", System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Public)!.Invoke(collection, [error]);

        var create = typeof(SqlException).GetMethod("CreateException", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic,
            null, [typeof(SqlErrorCollection), typeof(string)], null)!;
        return (SqlException)create.Invoke(null, [collection, "11.0.0"])!;
    }
}
