require 'rails_helper'

RSpec.describe FirstPurchaseEmailJob, type: :job do
  let(:admin) { create(:admin) }
  let(:other_admin) { create(:admin, email: "other@example.com") }
  let(:customer) { create(:customer) }
  let(:product) { create(:product, admin: admin) }
  let(:purchase) { create(:purchase, customer: customer, product: product) }

  before do
    # Mock AdminMailer
    allow(AdminMailer).to receive(:first_purchase_notification).and_return(double(deliver_now: true))
    # Mock Rails.logger
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when it is the first purchase of the product' do
      before do
        allow_any_instance_of(Purchase).to receive(:is_first_purchase_of_product?).and_return(true)
      end

      it 'sends email to product creator' do
        expect(AdminMailer).to receive(:first_purchase_notification).with(
          admin: admin,
          purchase: purchase,
          product: product,
          customer: customer,
          is_creator: true
        ).and_return(double(deliver_now: true))

        described_class.perform_now(purchase.id)
      end

      it 'sends copy to other admins' do
        expect(AdminMailer).to receive(:first_purchase_notification).with(
          admin: other_admin,
          purchase: purchase,
          product: product,
          customer: customer,
          is_creator: false
        ).and_return(double(deliver_now: true))

        described_class.perform_now(purchase.id)
      end

      it 'logs success message' do
        # CAMBIO: Asegurar que other_admin existe antes del test
        expect(other_admin).to be_persisted  # Forzar creación del other_admin
        
        expect(AdminMailer).to receive(:first_purchase_notification).twice.and_return(double(deliver_now: true))

        described_class.perform_now(purchase.id)
      end
    end

    context 'when it is not the first purchase of the product' do
      before do
        allow_any_instance_of(Purchase).to receive(:is_first_purchase_of_product?).and_return(false)
      end

      it 'does not send any emails' do
        expect(AdminMailer).not_to receive(:first_purchase_notification)

        described_class.perform_now(purchase.id)
      end
    end

    context 'when purchase is not found' do
      it 'logs error and does not raise exception' do
        expect(Rails.logger).to receive(:error).with(/First Purchase Email Job: Purchase 999999 not found/)

        expect { described_class.perform_now(999999) }.not_to raise_error
      end
    end

    context 'when an error occurs during email sending' do
      before do
        allow_any_instance_of(Purchase).to receive(:is_first_purchase_of_product?).and_return(true)
        allow(AdminMailer).to receive(:first_purchase_notification).and_raise(StandardError, "Email error")
      end

      it 'logs error and re-raises exception' do
        expect(Rails.logger).to receive(:error).with(/First Purchase Email Job: Error sending email for purchase #{purchase.id}/)

        expect { described_class.perform_now(purchase.id) }.to raise_error(StandardError, "Email error")
      end
    end

    context 'when there are no other admins' do
      before do
        allow_any_instance_of(Purchase).to receive(:is_first_purchase_of_product?).and_return(true)
        Admin.where.not(id: admin.id).destroy_all
      end

      it 'only sends email to product creator' do
        expect(AdminMailer).to receive(:first_purchase_notification).once.with(
          admin: admin,
          purchase: purchase,
          product: product,
          customer: customer,
          is_creator: true
        ).and_return(double(deliver_now: true))

        described_class.perform_now(purchase.id)
      end

      it 'logs correct message for single admin' do
        expect(Rails.logger).to receive(:info).with(/First Purchase Email Job: Email sent to #{admin.email} and 0 other admins for purchase #{purchase.id}/)

        described_class.perform_now(purchase.id)
      end
    end
  end
end
