Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
    
    # Configure queues with priorities
    config.queues = %w[critical default reports low]
    
    # Configure scheduler at startup
    config.on(:startup) do
      Rails.logger.info "Configurando Sidekiq Scheduler..."
      
      # Define scheduled jobs
      schedule = {
        'daily_purchase_report' => {
          'cron' => '0 8 * * *',  # Every day at 8:00 AM
          'class' => 'DailyPurchaseReportJob',
          'description' => 'Generate and send daily purchase report to admins'
        }
      }
      
      # Load the schedule
      Sidekiq::Scheduler.schedule = schedule
      Sidekiq::Scheduler.reload_schedule!
      
      Rails.logger.info "Sidekiq Scheduler configurado exitosamente"
      Rails.logger.info "Jobs programados: #{schedule.keys.join(', ')}"
    end
end
  
Sidekiq.configure_client do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# Configure logging level for Sidekiq
Sidekiq.logger.level = Logger::INFO