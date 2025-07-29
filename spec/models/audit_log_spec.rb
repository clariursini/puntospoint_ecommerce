require 'rails_helper'

RSpec.describe AuditLog, type: :model do
  let(:admin) { create(:admin) }
  let(:product) { create(:product, admin: admin) }
  let(:category) { create(:category, admin: admin) }

  describe 'validations' do
    it 'is valid with valid attributes' do
      audit_log = build(:audit_log, admin: admin, auditable: product)
      expect(audit_log).to be_valid
    end

    it 'requires action to be present' do
      audit_log = build(:audit_log, action: nil, admin: admin, auditable: product)
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:action]).to include("can't be blank")
    end

    it 'requires action to be in allowed list' do
      audit_log = build(:audit_log, action: 'invalid_action', admin: admin, auditable: product)
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:action]).to include('is not included in the list')
    end

    it 'accepts valid actions' do
      valid_actions = %w[created updated deleted category_associated category_disassociated]
      valid_actions.each do |action|
        audit_log = build(:audit_log, action: action, admin: admin, auditable: product)
        expect(audit_log).to be_valid, "#{action} should be a valid action"
      end
    end

    it 'requires changes_data to be present' do
      audit_log = build(:audit_log, changes_data: nil, admin: admin, auditable: product)
      expect(audit_log).not_to be_valid
      expect(audit_log.errors[:changes_data]).to include("can't be blank")
    end

    it 'accepts empty changes_data as valid JSON' do
      audit_log = build(:audit_log, changes_data: '{}', admin: admin, auditable: product)
      expect(audit_log).to be_valid
    end
  end

  describe 'associations' do
    it { should belong_to(:admin) }
    it { should belong_to(:auditable) }

    it 'can be associated with different auditable types' do
      product_log = create(:audit_log, admin: admin, auditable: product)
      category_log = create(:audit_log, admin: admin, auditable: category)
      
      expect(product_log.auditable).to eq(product)
      expect(product_log.auditable_type).to eq('Product')
      
      expect(category_log.auditable).to eq(category)
      expect(category_log.auditable_type).to eq('Category')
    end
  end

  describe 'scopes' do
    let!(:product_created_log) { create(:audit_log, action: 'created', admin: admin, auditable: product) }
    let!(:product_updated_log) { create(:audit_log, action: 'updated', admin: admin, auditable: product) }
    let!(:category_created_log) { create(:audit_log, action: 'created', admin: admin, auditable: category) }
    let(:another_admin) { create(:admin, email: 'another@example.com') }
    let!(:other_admin_log) { create(:audit_log, action: 'created', admin: another_admin, auditable: product) }

    describe '.by_action' do
      it 'returns audit logs filtered by action' do
        created_logs = AuditLog.by_action('created')
        expect(created_logs).to include(product_created_log, category_created_log, other_admin_log)
        expect(created_logs).not_to include(product_updated_log)
      end

      it 'returns empty collection for non-existent action' do
        logs = AuditLog.by_action('non_existent')
        expect(logs).to be_empty
      end
    end

    describe '.by_auditable_type' do
      it 'returns audit logs filtered by auditable type' do
        product_logs = AuditLog.by_auditable_type('Product')
        expect(product_logs).to include(product_created_log, product_updated_log, other_admin_log)
        expect(product_logs).not_to include(category_created_log)
      end

      it 'returns audit logs for Category type' do
        category_logs = AuditLog.by_auditable_type('Category')
        expect(category_logs).to include(category_created_log)
        expect(category_logs).not_to include(product_created_log, product_updated_log)
      end
    end

    describe '.by_admin' do
      it 'returns audit logs filtered by admin' do
        admin_logs = AuditLog.by_admin(admin.id)
        expect(admin_logs).to include(product_created_log, product_updated_log, category_created_log)
        expect(admin_logs).not_to include(other_admin_log)
      end

      it 'returns logs for different admin' do
        other_logs = AuditLog.by_admin(another_admin.id)
        expect(other_logs).to include(other_admin_log)
        expect(other_logs).not_to include(product_created_log)
      end
    end

    describe '.recent' do
      let!(:old_log) { create(:audit_log, admin: admin, auditable: product, created_at: 1.week.ago) }
      let!(:new_log) { create(:audit_log, admin: admin, auditable: product, created_at: 1.hour.ago) }

      it 'returns audit logs ordered by created_at desc' do
        recent_logs = AuditLog.recent
        expect(recent_logs.first.created_at).to be > recent_logs.last.created_at
      end

      it 'has newest log first' do
        recent_logs = AuditLog.recent
        # Verificar que el más reciente esté primero
        expect(recent_logs.first.created_at).to be > recent_logs.second.created_at
      end
    end
  end

  describe 'instance methods' do
    describe '#changes_hash' do
      context 'with valid JSON in changes_data' do
        it 'parses and returns the changes as a hash' do
          changes_data = { name: ['Old Name', 'New Name'], price: [100, 150] }.to_json
          audit_log = create(:audit_log, 
            admin: admin, 
            auditable: product, 
            changes_data: changes_data
          )
          
          expected_hash = { 'name' => ['Old Name', 'New Name'], 'price' => [100, 150] }
          expect(audit_log.changes_hash).to eq(expected_hash)
        end

        it 'handles complex nested data' do
          changes_data = { 
            user: { name: 'John', email: 'john@example.com' },
            settings: { theme: 'dark', notifications: true }
          }.to_json
          
          audit_log = create(:audit_log, 
            admin: admin, 
            auditable: product, 
            changes_data: changes_data
          )
          
          result = audit_log.changes_hash
          expect(result['user']['name']).to eq('John')
          expect(result['settings']['theme']).to eq('dark')
        end
      end

      context 'with invalid JSON in changes_data' do
        it 'returns empty hash when JSON is invalid' do
          audit_log = create(:audit_log, 
            admin: admin, 
            auditable: product, 
            changes_data: 'invalid json {'
          )
          
          expect(audit_log.changes_hash).to eq({})
        end

        it 'handles malformed JSON gracefully' do
          audit_log = create(:audit_log, 
            admin: admin, 
            auditable: product, 
            changes_data: '{"name": "incomplete'
          )
          
          expect(audit_log.changes_hash).to eq({})
        end
      end

      context 'with empty changes_data' do
        it 'returns empty hash for empty JSON object' do
          audit_log = create(:audit_log, 
            admin: admin, 
            auditable: product, 
            changes_data: '{}'
          )
          
          expect(audit_log.changes_hash).to eq({})
        end

        it 'returns empty hash for null values' do
          audit_log = create(:audit_log, 
            admin: admin, 
            auditable: product, 
            changes_data: 'null'
          )
          
          expect(audit_log.changes_hash).to eq({})
        end
      end
    end

    describe '#formatted_changes' do
      it 'formats changes as readable string' do
        changes_data = { 
          name: ['Old Product', 'New Product'], 
          price: [100, 150],
          stock: [10, 20]
        }.to_json
        
        audit_log = create(:audit_log, 
          admin: admin, 
          auditable: product,
          changes_data: changes_data
        )
        
        formatted = audit_log.formatted_changes
        expect(formatted).to be_a(String)
        expect(formatted).to include('name:')
        expect(formatted).to include('price:')
        expect(formatted).to include('stock:')
      end

      it 'returns empty string when no changes' do
        audit_log = create(:audit_log, 
          admin: admin, 
          auditable: product, 
          changes_data: '{}'
        )
        
        expect(audit_log.formatted_changes).to eq('')
      end

      it 'handles single change' do
        changes_data = { name: ['Old Name', 'New Name'] }.to_json
        audit_log = create(:audit_log, 
          admin: admin, 
          auditable: product, 
          changes_data: changes_data
        )
        
        formatted = audit_log.formatted_changes
        expect(formatted).to eq('name: ["Old Name", "New Name"]')
      end

      it 'handles boolean and numeric values' do
        changes_data = { 
          active: [true, false], 
          count: [0, 5],
          price: [99.99, 149.99]
        }.to_json
        
        audit_log = create(:audit_log, 
          admin: admin, 
          auditable: product,
          changes_data: changes_data
        )
        
        formatted = audit_log.formatted_changes
        expect(formatted).to include('active: ["true", "false"]')
        expect(formatted).to include('count: ["0", "5"]')
        expect(formatted).to include('price: ["99.99", "149.99"]')
      end

      it 'handles nil values gracefully' do
        changes_data = { 
          description: [nil, 'New Description'], 
          category: ['Old Category', nil]
        }.to_json
        
        audit_log = create(:audit_log, 
          admin: admin, 
          auditable: product,
          changes_data: changes_data
        )
        
        formatted = audit_log.formatted_changes
        expect(formatted).to include('description: ["", "New Description"]')
        expect(formatted).to include('category: ["Old Category", ""]')
      end
    end
  end

  describe 'integration with models' do
    it 'is created automatically when product is created' do
      Current.admin = admin
      
      expect {
        create(:product, admin: admin)
      }.to change(AuditLog, :count).by(1)
      
      audit_log = AuditLog.last
      expect(audit_log.action).to eq('created')
      expect(audit_log.admin).to eq(admin)
      expect(audit_log.auditable_type).to eq('Product')
    end

    it 'is created automatically when category is updated' do
      category = create(:category, admin: admin)
      Current.admin = admin
      
      expect {
        category.update!(name: 'Updated Category Name')
      }.to change(AuditLog, :count).by(1)
      
      audit_log = AuditLog.last
      expect(audit_log.action).to eq('updated')
      expect(audit_log.admin).to eq(admin)
      expect(audit_log.auditable).to eq(category)
    end
        
    it 'stores meaningful change data for updates' do
      Current.admin = admin
      product = create(:product, admin: admin, name: 'Original Name', price: 100)
      
      product.update!(name: 'Updated Name', price: 200)
      
      audit_log = AuditLog.where(action: 'updated').last
      changes = audit_log.changes_hash
      
      expect(changes['name']).to eq(['Original Name', 'Updated Name'])
      expect(changes['price']).to eq(['100.0', '200.0']) # Los valores se guardan como strings en JSON
    end

    it 'tracks product category associations' do
      product = create(:product, admin: admin)
      category = create(:category, admin: admin)
      
      expect {
        create(:product_category, product: product, category: category)
      }.to change { AuditLog.where(action: 'category_associated').count }.by(1)
      
      audit_log = AuditLog.where(action: 'category_associated').last
      expect(audit_log.admin).to eq(admin)
      
      changes = audit_log.changes_hash
      expect(changes['category_id']).to eq(category.id)
      expect(changes['category_name']).to eq(category.name)
    end

    it 'tracks product category disassociations' do
      product = create(:product, admin: admin)
      category = create(:category, admin: admin)
      product_category = create(:product_category, product: product, category: category)
      
      expect {
        product_category.destroy!
      }.to change { AuditLog.where(action: 'category_disassociated').count }.by(1)
      
      audit_log = AuditLog.where(action: 'category_disassociated').last
      expect(audit_log.admin).to eq(admin)
    end
  end

  describe 'querying audit trail' do
    let!(:product) { create(:product, admin: admin, name: 'Test Product') }
    
    before do
      Current.admin = admin
      product.update!(name: 'Updated Product', price: 199.99)
      product.update!(stock: 50)
    end

    it 'can track full history of an object' do
      logs = AuditLog.where(auditable: product).recent
      
      expect(logs.count).to eq(3) # created + 2 updates
      expect(logs.map(&:action)).to eq(['updated', 'updated', 'created'])
    end

    it 'can filter by specific actions' do
      update_logs = AuditLog.where(auditable: product).by_action('updated')
      expect(update_logs.count).to eq(2)
    end

    it 'can track changes over time' do
      logs = AuditLog.where(auditable: product).recent
      
      creation_log = logs.find { |log| log.action == 'created' }
      expect(creation_log.changes_hash['name']).to eq('Test Product')
      
      name_update_log = logs.find { |log| log.changes_hash.key?('name') && log.action == 'updated' }
      expect(name_update_log.changes_hash['name']).to eq(['Test Product', 'Updated Product'])
    end
  end

  describe 'performance considerations' do
    it 'can handle large change data efficiently' do
      large_data = {
        description: ['Short description', 'A' * 1000],
        metadata: (1..100).map { |i| ["key#{i}", "value#{i}"] }.to_h
      }
      
      audit_log = create(:audit_log, 
        admin: admin, 
        auditable: product,
        changes_data: large_data.to_json
      )
      
      expect { audit_log.changes_hash }.not_to raise_error
      expect { audit_log.formatted_changes }.not_to raise_error
      expect(audit_log.changes_hash['metadata']['key50']).to eq('value50')
    end
  end
end