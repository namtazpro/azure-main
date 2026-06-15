FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY src/ConstructionCompliance.Agent/ConstructionCompliance.Agent.csproj src/ConstructionCompliance.Agent/
RUN dotnet restore src/ConstructionCompliance.Agent/ConstructionCompliance.Agent.csproj

COPY . .
RUN dotnet publish src/ConstructionCompliance.Agent/ConstructionCompliance.Agent.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

ENV ASPNETCORE_URLS=http://0.0.0.0:8080
EXPOSE 8080

COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "ConstructionCompliance.Agent.dll"]
