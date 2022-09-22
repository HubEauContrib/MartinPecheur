namespace HubEauContrib.MartinPecheur.Api
{
    public class HubWorker : BackgroundService
    {
        private readonly ILogger<HubWorker> _logger;

        public HubWorker(ILogger<HubWorker> logger)
        {
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                _logger.LogInformation("Worker running at: {time}", DateTimeOffset.Now);
                await Task.Delay(1000, stoppingToken);
            }
        }
    }
}
