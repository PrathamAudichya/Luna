const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');

// Load env vars from backend/.env explicitly (avoids relying on cwd)
dotenv.config({ path: path.resolve(__dirname, '.env') });

const app = express();

// Middlewares
app.use(cors({
    origin: ['http://127.0.0.1:5500', 'http://localhost:5500', 'http://localhost:5000'],
    credentials: true
}));
app.use(express.json());

// Main Backend API Routes will be imported here
const authRoutes = require('./routes/authRoutes');
const productRoutes = require('./routes/productRoutes');
const cartRoutes = require('./routes/cartRoutes');
const orderRoutes = require('./routes/orderRoutes');
const reviewRoutes = require('./routes/reviewRoutes');
const couponRoutes = require('./routes/couponRoutes');

// Use Routes
app.use('/api/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/cart', cartRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/reviews', reviewRoutes);
app.use('/api/coupons', couponRoutes);

// Simple health check
app.get('/api/health', (req, res) => res.json({ status: 'API is running...', db: 'connected' }));

// Serve Static Frontend Files
const frontendPath = path.join(__dirname, '../frontend');
app.use(express.static(frontendPath));

// Fallback for SPA routing: send index.html for all unknown non-API routes
app.get('*', (req, res) => {
    if(!req.path.startsWith('/api/')) {
        res.sendFile(path.join(frontendPath, 'index.html'));
    } else {
        res.status(404).json({ message: 'API Route Not Found' });
    }
});

const PORT = process.env.PORT || 5000;

// Verify DB connection before starting server
const pool = require('./config/db');
pool.getConnection()
    .then(conn => {
        conn.release();
        console.log('✅ MySQL database connected successfully');
        app.listen(PORT, () => {
            console.log(`🚀 Server running on port ${PORT}`);
            console.log(`📡 API available at http://localhost:${PORT}/api/health`);
        });
    })
    .catch(err => {
        console.error('❌ MySQL connection failed:', err.message);
        console.error('   Check DB_HOST, DB_USER, DB_PASSWORD, DB_NAME in backend/.env');
        console.error('   Ensure MySQL server is running and the database exists');
        process.exit(1);
    });
