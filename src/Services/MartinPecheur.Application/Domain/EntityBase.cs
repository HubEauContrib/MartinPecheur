using HubEauContrib.MartinPecheur.Application.Interfaces;
using System.ComponentModel.DataAnnotations.Schema;

namespace HubEauContrib.MartinPecheur.Application.Domain;

public abstract class EntityBase
{
    public Guid Id { get; protected set; }
}
