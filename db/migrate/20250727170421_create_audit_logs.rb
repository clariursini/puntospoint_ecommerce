class CreateAuditLogs < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_logs do |t|
      t.references :admin, null: false, foreign_key: true
      t.string :auditable_type
      t.integer :auditable_id
      t.string :action
      t.text :changes_data

      t.timestamps
    end
    
    add_index :audit_logs, [:auditable_type, :auditable_id]
    add_index :audit_logs, :action
  end
end
