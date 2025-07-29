# Documentación de APIs - PuntosPoint E-commerce

## Información General

- **Base URL**: `http://localhost:3000/api/v1`
- **Autenticación**: JWT Bearer Token
- **Formato de respuesta**: JSON
- **Encoding**: UTF-8

## Autenticación

Todas las APIs requieren autenticación JWT excepto `/login` y `/health`.

### Headers requeridos:
```
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

## Endpoints

---

## 🔐 Autenticación

### POST /login
**Descripción**: Inicia sesión de administrador y obtiene token JWT

**Headers**: No requiere autenticación

**Body**:
```json
{
  "email": "admin@example.com",
  "password": "password123"
}
```

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "message": "Login successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiJ9...",
    "admin": {
      "id": 1,
      "name": "Admin User",
      "email": "admin@example.com"
    }
  }
}
```

**Respuesta de error** (401):
```json
{
  "status": "error",
  "message": "Invalid credentials"
}
```

### POST /logout
**Descripción**: Cierra sesión (stateless - solo para logging)

**Respuesta** (200):
```json
{
  "status": "success",
  "message": "Logout successful"
}
```

### GET /me
**Descripción**: Obtiene información del administrador actual

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "name": "Admin User",
    "email": "admin@example.com"
  }
}
```

---

## 📦 Productos

### GET /products
**Descripción**: Lista todos los productos con paginación

**Query Parameters**:
- `page` (integer, opcional): Número de página (default: 1)
- `per_page` (integer, opcional): Elementos por página (default: 20)

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "products": [
      {
        "id": 1,
        "name": "Product Name",
        "description": "Product description",
        "price": 99.99,
        "stock": 50,
        "admin": {
          "id": 1,
          "name": "Admin Name"
        },
        "categories": [
          {
            "id": 1,
            "name": "Category Name"
          }
        ],
        "images": [
          {
            "id": 1,
            "image_url": "https://example.com/image.jpg",
            "caption": "Image caption"
          }
        ]
      }
    ],
    "pagination": {
      "current_page": 1,
      "next_page": 2,
      "prev_page": null,
      "total_pages": 5,
      "total_count": 100
    }
  }
}
```

### GET /products/:id
**Descripción**: Obtiene un producto específico

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "name": "Product Name",
    "description": "Product description",
    "price": 99.99,
    "stock": 50,
    "admin": {
      "id": 1,
      "name": "Admin Name"
    },
    "categories": [...],
    "images": [...],
    "total_purchases": 25,
    "total_revenue": 2499.75
  }
}
```

### POST /products
**Descripción**: Crea un nuevo producto

**Body**:
```json
{
  "product": {
    "name": "New Product",
    "description": "Product description",
    "price": 99.99,
    "stock": 50,
    "category_ids": [1, 2],
    "images_attributes": [
      {
        "image_url": "https://example.com/image1.jpg",
        "caption": "Main image"
      }
    ]
  }
}
```

### PUT /products/:id
**Descripción**: Actualiza un producto existente

**Body**: Igual que POST

### DELETE /products/:id
**Descripción**: Elimina un producto

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "message": "Product deleted successfully"
}
```

### GET /products/most_purchased_by_category
**Descripción**: Obtiene los productos más comprados por categoría

**Query Parameters**:
- `limit` (integer, opcional): Límite por categoría (default: 10)

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": [
    {
      "category": {
        "id": 1,
        "name": "Electronics"
      },
      "products": [
        {
          "id": 1,
          "name": "Product Name",
          "purchase_count": 150
        }
      ]
    }
  ]
}
```

### GET /products/top_revenue_by_category
**Descripción**: Obtiene los 3 productos con mayor ingresos por categoría

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": [
    {
      "category": {
        "id": 1,
        "name": "Electronics"
      },
      "top_products": [
        {
          "id": 1,
          "name": "Product Name",
          "total_revenue": 15000.00
        }
      ]
    }
  ]
}
```

---

## 🛒 Compras

### POST /purchases
**Descripción**: Crea una nueva compra

**Body**:
```json
{
  "purchase": {
    "customer_id": 1,
    "product_id": 1,
    "quantity": 2,
    "purchased_at": "2024-01-15T10:30:00Z"
  }
}
```

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "id": 1,
    "quantity": 2,
    "total_price": 199.98,
    "unit_price": 99.99,
    "purchased_at": "2024-01-15T10:30:00Z",
    "customer": {
      "id": 1,
      "name": "Customer Name",
      "email": "customer@example.com"
    },
    "product": {
      "id": 1,
      "name": "Product Name",
      "price": 99.99,
      "categories": [...],
      "admin": {
        "id": 1,
        "name": "Admin Name"
      }
    }
  }
}
```

### GET /purchases/filtered
**Descripción**: Obtiene compras filtradas

**Query Parameters**:
- `start_date` (string, opcional): Fecha de inicio (YYYY-MM-DD)
- `end_date` (string, opcional): Fecha de fin (YYYY-MM-DD)
- `category_id` (integer, opcional): ID de categoría
- `customer_id` (integer, opcional): ID de cliente
- `admin_id` (integer, opcional): ID de administrador
- `page` (integer, opcional): Número de página
- `per_page` (integer, opcional): Elementos por página

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "purchases": [...],
    "pagination": {...},
    "filters_applied": {
      "start_date": "2024-01-01",
      "end_date": "2024-01-31"
    }
  }
}
```

### GET /purchases/count_by_granularity
**Descripción**: Obtiene conteo de compras agrupadas por granularidad

**Query Parameters**:
- `granularity` (string, requerido): "hour", "day", "week", "year"
- `start_date` (string, opcional): Fecha de inicio
- `end_date` (string, opcional): Fecha de fin
- `category_id` (integer, opcional): ID de categoría
- `customer_id` (integer, opcional): ID de cliente
- `admin_id` (integer, opcional): ID de administrador

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "grouped_data": {
      "2024-01-01": 25,
      "2024-01-02": 30,
      "2024-01-03": 20
    },
    "total_purchases": 75,
    "filters_applied": {...}
  }
}
```

### GET /purchases/daily_report
**Descripción**: Obtiene reporte diario de compras

**Query Parameters**:
- `date` (string, opcional): Fecha del reporte (YYYY-MM-DD, default: ayer)

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "date": "2024-01-15",
    "summary": {
      "total_purchases": 50,
      "total_revenue": 5000.00,
      "unique_customers": 30,
      "unique_products": 25
    },
    "products_sold": [...],
    "categories_performance": [...],
    "administrators_performance": [...],
    "top_customers": [...]
  }
}
```

---

## 📂 Categorías

### GET /categories
**Descripción**: Lista todas las categorías

**Query Parameters**:
- `page` (integer, opcional): Número de página
- `per_page` (integer, opcional): Elementos por página

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "categories": [
      {
        "id": 1,
        "name": "Electronics",
        "description": "Electronic products",
        "admin": {
          "id": 1,
          "name": "Admin Name"
        },
        "total_products": 25,
        "total_purchases": 150,
        "total_revenue": 15000.00
      }
    ],
    "pagination": {...}
  }
}
```

### GET /categories/:id
**Descripción**: Obtiene una categoría específica

### POST /categories
**Descripción**: Crea una nueva categoría

**Body**:
```json
{
  "category": {
    "name": "New Category",
    "description": "Category description"
  }
}
```

### PUT /categories/:id
**Descripción**: Actualiza una categoría existente

### DELETE /categories/:id
**Descripción**: Elimina una categoría

---

## 👥 Clientes

### GET /customers
**Descripción**: Lista todos los clientes

**Query Parameters**:
- `page` (integer, opcional): Número de página
- `per_page` (integer, opcional): Elementos por página

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "customers": [
      {
        "id": 1,
        "name": "Customer Name",
        "email": "customer@example.com",
        "phone": "+1234567890",
        "address": "Customer address",
        "total_spent": 1500.00,
        "purchase_count": 15,
        "last_purchase_date": "2024-01-15T10:30:00Z"
      }
    ],
    "pagination": {...}
  }
}
```

### GET /customers/:id
**Descripción**: Obtiene un cliente específico

### POST /customers
**Descripción**: Crea un nuevo cliente

**Body**:
```json
{
  "customer": {
    "name": "New Customer",
    "email": "newcustomer@example.com",
    "phone": "+1234567890",
    "address": "Customer address"
  }
}
```

### PUT /customers/:id
**Descripción**: Actualiza un cliente existente

### DELETE /customers/:id
**Descripción**: Elimina un cliente

---

## ⚙️ Scheduler

### GET /scheduler/status
**Descripción**: Obtiene el estado del scheduler y Sidekiq

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "scheduler_enabled": true,
    "scheduled_jobs": 2,
    "next_runs": {
      "daily_report": "2024-01-16T06:00:00Z"
    },
    "sidekiq_stats": {
      "running": true,
      "processed": 1500,
      "failed": 5,
      "scheduled": 2,
      "retry": 1,
      "dead": 0
    },
    "queue_stats": {
      "default": 0,
      "reports": 1,
      "critical": 0,
      "low": 0
    },
    "worker_stats": {
      "total_workers": 2,
      "busy_workers": 1
    }
  }
}
```

### POST /scheduler/trigger_daily_report
**Descripción**: Dispara manualmente el reporte diario

**Body** (opcional):
```json
{
  "date": "2024-01-15"
}
```

**Respuesta exitosa** (200):
```json
{
  "status": "success",
  "data": {
    "job_id": "abc123",
    "date": "2024-01-15",
    "status": "queued"
  }
}
```

### POST /scheduler/trigger_first_purchase_test
**Descripción**: Dispara manualmente el email de primera compra

**Body**:
```json
{
  "purchase_id": 1
}
```

---

## 🏥 Health Check

### GET /health
**Descripción**: Verifica el estado del sistema

**Headers**: No requiere autenticación

**Respuesta exitosa** (200):
```json
{
  "status": "OK",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0",
  "environment": "development"
}
```

---

## Códigos de Error

### Errores HTTP Comunes

| Código | Descripción |
|--------|-------------|
| 400 | Bad Request - Parámetros inválidos |
| 401 | Unauthorized - Token inválido o faltante |
| 403 | Forbidden - Sin permisos |
| 404 | Not Found - Recurso no encontrado |
| 422 | Unprocessable Entity - Validación fallida |
| 500 | Internal Server Error - Error del servidor |

### Formato de Error
```json
{
  "status": "error",
  "message": "Error description",
  "details": "Additional error details"
}
```

---

## Ejemplos de Uso

### Ejemplo 1: Crear un producto y hacer una compra

```bash
# 1. Login
curl -X POST http://localhost:3000/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@example.com", "password": "password123"}'

# 2. Crear producto
curl -X POST http://localhost:3000/api/v1/products \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "product": {
      "name": "iPhone 15",
      "description": "Latest iPhone model",
      "price": 999.99,
      "stock": 10,
      "category_ids": [1],
      "images_attributes": [
        {
          "image_url": "https://example.com/iphone15.jpg",
          "caption": "iPhone 15 Pro"
        }
      ]
    }
  }'

# 3. Crear compra
curl -X POST http://localhost:3000/api/v1/purchases \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "purchase": {
      "customer_id": 1,
      "product_id": 1,
      "quantity": 1
    }
  }'
```

### Ejemplo 2: Obtener reportes

```bash
# Obtener productos más comprados por categoría
curl -X GET "http://localhost:3000/api/v1/products/most_purchased_by_category?limit=5" \
  -H "Authorization: Bearer <token>"

# Obtener compras filtradas
curl -X GET "http://localhost:3000/api/v1/purchases/filtered?start_date=2024-01-01&end_date=2024-01-31&category_id=1" \
  -H "Authorization: Bearer <token>"

# Obtener conteo por día
curl -X GET "http://localhost:3000/api/v1/purchases/count_by_granularity?granularity=day&start_date=2024-01-01&end_date=2024-01-31" \
  -H "Authorization: Bearer <token>"
```

---

## Notas Importantes

### Caché
- Las APIs implementan caché Redis para mejorar performance
- El caché se invalida automáticamente al crear/actualizar registros
- TTL configurado según el tipo de dato (10min - 1hora)

### Auditoría
- Todos los cambios en productos y categorías se registran automáticamente
- Los logs incluyen qué administrador realizó el cambio
- Asociación polimórfica para flexibilidad

### Background Jobs
- Emails de primera compra se envían automáticamente
- Reportes diarios se generan automáticamente a las 6:00 AM
- Jobs se ejecutan en colas prioritarias (critical, default, reports, low)

### Validaciones
- Emails únicos para admins y customers
- Stock suficiente para compras
- Precios y cantidades positivas
- Al menos una imagen por producto 