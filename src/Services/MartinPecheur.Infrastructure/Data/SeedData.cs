using HubEauContrib.MartinPecheur.Application.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

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
                new River(Guid.Parse("49F1C5FA-96D6-4562-8015-CF0510EAA96D"), "La Loire", "----0000", "https://www.sandre.eaufrance.fr/geo/CoursEau_Carthage2017/----0000", 1006, "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0d/LoireAChamptoceaux.jpg/320px-LoireAChamptoceaux.jpg"),
                new River(Guid.Parse("1E469B92-905D-4301-AB78-26F1CCC4A332"), "La Seine", "----0010", "https://www.sandre.eaufrance.fr/geo/CoursEau_Carthage2017/----0010", 775, ""));

            context.SaveChanges();

        }
    }
}
