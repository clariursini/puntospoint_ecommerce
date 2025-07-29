# Diagrama de Entidad-Relación - PuntosPoint E-commerce

## Diagrama Mermaid

```mermaid
erDiagram
    ADMINS {
        integer id PK
        string email UK
        string password_digest
        string name
        timestamp created_at
        timestamp updated_at
    }

    CATEGORIES {
        integer id PK
        string name
        text description
        integer admin_id FK
        timestamp created_at
        timestamp updated_at
    }

    PRODUCTS {
        integer id PK
        string name
        text description
        decimal price
        integer stock
        integer admin_id FK
        timestamp created_at
        timestamp updated_at
    }

    CUSTOMERS {
        integer id PK
        string email UK
        string name
        string phone
        text address
        timestamp created_at
        timestamp updated_at
    }

    PURCHASES {
        integer id PK
        integer customer_id FK
        integer product_id FK
        integer quantity
        decimal total_price
        timestamp purchased_at
        timestamp created_at
        timestamp updated_at
    }

    PRODUCT_CATEGORIES {
        integer id PK
        integer product_id FK
        integer category_id FK
        timestamp created_at
        timestamp updated_at
    }

    PRODUCT_IMAGES {
        integer id PK
        integer product_id FK
        string image_url
        string caption
        timestamp created_at
        timestamp updated_at
    }

    AUDIT_LOGS {
        integer id PK
        integer admin_id FK
        string auditable_type
        integer auditable_id
        string action
        text changes_data
        timestamp created_at
        timestamp updated_at
    }

    %% Relaciones
    ADMINS ||--o{ CATEGORIES : "creates"
    ADMINS ||--o{ PRODUCTS : "creates"
    ADMINS ||--o{ AUDIT_LOGS : "performs"

    CATEGORIES }o--o{ PRODUCTS : "belongs_to"
    PRODUCTS }o--o{ PRODUCT_CATEGORIES : "has_many"
    PRODUCT_CATEGORIES }o--|| PRODUCTS : "belongs_to"
    PRODUCT_CATEGORIES }o--|| CATEGORIES : "belongs_to"

    PRODUCTS ||--o{ PRODUCT_IMAGES : "has_many"
    PRODUCTS ||--o{ PURCHASES : "has_many"

    CUSTOMERS ||--o{ PURCHASES : "has_many"

    PURCHASES }o--|| PRODUCTS : "belongs_to"
    PURCHASES }o--|| CUSTOMERS : "belongs_to"

    AUDIT_LOGS }o--|| ADMINS : "belongs_to"
```

## Descripción de las Entidades

### **ADMINS** (Administradores)
- **Propósito**: Usuarios administradores del sistema
- **Relaciones**: 
  - Crea categorías (1:N)
  - Crea productos (1:N)
  - Realiza auditorías (1:N)

### **CATEGORIES** (Categorías)
- **Propósito**: Clasificación de productos
- **Relaciones**:
  - Pertenece a un administrador (N:1)
  - Tiene muchos productos (N:N a través de product_categories)

### **PRODUCTS** (Productos)
- **Propósito**: Productos del e-commerce
- **Relaciones**:
  - Pertenece a un administrador (N:1)
  - Tiene muchas categorías (N:N a través de product_categories)
  - Tiene muchas imágenes (1:N)
  - Tiene muchas compras (1:N)

### **CUSTOMERS** (Clientes)
- **Propósito**: Clientes que realizan compras
- **Relaciones**:
  - Tiene muchas compras (1:N)

### **PURCHASES** (Compras)
- **Propósito**: Registro de compras realizadas
- **Relaciones**:
  - Pertenece a un cliente (N:1)
  - Pertenece a un producto (N:1)

### **PRODUCT_CATEGORIES** (Tabla de unión)
- **Propósito**: Relación muchos a muchos entre productos y categorías
- **Relaciones**:
  - Pertenece a un producto (N:1)
  - Pertenece a una categoría (N:1)

### **PRODUCT_IMAGES** (Imágenes de productos)
- **Propósito**: Imágenes asociadas a productos
- **Relaciones**:
  - Pertenece a un producto (N:1)

### **AUDIT_LOGS** (Logs de auditoría)
- **Propósito**: Registro de cambios realizados por administradores
- **Relaciones**:
  - Pertenece a un administrador (N:1)
  - Asociación polimórfica con entidades auditables

## Índices de Base de Datos

### **Índices Principales**
- `admins.email` (UNIQUE)
- `customers.email` (UNIQUE)
- `purchases.purchased_at`
- `purchases.customer_id, purchased_at`
- `purchases.product_id, purchased_at`
- `audit_logs.auditable_type, auditable_id`
- `product_categories.product_id, category_id` (UNIQUE)

### **Índices de Performance**
- `products.name`
- `products.created_at`
- `products.price`
- `categories.name`
- `audit_logs.created_at`
- `audit_logs.action`

## Características Especiales

### **Auditoría Automática**
- Todos los cambios en productos y categorías se registran automáticamente
- Uso de `ActiveSupport::CurrentAttributes` para tracking del admin actual
- Asociación polimórfica para flexibilidad

### **Validaciones**
- Emails únicos para admins y customers
- Stock suficiente para compras
- Precios y cantidades positivas
- Al menos una imagen por producto

### **Callbacks**
- Cálculo automático de precios totales
- Reducción automática de stock
- Envío de emails en primera compra
- Logging de auditoría 