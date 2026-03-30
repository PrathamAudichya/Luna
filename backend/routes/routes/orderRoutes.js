const express = require('express');
const router = express.Router();
const { protect } = require('../middlewares/authMiddleware');
const pool = require('../config/db');

// @desc    Validate a coupon code
// @route   POST /api/orders/validate-coupon
// @access  Private
router.post('/validate-coupon', protect, async (req, res) => {
    const { code, cartSubtotal } = req.body;
    try {
        const [coupons] = await pool.query(
            'SELECT * FROM coupons WHERE code = ? AND is_active = 1 AND NOW() BETWEEN valid_from AND valid_until', 
            [code]
        );
        
        if (coupons.length === 0) {
            return res.status(404).json({ message: 'Invalid or expired coupon code' });
        }
        
        const coupon = coupons[0];
        if (cartSubtotal < parseFloat(coupon.min_order_value)) {
            return res.status(400).json({ 
                message: `Minimum order value for this coupon is ${parseFloat(coupon.min_order_value)}` 
            });
        }
        
        res.json({
            id: coupon.id,
            code: coupon.code,
            discount_type: coupon.discount_type,
            discount_value: parseFloat(coupon.discount_value)
        });
    } catch (error) {
        console.error('Coupon Validation Error:', error);
        res.status(500).json({ message: 'Server error validating coupon' });
    }
});

// @desc    Create new order
// @route   POST /api/orders
// @access  Private
router.post('/', protect, async (req, res) => {
    const { delivery_name, phone, delivery_address, pin_code, payment_method, upi_id, coupon_code } = req.body;

    // Validate PIN code
    if(!pin_code || !/^\d{6}$/.test(pin_code)) {
        return res.status(400).json({ message: 'Invalid 6-digit Indian PIN code' });
    }

    // Validate Payment method
    const validMethods = ['COD', 'UPI', 'CARD'];
    if(!validMethods.includes(payment_method)) {
        return res.status(400).json({ message: 'Invalid payment method' });
    }

    const dbPaymentMethod = payment_method === 'CARD' ? 'Credit Card' : payment_method;
    const finalUpi = payment_method === 'UPI' ? upi_id : null;

    if(payment_method === 'UPI') {
        if(!upi_id || !/^[\w.-]+@[\w.-]+$/.test(upi_id)) {
            return res.status(400).json({ message: 'Invalid UPI ID format' });
        }
    }

    let connection;
    try {
        connection = await pool.getConnection(); // Use transaction to safely write multi-table
        await connection.beginTransaction();

        // 1. Get cart items from DB
        const [cartItems] = await connection.query(`
            SELECT c.quantity, p.id as product_id, p.price, p.discount_price, p.tax_percentage 
            FROM cart c JOIN products p ON c.product_id = p.id 
            WHERE c.user_id = ?
        `, [req.user.id]);

        if (cartItems.length === 0) {
            await connection.rollback();
            return res.status(400).json({ message: 'No items in cart' });
        }

        // 2. Insert into addresses table
        const [addrResult] = await connection.query(
            'INSERT INTO addresses (user_id, recipient_name, phone, address_line1, city, state, pin_code) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [req.user.id, delivery_name, phone || '0000000000', delivery_address, 'City', 'State', pin_code]
        );
        const addressId = addrResult.insertId;

        // 3. Compute totals
        let subtotal = 0;
        let totalTax = 0;
        let orderItemsValues = [];

        cartItems.forEach(item => {
            const activePrice = parseFloat(item.discount_price || item.price);
            const itemTotal = activePrice * item.quantity;
            const itemTax = itemTotal * (parseFloat(item.tax_percentage) / 100);

            subtotal += itemTotal;
            totalTax += itemTax;

            orderItemsValues.push([
                null, // reserved for orderId
                item.product_id,
                item.quantity,
                activePrice,
                item.tax_percentage,
                itemTax
            ]);
        });

        // 3b. Apply Coupon if provided
        let discountAmount = 0;
        let couponId = null;
        if (coupon_code) {
            const [coupons] = await connection.query(
                'SELECT * FROM coupons WHERE code = ? AND is_active = 1 AND NOW() BETWEEN valid_from AND valid_until',
                [coupon_code]
            );
            if (coupons.length > 0) {
                const c = coupons[0];
                if (subtotal >= parseFloat(c.min_order_value)) {
                    couponId = c.id;
                    if (c.discount_type === 'percentage') {
                        discountAmount = (subtotal * parseFloat(c.discount_value)) / 100;
                    } else {
                        discountAmount = parseFloat(c.discount_value);
                    }
                }
            }
        }

        const grandTotal = subtotal + totalTax - discountAmount;

        // 4. Create Order
        const [orderResult] = await connection.query(
            'INSERT INTO orders (user_id, address_id, coupon_id, subtotal, tax_amount, discount_amount, total_price, status) VALUES (?, ?, ?, ?, ?, ?, ?, "Pending")', 
            [req.user.id, addressId, couponId, subtotal, totalTax, discountAmount, grandTotal]
        );
        const orderId = orderResult.insertId;

        // 5. Create Order Items
        orderItemsValues.forEach(arr => arr[0] = orderId);
        await connection.query('INSERT INTO order_items (order_id, product_id, quantity, unit_price, tax_percentage, tax_amount) VALUES ?', [orderItemsValues]);

        // 6. Create Payments row
        await connection.query(
            'INSERT INTO payments (order_id, payment_method, upi_id, amount, status) VALUES (?, ?, ?, ?, ?)',
            [orderId, dbPaymentMethod, finalUpi, grandTotal, payment_method === 'COD' ? 'Pending' : 'Success']
        );

        // 7. Clear Cart
        await connection.query('DELETE FROM cart WHERE user_id = ?', [req.user.id]);

        await connection.commit();

        // 8. Automated lifecycle simulation (Simulation only)
        // In real production, this would be a Cron Job or Queue Job.
        setTimeout(async () => {
             try {
                await pool.query('UPDATE orders SET status = "Shipped", updated_at = NOW() WHERE id = ? AND status = "Pending"', [orderId]);
                console.log(`[Order Lifecycle] Order #${orderId} moved to SHIPPED`);
             } catch(e) {}
        }, 12 * 60 * 60 * 1000); // 12 hours

        setTimeout(async () => {
            try {
                await pool.query('UPDATE orders SET status = "Delivered", updated_at = NOW() WHERE id = ? AND status = "Shipped"', [orderId]);
                console.log(`[Order Lifecycle] Order #${orderId} moved to DELIVERED`);
            } catch(e) {}
        }, 48 * 60 * 60 * 1000); // 48 hours

        res.status(201).json({ message: 'Order placed successfully', orderId });
    } catch (error) {
        if(connection) await connection.rollback();
        console.error("Order Creation Error:", error);
        res.status(500).json({ message: 'Server error creating order' });
    } finally {
        if(connection) connection.release();
    }
});

// @desc    Get logged in user orders
// @route   GET /api/orders
// @access  Private
router.get('/', protect, async (req, res) => {
    try {
        // LEFT JOIN payments to get the payment_method for each order
        // (payment_method is in payments table, NOT in orders table)
        const [dbOrders] = await pool.query(`
            SELECT o.*,
                   pay.payment_method,
                   f.rating  AS feedback_rating,
                   f.comment AS feedback_comment
            FROM orders o
            LEFT JOIN payments pay ON pay.order_id = o.id
            LEFT JOIN order_feedback f ON f.order_id = o.id
            WHERE o.user_id = ?
            ORDER BY o.created_at DESC
        `, [req.user.id]);

        // Catch-Up Logic: If order is older than 12/48 hours but status remains Pending/Shipped, update locally.
        const orders = dbOrders.map(o => {
            const now = new Date();
            const createdAt = new Date(o.created_at);
            const hoursElapsed = (now - createdAt) / (1000 * 60 * 60);

            if (o.status === 'Pending' && hoursElapsed >= 12) {
                o.status = 'Shipped';
                // Trigger soft update in DB background (not awaiting to keep response fast)
                pool.query('UPDATE orders SET status = "Shipped" WHERE id = ?', [o.id]).catch(() => {});
            } 
            if ((o.status === 'Shipped' || o.status === 'Pending') && hoursElapsed >= 48) {
                o.status = 'Delivered';
                pool.query('UPDATE orders SET status = "Delivered" WHERE id = ?', [o.id]).catch(() => {});
            }
            return o;
        });

        // Fetch items for each order
        // LEFT JOIN product_images because products table has NO image_url column
        for (let order of orders) {
            const [items] = await pool.query(`
                SELECT oi.quantity,
                       oi.unit_price AS price,
                       p.title,
                       pi.image_url
                FROM order_items oi
                JOIN products p ON oi.product_id = p.id
                LEFT JOIN product_images pi
                       ON pi.product_id = p.id AND pi.is_primary = TRUE
                WHERE oi.order_id = ?
            `, [order.id]);
            order.items = items;
        }

        res.json(orders);
    } catch (error) {
        console.error('GET /orders error:', error);
        res.status(500).json({ message: 'Server error fetching orders' });
    }
});

// @desc    Cancel an order
// @route   DELETE /api/orders/:id
// @access  Private
router.delete('/:id', protect, async (req, res) => {
    try {
        const orderId = req.params.id;
        
        // Find order
        const [orderCheck] = await pool.query('SELECT user_id, status FROM orders WHERE id = ?', [orderId]);
        if(orderCheck.length === 0) return res.status(404).json({ message: 'Order not found' });
        
        const order = orderCheck[0];
        
        // Verify ownership
        if(order.user_id !== req.user.id) return res.status(403).json({ message: 'Not authorized' });
        
        // Prevent cancel if already delivered
        if(['Delivered', 'Cancelled'].includes(order.status)) {
            return res.status(400).json({ message: 'Cannot cancel an order that is already ' + order.status });
        }
        
        // Update to cancelled instead of hard delete
        await pool.query('UPDATE orders SET status = "Cancelled", updated_at = NOW() WHERE id = ?', [orderId]);
        
        res.json({ message: 'Order Cancelled Successfully' });
    } catch(err) {
        console.error(err);
        res.status(500).json({ message: 'Server Error cancelling order' });
    }
});

// @desc    Submit feedback for a delivered order
// @route   POST /api/orders/feedback
// @access  Private
router.post('/feedback', protect, async (req, res) => {
    try {
        const { order_id, rating, comment } = req.body;
        
        if(!order_id || !rating || rating < 1 || rating > 5) {
            return res.status(400).json({ message: 'A valid rating (1-5) and order_id are required' });
        }

        const [orderCheck] = await pool.query('SELECT user_id, status FROM orders WHERE id = ?', [order_id]);
        if(orderCheck.length === 0) return res.status(404).json({ message: 'Order not found' });
        
        const order = orderCheck[0];
        if(order.user_id !== req.user.id) return res.status(403).json({ message: 'Not authorized' });
        if(order.status !== 'Delivered') return res.status(400).json({ message: 'Feedback is only allowed for delivered orders' });

        // Add to order_feedback
        await pool.query(
            'INSERT INTO order_feedback (order_id, user_id, rating, comment) VALUES (?, ?, ?, ?)',
            [order_id, req.user.id, rating, comment]
        );

        res.status(201).json({ message: 'Thank you for your feedback!' });
    } catch(err) {
        if(err.code === 'ER_DUP_ENTRY') {
            return res.status(400).json({ message: 'You have already submitted feedback for this order' });
        }
        console.error(err);
        res.status(500).json({ message: 'Server error saving feedback' });
    }
});

module.exports = router;
