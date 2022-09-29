namespace HubEauContrib.MartinPecheur.App.Models;

public class River
{
    public River(Guid id,
                 string name,
                 string code,
                 string uri,
                 int length,
                 string image = null)
    {
        Id = id;
        Name = name;
        Code = code;
        Image = image;
        Length = length;
        Uri = uri;
    }
    public Guid Id { get; private set; }
    public string Name { get; private set; }
    public string Code { get; private set; }
    public string Image { get; private set; }
    public int Length { get; private set; }
    public string Uri { get; private set; }
}