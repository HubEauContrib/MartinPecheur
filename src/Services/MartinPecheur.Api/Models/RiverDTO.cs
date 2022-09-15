using HubEauContrib.MartinPecheur.Application.Models;

namespace HubEauContrib.MartinPecheur.Api.Models;

public record RiverDTO(Guid Id, string Name, string Code, string? Image, int Length, string Uri)
{

    public static RiverDTO FromRiver(River river)
    {
        return new RiverDTO(river.Id, river.Name, river.Code, river.Image, river.Length, river.Uri);
    }
}

