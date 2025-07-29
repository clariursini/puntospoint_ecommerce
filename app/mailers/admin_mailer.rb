class AdminMailer < ApplicationMailer

  def first_purchase_notification(admin:, purchase:, product:, customer:, is_creator:)
    @admin = admin
    @purchase = purchase
    @product = product
    @customer = customer
    @is_creator = is_creator
    
    subject = is_creator ? 
      "First purchase of your product #{@product.name}" :
      "New first purchase of the product: #{@product.name}"
    
    mail(
      to: @admin.email,
      subject: subject
    )
  end

  def daily_purchase_report(admin:, report_data:, report_date:)
    @admin = admin
    @report_data = report_data
    @report_date = report_date
    
    mail(
      to: @admin.email,
      subject: "Reporte diario de compras - #{@report_date.strftime('%d/%m/%Y')}"
    )
  end
end 