# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Starting seeds..."

# Temporarily disable callbacks for seeding
Category.skip_callback(:create, :after, :log_creation)
Category.skip_callback(:update, :after, :log_changes)
Category.skip_callback(:destroy, :after, :log_deletion)
Product.skip_callback(:create, :after, :log_creation)
Product.skip_callback(:update, :after, :log_changes)
Product.skip_callback(:destroy, :after, :log_deletion)
ProductCategory.skip_callback(:create, :after, :log_association)
ProductCategory.skip_callback(:destroy, :after, :log_disassociation)

# Clear existing data
puts "Clearing existing data..."
Purchase.destroy_all
ProductImage.destroy_all
ProductCategory.destroy_all
Product.destroy_all
Category.destroy_all
Admin.destroy_all

# Create Administrators
puts "Creating administrators..."
admin1 = Admin.find_or_create_by!(email: 'admin1@example.com') do |admin|
  admin.name = 'Admin 1'
  admin.password = 'password123'
end

admin2 = Admin.find_or_create_by!(email: 'admin2@example.com') do |admin|
  admin.name = 'Admin 2'
  admin.password = 'password123'
end

admin3 = Admin.find_or_create_by!(email: 'moderator@example.com') do |admin|
  admin.name = 'Admin 3'
  admin.password = 'password123'
end

# Create Categories
puts "Creating categories..."
electronics = Category.find_or_create_by!(name: 'Electrónicos') do |category|
  category.description = 'Productos electrónicos y tecnología'
  category.admin = admin1
end

clothing = Category.find_or_create_by!(name: 'Ropa') do |category|
  category.description = 'Ropa y accesorios de moda'
  category.admin = admin2
end

books = Category.find_or_create_by!(name: 'Libros') do |category|
  category.description = 'Libros de ficción'
  category.admin = admin1
end

home = Category.find_or_create_by!(name: 'Hogar') do |category|
  category.description = 'Productos para el hogar'
  category.admin = admin2
end

# Create Products
puts "Creating products..."
products_data = [
  {
    name: 'iPhone 15 Pro',
    description: 'El último iPhone con características avanzadas',
    price: 999.99,
    stock: 50,
    admin: admin1,
    categories: [electronics],
    images: [
      { image_url: 'https://www.apple.com/newsroom/videos/iphone-15-pro-action-button/posters/Apple-iPhone-15-Pro-lineup-Action-button-230912.jpg.large_2x.jpg', caption: 'iPhone 15 Pro - Vista frontal' },
      { image_url: 'https://www.apple.com/newsroom/images/2023/09/apple-unveils-iphone-15-pro-and-iphone-15-pro-max/article/Apple-iPhone-15-Pro-lineup-hero-230912_Full-Bleed-Image.jpg.xlarge_2x.jpg', caption: 'iPhone 15 Pro - Vista trasera' }
    ]
  },
  {
    name: 'MacBook Air M2',
    description: 'Laptop ultraligera con chip M2',
    price: 1199.99,
    stock: 30,
    admin: admin1,
    categories: [electronics],
    images: [
      { image_url: 'https://megano.skillbox.cc/ru/catalog/noutbuk-apple-macbook-air-15-m2-8256gb-midnight/', caption: 'MacBook Air M2' }
    ]
  },
  {
    name: 'Camiseta Básica',
    description: 'Camiseta de algodón 100%',
    price: 29.99,
    stock: 100,
    admin: admin2,
    categories: [clothing],
    images: [
      { image_url: 'https://acdn-us.mitiendanube.com/stores/184/874/products/camiseta-algodon-organico-manga-corta-adulto-blanco1-ba59397543d505555e16959182633428-480-0.jpg', caption: 'Camiseta básica' }
    ]
  },
  {
    name: 'El Señor de los Anillos',
    description: 'Trilogía completa de J.R.R. Tolkien',
    price: 49.99,
    stock: 25,
    admin: admin1,
    categories: [books],
    images: [
      { image_url: 'https://tienda.planetadelibros.com.ar/cdn/shop/files/ElSenordelosAnillosn_01.LaComunidaddelAnillo_Fte_800x.jpg?v=1693598478', caption: 'El Señor de los Anillos' }
    ]
  },
  {
    name: 'Sofá Moderno',
    description: 'Sofá elegante para sala de estar',
    price: 599.99,
    stock: 10,
    admin: admin2,
    categories: [home],
    images: [
      { image_url: 'https://acdn-us.mitiendanube.com/stores/002/792/899/products/wave-3-modulos-mas-puff-57b0c77756eb0f2c4616982823474449-1024-1024.jpeg', caption: 'Sofá moderno' }
    ]
  }
]

products_data.each do |product_data|
  images_data = product_data.delete(:images)
  categories_data = product_data.delete(:categories)
  
  # Create product with images first
  product = Product.find_or_create_by!(name: product_data[:name]) do |p|
    p.assign_attributes(product_data)
    
    # Create images immediately
    images_data.each do |image_data|
      p.product_images.build(
        image_url: image_data[:image_url],
        caption: image_data[:caption]
      )
    end
  end
  
  # Associate categories
  categories_data.each do |category|
    product.categories << category unless product.categories.include?(category)
  end
end

# Create Customers
puts "Creating customers..."
customers_data = [
  {
    name: 'Juan Pérez',
    email: 'juan.perez@example.com',
    phone: '+5491133333333',
    address: 'Av. Corrientes 123, Ciudad Autónoma de Buenos Aires'
  },
  {
    name: 'María García',
    email: 'maria.garcia@example.com',
    phone: '+5491133333334',
    address: 'Av. Santa Fe 456, Ciudad Autónoma de Buenos Aires'
  },
  {
    name: 'Carlos López',
    email: 'carlos.lopez@example.com',
    phone: '+5491133333335',
    address: 'Av. Córdoba 789, Ciudad Autónoma de Buenos Aires'
  },  
  {
    name: 'Ana Rodríguez',
    email: 'ana.rodriguez@example.com',
    phone: '+5491133333336',
    address: 'Av. Rivadavia 321, Ciudad Autónoma de Buenos Aires'
  }
]

customers_data.each do |customer_data|
  Customer.find_or_create_by!(email: customer_data[:email]) do |customer|
    customer.assign_attributes(customer_data)
  end
end

# Create some sample purchases
puts "Creating sample purchases..."
customers = Customer.all
products = Product.all

# Create purchases for the last 30 days
30.times do |i|
  customer = customers.sample
  product = products.sample
  quantity = rand(1..3)
  purchased_at = i.days.ago
  
  Purchase.create!(
    customer: customer,
    product: product,
    quantity: quantity,
    total_price: quantity * product.price,
    purchased_at: purchased_at
  )
end

puts "✅ Seeds completed successfully!"
puts "Created:"
puts "  - #{Admin.count} administrators"
puts "  - #{Category.count} categories"
puts "  - #{Product.count} products"
puts "  - #{Customer.count} customers"
puts "  - #{Purchase.count} purchases"
puts ""
puts "Default admin credentials:"
puts "  Email: admin1@example.com"
puts "  Password: password123"

# Re-enable callbacks
Category.set_callback(:create, :after, :log_creation)
Category.set_callback(:update, :after, :log_changes)
Category.set_callback(:destroy, :after, :log_deletion)
Product.set_callback(:create, :after, :log_creation)
Product.set_callback(:update, :after, :log_changes)
Product.set_callback(:destroy, :after, :log_deletion)
ProductCategory.set_callback(:create, :after, :log_association)
ProductCategory.set_callback(:destroy, :after, :log_disassociation)
