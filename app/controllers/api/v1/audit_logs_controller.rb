class Api::V1::AuditLogsController < ApplicationController
  before_action :authenticate_admin!
  
  # GET /api/v1/audit_logs
  def index
    @audit_logs = AuditLog.includes(:admin, :auditable)
                         .order(created_at: :desc)
                         .page(params[:page])
                         .per(params[:per_page] || 10)
    
    render_success({
      audit_logs: @audit_logs.map { |log| serialize_audit_log(log) },
      pagination: pagination_meta(@audit_logs)
    }, 'Audit logs retrieved successfully')
  end
  
  # GET /api/v1/audit_logs/recent
  def recent
    @audit_logs = AuditLog.includes(:admin, :auditable)
                         .where('created_at >= ?', 1.hour.ago)
                         .order(created_at: :desc)
                         .limit(20)
    
    render_success({
      audit_logs: @audit_logs.map { |log| serialize_audit_log(log) },
      total_count: @audit_logs.count,
      time_range: 'Last hour'
    }, 'Recent audit logs retrieved successfully')
  end
  
  # GET /api/v1/audit_logs/by_entity/:entity_type/:entity_id
  def by_entity
    entity_type = params[:entity_type].classify
    entity_id = params[:entity_id]
    
    @audit_logs = AuditLog.includes(:admin)
                         .where(auditable_type: entity_type, auditable_id: entity_id)
                         .order(created_at: :desc)
    
    render_success({
      audit_logs: @audit_logs.map { |log| serialize_audit_log(log) },
      entity_type: entity_type,
      entity_id: entity_id,
      total_count: @audit_logs.count
    }, "Audit logs for #{entity_type} #{entity_id} retrieved successfully")
  end
  
  private
  
  def serialize_audit_log(log)
    {
      id: log.id,
      action: log.action,
      admin: {
        id: log.admin&.id,
        name: log.admin&.name
      },
      auditable: {
        type: log.auditable_type,
        id: log.auditable_id,
        name: get_auditable_name(log)
      },
      changes_data: log.changes_data,
      created_at: log.created_at
    }
  end
  
  def get_auditable_name(log)
    case log.auditable_type
    when 'Product'
      log.auditable&.name
    when 'Category'
      log.auditable&.name
    when 'Customer'
      log.auditable&.name
    when 'Purchase'
      "Purchase ##{log.auditable_id}"
    when 'ProductCategory'
      "Product #{log.auditable&.product&.name} - Category #{log.auditable&.category&.name}"
    else
      "#{log.auditable_type} ##{log.auditable_id}"
    end
  rescue
    "#{log.auditable_type} ##{log.auditable_id}"
  end
  
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end 