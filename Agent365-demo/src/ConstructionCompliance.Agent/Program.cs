using ConstructionCompliance.Agent.Adapters;
using ConstructionCompliance.Agent.Models;
using ConstructionCompliance.Agent.Routing;
using ConstructionCompliance.Agent.Services;
using ConstructionCompliance.Agent.Skills;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IIntentResolver, KeywordIntentResolver>();
builder.Services.AddSingleton<IJurisdictionResolverSkill, MockJurisdictionResolverSkill>();
builder.Services.AddSingleton<IRegulationRetrievalSkill, MockRegulationRetrievalSkill>();
builder.Services.AddSingleton<IConstraintEngineSkill, MockConstraintEngineSkill>();
builder.Services.AddSingleton<IDesignCheckerSkill, MockDesignCheckerSkill>();
builder.Services.AddSingleton<ICitationAuditSkill, StrictCitationAuditSkill>();
builder.Services.AddSingleton<ConstructionComplianceAgentService>();
builder.Services.AddSingleton<IAgent365RegistrationProvider, Agent365RegistrationProvider>();

var app = builder.Build();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

app.MapGet("/api/agent365/registration", (IAgent365RegistrationProvider provider) => Results.Ok(provider.GetRegistrationPayload()));

app.MapPost("/api/agent/invoke", async (AgentRequest request, ConstructionComplianceAgentService service, CancellationToken cancellationToken) =>
{
	var response = await service.ProcessAsync(request, cancellationToken);
	return Results.Ok(response);
});

app.Run();
