namespace ItsmApi;

public class TicketDetail
{
    public string TicketNumber { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Status { get; set; } = "";
    public string Priority { get; set; } = "";
    public string Category { get; set; } = "";
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = "";
    public string CustomerCompany { get; set; } = "";
    public int? AssignedAgentId { get; set; }
    public string? AssignedAgentName { get; set; }
    public string? Team { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public DateTime DueAt { get; set; }
    public bool IsOverdue { get; set; }
}

public class TicketSummaryItem
{
    public string TicketNumber { get; set; } = "";
    public string Title { get; set; } = "";
    public string Status { get; set; } = "";
    public string Priority { get; set; } = "";
    public string Category { get; set; } = "";
    public int CustomerId { get; set; }
    public string CustomerName { get; set; } = "";
    public string CustomerCompany { get; set; } = "";
    public int? AssignedAgentId { get; set; }
    public string? AssignedAgentName { get; set; }
    public string? Team { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public DateTime DueAt { get; set; }
    public bool IsOverdue { get; set; }
}

public class TicketPage
{
    public int PageNumber { get; set; }
    public int PageSize { get; set; }
    public int TotalCount { get; set; }
    public IReadOnlyList<TicketSummaryItem> Items { get; set; } = [];
}

public class TicketComment
{
    public int CommentId { get; set; }
    public string TicketNumber { get; set; } = "";
    public string AuthorType { get; set; } = "";
    public string AuthorName { get; set; } = "";
    public string Body { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

public class Customer
{
    public int CustomerId { get; set; }
    public string Name { get; set; } = "";
    public string Email { get; set; } = "";
    public string Company { get; set; } = "";
    public string Tier { get; set; } = "";
    public int OpenTickets { get; set; }
}

public class CustomerTicket
{
    public string TicketNumber { get; set; } = "";
    public string Title { get; set; } = "";
    public string Status { get; set; } = "";
    public string Priority { get; set; } = "";
    public string Category { get; set; } = "";
    public string? AssignedAgentName { get; set; }
    public string? Team { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public DateTime? ResolvedAt { get; set; }
    public DateTime DueAt { get; set; }
    public bool IsOverdue { get; set; }
}

public class AgentWorkload
{
    public int AgentId { get; set; }
    public string AgentName { get; set; } = "";
    public string Team { get; set; } = "";
    public int OpenTickets { get; set; }
    public int CriticalTickets { get; set; }
    public int HighTickets { get; set; }
    public int OverdueTickets { get; set; }
    public DateTime? OldestOpenTicketCreatedAt { get; set; }
}

public class SummaryRow
{
    public string Dimension { get; set; } = "";
    public string Name { get; set; } = "";
    public int TicketCount { get; set; }
    public decimal? AvgResolutionHours { get; set; }
}

public class SlaBreach
{
    public string TicketNumber { get; set; } = "";
    public string Title { get; set; } = "";
    public string Status { get; set; } = "";
    public string Priority { get; set; } = "";
    public string Category { get; set; } = "";
    public string CustomerName { get; set; } = "";
    public string CustomerCompany { get; set; } = "";
    public string? AssignedAgentName { get; set; }
    public string? Team { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime DueAt { get; set; }
    public int HoursOverdue { get; set; }
    public int TotalCount { get; set; }
}

public class SearchTicketsCriteria
{
    public string? Status { get; set; }
    public string? Priority { get; set; }
    public string? Category { get; set; }
    public int? AssignedAgentId { get; set; }
    public int? CustomerId { get; set; }
    public DateTime? CreatedFrom { get; set; }
    public DateTime? CreatedTo { get; set; }
    public string? SearchText { get; set; }
    public bool OverdueOnly { get; set; }
    public int PageNumber { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}

public class CreateTicketRequest
{
    public int CustomerId { get; set; }
    public string Category { get; set; } = "";
    public string Title { get; set; } = "";
    public string Description { get; set; } = "";
    public string Priority { get; set; } = "Medium";
}

public class UpdateTicketStatusRequest
{
    public string Status { get; set; } = "";
    public int? AssignedAgentId { get; set; }
    public string? Comment { get; set; }
}

public class ErrorResponse
{
    public string Error { get; set; } = "";
}
