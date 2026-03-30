const express = require('express');
const router = express.Router();
const { protect } = require('../middlewares/authMiddleware');
const pool = require('../config/db');

// @desc    Get user cart details with product info
// @route   GET /api/cart
// @access  Private
router.get('/', protect, async (req, res) => {
    try {
        const [cartItems] = await pool.query(`
            SELECT c.id as cart_id, c.quantity, p.id, p.title, p.price, p.discount_price, p.tax_percentage, p.product_brand, pi.image_url 
            FROM cart c 
            JOIN products p ON c.product_id = p.id 
            LEFT JOIN product_images pi ON pi.product_id = p.id AND pi.is_primary = TRUE
            WHERE c.user_id = ?
        `, [req.user.id]);
        
        let subtotal = 0;
        let totalGst = 0;

        const enhancedCart = cartItems.map(item => {
            // MySQL DECIMAL columns arrive as strings — cast everything to numbers
            const price         = parseFloat(item.price)          || 0;
            const discountPrice = item.discount_price != null ? parseFloat(item.discount_price) : null;
            const taxPct        = parseFloat(item.tax_percentage)  || 18;
            const qty           = parseInt(item.quantity)          || 1;

            const activePrice = discountPrice !== null ? discountPrice : price;
            const itemTotal   = activePrice * qty;
            const itemGst     = itemTotal * (taxPct / 100);

            subtotal += itemTotal;
            totalGst += itemGst;

            return {
                ...item,
                // Overwrite with properly typed numbers
                price,
                discount_price: discountPrice,
                tax_percentage: taxPct,
                quantity:       qty,
                active_price:   activePrice,
                item_total:     parseFloat(itemTotal.toFixed(2)),
                item_gst:       parseFloat(itemGst.toFixed(2)),
                total_with_gst: parseFloat((itemTotal + itemGst).toFixed(2))
            };
        });

        res.json({
            items: enhancedCart,
            summary: {
                cart_subtotal:    parseFloat(subtotal.toFixed(2)),
                total_gst:        parseFloat(totalGst.toFixed(2)),
                cart_grand_total: parseFloat((subtotal + totalGst).toFixed(2))
            }
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error fetching cart' });
    }
});

// @desc    Get cart summary from View (DBMS specific)
// @route   GET /api/cart/summary
// @access  Private
router.get('/summary', protect, async (req, res) => {
    try {
        const [summary] = await pool.query('SELECT * FROM vw_cart_summary_with_tax WHERE user_id = ?', [req.user.id]);
        if (summary.length > 0) {
            res.json(summary[0]);
        } else {
            res.json({ cart_subtotal: 0, total_gst: 0, cart_grand_total: 0 });
        }
    } catch(err) {
        console.error(err);
        res.status(500).json({ message: 'Server error fetching cart summary' });
    }
});

// @desc    Add item to cart
// @route   POST /api/cart
// @access  Private
router.post('/', protect, async (req, res) => {
    const { productId, quantity } = req.body;
    try {
        await pool.query(
            'INSERT INTO cart (user_id, product_id, quantity) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE quantity = quantity + ?', 
            [req.user.id, productId, quantity || 1, quantity || 1]
        );
        res.json({ message: 'Cart updated' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error updating cart' });
    }
});

// @desc    Sync cart items (mass upload/replace)
// @route   POST /api/cart/sync
// @access  Private
router.post('/sync', protect, async (req, res) => {
    const { cart } = req.body; // array of {id, quantity}
    if(!Array.isArray(cart)) return res.status(400).json({message: "Invalid cart format"});
    
    try {
        // Clear existing cart for sync
        await pool.query('DELETE FROM cart WHERE user_id = ?', [req.user.id]);
        
        if (cart.length > 0) {
            const insertValues = cart.map(item => [req.user.id, item.id, item.quantity]);
            await pool.query('INSERT IGNORE INTO cart (user_id, product_id, quantity) VALUES ?', [insertValues]);
        }
        res.json({ message: 'Cart synced successfully' });
    } catch(err) {
        console.error(err);
        res.status(500).json({ message: 'Server error syncing cart' });
    }
});

module.exports = router;
