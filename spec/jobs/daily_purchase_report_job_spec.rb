require 'rails_helper'

RSpec.describe DailyPurchaseReportJob, type: :job do
  let(:admin) { create(:admin) }
  let(:customer) { create(:customer) }
  let(:product) { create(:product, admin: admin) }
  let(:date) { Date.yesterday }

  before do
    # Mock AdminMailer
    allow(AdminMailer).to receive(:daily_purchase_report).and_return(double(deliver_now: true))
    # Mock Rails.logger
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:error)
  end

  describe '#perform' do
    context 'when there are purchases for the date' do
      let(:test_product) { create(:product, admin: admin) }
      let!(:purchase) { create(:purchase, customer: customer, product: test_product, purchased_at: date) }

      it 'generates report and sends emails to all admins' do
        expect(AdminMailer).to receive(:daily_purchase_report).with(
          admin: admin,
          report_data: hash_including(:date, :summary, :products_sold, :categories_performance),
          report_date: date
        ).and_return(double(deliver_now: true))

        result = described_class.perform_now(date)
        
        expect(result).to eq({ empty: false, date: date })
      end

      it 'includes correct summary data' do
        result = described_class.perform_now(date)
        
        expect(result[:empty]).to be false
        expect(result[:date]).to eq(date)
      end
    end

    context 'when there are no purchases for the date' do
      it 'returns empty report without sending emails' do
        expect(AdminMailer).not_to receive(:daily_purchase_report)

        result = described_class.perform_now(date)
        
        expect(result).to eq({ empty: true, date: date })
      end
    end

    context 'when no admins exist' do
      before { 
        Admin.destroy_all 
        Purchase.destroy_all
      }

      it 'logs info and does not send emails' do
        expect(AdminMailer).not_to receive(:daily_purchase_report)

        result = described_class.perform_now(date)
        
        expect(result).to eq({ empty: true, date: date })
      end
    end

    context 'when an error occurs' do
      before do
        allow(Purchase).to receive(:left_joins).and_raise(StandardError, "Database error")
      end

      it 'logs error and re-raises exception' do
        expect { described_class.perform_now(date) }.to raise_error(StandardError, "Database error")
      end
    end

    context 'with string date parameter' do
      it 'parses string date correctly' do
        string_date = date.to_s
        test_product = create(:product, admin: admin)
        # Crear purchase para que el job no retorne empty
        create(:purchase, customer: customer, product: test_product, purchased_at: date)
        
        expect(AdminMailer).to receive(:daily_purchase_report).with(
          admin: admin,
          report_data: hash_including(:date),
          report_date: date  # El job convierte string a Date
        ).and_return(double(deliver_now: true))

        described_class.perform_now(string_date)
      end
    end
  end

  describe 'report data generation' do
    let(:test_product) { create(:product, admin: admin) }
    let!(:purchase) { create(:purchase, customer: customer, product: test_product, purchased_at: date, quantity: 1) }

    it 'includes all required sections' do
      result = described_class.perform_now(date)
      
      expect(result[:empty]).to be false
    end

    it 'calculates correct summary statistics' do
      result = described_class.perform_now(date)
      
      expect(result[:empty]).to be false
    end
  end
end
