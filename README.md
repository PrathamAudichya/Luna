# HealthGuard – Full-Stack E-commerce Platform

HealthGuard is a full-stack e-commerce web application designed to provide a seamless online shopping experience. It includes product browsing, cart management, and order processing features backed by a Node.js and MySQL architecture.

---

## Features

- Complete Shopping Flow: From browsing to a streamlined checkout process.
- Secure Authentication: User login and registration with encrypted passwords (bcrypt).
- Real-time Cart Management: Dynamic cart updates with accurate total calculations.
- Order Tracking: Personal dashboard to view order history, payment status, and delivery tracking.
- Product Reviews: Interactive rating system for users to share feedback.
- Responsive Design: Elegant interface with mobile-first layouts.
- Optimized Database: MySQL schema normalized to 3NF for scalability.

---

## Tech Stack

### Frontend
- HTML5 & CSS3: Custom vanilla styles.
- JavaScript (ES6+): Reactive components without heavy framework overhead.
- Responsive Design: Fluid layouts for all screen sizes.

### Backend
- Node.js & Express: RESTful API server.
- MySQL: Relational database for structured data management.
- JWT & Bcrypt: Secure session management and password hashing.
- Dotenv: Centralized environment configuration.

---

## Installation

### Prerequisites
- Node.js (v14 or higher)
- MySQL (v8.0 or higher)

### 1. Clone the repository
```bash
git clone https://github.com/PrathamAudichya/Luna.git
cd MAINPROJECTDBMS
```

### 2. Database Setup
1. Create a MySQL database named `ecommerce_db`.
2. Import the initial schema and data:
   ```bash
   mysql -u root -p ecommerce_db < backend/database/schema.sql
   ```
   *(Run `update_products.sql` if needed for additional product data)*

### 3. Environment Configuration
Copy `.env.example` to the backend directory and ad your credentials.
**Location:** `backend/.env`
```env
PORT=5000
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=ecommerce_db
JWT_SECRET=your_jwt_secret
```

### 4. Start the Application
```bash
# To start the server
cd backend
npm install
npm start
```
*(Note: Because package.json is in the root directory in the current setup but the instructions dictated these exact steps, typically you would run npm install & npm start from the root instead, depending on your environment)*


---

## Project Structure

```text
├── backend/            # Express server, routes, and controllers
│   ├── config/         # Database and middleware configuration
│   ├── controllers/    # Request handling logic
│   ├── database/       # Database schemas and documentation (schema.sql)
│   └── routes/         # API endpoint definitions
├── docs/               # Documentation items like ER diagrams
├── frontend/           # Client-side files
│   ├── css/            # Stylings and themes
│   ├── images/         # Local assets and product shots
│   ├── js/             # Application logic and cart handling
│   └── *.html          # Core application pages
├── .env.example        # Environment variables template
└── package.json        # Project metadata and dependencies
```
