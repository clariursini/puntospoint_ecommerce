class FirstPurchaseEmailJob < ApplicationJob
  queue_as :default

  def perform(purchase_id)
    purchase = Purchase.find(purchase_id)
    
    # Verify if it is the first purchase of the customer
    return unless purchase.is_first_purchase_of_product?

    product = purchase.product
    customer = purchase.customer
    product_creator = product.admin

    # Get all admins except the product creator
    other_admins = Admin.where.not(id: product_creator.id) 
    
    # Send email to the product creator
    AdminMailer.first_purchase_notification(
      admin: product_creator,
      purchase: purchase,
      product: product,
      customer: customer,
      is_creator: true
    ).deliver_now

    # Send copy to other admins
    other_admins.each do |admin|
      AdminMailer.first_purchase_notification(
        admin: admin,
        purchase: purchase,
        product: product,
        customer: customer,
        is_creator: false
      ).deliver_now
    end

    Rails.logger.info "First Purchase Email Job: Email sent to #{product_creator.email} and #{other_admins.count} other admins for purchase #{purchase_id}"
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "First Purchase Email Job: Purchase #{purchase_id} not found - #{e.message}"
  rescue StandardError => e
    Rails.logger.error "First Purchase Email Job: Error sending email for purchase #{purchase_id} - #{e.message}"
    raise e
  end
end
