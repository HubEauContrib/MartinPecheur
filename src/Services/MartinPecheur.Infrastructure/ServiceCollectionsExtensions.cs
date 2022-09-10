using HubEauContrib.MartinPecheur.Infrastructure.Data;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace HubEauContrib.MartinPecheur.Infrastructure;

public static class ServiceCollectionsExtensions
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection serviceCollection, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("RiverDb");
        serviceCollection.AddSqlite<RiverDbContext>(connectionString);
        return serviceCollection;
    }
}
