class Api::V1::SchedulerController < ApplicationController
  
  # GET /api/v1/scheduler/status
  def status
    render_success({
      scheduler_enabled: sidekiq_status,
      scheduled_jobs: scheduled_jobs_count,
      next_runs: get_next_runs,
      sidekiq_stats: sidekiq_status,
      queue_stats: queue_stats,
      worker_stats: worker_stats
    }, 'Scheduler status')
  end
  
  # POST /api/v1/scheduler/trigger_daily_report
  def trigger_daily_report
    date = params[:date] ? Date.parse(params[:date]) : Date.yesterday
    
    # Enqueue the job
    DailyPurchaseReportJob.perform_later(date)
    
    render_success({
      date: date,
      status: "queued"
    }, 'Daily purchase report job enqueued')
  rescue StandardError => e
    render_error("Failed to enqueue daily report job: #{e.message}")
  end
  
  # POST /api/v1/scheduler/trigger_first_purchase_test
  def trigger_first_purchase_test
    purchase_id = params[:purchase_id]
    
    unless purchase_id
      return render_error("purchase_id parameter is required", nil, :bad_request)
    end
    
    # Enqueue the job
    purchase = Purchase.find(purchase_id)
    FirstPurchaseEmailJob.perform_later(purchase)
    
    render_success({
      purchase_id: purchase_id,
      status: "queued"
    }, 'First purchase email job enqueued')
    rescue ActiveRecord::RecordNotFound
    render_error("Purchase not found", nil, :not_found)
  rescue StandardError => e
    render_error("Failed to enqueue first purchase email job: #{e.message}", nil, :unprocessable_entity)
  end
  
  private

  def get_next_runs
    next_runs = {}
    
    # Check if sidekiq-scheduler is configured
    if defined?(Sidekiq::Scheduler) && Sidekiq::Scheduler.respond_to?(:schedule)
      schedule = Sidekiq::Scheduler.schedule
      
      schedule.each do |name, config|
        if config['cron']
          begin
            cron = Chronic::Parser.new.parse(config['cron'])
            next_runs[name] = cron&.next_time&.to_s
          rescue
            next_runs[name] = 'Error parsing cron'
          end
        end
      end
    else
      next_runs = { 'info' => 'Sidekiq scheduler not configured' }
    end
    
    next_runs
  end
  
  def sidekiq_status
    begin
      # Check if Sidekiq is running
      stats = Sidekiq::Stats.new
      {
        running: true,
        processed: stats.processed,
        failed: stats.failed,
        scheduled: stats.scheduled_size,
        retry: stats.retry_size,
        dead: stats.dead_size
      }
    rescue => e
      {
        running: false,
        error: e.message
      }
    end
  end
  
  def queue_stats
    begin
      stats = Sidekiq::Stats.new
      {
        default: stats.queues["default"] || 0,
        reports: stats.queues["reports"] || 0,
        critical: stats.queues["critical"] || 0,
        low: stats.queues["low"] || 0
      }
    rescue => e
      {
        error: e.message
      }
    end
  end
  
  def worker_stats
    begin
      workers = Sidekiq::Workers.new
      {
        total_workers: workers.size,
        busy_workers: workers.count { |_, _, work| work }
      }
    rescue => e
      {
        error: e.message
      }
    end
  end
  
  def scheduled_jobs_count
    begin
      Sidekiq::ScheduledSet.new.size
    rescue => e
      0
    end
  end
end 