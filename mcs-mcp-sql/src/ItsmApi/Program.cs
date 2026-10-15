using ItsmApi.Data;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.OpenApi.Extensions;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Abstractions;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Configurations;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.OpenApi.Models;

var host = new HostBuilder()
    .ConfigureFunctionsWebApplication()
    .ConfigureOpenApi()
    .ConfigureServices(services =>
    {
        services.AddApplicationInsightsTelemetryWorkerService();
        services.ConfigureFunctionsApplicationInsights();
        services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
        services.AddSingleton<ITicketRepository, TicketRepository>();
        services.AddSingleton<IOpenApiConfigurationOptions>(_ => new DefaultOpenApiConfigurationOptions
        {
            Info = new OpenApiInfo
            {
                Version = "1.0.0",
                Title = "IT Service Desk API",
                Description = "Search and manage IT support tickets, customers, agents and SLA reports."
            },
            OpenApiVersion = OpenApiVersionType.V3,
            ForceHttps = true,
            IncludeRequestingHostName = true
        });
    })
    .Build();

host.Run();
