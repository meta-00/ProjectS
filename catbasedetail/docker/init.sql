-- ===================== USERS & AUTHENTICATION =====================

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    CONSTRAINT chk_username_length CHECK (char_length(username) >= 3),
    CONSTRAINT chk_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- ===================== ROLES & PERMISSIONS =====================

CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE permissions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_roles (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE role_permissions (
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    permission_id INTEGER REFERENCES permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- ===================== REFRESH TOKENS =====================

CREATE TABLE refresh_tokens (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(500) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);

-- ===================== AUDIT LOGS =====================

CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    resource VARCHAR(50) NOT NULL,
    resource_id VARCHAR(100),
    details JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- ===================== CAT BREEDS (Admin manages) =====================

CREATE TABLE cat_breeds (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    origin VARCHAR(255),
    description TEXT,
    care_instructions TEXT,
    image_url TEXT,
    
    -- Engagement metrics 
    like_count INTEGER DEFAULT 0,
    dislike_count INTEGER DEFAULT 0,
    discussion_count INTEGER DEFAULT 0,
    view_count INTEGER DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    
    CONSTRAINT chk_name_not_empty CHECK (char_length(name) > 0)
);

CREATE INDEX idx_cat_breeds_name ON cat_breeds(name);
CREATE INDEX idx_cat_breeds_created_at ON cat_breeds(created_at);

-- ===================== BREED REACTIONS (Like/Dislike) =====================

CREATE TYPE reaction_type_enum AS ENUM ('like', 'dislike');

CREATE TABLE breed_reactions (
    id SERIAL PRIMARY KEY,
    breed_id INTEGER NOT NULL REFERENCES cat_breeds(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction_type reaction_type_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- ผู้ใช้แต่ละคนกด like หรือ dislike ได้อันเดียวต่อ breed
    CONSTRAINT unique_user_breed_reaction UNIQUE (breed_id, user_id)
);

CREATE INDEX idx_breed_reactions_breed_id ON breed_reactions(breed_id);
CREATE INDEX idx_breed_reactions_user_id ON breed_reactions(user_id);

-- ===================== DISCUSSIONS (Comments) =====================

CREATE TABLE discussions (
    id SERIAL PRIMARY KEY,
    breed_id INTEGER NOT NULL REFERENCES cat_breeds(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    parent_id INTEGER REFERENCES discussions(id) ON DELETE CASCADE, -- สำหรับ reply
    
    -- Engagement
    like_count INTEGER DEFAULT 0,
    dislike_count INTEGER DEFAULT 0,
    reply_count INTEGER DEFAULT 0,
    
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_message_not_empty CHECK (char_length(message) > 0)
);

CREATE INDEX idx_discussions_breed_id ON discussions(breed_id);
CREATE INDEX idx_discussions_user_id ON discussions(user_id);
CREATE INDEX idx_discussions_parent_id ON discussions(parent_id);
CREATE INDEX idx_discussions_created_at ON discussions(created_at);

-- ===================== DISCUSSION REACTIONS (Like/Dislike Comments) =====================

CREATE TABLE discussion_reactions (
    id SERIAL PRIMARY KEY,
    discussion_id INTEGER NOT NULL REFERENCES discussions(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reaction_type reaction_type_enum NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- ป้องกันกดซ้ำ
    CONSTRAINT unique_user_discussion_reaction UNIQUE (discussion_id, user_id)
);

CREATE INDEX idx_discussion_reactions_discussion_id ON discussion_reactions(discussion_id);
CREATE INDEX idx_discussion_reactions_user_id ON discussion_reactions(user_id);

-- ===================== TRIGGERS =====================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER update_cat_breeds_modtime
    BEFORE UPDATE ON cat_breeds
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_breed_reactions_modtime
    BEFORE UPDATE ON breed_reactions
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_discussions_modtime
    BEFORE UPDATE ON discussions
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- ===================== BREED REACTION COUNTERS =====================

-- Update cat_breeds like/dislike count
CREATE OR REPLACE FUNCTION update_breed_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF NEW.reaction_type = 'like' THEN
            UPDATE cat_breeds SET like_count = like_count + 1 WHERE id = NEW.breed_id;
        ELSE
            UPDATE cat_breeds SET dislike_count = dislike_count + 1 WHERE id = NEW.breed_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- ถ้าเปลี่ยนจาก like -> dislike หรือ dislike -> like
        IF OLD.reaction_type = 'like' AND NEW.reaction_type = 'dislike' THEN
            UPDATE cat_breeds SET like_count = like_count - 1, dislike_count = dislike_count + 1 
            WHERE id = NEW.breed_id;
        ELSIF OLD.reaction_type = 'dislike' AND NEW.reaction_type = 'like' THEN
            UPDATE cat_breeds SET dislike_count = dislike_count - 1, like_count = like_count + 1 
            WHERE id = NEW.breed_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        IF OLD.reaction_type = 'like' THEN
            UPDATE cat_breeds SET like_count = like_count - 1 WHERE id = OLD.breed_id;
        ELSE
            UPDATE cat_breeds SET dislike_count = dislike_count - 1 WHERE id = OLD.breed_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_breed_reaction_count
AFTER INSERT OR UPDATE OR DELETE ON breed_reactions
FOR EACH ROW EXECUTE FUNCTION update_breed_reaction_count();

-- ===================== DISCUSSION REACTION COUNTERS =====================

-- Update discussions like/dislike count
CREATE OR REPLACE FUNCTION update_discussion_reaction_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF NEW.reaction_type = 'like' THEN
            UPDATE discussions SET like_count = like_count + 1 WHERE id = NEW.discussion_id;
        ELSE
            UPDATE discussions SET dislike_count = dislike_count + 1 WHERE id = NEW.discussion_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF OLD.reaction_type = 'like' AND NEW.reaction_type = 'dislike' THEN
            UPDATE discussions SET like_count = like_count - 1, dislike_count = dislike_count + 1 
            WHERE id = NEW.discussion_id;
        ELSIF OLD.reaction_type = 'dislike' AND NEW.reaction_type = 'like' THEN
            UPDATE discussions SET dislike_count = dislike_count - 1, like_count = like_count + 1 
            WHERE id = NEW.discussion_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        IF OLD.reaction_type = 'like' THEN
            UPDATE discussions SET like_count = like_count - 1 WHERE id = OLD.discussion_id;
        ELSE
            UPDATE discussions SET dislike_count = dislike_count - 1 WHERE id = OLD.discussion_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_discussion_reaction_count
AFTER INSERT OR UPDATE OR DELETE ON discussion_reactions
FOR EACH ROW EXECUTE FUNCTION update_discussion_reaction_count();

-- ===================== DISCUSSION COUNTER =====================

-- Update cat_breeds discussion_count
CREATE OR REPLACE FUNCTION update_breed_discussion_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE cat_breeds SET discussion_count = discussion_count + 1 WHERE id = NEW.breed_id;
        -- Update parent reply count if this is a reply
        IF NEW.parent_id IS NOT NULL THEN
            UPDATE discussions SET reply_count = reply_count + 1 WHERE id = NEW.parent_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE cat_breeds SET discussion_count = discussion_count - 1 WHERE id = OLD.breed_id;
        IF OLD.parent_id IS NOT NULL THEN
            UPDATE discussions SET reply_count = reply_count - 1 WHERE id = OLD.parent_id;
        END IF;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_breed_discussion_count
AFTER INSERT OR DELETE ON discussions
FOR EACH ROW EXECUTE FUNCTION update_breed_discussion_count();


-- ===================== INITIAL DATA =====================

-- Insert default roles
INSERT INTO roles (name) VALUES
('admin'),
('user');

-- Insert permissions
INSERT INTO permissions (name) VALUES
-- Cat breed permissions
('breed.create'),
('breed.update'),
('breed.delete'),
('breed.view'),

-- Discussion permissions
('discussion.create'),
('discussion.update'),
('discussion.delete'),
('discussion.delete.any'),

-- Reaction permissions
('reaction.create');

-- Assign permissions to roles
-- Admin gets all permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.name = 'admin';

-- User gets limited permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p 
WHERE r.name = 'user' AND p.name IN (
    'breed.view',
    'discussion.create', 'discussion.update', 'discussion.delete',
    'reaction.create'
);



-- Insert sample cat breeds
INSERT INTO cat_breeds (name, origin, description, care_instructions, image_url) VALUES
('Persian', 'Iran', 
 'แมวเปอร์เซียเป็นสายพันธุ์ที่มีขนยาวและนุ่มนวล หน้าแบนและตาโต เป็นแมวที่นิ่งและชอบอยู่ในบ้าน มีนิสัยสงบเสงี่ยม เหมาะกับการเลี้ยงในอพาร์ทเมนท์',
 'ต้องหวีขนทุกวันเพื่อป้องกันขนพันกัน อาบน้ำเดือนละ 1-2 ครั้ง ตัดเล็บสม่ำเสมอ ทำความสะอาดรอบดวงตาเป็นประจำ',
 'https://images.unsplash.com/photo-1518791841217-8f162f1e1131'),
 
('Siamese', 'Thailand', 
 'แมวสยามเป็นแมวพันธุ์ไทย มีลักษณะเด่นคือหูใหญ่ ตาสีฟ้า ขนสีอ่อนจุดสีเข้มที่หู หน้า ขา และหาง มีนิสัยช่างพูด ชอบสนใจและเข้าหาเจ้าของ',
 'หวีขนสัปดาห์ละ 2-3 ครั้ง ชอบพูดคุยและต้องการความสนใจ ให้อาหารคุณภาพดี เล่นกับแมวเป็นประจำ',
 'https://images.unsplash.com/photo-1513360371669-4adf3dd7dff8'),
 
('Maine Coon', 'United States', 
 'แมวเมนคูนเป็นแมวขนาดใหญ่ มีขนยาวและหนา เป็นมิตร ฉลาด และชอบเล่นกับน้ำ มีนิสัยอ่อนโยนและเป็นมิตรกับทุกคน',
 'หวีขนสัปดาห์ละ 2-3 ครั้ง ต้องการพื้นที่ออกกำลังกาย ให้อาหารโปรตีนสูง มีน้ำสะอาดให้ตลอดเวลา',
 'https://images.unsplash.com/photo-1574158622682-e40e69881006'),
 
('Scottish Fold', 'Scotland',
 'แมวสก็อตติชโฟลด์มีลักษณะเด่นคือหูพับ ตัวกลม น่ารัก นิสัยอ่อนโยนและเป็นมิตร ชอบอยู่กับคนและสัตว์เลี้ยงอื่นๆ',
 'หวีขนสัปดาห์ละ 2-3 ครั้ง ตรวจหูสม่ำเสมอเพราะหูพับ เล่นกับแมวเป็นประจำ ให้ความรักและความสนใจ',
 'https://images.unsplash.com/photo-1568152950566-c1bf43f4ab28'),

('British Shorthair', 'United Kingdom',
 'แมวบริติชชอร์ตแฮร์มีรูปร่างกลมอ้วน หน้ากลม แก้มป่อง ตาโต มีนิสัยสงบ อิสระ แต่ก็เป็นมิตรและรักเจ้าของ',
 'หวีขนสัปดาห์ละ 1-2 ครั้ง ควบคุมน้ำหนักเพราะชอบอ้วน ให้อาหารตามปริมาณที่เหมาะสม',
 'https://images.unsplash.com/photo-1595433707802-6b2626ef1c91');


-- ===================== INSERT USERS & ADMIN =====================

-- สร้าง Users ทั่วไป
-- หมายเหตุ: password_hash ในตัวอย่างนี้เป็นการ hash จาก bcrypt สำหรับรหัสผ่าน "password123"
-- ในการใช้งานจริงควรใช้ bcrypt หรือ argon2 ในการ hash รหัสผ่าน

INSERT INTO users (username, email, password_hash, is_active) VALUES
-- Admin user (password: admin123)
('admin', 'admin@catbreeds.com', '$2a$12$Jh17GEOUujYkjq/l/8JFsuSL.6xNamnMKVPWmyHskZZZUGU24Gbwq', true),

-- Regular users (password: password123)
('john_doe', 'john@example.com', '$2a$12$X./jfZnL4iH5tRwPdKO16OCDu5McGtDrwNIjjxItukO0rZzkjXFNe', true),
-- Regular users (password: password1234)
('jane_smith', 'jane@example.com', '$2a$12$5.XT7TZatli8vo3/Wsiez.OLaEc.AcTT29xVXeHKTqSC3hBGr6s..', true);

-- ===================== INSERT ROLES =====================

INSERT INTO roles (name) VALUES
('admin'),
('user');
-- ===================== INSERT PERMISSIONS =====================

INSERT INTO permissions (name) VALUES
-- Breed Management
('breed.create'),
('breed.read'),
('breed.update'),
('breed.delete'),

-- Discussion Management
('discussion.create'),
('discussion.read'),
('discussion.update'),
('discussion.delete'),

-- Reaction Management
('reaction.create'),
('reaction.delete'),

-- User Management
('user.read'),
('user.update'),
('user.delete'),
('user.manage_roles'),

-- Audit
('audit.read');

-- ===================== ASSIGN ROLES TO USERS =====================

-- Admin gets admin role
INSERT INTO user_roles (user_id, role_id) VALUES
(1, 1); -- admin user gets admin role

-- Regular users get user role
INSERT INTO user_roles (user_id, role_id) VALUES
(2, 3), -- john_doe gets user role
(3, 3), -- jane_smith gets user role
(4, 3), -- cat_lover99 gets user role
(5, 3), -- meow_master gets user role
(6, 3); -- fluffy_fan gets user role

-- ===================== ASSIGN PERMISSIONS TO ROLES =====================

-- Admin role gets ALL permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 1, id FROM permissions;


-- User role permissions
INSERT INTO role_permissions (role_id, permission_id)
SELECT 3, id FROM permissions
WHERE name IN (
    'breed.read',
    'discussion.create', 'discussion.read', 'discussion.update', 'discussion.delete',
    'reaction.create', 'reaction.delete'
);



-- ===================== UPDATE LAST LOGIN =====================

UPDATE users
SET last_login = CURRENT_TIMESTAMP
WHERE id IN (1, 2, 3);