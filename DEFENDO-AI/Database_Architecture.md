# SecureNow Database Architecture

This document outlines the comprehensive database schema for the SecureNow application using Supabase as the backend service.

## 🗄️ Database Overview

The SecureNow database is built on PostgreSQL with Supabase, providing:
- **Real-time subscriptions** for live updates
- **Row Level Security (RLS)** for data protection
- **Built-in authentication** with JWT tokens
- **Automatic API generation** for all tables
- **Real-time presence** for user status tracking

## 📊 Core Tables

### 1. Users Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    name VARCHAR(255) NOT NULL,
    role user_role DEFAULT 'user',
    safety_score INTEGER DEFAULT 85,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login TIMESTAMP WITH TIME ZONE,
    is_verified BOOLEAN DEFAULT FALSE,
    profile_image_url TEXT,
    emergency_contacts_count INTEGER DEFAULT 0,
    total_bookings INTEGER DEFAULT 0,
    total_sos_alerts INTEGER DEFAULT 0
);

-- User roles enum
CREATE TYPE user_role AS ENUM ('user', 'provider', 'admin', 'guest');
```

### 2. Emergency Contacts
```sql
CREATE TABLE emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    relationship VARCHAR(100),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_notified TIMESTAMP WITH TIME ZONE,
    notification_count INTEGER DEFAULT 0
);
```

### 3. Safety Zones
```sql
CREATE TABLE safety_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    color safety_color NOT NULL,
    risk_level INTEGER CHECK (risk_level BETWEEN 1 AND 5),
    center_latitude DECIMAL(10, 8) NOT NULL,
    center_longitude DECIMAL(11, 8) NOT NULL,
    radius_meters INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    incident_count INTEGER DEFAULT 0,
    last_incident TIMESTAMP WITH TIME ZONE
);

-- Safety color enum
CREATE TYPE safety_color AS ENUM ('green', 'yellow', 'red');
```

### 4. SOS Alerts
```sql
CREATE TABLE sos_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    status sos_status DEFAULT 'active',
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    address TEXT,
    description TEXT,
    device_info JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES users(id),
    police_notified BOOLEAN DEFAULT FALSE,
    emergency_contacts_notified BOOLEAN DEFAULT FALSE,
    location_accuracy DECIMAL(5, 2),
    battery_level INTEGER,
    signal_strength INTEGER
);

-- SOS status enum
CREATE TYPE sos_status AS ENUM ('active', 'resolved', 'cancelled', 'false_alarm');
```

### 5. Location History
```sql
CREATE TABLE location_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    accuracy DECIMAL(5, 2),
    speed DECIMAL(5, 2),
    heading DECIMAL(5, 2),
    altitude DECIMAL(8, 2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    address TEXT,
    safety_zone_id UUID REFERENCES safety_zones(id),
    safety_score INTEGER
);
```

### 6. Incident Reports
```sql
CREATE TABLE incident_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID REFERENCES users(id) ON DELETE CASCADE,
    incident_type incident_type NOT NULL,
    description TEXT NOT NULL,
    location TEXT NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    status report_status DEFAULT 'pending',
    severity severity_level DEFAULT 'medium',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES users(id),
    attachments JSONB,
    witness_count INTEGER DEFAULT 0,
    police_report_number VARCHAR(100)
);

-- Incident type enum
CREATE TYPE incident_type AS ENUM ('assault', 'theft', 'medical', 'suspicious', 'other');

-- Report status enum
CREATE TYPE report_status AS ENUM ('pending', 'investigating', 'resolved', 'dismissed');

-- Severity level enum
CREATE TYPE severity_level AS ENUM ('low', 'medium', 'high', 'critical');
```

### 7. Service Providers
```sql
CREATE TABLE service_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    description TEXT,
    service_types service_type[] NOT NULL,
    license_number VARCHAR(100),
    insurance_info JSONB,
    verification_status verification_status DEFAULT 'pending',
    rating DECIMAL(3, 2) DEFAULT 0,
    total_reviews INTEGER DEFAULT 0,
    hourly_rate DECIMAL(8, 2),
    is_available BOOLEAN DEFAULT TRUE,
    coverage_area JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Service type enum
CREATE TYPE service_type AS ENUM ('security_guard', 'drone_patrol', 'surveillance', 'consultation');

-- Verification status enum
CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected', 'suspended');
```

### 8. Bookings
```sql
CREATE TABLE bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES service_providers(id) ON DELETE CASCADE,
    service_type service_type NOT NULL,
    booking_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    duration_hours INTEGER NOT NULL,
    location TEXT NOT NULL,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    status booking_status DEFAULT 'pending',
    price DECIMAL(8, 2) NOT NULL,
    payment_status payment_status DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    provider_notes TEXT,
    user_notes TEXT
);

-- Booking status enum
CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled');

-- Payment status enum
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'refunded', 'failed');
```

### 9. Reviews
```sql
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    reviewer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES service_providers(id) ON DELETE CASCADE,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5) NOT NULL,
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_verified BOOLEAN DEFAULT FALSE
);
```

### 10. Notifications
```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Notification type enum
CREATE TYPE notification_type AS ENUM ('sos_alert', 'booking_update', 'safety_alert', 'emergency_contact', 'system');
```

## 🔐 Row Level Security (RLS)

### Users Table RLS
```sql
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Admins can view all users" ON users
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
);
```

### Emergency Contacts RLS
```sql
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own emergency contacts" ON emergency_contacts
    FOR ALL USING (user_id = auth.uid());
```

### SOS Alerts RLS
```sql
ALTER TABLE sos_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own SOS alerts" ON sos_alerts
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Users can create SOS alerts" ON sos_alerts
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admins can view all SOS alerts" ON sos_alerts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
```

## 🔄 Real-time Subscriptions

### SOS Alerts Subscription
```sql
-- Enable real-time for SOS alerts
ALTER PUBLICATION supabase_realtime ADD TABLE sos_alerts;

-- Subscribe to new SOS alerts (admin only)
CREATE OR REPLACE FUNCTION subscribe_to_sos_alerts()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify(
        'sos_alerts_channel',
        json_build_object(
            'operation', TG_OP,
            'record', row_to_json(NEW)
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sos_alerts_notify
    AFTER INSERT ON sos_alerts
    FOR EACH ROW EXECUTE FUNCTION subscribe_to_sos_alerts();
```

### Location Updates Subscription
```sql
-- Enable real-time for location history
ALTER PUBLICATION supabase_realtime ADD TABLE location_history;

-- Subscribe to location updates for safety monitoring
CREATE OR REPLACE FUNCTION subscribe_to_location_updates()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM pg_notify(
        'location_updates_channel',
        json_build_object(
            'user_id', NEW.user_id,
            'latitude', NEW.latitude,
            'longitude', NEW.longitude,
            'timestamp', NEW.timestamp
        )::text
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER location_updates_notify
    AFTER INSERT ON location_history
    FOR EACH ROW EXECUTE FUNCTION subscribe_to_location_updates();
```

## 📈 Analytics Views

### Safety Analytics View
```sql
CREATE VIEW safety_analytics AS
SELECT 
    DATE_TRUNC('day', created_at) as date,
    COUNT(*) as total_incidents,
    COUNT(CASE WHEN severity = 'critical' THEN 1 END) as critical_incidents,
    COUNT(CASE WHEN severity = 'high' THEN 1 END) as high_incidents,
    AVG(safety_score) as avg_safety_score
FROM incident_reports ir
LEFT JOIN location_history lh ON ir.latitude = lh.latitude AND ir.longitude = lh.longitude
GROUP BY DATE_TRUNC('day', created_at)
ORDER BY date DESC;
```

### User Activity View
```sql
CREATE VIEW user_activity AS
SELECT 
    u.id,
    u.name,
    u.email,
    u.safety_score,
    COUNT(DISTINCT sa.id) as sos_alerts_count,
    COUNT(DISTINCT b.id) as bookings_count,
    COUNT(DISTINCT ec.id) as emergency_contacts_count,
    MAX(sa.created_at) as last_sos_alert,
    MAX(b.created_at) as last_booking
FROM users u
LEFT JOIN sos_alerts sa ON u.id = sa.user_id
LEFT JOIN bookings b ON u.id = b.user_id
LEFT JOIN emergency_contacts ec ON u.id = ec.user_id
GROUP BY u.id, u.name, u.email, u.safety_score;
```

## 🔧 Database Functions

### Update Safety Score Function
```sql
CREATE OR REPLACE FUNCTION update_user_safety_score(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    new_score INTEGER;
BEGIN
    -- Calculate safety score based on recent incidents and location
    SELECT 
        CASE 
            WHEN COUNT(*) = 0 THEN 85
            WHEN COUNT(*) <= 2 THEN 70
            WHEN COUNT(*) <= 5 THEN 55
            ELSE 40
        END INTO new_score
    FROM incident_reports ir
    WHERE ir.latitude IN (
        SELECT latitude FROM location_history 
        WHERE user_id = user_uuid 
        AND timestamp > NOW() - INTERVAL '30 days'
    )
    AND ir.created_at > NOW() - INTERVAL '30 days';
    
    -- Update user's safety score
    UPDATE users 
    SET safety_score = new_score, updated_at = NOW()
    WHERE id = user_uuid;
    
    RETURN new_score;
END;
$$ LANGUAGE plpgsql;
```

### Emergency Contact Notification Function
```sql
CREATE OR REPLACE FUNCTION notify_emergency_contacts(
    user_uuid UUID,
    alert_message TEXT,
    location_data JSONB
)
RETURNS VOID AS $$
DECLARE
    contact_record RECORD;
BEGIN
    -- Get all emergency contacts for the user
    FOR contact_record IN 
        SELECT * FROM emergency_contacts 
        WHERE user_id = user_uuid AND is_primary = TRUE
    LOOP
        -- Insert notification for each emergency contact
        INSERT INTO notifications (user_id, type, title, message, data)
        VALUES (
            user_uuid,
            'emergency_contact',
            'Emergency Alert',
            alert_message,
            jsonb_build_object(
                'contact_name', contact_record.name,
                'contact_phone', contact_record.phone,
                'location', location_data
            )
        );
        
        -- Update contact notification count
        UPDATE emergency_contacts 
        SET notification_count = notification_count + 1,
            last_notified = NOW()
        WHERE id = contact_record.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

## 🚀 Performance Optimizations

### Indexes
```sql
-- Location-based queries
CREATE INDEX idx_location_history_user_timestamp ON location_history(user_id, timestamp DESC);
CREATE INDEX idx_location_history_coordinates ON location_history(latitude, longitude);

-- SOS alerts
CREATE INDEX idx_sos_alerts_user_status ON sos_alerts(user_id, status);
CREATE INDEX idx_sos_alerts_created_at ON sos_alerts(created_at DESC);

-- Incident reports
CREATE INDEX idx_incident_reports_location ON incident_reports(latitude, longitude);
CREATE INDEX idx_incident_reports_type_status ON incident_reports(incident_type, status);

-- Bookings
CREATE INDEX idx_bookings_user_date ON bookings(user_id, booking_date);
CREATE INDEX idx_bookings_provider_status ON bookings(provider_id, status);

-- Notifications
CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
```

### Partitioning
```sql
-- Partition location_history by month for better performance
CREATE TABLE location_history_2024_01 PARTITION OF location_history
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE location_history_2024_02 PARTITION OF location_history
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
```

## 🔒 Security Considerations

### Data Encryption
- All sensitive data is encrypted at rest
- TLS 1.3 for data in transit
- JWT tokens for API authentication
- Row Level Security (RLS) for data access control

### Backup Strategy
- Automated daily backups
- Point-in-time recovery
- Cross-region replication
- 30-day retention policy

### Monitoring
- Database performance monitoring
- Query performance analysis
- Security event logging
- Real-time alerting for anomalies

## 📊 Data Retention Policy

| Table | Retention Period | Archival Strategy |
|-------|-----------------|-------------------|
| location_history | 90 days | Archive to cold storage |
| sos_alerts | 1 year | Archive to cold storage |
| incident_reports | 2 years | Archive to cold storage |
| notifications | 30 days | Soft delete |
| reviews | Permanent | Keep active |
| users | Permanent | Keep active |

## 🔄 Migration Strategy

### Version Control
- All schema changes are versioned
- Migration scripts are tested in staging
- Rollback procedures for each migration
- Zero-downtime deployments

### Data Migration
- Incremental data migration
- Data validation checks
- Performance impact assessment
- User notification for breaking changes

---

This database architecture provides a robust foundation for the SecureNow application, ensuring scalability, security, and performance for all security-related features.
