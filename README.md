# MartinPecheur

## Configuration de la base de données
* Installer l'outil EF:

    ```
    dotnet tool install --global dotnet-ef    
    ```    

* Migrer la base de données:
    ```
        dotnet ef migrations add InitialCreate --context riverdbcontext -p ../MartinPecheur.Infrastructure/MartinPecheur.Infrastructure.csproj -s MartinPecheur.Api.csproj -o Data/Migrations
    ```

* Mettre à jour la base de données:

    ```
    dotnet ef database update -c riverdbcontext -p ../MartinPecheur.Infrastructure/MartinPecheur.Infrastructure.csproj -s MartinPecheur.Api.csproj
    ```     