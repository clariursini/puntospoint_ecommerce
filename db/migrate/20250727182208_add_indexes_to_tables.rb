class AddIndexesToTables < ActiveRecord::Migration[7.2]
  def change
    # Índices para purchases
    add_index :purchases, :purchased_at
    add_index :purchases, [:customer_id, :purchased_at]
    add_index :purchases, [:product_id, :purchased_at]
    add_index :purchases, :total_price
    
    # Índices para audit_logs
    add_index :audit_logs, :created_at
    
    # Índices para categorías
    add_index :categories, :name
    
    # Índices para productos
    add_index :products, :name
    add_index :products, :created_at
    add_index :products, :price
    
    # Índices compuestos para consultas frecuentes
    add_index :product_categories, [:product_id, :category_id], unique: true
  end
end
