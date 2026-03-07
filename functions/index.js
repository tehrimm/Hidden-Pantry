const functions = require('firebase-functions'); // Deployment Force: 2026-02-19T01:23:00
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Scheduled function to delete rejected nutritionist accounts after 5 days
 * if they haven't logged in after rejection.
 * 
 * Runs daily at 2:00 AM UTC
 */
exports.deleteRejectedNutritionists = functions.pubsub
    .schedule('0 2 * * *') // Daily at 2:00 AM UTC
    .timeZone('UTC')
    .onRun(async (context) => {
        const db = admin.firestore();
        const storage = admin.storage();
        const auth = admin.auth();

        console.log('Starting rejected nutritionist cleanup...');

        try {
            // Get all rejected nutritionists
            const snapshot = await db
                .collection('nutritionists')
                .where('verificationStatus', '==', 'rejected')
                .where('hasLoggedInAfterRejection', '==', false)
                .get();

            if (snapshot.empty) {
                console.log('No rejected nutritionists to process');
                return null;
            }

            const now = admin.firestore.Timestamp.now();
            const fiveDaysAgo = new Date(now.toDate().getTime() - 5 * 24 * 60 * 60 * 1000);

            let deletedCount = 0;
            const batch = db.batch();

            for (const doc of snapshot.docs) {
                const data = doc.data();
                const rejectionDate = data.rejectionDate?.toDate();

                if (!rejectionDate) {
                    console.log(`Skipping ${doc.id}: no rejection date`);
                    continue;
                }

                // Check if 5 days have passed since rejection
                if (rejectionDate < fiveDaysAgo) {
                    console.log(`Deleting nutritionist ${doc.id} (rejected on ${rejectionDate})`);

                    // Delete certificate from storage if exists
                    if (data.certificateUrl) {
                        try {
                            const bucket = storage.bucket();
                            const filePath = decodeURIComponent(
                                data.certificateUrl.split('/o/')[1].split('?')[0]
                            );
                            await bucket.file(filePath).delete();
                            console.log(`Deleted certificate for ${doc.id}`);
                        } catch (error) {
                            console.error(`Error deleting certificate for ${doc.id}:`, error);
                            // Continue with account deletion even if certificate deletion fails
                        }
                    }

                    // Delete Firestore document
                    batch.delete(doc.ref);

                    // Delete Firebase Auth account
                    try {
                        await auth.deleteUser(doc.id);
                        console.log(`Deleted auth account for ${doc.id}`);
                    } catch (error) {
                        console.error(`Error deleting auth account for ${doc.id}:`, error);
                        // Continue even if auth deletion fails
                    }

                    deletedCount++;
                }
            }

            // Commit batch delete
            if (deletedCount > 0) {
                await batch.commit();
                console.log(`Successfully deleted ${deletedCount} rejected nutritionist(s)`);
            } else {
                console.log('No nutritionists met the 5-day deletion criteria');
            }

            return null;
        } catch (error) {
            console.error('Error in deleteRejectedNutritionists:', error);
            throw error;
        }
    });

/**
 * Triggered when a nutritionist document is updated.
 * Sends a push notification if verificationStatus changes to 'approved' or 'rejected'.
 */
exports.onNutritionistStatusChange = functions.firestore
    .document('nutritionists/{uid}')
    .onUpdate(async (change, context) => {
        const after = change.after.data();
        const before = change.before.data();

        // Check if status changed
        if (after.verificationStatus === before.verificationStatus) {
            return null;
        }

        const uid = context.params.uid;

        // NEW: Delete certificate immediately if approved or rejected
        if ((after.verificationStatus === 'approved' || after.verificationStatus === 'rejected') && after.certificateUrl) {
            try {
                const storage = admin.storage();
                const bucket = storage.bucket();
                // Extract file path from Firebase Storage URL
                const filePath = decodeURIComponent(
                    after.certificateUrl.split('/o/')[1].split('?')[0]
                );
                await bucket.file(filePath).delete();
                console.log(`Deleted certificate for ${uid} on status: ${after.verificationStatus}`);

                // Clear URL in Firestore
                await change.after.ref.update({
                    certificateUrl: admin.firestore.FieldValue.delete()
                });
            } catch (error) {
                console.error(`Error deleting certificate for ${uid}:`, error);
                // Notification flow continues even if deletion fails
            }
        }

        const fcmToken = after.fcmToken;
        if (!fcmToken) {
            console.log(`No FCM token for user ${context.params.uid}`);
            return null;
        }

        let title = '';
        let body = '';

        if (after.verificationStatus === 'approved') {
            title = 'Account Approved! 🎉';
            body = 'Congratulations! Your nutritionist account has been approved. You can now access the dashboard.';
        } else if (after.verificationStatus === 'rejected') {
            title = 'Account Update';
            body = `Your account verification was rejected. Reason: ${after.rejectionReason || 'Not specified'}.`;
        } else {
            return null;
        }

        const message = {
            notification: {
                title: title,
                body: body,
            },
            token: fcmToken,
            data: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                status: after.verificationStatus,
            }
        };

        try {
            await admin.messaging().send(message);
            console.log(`Notification sent to ${context.params.uid}`);
        } catch (error) {
            console.error('Error sending notification:', error);
        }
    });

/**
 * Generic trigger for all user and nutritionist notifications.
 * Sends a push notification whenever a new doc is added to any 'notifications' subcollection.
 */
exports.onNotificationCreated = functions.firestore
    .document('{collection}/{uid}/notifications/{id}')
    .onCreate(async (snap, context) => {
        const data = snap.data();
        const { collection, uid } = context.params;

        // Only handle 'users' and 'nutritionists' collections
        if (collection !== 'users' && collection !== 'nutritionists') {
            return null;
        }

        // 1. Fetch recipient's FCM token and preferences
        const db = admin.firestore();
        const recipientDoc = await db.collection(collection).doc(uid).get();
        const recipientData = recipientDoc.data() || {};
        const fcmToken = recipientData.fcmToken;

        // Check user preferences
        if (recipientData.notificationsEnabled === false) {
            console.log(`Push notifications are disabled for ${collection}/${uid}.`);
            return null;
        }

        if (!fcmToken) {
            console.log(`No FCM token for ${collection}/${uid}. Skipping push.`);
            return null;
        }

        // 2. Build the message
        const message = {
            notification: {
                title: data.title || 'New Notification',
                body: data.body || '',
            },
            data: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: data.type || '',
                id: data.targetId || '',
                senderId: data.senderId || '',
            },
            token: fcmToken,
        };

        try {
            await admin.messaging().send(message);
            console.log(`Push sent to ${collection}/${uid} for notification ${context.params.id}`);
        } catch (error) {
            console.error('Error sending push:', error);
        }
        return null;
    });

// ═══════════════════════════════════════════════════════════════
// STRIPE PAYMENT & SUBSCRIPTION FUNCTIONS
// ═══════════════════════════════════════════════════════════════

const stripe = require('stripe')(functions.config().stripe?.secret_key || 'sk_test_REPLACE_ME');

// ─────────────────────────────────────────────────────────────────
// NEW STRIPE CONNECT FUNCTIONS
// ─────────────────────────────────────────────────────────────────

/**
 * CALLABLE: Onboard a nutritionist to Stripe Connect (Standard).
 * Creates a Standard account and returns an Account Link URL.
 */
exports.onboardNutritionist = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const uid = context.auth.uid;
    const db = admin.firestore();
    const nutRef = db.collection('nutritionists').doc(uid);
    const nutDoc = await nutRef.get();

    if (!nutDoc.exists) {
        throw new functions.https.HttpsError('not-found', 'Nutritionist profile not found');
    }

    let stripeAccountId = nutDoc.data().stripeAccountId;

    try {
        // 1. Create a Standard Account if they don't have one
        if (!stripeAccountId) {
            const account = await stripe.accounts.create({
                type: 'standard',
                email: nutDoc.data().email,
                metadata: { firebaseUid: uid },
            });
            stripeAccountId = account.id;
            await nutRef.update({ stripeAccountId });
        }

        // 2. Create an Account Link for the onboarding flow
        const accountLink = await stripe.accountLinks.create({
            account: stripeAccountId,
            refresh_url: 'https://arched-sunbeam-478306-u3.web.app/stripe-onboarding-retry',
            return_url: 'https://arched-sunbeam-478306-u3.web.app/stripe-onboarding-success',
            type: 'account_onboarding',
        });

        return { url: accountLink.url };
    } catch (error) {
        console.error('onboardNutritionist error:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * CALLABLE: Create a Stripe Checkout session for a user to subscribe to a nutritionist.
 * Uses Direct Charges (payment goes straight to nutritionist account).
 */
exports.createNutritionistCheckout = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    let { planTitle, price, interval, nutritionistId, nutritionistName, tierLevel, existingSubscriptionId } = data;

    // Robustly parse price and tierLevel
    price = parseFloat(String(price || 0).replace(/[^\d.-]/g, ''));
    tierLevel = parseInt(String(tierLevel || 1).replace(/[^\d]/g, '')) || 1;

    if (isNaN(price) || price <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid price provided');
    }

    const uid = context.auth.uid;
    const db = admin.firestore();

    const nutDoc = await db.collection('nutritionists').doc(nutritionistId).get();
    const stripeAccountId = nutDoc.data()?.stripeAccountId;

    if (!stripeAccountId) {
        console.warn(`Checkout failed: Nutritionist ${nutritionistId} (${nutritionistName}) has no stripeAccountId`);
        throw new functions.https.HttpsError('failed-precondition', 'Nutritionist has not set up their Stripe account yet.');
    }

    const userDoc = await db.collection('users').doc(uid).get();
    const userName = userDoc.exists ? (userDoc.data().fullName || userDoc.data().name || 'User') : 'User';

    // Map interval
    const intervalMap = { 'week': 'week', 'weekly': 'week', 'month': 'month', 'monthly': 'month', 'year': 'year', 'yearly': 'year' };
    const stripeInterval = intervalMap[(interval || 'month').toLowerCase()] || 'month';

    try {
        let proRatedCredit = 0;
        let oldStripeSubId = null;
        let trialEnd = undefined; // Prevent "Invalid integer" error from Stripe by using undefined instead of null
        let isDowngrade = false;

        if (existingSubscriptionId) {
            const oldSubSnap = await db.collection('subscriptions').doc(existingSubscriptionId).get();
            if (oldSubSnap.exists) {
                const oldData = oldSubSnap.data();
                oldStripeSubId = oldData.stripeSubscriptionId;

                const expiryDate = oldData.expiryDate?.toDate();
                const now = new Date();
                const oldTier = oldData.tierLevel || 1;
                const newTier = tierLevel || 1;

                if (newTier > oldTier) {
                    // ── UPGRADE LOGIC ──
                    if (expiryDate && expiryDate > now) {
                        const status = oldData.status;
                        if (status !== 'trialing') {
                            const oldPrice = parseFloat(oldData.price) || 0;
                            const totalDays = 30;
                            const diffInMs = expiryDate.getTime() - now.getTime();
                            const remainingDays = Math.max(0, Math.ceil(diffInMs / (1000 * 60 * 60 * 24)));
                            proRatedCredit = (oldPrice / totalDays) * Math.min(remainingDays, totalDays);
                        }
                    }
                } else if (newTier < oldTier) {
                    // ── DOWNGRADE LOGIC ──
                    // Access starts only after current tier expires
                    isDowngrade = true;
                    if (expiryDate && expiryDate > now) {
                        trialEnd = Math.floor(expiryDate.getTime() / 1000);
                    }
                }
            }
        }

        // 1. Create a pending subscription doc
        const subDoc = await db.collection('subscriptions').add({
            userId: uid,
            nutritionistId,
            nutritionistName,
            planId: planTitle,
            price: price || 0,
            tierLevel: tierLevel || 1,
            interval: interval || 'Monthly',
            status: 'pending',
            // FIX: Don't grant future access for pending subs
            expiryDate: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            type: 'direct_subscription',
            userName,
            oldSubscriptionId: existingSubscriptionId,
            isDowngrade,
        });

        // 2. Prepare discounts for Upgrade
        let discounts = [];
        if (proRatedCredit > 0.5) {
            const coupon = await stripe.coupons.create({
                amount_off: Math.round(proRatedCredit * 100),
                currency: 'pkr',
                duration: 'once',
                name: `Upgrade Credit (${planTitle})`,
            });
            discounts = [{ coupon: coupon.id }];
        }

        // 3. Create Checkout Session
        const session = await stripe.checkout.sessions.create({
            mode: 'subscription',
            payment_method_types: ['card'],
            line_items: [{
                price_data: {
                    currency: 'pkr',
                    product_data: {
                        name: `${nutritionistName} - ${planTitle}`,
                        description: isDowngrade ? `Scheduled Downgrade to ${planTitle}` : `Upgrade to ${planTitle}`,
                    },
                    unit_amount: Math.round(price * 100),
                    recurring: { interval: stripeInterval },
                },
                quantity: 1,
            }],
            discounts,
            subscription_data: {
                trial_end: trialEnd, // Used for Downgrades: no charge until this date
                transfer_data: { destination: stripeAccountId },
                metadata: {
                    subscriptionDocId: subDoc.id,
                    userId: uid,
                    nutritionistId,
                    tierLevel: String(tierLevel || 1),
                    oldStripeSubId: oldStripeSubId || '',
                    isDowngrade: isDowngrade ? 'true' : 'false',
                },
            },
            success_url: 'https://arched-sunbeam-478306-u3.web.app/payment-success?session_id={CHECKOUT_SESSION_ID}',
            cancel_url: 'https://arched-sunbeam-478306-u3.web.app/payment-cancelled',
            metadata: {
                userId: uid,
                nutritionistId,
                planTitle,
                price: String(price),
                tierLevel: String(tierLevel || 1),
                type: 'user_subscription',
                subscriptionDocId: subDoc.id,
                userName,
                oldStripeSubId: oldStripeSubId || '',
                isDowngrade: isDowngrade ? 'true' : 'false',
            },
        });

        return { url: session.url, sessionId: session.id, subscriptionDocId: subDoc.id };
    } catch (error) {
        console.error('createNutritionistCheckout error:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});


/**
 * CALLABLE: Create a Stripe Checkout session for the nutritionist to pay SaaS fee to platform.
 */
exports.subscribeToPlatform = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const uid = context.auth.uid;
    const db = admin.firestore();
    const nutDoc = await db.collection('nutritionists').doc(uid).get();

    try {
        const session = await stripe.checkout.sessions.create({
            mode: 'subscription',
            payment_method_types: ['card'],
            line_items: [{
                price_data: {
                    currency: 'pkr',
                    product_data: {
                        name: 'Hidden Pantry Nutritionist SaaS Fee',
                        description: 'Monthly platform membership fee',
                    },
                    unit_amount: 1200 * 100, // Fixed SaaS fee of 1200 PKR
                    recurring: { interval: 'month' },
                },
                quantity: 1,
            }],
            success_url: 'https://arched-sunbeam-478306-u3.web.app/saas-success',
            cancel_url: 'https://arched-sunbeam-478306-u3.web.app/saas-cancelled',
            metadata: {
                nutritionistId: uid,
                type: 'platform_saas'
            },
        });

        return { url: session.url, sessionId: session.id };
    } catch (error) {
        console.error('subscribeToPlatform error:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});

/**
 * CALLABLE: Cancel a subscription at period end.
 */
exports.cancelSubscription = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const { subscriptionDocId } = data;
    if (!subscriptionDocId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing subscriptionDocId');
    }

    const db = admin.firestore();
    const docRef = db.collection('subscriptions').doc(subscriptionDocId);
    const doc = await docRef.get();

    if (!doc.exists) {
        throw new functions.https.HttpsError('not-found', 'Subscription not found');
    }

    // Verify ownership
    if (doc.data().userId !== context.auth.uid) {
        throw new functions.https.HttpsError('permission-denied', 'Not your subscription');
    }

    const stripeSubId = doc.data().stripeSubscriptionId;

    try {
        if (stripeSubId) {
            // Cancel at period end (user keeps access until expiry)
            await stripe.subscriptions.update(stripeSubId, {
                cancel_at_period_end: true,
            });
        }

        await docRef.update({
            isCancelled: true,
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return { success: true };
    } catch (error) {
        console.error('cancelSubscription error:', error);
        throw new functions.https.HttpsError('internal', error.message || 'Cancellation failed');
    }
});

/**
 * CALLABLE: Nutritionist requests a payout of their current balance.
 */
exports.requestPayout = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const uid = context.auth.uid;
    const { amount, payoutMethod } = data;

    if (!amount || amount <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid payout amount');
    }

    const db = admin.firestore();
    const nutRef = db.collection('nutritionists').doc(uid);

    try {
        return await db.runTransaction(async (transaction) => {
            const nutDoc = await transaction.get(nutRef);
            if (!nutDoc.exists) {
                throw new Error('Nutritionist profile not found');
            }

            const currentBalance = nutDoc.data().currentBalance || 0;
            if (currentBalance < amount) {
                throw new Error('Insufficient balance for this payout request');
            }

            // 1. Create payout record
            const payoutRef = db.collection('payouts').doc();
            transaction.set(payoutRef, {
                nutritionistId: uid,
                amount: amount,
                status: 'pending',
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                payoutMethod: payoutMethod || 'Default',
                nutritionistName: nutDoc.data().fullName || 'Nutritionist',
            });

            // 2. Deduct from balance
            transaction.update(nutRef, {
                currentBalance: admin.firestore.FieldValue.increment(-amount),
                pendingPayouts: admin.firestore.FieldValue.increment(amount),
            });

            return { success: true, payoutId: payoutRef.id };
        });
    } catch (error) {
        console.error('requestPayout error:', error);
        throw new functions.https.HttpsError('internal', error.message || 'Payout request failed');
    }
});

/**
 * HTTP: Stripe Webhook endpoint.
 * Handles invoice.paid (renewal) and customer.subscription.deleted (deactivation).
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecret = functions.config().stripe?.webhook_secret || 'whsec_REPLACE_ME';

    let event;
    try {
        event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
    } catch (err) {
        console.error('Webhook signature verification failed. Please ensure stripe.webhook_secret is set in firebase functions:config.');
        console.error('Error:', err.message);
        return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    const db = admin.firestore();

    try {
        switch (event.type) {
            case 'checkout.session.completed': {
                const session = event.data.object;
                const metadata = session.metadata;

                if (metadata.type === 'user_subscription') {
                    // ── Case 1: User subscribed to a Nutritionist ──
                    const { userId, nutritionistId, planTitle, price, subscriptionDocId, tierLevel, oldStripeSubId } = metadata;
                    console.log(`User ${userId} subscribed to Nut ${nutritionistId} for ${price} (Session: ${session.id}, Tier: ${tierLevel})`);

                    if (subscriptionDocId) {
                        // Update the pending doc to active
                        const expiryDate = new Date();
                        expiryDate.setMonth(expiryDate.getMonth() + 1);

                        await db.collection('subscriptions').doc(subscriptionDocId).update({
                            status: 'active',
                            tierLevel: parseInt(tierLevel) || 1,
                            stripeSubscriptionId: session.subscription,
                            expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                        });
                        console.log(`Updated subscription doc ${subscriptionDocId} to active with tier ${tierLevel}`);
                    } else {
                        // Fallback: create a new subscription doc
                        const expiryDate = new Date();
                        expiryDate.setMonth(expiryDate.getMonth() + 1);

                        await db.collection('subscriptions').add({
                            userId,
                            nutritionistId,
                            planId: planTitle,
                            price: parseFloat(price) || 0,
                            tierLevel: parseInt(tierLevel) || 1,
                            status: 'active',
                            stripeSubscriptionId: session.subscription,
                            expiryDate: admin.firestore.Timestamp.fromDate(expiryDate),
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                            type: 'direct_subscription',
                            userName: metadata.userName,
                        });
                    }

                    // ── Handle Interaction with Old Subscription ──
                    if (oldStripeSubId) {
                        try {
                            if (metadata.isDowngrade === 'true') {
                                // DOWNGRADE: Cancel old sub at period end (don't delete immediately)
                                await stripe.subscriptions.update(oldStripeSubId, {
                                    cancel_at_period_end: true,
                                });
                                console.log(`Scheduled old sub ${oldStripeSubId} to cancel at period end for downgrade.`);
                            } else {
                                // UPGRADE: Delete immediately
                                await stripe.subscriptions.del(oldStripeSubId);
                                console.log(`Deleted old sub ${oldStripeSubId} immediately for upgrade.`);
                            }

                            // Mark old record in Firestore
                            const oldSubSnap = await db.collection('subscriptions')
                                .where('stripeSubscriptionId', '==', oldStripeSubId)
                                .limit(1)
                                .get();

                            if (!oldSubSnap.empty) {
                                await oldSubSnap.docs[0].ref.update({
                                    status: metadata.isDowngrade === 'true' ? 'downgrading' : 'upgraded',
                                    isCancelled: metadata.isDowngrade === 'true' ? true : false,
                                    replacementSubId: subscriptionDocId || 'new_sub',
                                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                                });
                            }
                        } catch (e) {
                            console.warn(`Failed to process old sub ${oldStripeSubId}: ${e.message}`);
                        }
                    }

                    // Record Earning for Nutritionist
                    try {
                        const amount = session.amount_total / 100;
                        await db.collection('nutritionists').doc(nutritionistId).collection('earnings_history').add({
                            amount: amount,
                            userName: metadata.userName || 'Subscriber',
                            userUid: userId,
                            planTitle: planTitle,
                            timestamp: admin.firestore.FieldValue.serverTimestamp(),
                            stripeSessionId: session.id,
                            type: 'new_subscription'
                        });

                        await db.collection('nutritionists').doc(nutritionistId).update({
                            totalEarnings: admin.firestore.FieldValue.increment(amount),
                            currentBalance: admin.firestore.FieldValue.increment(amount)
                        });
                        console.log(`Recorded earning of ${amount} for ${nutritionistId}`);
                    } catch (e) {
                        console.error(`Failed to record earning for ${nutritionistId}:`, e);
                    }
                } else if (metadata.type === 'platform_saas') {
                    // ── Case 2: Nutritionist paid SaaS fee to Platform ──
                    const { nutritionistId } = metadata;
                    console.log(`Nutritionist ${nutritionistId} paid SaaS fee (Session: ${session.id})`);

                    await db.collection('nutritionists').doc(nutritionistId).update({
                        saasStatus: 'active',
                        saasExpiryDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)), // 30 days
                        lastSaaSPaymentAt: admin.firestore.FieldValue.serverTimestamp(),
                    });

                    // Record SaaS payment history
                    await db.collection('platform_payments').add({
                        nutritionistId,
                        amount: session.amount_total / 100,
                        currency: session.currency,
                        status: 'paid',
                        stripeSessionId: session.id,
                        type: 'initial_saas_payment',
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }
                break;
            }

            case 'invoice.paid': {
                const invoice = event.data.object;
                const subscriptionId = invoice.subscription;

                console.log(`Invoice ${invoice.id} paid for subscription ${subscriptionId}`);

                // Check if it's a SaaS renewal
                const nutSnap = await db.collection('nutritionists')
                    .where('stripeSaaSSubscriptionId', '==', subscriptionId)
                    .limit(1)
                    .get();

                if (!nutSnap.empty) {
                    const nutId = nutSnap.docs[0].id;
                    await nutSnap.docs[0].ref.update({
                        saasStatus: 'active',
                        saasExpiryDate: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 32 * 24 * 60 * 60 * 1000)),
                    });

                    // Record SaaS renewal history
                    await db.collection('platform_payments').add({
                        nutritionistId: nutId,
                        amount: invoice.amount_paid / 100,
                        currency: invoice.currency,
                        status: 'paid',
                        stripeInvoiceId: invoice.id,
                        type: 'saas_renewal',
                        createdAt: admin.firestore.FieldValue.serverTimestamp()
                    });
                }

                // Check if it's a user subscription renewal
                const subSnap = await db.collection('subscriptions')
                    .where('stripeSubscriptionId', '==', subscriptionId)
                    .limit(1)
                    .get();

                if (!subSnap.empty) {
                    const expiryDate = new Date();
                    expiryDate.setMonth(expiryDate.getMonth() + 1);
                    await subSnap.docs[0].ref.update({
                        status: 'active',
                        expiryDate: admin.firestore.Timestamp.fromDate(expiryDate)
                    });

                    // Record Earning for Nutritionist (Renewal)
                    try {
                        const subData = subSnap.docs[0].data();
                        const nutritionistId = subData.nutritionistId;
                        const amount = invoice.amount_paid / 100;

                        await db.collection('nutritionists').doc(nutritionistId).collection('earnings_history').add({
                            amount: amount,
                            userName: subData.userName || 'Subscriber',
                            userUid: subData.userId,
                            planTitle: subData.planId || 'Subscription',
                            timestamp: admin.firestore.FieldValue.serverTimestamp(),
                            stripeInvoiceId: invoice.id,
                            type: 'renewal'
                        });

                        await db.collection('nutritionists').doc(nutritionistId).update({
                            totalEarnings: admin.firestore.FieldValue.increment(amount),
                            currentBalance: admin.firestore.FieldValue.increment(amount)
                        });
                        console.log(`Recorded renewal earning of ${amount} for ${nutritionistId}`);
                    } catch (e) {
                        console.error(`Failed to record renewal earning:`, e);
                    }
                }
                break;
            }

            case 'invoice.payment_failed': {
                const invoice = event.data.object;
                const stripeSubId = invoice.subscription;

                // If it's a SaaS subscription failure, deactivate nutritionist
                const nutSnap = await db.collection('nutritionists')
                    .where('stripeSaaSSubscriptionId', '==', stripeSubId)
                    .limit(1)
                    .get();

                if (!nutSnap.empty) {
                    const nutId = nutSnap.docs[0].id;
                    console.log(`SaaS Payment Failed for Nutritionist ${nutId}. Deactivating listing.`);
                    await db.collection('nutritionists').doc(nutId).update({
                        saasStatus: 'past_due',
                        // Optional: hide profile from users
                        isActive: false
                    });
                }
                break;
            }

            case 'customer.subscription.deleted': {
                const subscription = event.data.object;
                const stripeSubId = subscription.id;

                // 1. Check if it's a platform SaaS subscription
                const nutSnap = await db.collection('nutritionists')
                    .where('stripeSaaSSubscriptionId', '==', stripeSubId)
                    .limit(1)
                    .get();

                if (!nutSnap.empty) {
                    await nutSnap.docs[0].ref.update({
                        saasStatus: 'unpaid',
                        isActive: false
                    });
                }

                // 2. Check if it's a user subscription
                const subSnap = await db.collection('subscriptions')
                    .where('stripeSubscriptionId', '==', stripeSubId)
                    .limit(1)
                    .get();

                if (!subSnap.empty) {
                    await subSnap.docs[0].ref.update({ status: 'expired' });
                }
                break;
            }

            default:
                console.log(`Unhandled event type: ${event.type}`);
        }
    } catch (err) {
        console.error(`Error processing webhook ${event.id}:`, err);
        return res.status(500).send('Internal Server Error');
    }

    res.status(200).json({ received: true });
});

/**
 * SCHEDULED: Check for expired subscriptions daily and downgrade them.
 */
exports.checkExpiredSubscriptions = functions.pubsub
    .schedule('0 3 * * *') // Daily at 3:00 AM UTC
    .timeZone('UTC')
    .onRun(async (context) => {
        const db = admin.firestore();
        const now = new Date();

        try {
            const snapshot = await db.collection('subscriptions')
                .where('status', '==', 'active')
                .where('expiryDate', '<', now)
                .get();

            if (snapshot.empty) {
                console.log('No expired subscriptions to process');
                return null;
            }

            const batch = db.batch();
            let count = 0;

            for (const doc of snapshot.docs) {
                batch.update(doc.ref, { status: 'expired' });
                count++;
            }

            await batch.commit();
            console.log(`Downgraded ${count} expired subscription(s)`);

            return null;
        } catch (error) {
            console.error('checkExpiredSubscriptions error:', error);
            throw error;
        }
    });

/**
 * CALLABLE: Cleanup when ANY user deletes their account.
 * Handles both Nutritionists (cleanup their subscribers) and Regular Users (cleanup their own subscriptions).
 */
exports.cleanupUserDeletion = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const uid = context.auth.uid;
    const db = admin.firestore();

    try {
        console.log(`Starting account deletion cleanup for user ${uid}`);

        // --- 1. CLEANUP AS A NUTRITIONIST (if applicable) ---
        const nutDoc = await db.collection('nutritionists').doc(uid).get();
        if (nutDoc.exists) {
            const nutritionistName = nutDoc.data().fullName || 'Your nutritionist';

            // Find all active/pending subscriptions TO this nutritionist
            const incomingSubs = await db.collection('subscriptions')
                .where('nutritionistId', '==', uid)
                .where('status', 'in', ['active', 'pending'])
                .get();

            console.log(`Cleaning up ${incomingSubs.size} incoming subscriptions for nutritionist ${uid}`);

            const affectedUsers = new Map();

            for (const subDoc of incomingSubs.docs) {
                const subData = subDoc.data();

                // Cancel Stripe sub
                if (subData.stripeSubscriptionId) {
                    try {
                        await stripe.subscriptions.cancel(subData.stripeSubscriptionId);
                    } catch (e) {
                        console.warn(`Failed to cancel incoming Stripe sub ${subData.stripeSubscriptionId}: ${e.message}`);
                    }
                }

                // Update Firestore
                await subDoc.ref.update({
                    status: 'cancelled',
                    isCancelled: true,
                    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                    cancellationReason: 'nutritionist_account_deleted',
                    cancellationNote: `${nutritionistName} has left the platform`,
                });

                // Prepare notifications
                if (subData.userId) {
                    const userDoc = await db.collection('users').doc(subData.userId).get();
                    if (userDoc.exists && userDoc.data().fcmToken) {
                        affectedUsers.set(subData.userId, userDoc.data().fcmToken);
                    }
                }
            }

            // Notify subscribers
            const notifications = [];
            for (const [userId, token] of affectedUsers) {
                notifications.push(
                    admin.messaging().send({
                        token: token,
                        notification: {
                            title: 'Subscription Update',
                            body: `${nutritionistName} has left the platform. Your subscription has been cancelled.`,
                        },
                    }).catch(e => console.warn(`Failed notification for ${userId}: ${e.message}`))
                );
            }
            await Promise.all(notifications);
        }

        // --- 2. CLEANUP AS A SUBSCRIBER (cancel own outgoing subs) ---
        const outgoingSubs = await db.collection('subscriptions')
            .where('userId', '==', uid)
            .where('status', 'in', ['active', 'pending'])
            .get();

        console.log(`Cleaning up ${outgoingSubs.size} outgoing subscriptions for user ${uid}`);

        for (const subDoc of outgoingSubs.docs) {
            const subData = subDoc.data();

            // Cancel Stripe sub
            if (subData.stripeSubscriptionId) {
                try {
                    await stripe.subscriptions.cancel(subData.stripeSubscriptionId);
                    console.log(`Cancelled outgoing Stripe sub ${subData.stripeSubscriptionId}`);
                } catch (e) {
                    console.warn(`Failed to cancel outgoing Stripe sub ${subData.stripeSubscriptionId}: ${e.message}`);
                }
            }

            // Update Firestore
            await subDoc.ref.update({
                status: 'cancelled',
                isCancelled: true,
                cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
                cancellationReason: 'user_account_deleted',
                cancellationNote: `User deleted their account`,
            });
        }

        return { success: true };
    } catch (error) {
        console.error('cleanupUserDeletion error:', error);
        throw new functions.https.HttpsError('internal', error.message || 'Cleanup failed');
    }
});

/**
 * CALLABLE: Get accurate nutritionist stats (posts, subscribers) bypassing client side rules.
 */
exports.getNutritionistStats = functions.https.onCall(async (data, context) => {
    const { nutritionistId } = data;
    if (!nutritionistId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing nutritionistId');
    }

    const db = admin.firestore();

    try {
        let totalPosts = 0;

        // 1. Get Tips Count
        const tipsCountSnap = await db.collection('nutritionists').doc(nutritionistId).collection('tips').count().get();
        totalPosts += tipsCountSnap.data().count || 0;

        // 2. Get Meal Plans Count
        const plansCountSnap = await db.collection('nutritionists').doc(nutritionistId).collection('meal_plans').count().get();
        totalPosts += plansCountSnap.data().count || 0;

        // 3. Get Unique Subscribers (including trialing)
        const subsSnap = await db.collection('subscriptions')
            .where('nutritionistId', '==', nutritionistId)
            .where('status', 'in', ['active', 'trialing'])
            .get();

        const uniqueUserIds = new Set();
        subsSnap.forEach(doc => {
            const data = doc.data();
            if (data.userId) {
                uniqueUserIds.add(data.userId);
            } else {
                uniqueUserIds.add(doc.id);
            }
        });

        const totalSubs = uniqueUserIds.size;

        return {
            posts: totalPosts,
            subs: totalSubs
        };
    } catch (error) {
        console.error('getNutritionistStats error:', error);
        throw new functions.https.HttpsError('internal', 'Error calculating stats.');
    }
});

