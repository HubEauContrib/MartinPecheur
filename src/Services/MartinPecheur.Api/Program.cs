using HubEauContrib.MartinPecheur.Api;
using HubEauContrib.MartinPecheur.Api.Models;
using HubEauContrib.MartinPecheur.Application.Models;
using HubEauContrib.MartinPecheur.Infrastructure;
using HubEauContrib.MartinPecheur.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddInfrastructure(builder.Configuration);

builder.Services.AddHostedService<HubWorker>();

// Add services to the container.
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();


var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;

    SeedData.Initialize(services);
}

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();


app.MapGet("/rivers/{id}", async (Guid id, RiverDbContext context) =>
    await context.Rivers.FindAsync(id)
        is River river
        ? Results.Ok(RiverDTO.FromRiver(river))
        : Results.NotFound());

app.MapGet("/rivers", async (RiverDbContext context) =>
{
    var rivers = await context.Rivers.ToListAsync();
    return rivers.Select(r => RiverDTO.FromRiver(r));
});


app.Run();

internal record WeatherForecast(DateTime Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}