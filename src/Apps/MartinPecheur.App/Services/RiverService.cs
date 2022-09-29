using HubEauContrib.MartinPecheur.App.Models;

namespace HubEauContrib.MartinPecheur.App.Services;

public class RiverService
{
    public List<River> List()
    {
        return new List<River>
        {
            new(Guid.Parse("93400BF9-6C41-46E1-8D62-EE143A08804E"), "Le Doubs", "U2--0200", "https://www.sandre.eaufrance.fr/geo/CoursEau_Carthage2017/U2--0200", 453, "https://upload.wikimedia.org/wikipedia/commons/c/cc/Doubs_Laissey.jpghttps://upload.wikimedia.org/wikipedia/commons/c/cc/Doubs_Laissey.jpg")
        };
    }
}
