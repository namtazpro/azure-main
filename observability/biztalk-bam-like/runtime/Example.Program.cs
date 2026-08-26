// Agentic BAM - Example: Registering the interceptor with Microsoft Agent Framework
// This shows how a developer wires up BAM in their agent host Program.cs
// WITHOUT modifying any agent code.

using Microsoft.Agents.Builder;
using Microsoft.Agents.Builder.App;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using AgenticBam.Runtime;

var builder = Host.CreateApplicationBuilder(args);

// ─── Register your agents (normal setup, unaware of BAM) ──────────────────

builder.Services.AddAgents(agents =>
{
    // These are Azure AI Foundry agents orchestrated by Microsoft Agent Framework
    agents.AddAgent<IntakeAgent>("IntakeAgent");
    agents.AddAgent<ValidationAgent>("ValidationAgent");
    agents.AddAgent<CreditCheckAgent>("CreditCheckAgent");
    agents.AddAgent<ApprovalAgent>("ApprovalAgent");
    agents.AddAgent<FulfilmentAgent>("FulfilmentAgent");
    agents.AddAgent<InvoiceAgent>("InvoiceAgent");
});

// ─── Register Agentic BAM (one line — agents remain unaware) ──────────────

builder.Services.AddAgenticBam(options =>
{
    // Point to the YAML definitions and profiles
    options.DefinitionsPath = "./definitions";
    options.TrackingProfilesPath = "./tracking-profiles";

    // BAM activity store connection
    options.ActivityStoreConnectionString =
        builder.Configuration.GetConnectionString("BamActivityStore")!;

    // Enable correlation token propagation via agent context metadata
    options.EnableContextPropagation = true;
});

// ─── Register the BAM interceptor in the agent middleware pipeline ─────────

builder.Services.AddAgentMiddleware(pipeline =>
{
    // BAM interceptor runs AFTER the agent completes — it never interferes
    // with agent execution, just observes the result.
    pipeline.UseAfterTurn<BamInterceptorMiddleware>();
});

var app = builder.Build();
await app.RunAsync();

// ═══════════════════════════════════════════════════════════════════════════
// Notes:
//
// 1. The agents (IntakeAgent, ValidationAgent, etc.) are standard
//    Microsoft Agent Framework agents backed by Azure AI Foundry.
//    They can be prompt-based or hosted agents with tools.
//
// 2. The BAM interceptor middleware runs in the "after turn" pipeline
//    position — it fires after each agent completes a turn, reads the
//    agent's output, and if a tracking profile binding matches, writes
//    the milestone to the activity store.
//
// 3. If BAM fails (DB down, config error), the business process
//    continues unaffected. BAM is purely observational.
//
// 4. Multiple activities can be tracked simultaneously. If you add a
//    "Shipment" activity later, just add a new .activity.yaml and
//    .profile.yaml — no agent code changes needed.
//
// 5. The correlation token propagates automatically through the agent
//    framework's context metadata, so downstream agents in the same
//    orchestration don't need explicit token passing.
// ═══════════════════════════════════════════════════════════════════════════
