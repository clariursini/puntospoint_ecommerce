class DailyPurchaseReportJob < ApplicationJob
  queue_as :reports

  def perform(date = Date.yesterday)
    report_date = date.is_a?(String) ? Date.parse(date) : date

    # Get all purchases of the previous day
    purchases = Purchase.left_joins(:product, :customer, product: [:admin, :categories])
                       .where(purchased_at: report_date.beginning_of_day..report_date.end_of_day)
    
    return { empty: true, date: date } if purchases.empty?
    
    # Generate report
    report_data = generate_report_data(purchases, report_date)
    
    # Get all admins
    admins = Admin.all
    
    # Send report to all admins
    if admins.count > 0
      admins.each do |admin|
        AdminMailer.daily_purchase_report(
          admin: admin,
          report_data: report_data,
          report_date: report_date
        ).deliver_now
      end
    else
      Rails.logger.info "Daily Purchase Report Job: No admins found"
    end

    Rails.logger.info "Daily Purchase Report Job: Report sent to #{admins.count} admins for #{report_date}"

    { empty: false, date: date }
  rescue StandardError => e
    Rails.logger.error "Daily Purchase Report Job: Error generating report for #{report_date} - #{e.message}"
    raise e
  end
  
  private
  
  def generate_report_data(purchases, report_date)
    {
      date: report_date,
      summary: {
        total_purchases: purchases.count,
        total_revenue: purchases.sum(:total_price).to_f,
        unique_customers: purchases.distinct.count(:customer_id),
        unique_products: purchases.distinct.count(:product_id)
      },
      products_sold: generate_products_summary(purchases),
      categories_performance: generate_categories_summary(purchases),
      administrators_performance: generate_administrators_summary(purchases),
      top_customers: generate_customers_summary(purchases)
    }
  end

  def generate_products_summary(purchases)
    purchases.joins(:product)
             .group('products.id', 'products.name', 'products.price')
             .select('
               products.id,
               products.name,
               products.price,
               SUM(purchases.quantity) as total_quantity,
               SUM(purchases.total_price) as total_revenue,
               COUNT(purchases.id) as purchase_count
             ')
             .order('total_revenue DESC')
             .limit(20) # Top 20 productos
             .map do |product|
               {
                 product_id: product.id,
                 product_name: product.name,
                 unit_price: product.price.to_f,
                 quantity_sold: product.total_quantity,
                 total_revenue: product.total_revenue.to_f,
                 purchase_count: product.purchase_count
               }
             end
  end
  
  def generate_categories_summary(purchases)
    purchases.joins(product: :categories)
             .group('categories.id', 'categories.name')
             .select('
               categories.id,
               categories.name,
               SUM(purchases.quantity) as total_quantity,
               SUM(purchases.total_price) as total_revenue,
               COUNT(purchases.id) as purchase_count
             ')
             .order('total_revenue DESC')
             .map do |category|
               {
                 category_id: category.id,
                 category_name: category.name,
                 quantity_sold: category.total_quantity,
                 total_revenue: category.total_revenue.to_f,
                 purchase_count: category.purchase_count
               }
             end
  end
  
  def generate_administrators_summary(purchases)
    purchases.joins(product: :admin)
             .group('admins.id', 'admins.name')
             .select('
               admins.id,
               admins.name,
               SUM(purchases.quantity) as total_quantity,
               SUM(purchases.total_price) as total_revenue,
               COUNT(purchases.id) as purchase_count
             ')
             .order('total_revenue DESC')
             .map do |admin|
               {
                 administrator_id: admin.id,
                 administrator_name: admin.name,
                 quantity_sold: admin.total_quantity,
                 total_revenue: admin.total_revenue.to_f,
                 purchase_count: admin.purchase_count
               }
             end
  end
  
  def generate_customers_summary(purchases)
    purchases.joins(:customer)
             .group('customers.id', 'customers.name', 'customers.email')
             .select('
               customers.id,
               customers.name,
               customers.email,
               SUM(purchases.quantity) as total_quantity,
               SUM(purchases.total_price) as total_spent,
               COUNT(purchases.id) as purchase_count
             ')
             .order('total_spent DESC')
             .limit(10) # Top 10 clientes del día
             .map do |customer|
               {
                 customer_id: customer.id,
                 customer_name: customer.name,
                 customer_email: customer.email,
                 quantity_purchased: customer.total_quantity,
                 total_spent: customer.total_spent.to_f,
                 purchase_count: customer.purchase_count
               }
             end
  end
end
