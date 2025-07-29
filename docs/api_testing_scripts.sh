#!/bin/bash

# PuntosPoint E-commerce API Testing Scripts
# ===========================================

# Configuración
BASE_URL="http://localhost:3000/api/v1"
ADMIN_EMAIL="admin1@example.com"
ADMIN_PASSWORD="password123"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir headers
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Función para imprimir resultados
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

# Función para obtener JWT token
get_jwt_token() {
    echo -e "\n${YELLOW}🔐 Obteniendo JWT token...${NC}"
    
    RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$ADMIN_EMAIL\",
            \"password\": \"$ADMIN_PASSWORD\"
        }")
    
    TOKEN=$(echo $RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$TOKEN" ]; then
        echo -e "${GREEN}✅ Token obtenido: ${TOKEN:0:20}...${NC}"
        export JWT_TOKEN="Bearer $TOKEN"
        return 0
    else
        echo -e "${RED}❌ Error obteniendo token${NC}"
        echo "Response: $RESPONSE"
        return 1
    fi
}

# ========================================
# 1. HEALTH CHECK
# ========================================
test_health_check() {
    print_header "🏥 HEALTH CHECK"
    
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "http://localhost:3000/health")
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Health check exitoso"
        echo "Response: $BODY"
    else
        print_result 1 "Health check falló (HTTP $HTTP_CODE)"
    fi
}

# ========================================
# 2. AUTHENTICATION
# ========================================
test_authentication() {
    print_header "🔐 AUTHENTICATION"
    
    # Login
    echo -e "\n${YELLOW}Testing Login...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$ADMIN_EMAIL\",
            \"password\": \"$ADMIN_PASSWORD\"
        }")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Login exitoso"
        TOKEN=$(echo $BODY | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        export JWT_TOKEN="Bearer $TOKEN"
        echo "Token: ${TOKEN:0:20}..."
        echo "JWT_TOKEN length: ${#JWT_TOKEN}"
    else
        print_result 1 "Login falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        return 1
    fi
    
    # Get Current Admin
    echo -e "\n${YELLOW}Testing Get Current Admin...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/me" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Get current admin exitoso"
        echo "Admin: $(echo $BODY | grep -o '"name":"[^"]*"' | cut -d'"' -f4)"
    else
        print_result 1 "Get current admin falló (HTTP $HTTP_CODE)"
    fi
    
    # Logout
    echo -e "\n${YELLOW}Testing Logout...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/logout" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Logout exitoso"
    else
        print_result 1 "Logout falló (HTTP $HTTP_CODE)"
    fi
}

# ========================================
# 3. CATEGORIES
# ========================================
test_categories() {
    print_header "📂 CATEGORIES"
    
    # List Categories
    echo -e "\n${YELLOW}Testing List Categories...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/categories?page=1&per_page=5" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "List categories exitoso"
        echo "Categories count: $(echo $BODY | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
    else
        print_result 1 "List categories falló (HTTP $HTTP_CODE)"
    fi
    
    # Create Category
    echo -e "\n${YELLOW}Testing Create Category...${NC}"
    
    # First, try to create the category
    echo "Attempting to create test category..."
    RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/categories" \
        -H "Authorization: $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "category": {
                "name": "Test Electronics",
                "description": "Test category for electronics"
            }
        }')
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    # If creation failed because it already exists, find and delete it
    if [ "$HTTP_CODE" -eq 422 ] && echo "$BODY" | grep -q "Name has already been taken"; then
        echo "Category already exists, searching for it..."
        SEARCH_RESPONSE=$(curl -s -X GET "$BASE_URL/categories?per_page=100" \
            -H "Authorization: $JWT_TOKEN")
        
        EXISTING_CATEGORY_ID=$(echo "$SEARCH_RESPONSE" | jq -r '.data.categories[] | select(.name == "Test Electronics") | .id // empty')
        
        if [ -n "$EXISTING_CATEGORY_ID" ]; then
            echo "Found existing test category with ID: $EXISTING_CATEGORY_ID, deleting..."
            DELETE_RESPONSE=$(curl -s -w "%{http_code}" -X DELETE "$BASE_URL/categories/$EXISTING_CATEGORY_ID" \
                -H "Authorization: $JWT_TOKEN")
            echo "Delete response: $DELETE_RESPONSE"
            
            # Now try to create again
            echo "Creating category again..."
            RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/categories" \
                -H "Authorization: $JWT_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{
                    "category": {
                        "name": "Test Electronics",
                        "description": "Test category for electronics"
                    }
                }')
            
            HTTP_CODE="${RESPONSE: -3}"
            BODY="${RESPONSE%???}"
        fi
    fi
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Create category exitoso"
        CATEGORY_ID=$(echo "$BODY" | jq -r '.data.id // empty')
        echo "Category ID: $CATEGORY_ID"
        echo "Response: $BODY"
        export TEST_CATEGORY_ID=$CATEGORY_ID
    else
        print_result 1 "Create category falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        echo "Details: $(echo "$BODY" | jq -r '.details // "No details provided"')"
    fi

    # Update Category
    if [ -n "$TEST_CATEGORY_ID" ]; then
        echo -e "\n${YELLOW}Testing Update Category...${NC}"
        
        # Generate unique name with timestamp
        TIMESTAMP=$(date +%s)
        UNIQUE_NAME="Updated Test Electronics $TIMESTAMP"
        
        RESPONSE=$(curl -s -w "%{http_code}" -X PUT "$BASE_URL/categories/$TEST_CATEGORY_ID" \
            -H "Authorization: $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "category": {
                    "name": "'"$UNIQUE_NAME"'",
                    "description": "Updated test category for electronics with unique name"
                }
            }')
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            print_result 0 "Update category exitoso"
            echo "Response: $BODY"
        else
            print_result 1 "Update category falló (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
            echo "Details: $(echo "$BODY" | jq -r '.details // "No details provided"')"
        fi
    fi
    
    # Get Category by ID
    if [ -n "$TEST_CATEGORY_ID" ]; then
        echo -e "\n${YELLOW}Testing Get Category by ID...${NC}"
        echo "Debug: TEST_CATEGORY_ID = $TEST_CATEGORY_ID"
        RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/categories/$TEST_CATEGORY_ID" \
            -H "Authorization: $JWT_TOKEN")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            print_result 0 "Get category by ID exitoso"
            echo "Response: $BODY"
        else
            print_result 1 "Get category by ID falló (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
        fi
    else
        echo "Debug: TEST_CATEGORY_ID is empty, skipping Get Category by ID test"
    fi
}

# ========================================
# 4. PRODUCTS
# ========================================
test_products() {
    print_header "📦 PRODUCTS"
    
    # Clear previous response variables
    unset RESPONSE HTTP_CODE BODY
    
    # List Products
    echo -e "\n${YELLOW}Testing List Products...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/products?page=1&per_page=5" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "List products exitoso"
        echo "Products count: $(echo $BODY | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
    else
        print_result 1 "List products falló (HTTP $HTTP_CODE)"
    fi
    
    # Create Product
    echo -e "\n${YELLOW}Testing Create Product...${NC}"
    
    # Get first available category
    echo "Getting first available category..."
    CATEGORIES_RESPONSE=$(curl -s -X GET "$BASE_URL/categories?per_page=1" \
        -H "Authorization: $JWT_TOKEN")
    
    CATEGORY_ID=$(echo "$CATEGORIES_RESPONSE" | jq -r '.data.categories[0].id // 1')
    echo "Using Category ID: $CATEGORY_ID"
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/products" \
        -H "Authorization: $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "product": {
                "name": "Test iPhone 15",
                "description": "Test iPhone 15 product",
                "price": 999.99,
                "stock": 50,
                "category_ids": ['$CATEGORY_ID'],
                "product_images_attributes": [
                    {
                        "image_url": "https://example.com/test-iphone.jpg",
                        "caption": "Test iPhone 15"
                    }
                ]
            }
        }')
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Create product exitoso"
        PRODUCT_ID=$(echo "$BODY" | jq -r '.data.id // empty')
        echo "Product ID: $PRODUCT_ID"
        echo "Response: $BODY"
        export TEST_PRODUCT_ID=$PRODUCT_ID
    else
        print_result 1 "Create product falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        echo "Details: $(echo "$BODY" | jq -r '.details // "No details provided"')"
    fi
    
    # Get Product by ID
    if [ -n "$TEST_PRODUCT_ID" ]; then
        echo -e "\n${YELLOW}Testing Get Product by ID...${NC}"
        RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/products/$TEST_PRODUCT_ID" \
            -H "Authorization: $JWT_TOKEN")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            print_result 0 "Get product by ID exitoso"
            echo "Response: $BODY"
        else
            print_result 1 "Get product by ID falló (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
        fi
    fi

    # Update Product
    if [ -n "$TEST_PRODUCT_ID" ]; then
        echo -e "\n${YELLOW}Testing Update Product...${NC}"
        
        # Generate unique name with timestamp
        TIMESTAMP=$(date +%s)
        UNIQUE_NAME="Updated Test iPhone 15 $TIMESTAMP"
        
        RESPONSE=$(curl -s -w "%{http_code}" -X PUT "$BASE_URL/products/$TEST_PRODUCT_ID" \
            -H "Authorization: $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "product": {
                    "name": "'"$UNIQUE_NAME"'",
                    "description": "Updated test iPhone 15 product description with unique name",
                    "price": 1099.99,
                    "stock": 75
                }
            }')
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            print_result 0 "Update product exitoso"
            echo "Response: $BODY"
        else
            print_result 1 "Update product falló (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
            echo "Details: $(echo "$BODY" | jq -r '.details // "No details provided"')"
        fi
    fi
    
    # Most Purchased by Category
    echo -e "\n${YELLOW}Testing Most Purchased by Category...${NC}"
    unset RESPONSE HTTP_CODE BODY
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/products/most_purchased_by_category?limit=5" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Most purchased by category exitoso"
        echo "Response: $BODY"
    else
        print_result 1 "Most purchased by category falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
    fi
    
    # Top Revenue by Category
    echo -e "\n${YELLOW}Testing Top Revenue by Category...${NC}"
    unset RESPONSE HTTP_CODE BODY
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/products/top_revenue_by_category" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Top revenue by category exitoso"
        echo "Response: $BODY"
    else
        print_result 1 "Top revenue by category falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
    fi
}

# ========================================
# 5. CUSTOMERS
# ========================================
test_customers() {
    print_header "👥 CUSTOMERS"
    
    # List Customers
    echo -e "\n${YELLOW}Testing List Customers...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/customers?page=1&per_page=5" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "List customers exitoso"
        echo "Customers count: $(echo $BODY | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
    else
        print_result 1 "List customers falló (HTTP $HTTP_CODE)"
    fi
    
    # Create Customer
    echo -e "\n${YELLOW}Testing Create Customer...${NC}"
    
    # First, try to create the customer
    echo "Attempting to create test customer..."
    RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/customers" \
        -H "Authorization: $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "customer": {
                "name": "Test Customer",
                "email": "test.customer@example.com",
                "phone": "+1234567890",
                "address": "123 Test St, Test City"
            }
        }')
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    # If creation failed because it already exists, find and delete it
    if [ "$HTTP_CODE" -eq 422 ] && echo "$BODY" | grep -q "Email has already been taken"; then
        echo "Customer already exists, searching for it..."
        SEARCH_RESPONSE=$(curl -s -X GET "$BASE_URL/customers?per_page=100" \
            -H "Authorization: $JWT_TOKEN")
        
        EXISTING_CUSTOMER_ID=$(echo "$SEARCH_RESPONSE" | jq -r '.data.customers[] | select(.email == "test.customer@example.com") | .id // empty')
        
        if [ -n "$EXISTING_CUSTOMER_ID" ]; then
            echo "Found existing test customer with ID: $EXISTING_CUSTOMER_ID, deleting..."
            DELETE_RESPONSE=$(curl -s -w "%{http_code}" -X DELETE "$BASE_URL/customers/$EXISTING_CUSTOMER_ID" \
                -H "Authorization: $JWT_TOKEN")
            echo "Delete response: $DELETE_RESPONSE"
            
            # Now try to create again
            echo "Creating customer again..."
            RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/customers" \
                -H "Authorization: $JWT_TOKEN" \
                -H "Content-Type: application/json" \
                -d '{
                    "customer": {
                        "name": "Test Customer",
                        "email": "test.customer@example.com",
                        "phone": "+1234567890",
                        "address": "123 Test St, Test City"
                    }
                }')
            
            HTTP_CODE="${RESPONSE: -3}"
            BODY="${RESPONSE%???}"
        fi
    fi
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Create customer exitoso"
        CUSTOMER_ID=$(echo "$BODY" | jq -r '.data.id // empty')
        echo "Customer ID: $CUSTOMER_ID"
        echo "Response: $BODY"
        export TEST_CUSTOMER_ID=$CUSTOMER_ID
    else
        print_result 1 "Create customer falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        echo "Details: $(echo "$BODY" | jq -r '.details // "No details provided"')"
    fi
}

# ========================================
# 6. PURCHASES
# ========================================
test_purchases() {
    print_header "🛒 PURCHASES"
    
    # Create Purchase
    echo -e "\n${YELLOW}Testing Create Purchase...${NC}"
    
    # Get first available customer and product with stock
    echo "Getting first available customer and product with stock..."
    CUSTOMERS_RESPONSE=$(curl -s -X GET "$BASE_URL/customers?per_page=1" \
        -H "Authorization: $JWT_TOKEN")
    PRODUCTS_RESPONSE=$(curl -s -X GET "$BASE_URL/products?per_page=10" \
        -H "Authorization: $JWT_TOKEN")
    
    CUSTOMER_ID=$(echo "$CUSTOMERS_RESPONSE" | jq -r '.data.customers[0].id // 1')
    # Find first product with stock > 0
    PRODUCT_ID=$(echo "$PRODUCTS_RESPONSE" | jq -r '.data.products[] | select(.stock > 0) | .id // empty' | head -1)
    
    if [ -z "$PRODUCT_ID" ]; then
        echo "No products with stock available, using first product"
        PRODUCT_ID=$(echo "$PRODUCTS_RESPONSE" | jq -r '.data.products[0].id // 1')
    fi
    
    echo "Using Customer ID: $CUSTOMER_ID, Product ID: $PRODUCT_ID"
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/purchases" \
        -H "Authorization: $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "purchase": {
                "customer_id": '$CUSTOMER_ID',
                "product_id": '$PRODUCT_ID',
                "quantity": 2,
                "purchased_at": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
            }
        }')
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Create purchase exitoso"
        PURCHASE_ID=$(echo "$BODY" | jq -r '.data.id // empty')
        echo "Purchase ID: $PURCHASE_ID"
        echo "Response: $BODY"
        export TEST_PURCHASE_ID=$PURCHASE_ID
    else
        print_result 1 "Create purchase falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
        echo "Details: $(echo "$BODY" | jq -r '.details // "No details provided"')"
    fi
    
    # Filtered Purchases
    echo -e "\n${YELLOW}Testing Filtered Purchases...${NC}"
    CURRENT_YEAR=$(date +%Y)
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/purchases/filtered?start_date=$CURRENT_YEAR-01-01&end_date=$CURRENT_YEAR-12-31&page=1&per_page=5" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Filtered purchases exitoso"
        echo "Purchases count: $(echo $BODY | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
    else
        print_result 1 "Filtered purchases falló (HTTP $HTTP_CODE)"
    fi
    
    # Count by Granularity - Day
    echo -e "\n${YELLOW}Testing Count by Granularity (Day)...${NC}"
    TODAY=$(date +%Y-%m-%d)
    PAST_WEEK=$(date -d '1 week ago' +%Y-%m-%d)
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/purchases/count_by_granularity?granularity=day&start_date=$PAST_WEEK&end_date=$TODAY" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Count by granularity (day) exitoso"
        echo "Response: $BODY"
    else
        print_result 1 "Count by granularity (day) falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
    fi
    
    # Count by Granularity - Hour
    echo -e "\n${YELLOW}Testing Count by Granularity (Hour)...${NC}"
    CURRENT_HOUR=$(date +%Y-%m-%dT%H:00:00)
    LAST_HOUR=$(date -d '1 hour ago' +%Y-%m-%dT%H:00:00)
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/purchases/count_by_granularity?granularity=hour&start_date=$LAST_HOUR&end_date=$CURRENT_HOUR" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Count by granularity (hour) exitoso"
        echo "Response: $BODY"
    else
        print_result 1 "Count by granularity (hour) falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
    fi
    
    # Daily Report
    echo -e "\n${YELLOW}Testing Daily Report...${NC}"
    unset RESPONSE HTTP_CODE BODY
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/purchases/daily_report?date=$(date +%Y-%m-%d)" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Daily report exitoso"
        echo "Response: $BODY"
    else
        print_result 1 "Daily report falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
    fi
}

# ========================================
# 7. AUDIT LOGS
# ========================================
test_audit_logs() {
    print_header "📋 AUDIT LOGS"
    
    # Get Recent Audit Logs
    echo -e "\n${YELLOW}Testing Get Recent Audit Logs...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/audit_logs/recent" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Get recent audit logs exitoso"
        echo "Total logs: $(echo $BODY | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
        echo "Response: $BODY"
    else
        print_result 1 "Get recent audit logs falló (HTTP $HTTP_CODE)"
        echo "Response: $BODY"
    fi
    
    # Get Audit Logs for Test Product
    if [ -n "$TEST_PRODUCT_ID" ]; then
        echo -e "\n${YELLOW}Testing Get Audit Logs for Test Product...${NC}"
        RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/audit_logs/by_entity/Product/$TEST_PRODUCT_ID" \
            -H "Authorization: $JWT_TOKEN")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            print_result 0 "Get audit logs for test product exitoso"
            echo "Total logs: $(echo $BODY | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
            echo "Response: $BODY"
        else
            print_result 1 "Get audit logs for test product falló (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
        fi
    fi
    
    # Get Audit Logs for Test Category
    if [ -n "$TEST_CATEGORY_ID" ]; then
        echo -e "\n${YELLOW}Testing Get Audit Logs for Test Category...${NC}"
        RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/audit_logs/by_entity/Category/$TEST_CATEGORY_ID" \
            -H "Authorization: $JWT_TOKEN")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            print_result 0 "Get audit logs for test category exitoso"
            echo "Total logs: $(echo $BODY | grep -o '"total_count":[0-9]*' | cut -d':' -f2)"
            echo "Response: $BODY"
        else
            print_result 1 "Get audit logs for test category falló (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
        fi
    fi
}

# ========================================
# 8. SCHEDULER
# ========================================
test_scheduler() {
    print_header "⚙️ SCHEDULER"
    
    # Get Scheduler Status
    echo -e "\n${YELLOW}Testing Get Scheduler Status...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X GET "$BASE_URL/scheduler/status" \
        -H "Authorization: $JWT_TOKEN")
    
    HTTP_CODE="${RESPONSE: -3}"
    BODY="${RESPONSE%???}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Get scheduler status exitoso"
        echo "Sidekiq running: $(echo $BODY | grep -o '"running":[^,]*' | cut -d':' -f2)"
    else
        print_result 1 "Get scheduler status falló (HTTP $HTTP_CODE)"
    fi
    
    # Trigger Daily Report
    echo -e "\n${YELLOW}Testing Trigger Daily Report...${NC}"
    RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/scheduler/trigger_daily_report" \
        -H "Authorization: $JWT_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "date": "'$(date +%Y-%m-%d)'"
        }')
    
    HTTP_CODE="${RESPONSE: -3}"
    
    if [ "$HTTP_CODE" -eq 200 ]; then
        print_result 0 "Trigger daily report exitoso"
    else
        print_result 1 "Trigger daily report falló (HTTP $HTTP_CODE)"
    fi
    
    # Trigger First Purchase Test
    if [ -n "$TEST_PURCHASE_ID" ]; then
        echo -e "\n${YELLOW}Testing Trigger First Purchase Test...${NC}"
        unset RESPONSE HTTP_CODE BODY
        RESPONSE=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/scheduler/trigger_first_purchase_test" \
            -H "Authorization: $JWT_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"purchase_id\": $TEST_PURCHASE_ID
            }")
        
        HTTP_CODE="${RESPONSE: -3}"
        BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ]; then
            print_result 0 "Trigger first purchase test exitoso"
            echo "Response: $BODY"
        else
            print_result 1 "Trigger first purchase test falló (HTTP $HTTP_CODE)"
            echo "Response: $BODY"
        fi
    fi
}

# ========================================
# MAIN EXECUTION
# ========================================
main() {
    echo -e "${BLUE}🚀 PuntosPoint E-commerce API Testing${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    # Verificar que el servidor esté corriendo
    if ! curl -s http://localhost:3000/health > /dev/null; then
        echo -e "${RED}❌ Error: El servidor no está corriendo en http://localhost:3000${NC}"
        echo "Por favor, inicia el servidor con: rails server"
        exit 1
    fi
    
    # Ejecutar tests
    test_health_check
    test_authentication
    
    # Solo continuar si la autenticación fue exitosa
    if [ -n "$JWT_TOKEN" ]; then
        test_categories
        test_products
        test_customers
        test_purchases
        test_audit_logs
        test_scheduler
    else
        echo -e "${RED}❌ No se pudo obtener el token JWT. Deteniendo tests.${NC}"
        exit 1
    fi
    
    echo -e "\n${GREEN}🎉 Testing completado!${NC}"
}

# Ejecutar main si el script se ejecuta directamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 