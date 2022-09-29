using HubEauContrib.MartinPecheur.App.ViewModels;

namespace MartinPecheur.App.Views
{
    public partial class MainPage : ContentPage
    {

        public MainPage(MainViewModel viewModel)
        {
            InitializeComponent();
            BindingContext = viewModel;           
        }
    }
}