INSERT INTO hotel_bookings (
    id, org_id, hotel_id, city, checkin_date, checkout_date,
    amount, status, created_at
)
SELECT
    gen_random_uuid(),
    ('00000000-0000-0000-0000-' || lpad(((gs - 1) % 6 + 1)::text, 12, '0'))::uuid,
    'hotel-' || lpad((((gs - 1) % 20) + 1)::text, 3, '0'),
    (ARRAY['delhi', 'mumbai', 'bangalore', 'hyderabad', 'pune'])[((gs - 1) % 5) + 1],
    CURRENT_DATE + ((gs % 25) - 10),
    CURRENT_DATE + ((gs % 25) - 7),
    round((1500 + (random() * 14500))::numeric, 2),
    (ARRAY['confirmed', 'pending', 'cancelled', 'completed'])[((gs - 1) % 4) + 1],
    NOW() - ((gs % 45) || ' days')::interval - ((gs % 24) || ' hours')::interval
FROM generate_series(1, 120) AS gs;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT
    id,
    CASE WHEN row_number_value % 2 = 0 THEN 'booking.created' ELSE 'booking.updated' END,
    jsonb_build_object('source', 'seed', 'sequence', row_number_value),
    created_at + interval '1 hour'
FROM (
    SELECT id, created_at, row_number() OVER (ORDER BY created_at, id) AS row_number_value
    FROM hotel_bookings
) b
WHERE row_number_value <= 60;
