require 'rails_helper'

RSpec.describe ProductCategory, type: :model do
  let(:admin) { create(:admin) }
  let(:product) { create(:product, admin: admin) }
  let(:category) { create(:category, admin: admin) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      product_category = build(:product_category, product: product, category: category)
      expect(product_category).to be_valid
    end

    it 'validates uniqueness of product_id scoped to category_id' do
      create(:product_category, product: product, category: category)
      duplicate = build(:product_category, product: product, category: category)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:product_id]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it { should belong_to(:product) }
    it { should belong_to(:category) }
  end

  describe 'callbacks' do
    it 'creates audit log on association' do
      # Contar solo los audit logs de category_associated
      expect {
        create(:product_category, product: product, category: category)
      }.to change { AuditLog.where(action: 'category_associated').count }.by(1)
      
      audit_log = AuditLog.where(action: 'category_associated').last
      expect(audit_log.action).to eq('category_associated')
      expect(audit_log.admin).to eq(admin)
    end

    it 'creates audit log on disassociation' do
      product_category = create(:product_category, product: product, category: category)
      
      # Contar solo los audit logs de category_disassociated
      expect {
        product_category.destroy
      }.to change { AuditLog.where(action: 'category_disassociated').count }.by(1)
      
      audit_log = AuditLog.where(action: 'category_disassociated').last
      expect(audit_log.action).to eq('category_disassociated')
    end
  end
end
