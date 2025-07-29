require 'rails_helper'

RSpec.describe Admin, type: :model do
  # Create a subject for shoulda-matchers that need an existing record
  subject { build(:admin) }

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { should validate_presence_of(:email) }
    
    # For uniqueness validation, shoulda-matchers needs a valid subject
    context 'with existing admin' do
      subject { create(:admin) }
      it { should validate_uniqueness_of(:email).case_insensitive }
    end
    
    it { should allow_value('test@example.com').for(:email) }
    it { should allow_value('user.name@domain.co.uk').for(:email) }
    it { should allow_value('test+tag@example.org').for(:email) }
    it { should_not allow_value('invalid-email').for(:email) }
    it { should_not allow_value('').for(:email) }
    it { should validate_length_of(:password).is_at_least(6) }

    it 'is valid with valid attributes' do
      admin = build(:admin)
      expect(admin).to be_valid
    end

    it 'accepts valid email formats' do
      valid_emails = [
        'test@example.com',
        'user.name@domain.co.uk', 
        'test+tag@example.org'
      ]
      
      valid_emails.each do |email|
        admin = build(:admin, email: email)
        expect(admin).to be_valid, "#{email} should be valid"
      end
    end

    it 'validates email case insensitivity for uniqueness' do
      create(:admin, email: 'test@example.com')
      
      admin = build(:admin, email: 'TEST@EXAMPLE.COM')
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to include('has already been taken')
    end
  end

  describe 'associations' do
    it { should have_many(:products).dependent(:destroy) }
    it { should have_many(:categories).dependent(:destroy) }
    it { should have_many(:audit_logs).dependent(:destroy) }

    it 'has many products' do
      admin = create(:admin)
      product1 = create(:product, admin: admin)
      product2 = create(:product, admin: admin)
      
      expect(admin.products).to include(product1, product2)
      expect(admin.products.count).to eq(2)
    end

    it 'has many categories' do
      admin = create(:admin)
      category1 = create(:category, admin: admin)
      category2 = create(:category, admin: admin)
      
      expect(admin.categories).to include(category1, category2)
      expect(admin.categories.count).to eq(2)
    end

    it 'has many audit logs' do
      admin = create(:admin)
      
      # This should create an audit log
      Current.admin = admin
      category = create(:category, admin: admin)
      
      expect(admin.audit_logs.count).to be > 0
    end

    describe 'dependent destroy behavior' do
      let(:admin) { create(:admin) }

      it 'destroys associated products when admin is destroyed' do
        product = create(:product, admin: admin)
        
        expect {
          admin.destroy
        }.to change(Product, :count).by(-1)
      end

      it 'destroys associated categories when admin is destroyed' do
        category = create(:category, admin: admin)
        
        expect {
          admin.destroy
        }.to change(Category, :count).by(-1)
      end

      it 'destroys associated audit logs when admin is destroyed' do
        # Create some audit logs
        Current.admin = admin
        create(:category, admin: admin)
        initial_audit_count = AuditLog.count
        
        expect {
          admin.destroy
        }.to change(AuditLog, :count).by(-initial_audit_count)
      end
    end
  end

  describe 'callbacks' do
    it 'normalizes email before save' do
      # Use a valid email format that just needs case normalization
      admin = Admin.new(
        name: 'Test Admin',
        email: 'TEST@EXAMPLE.COM',
        password: 'password123',
        password_confirmation: 'password123'
      )
      admin.save!
      expect(admin.email).to eq('test@example.com')
    end

    it 'handles email normalization with various formats' do
      test_cases = [
        ['test@EXAMPLE.com', 'test@example.com'],
        ['UPPER@CASE.COM', 'upper@case.com'],
        ['mixed.Case@Domain.ORG', 'mixed.case@domain.org']
      ]
      
      test_cases.each_with_index do |(input, expected), index|
        admin = Admin.new(
          name: "Test Admin #{index}",
          email: input,
          password: 'password123',
          password_confirmation: 'password123'
        )
        admin.save!
        expect(admin.email).to eq(expected)
      end
    end

    it 'normalizes email with spaces' do
      # Now this should work because before_validation runs before email validation
      admin = Admin.new(
        name: 'Test Admin',
        email: '  test@example.com  ',
        password: 'password123',
        password_confirmation: 'password123'
      )
      admin.save!
      expect(admin.email).to eq('test@example.com')
    end
  end

  describe '#generate_jwt_token' do
    let(:admin) { create(:admin) }

    it 'generates a valid JWT token' do
      token = admin.generate_jwt_token
      
      expect(token).to be_present
      expect(token).to be_a(String)
      expect(token.split('.').length).to eq(3) # JWT has 3 parts separated by dots
    end

    it 'includes correct payload in token' do
      token = admin.generate_jwt_token
      
      decoded_token = JWT.decode(token, JWT_SECRET, true, { algorithm: JWT_ALGORITHM })
      payload = decoded_token.first
      
      expect(payload['admin_id']).to eq(admin.id)
      expect(payload['email']).to eq(admin.email)
      expect(payload['exp']).to be > Time.current.to_i
    end

    it 'sets expiration time 24 hours from now' do
      # Freeze the current time to test exact expiration
      current_time = Time.current
      allow(Time).to receive(:current).and_return(current_time)
      
      token = admin.generate_jwt_token
      
      decoded_token = JWT.decode(token, JWT_SECRET, true, { algorithm: JWT_ALGORITHM })
      payload = decoded_token.first
      
      expected_exp = current_time + 24.hours
      expect(payload['exp']).to eq(expected_exp.to_i)
    end

    it 'generates different tokens for different admins' do
      admin2 = create(:admin)
      
      token1 = admin.generate_jwt_token
      token2 = admin2.generate_jwt_token
      
      expect(token1).not_to eq(token2)
    end
  end

  describe 'password handling' do
    it 'encrypts password using has_secure_password' do
      admin = create(:admin, password: 'secure_password123', password_confirmation: 'secure_password123')
      
      expect(admin.password_digest).to be_present
      expect(admin.password_digest).not_to eq('secure_password123')
      expect(admin.authenticate('secure_password123')).to eq(admin)
      expect(admin.authenticate('wrong_password')).to be_falsey
    end

    it 'does not validate password length when updating other attributes' do
      admin = create(:admin, password: 'secure_password123', password_confirmation: 'secure_password123')
      
      # Should be able to update name without providing password
      expect(admin.update(name: 'New Name')).to be true
      expect(admin.name).to eq('New Name')
    end

    it 'validates password length when password is being set' do
      admin = create(:admin)
      
      admin.password = 'short'
      admin.password_confirmation = 'short'
      expect(admin).not_to be_valid
      expect(admin.errors[:password]).to include('is too short (minimum is 6 characters)')
    end

    it 'requires password confirmation to match' do
      admin = build(:admin, password: 'password123', password_confirmation: 'different')
      expect(admin).not_to be_valid
      expect(admin.errors[:password_confirmation]).to include("doesn't match Password")
    end
  end

  describe 'email case sensitivity' do
    it 'treats emails as case insensitive for uniqueness' do
      create(:admin, email: 'test@example.com')
      
      admin = build(:admin, email: 'TEST@EXAMPLE.COM')
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to include('has already been taken')
    end
  end

  describe 'scopes and queries' do
    let!(:admin1) { create(:admin, name: 'Alice Admin') }
    let!(:admin2) { create(:admin, name: 'Bob Admin') }

    it 'can find admin by email' do
      found_admin = Admin.find_by(email: admin1.email)
      expect(found_admin).to eq(admin1)
    end

    it 'orders admins by creation date by default' do
      admins = Admin.all
      expect(admins.first.created_at).to be <= admins.last.created_at
    end
  end

  describe 'edge cases' do
    it 'handles nil email gracefully in normalize callback' do
      admin = Admin.new(name: 'Test', password: 'password123', password_confirmation: 'password123')
      # This should not crash even though email is nil
      expect { admin.valid? }.not_to raise_error
      expect(admin).not_to be_valid # Should fail validation, but not crash
    end

    it 'handles empty string email' do
      admin = build(:admin, email: '')
      expect(admin).not_to be_valid
      expect(admin.errors[:email]).to include("can't be blank")
    end
  end
end