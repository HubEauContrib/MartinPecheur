using HubEauContrib.MartinPecheur.SharedKernel.Interfaces;
using System.ComponentModel.DataAnnotations.Schema;

namespace HubEauContrib.MartinPecheur.SharedKernel
{
    public class EntityBase
    {
        private readonly List<IDomainEvent> _domainEvents;

        public EntityBase()
        {
            _domainEvents = new List<IDomainEvent>();
        }

        [NotMapped]
        public IReadOnlyList<IDomainEvent> DomainEvents => _domainEvents;
        public Guid Id { get; protected set; }

        public override bool Equals(object? obj)
        {
            var other = obj as EntityBase;

            if(ReferenceEquals(null, other)) 
                return false;
            if (ReferenceEquals(this, other))
                return true;
            if (Id == Guid.Empty || other.Id == Guid.Empty)
                return false;
            return Id.Equals(other.Id);
        }
        public override int GetHashCode()
        {
            return Id.GetHashCode();
        }
        internal void ClearDomainEvents() => _domainEvents.Clear();
        protected virtual void AddDomainEvent(IDomainEvent domainEvent) => _domainEvents.Add(domainEvent);
    }
}
