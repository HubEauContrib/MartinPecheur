using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using HubEauContrib.MartinPecheur.App.Models;
using HubEauContrib.MartinPecheur.App.Services;
using System.Collections.ObjectModel;

namespace HubEauContrib.MartinPecheur.App.ViewModels;

public partial class MainViewModel : ObservableObject
{
    private RiverService _riverService;

    public MainViewModel(RiverService riverService)
    { 
        _riverService = riverService;
    }

    public ObservableCollection<River> Rivers { get; } = new();

    [RelayCommand]
    public void ListRivers()
    {
        var rivers = _riverService.List();

        if (Rivers.Count != 0)
            Rivers.Clear();

        foreach (var river in rivers)
            Rivers.Add(river);
    }
}
