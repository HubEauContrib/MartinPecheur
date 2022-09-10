using HubEauContrib.MartinPecheur.Application.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Query.Internal;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace HubEauContrib.MartinPecheur.Infrastructure.Data
{
    public class RiverDbContext : DbContext
    {
        public RiverDbContext(DbContextOptions options)
            : base(options)
        {

        }

        public DbSet<River> Rivers => Set<River>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);
        }
    }
}
