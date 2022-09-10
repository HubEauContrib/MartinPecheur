using HubEauContrib.MartinPecheur.SharedKernel;
using HubEauContrib.MartinPecheur.SharedKernel.Interfaces;

namespace HubEauContrib.MartinPecheur.Application.Models
{
    public class River : EntityBase, IAggregateRoot
    {
        public River(Guid id,
                     string name,
                     string code,
                     string uri,
                     string? image = null)
        {
            Id = id;
            Name = name;
            Code = code;
            Image = image;
            Uri = uri;
        }

        public string Name { get; private set; }
        public string Code { get; private set; }
        public string? Image { get; private set; }
        public int Length { get; private set; }
        public string Uri { get; private set; }
    }
}
