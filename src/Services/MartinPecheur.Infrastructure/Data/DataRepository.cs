using Ardalis.Specification;
using Ardalis.Specification.EntityFrameworkCore;
using HubEauContrib.MartinPecheur.Application.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace HubEauContrib.MartinPecheur.Infrastructure.Data
{
    internal class DataRepository<T> : RepositoryBase<T>, IReadRepository<T>, IRepository<T>
        where T : class, IAggregateRoot
    {
        public DataRepository(RiverDbContext dbContext)
            :  base(dbContext)

        {

        }
    }
}
