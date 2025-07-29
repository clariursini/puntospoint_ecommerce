class CreateCustomers < ActiveRecord::Migration[7.2]
  def change
    create_table :customers do |t|
      t.string :email
      t.string :name
      t.string :phone
      t.text :address

      t.timestamps
    end
    add_index :customers, :email, unique: true
  end
end
