using HubEauContrib.MartinPecheur.Application.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace HubEauContrib.MartinPecheur.Infrastructure.Data;

public static class SeedData
{
    public static void Initialize(IServiceProvider serviceProvider)
    {
        using (var context = new RiverDbContext(
            serviceProvider.GetRequiredService<
                DbContextOptions<RiverDbContext>>()))
        {
            if (context.Rivers.Any())
                return;

            context.Rivers.AddRange(
                new River(Guid.NewGuid(), "La Loire", "----0000", "https://www.sandre.eaufrance.fr/geo/CoursEau_Carthage2017/----0000"));          

        }
    }
}
