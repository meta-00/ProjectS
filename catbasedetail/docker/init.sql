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
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE permissions (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
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
    
    -- Engagement metrics (เอา rating ออก)
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



INSERT INTO cat_breeds (name, origin, description, care_instructions, image_url) VALUES

-- 1. Persian
(
    'Persian',
    'Iran',
    'ประวัติความเป็นมา
ต้นกำเนิดของ Persian ย้อนกลับไปกว่า 400 ปีก่อน นักเดินทางชาวอิตาลีชื่อ Pietro Della Valle ได้พาแมวขนยาวจากเมือง Khorasan ในจักรวรรดิเปอร์เซีย(ปัจจุบันคืออิหร่าน) เข้ามายังยุโรปช่วงศตวรรษที่ 17 ก่อนเผยแพร่ไปยังฝรั่งเศสและอังกฤษ และกลายเป็นสัตว์เลี้ยงยอดนิยมของชนชั้นสูงในยุโรป
 พัฒนาการของสายพันธุ์
หลังสงครามโลกครั้งที่สอง Breeder หันมาพัฒนาสายพันธุ์ภายใน ปรับโครงหน้าให้กลม อ่อนหวาน และดูแบ๊วขึ้น จนกลายเป็นเอกลักษณ์แบบอเมริกัน
 ลักษณะเด่นและนิสัย
 รูปลักษณ์: ใบหน้ากลม ดวงตาโต กลม จมูกสั้น หูเล็ก ปลายมน ลำตัวสั้น ขาใหญ่ กล้ามเนื้อแน่น ขนยาวหนานุ่ม มีชั้นขนละเอียด ที่ต้องได้รับการดูแลสม่ำเสมอ
 นิสัย: นุ่มนวล รักสงบ อ่อนโยน ไม่ชอบเสียงดัง ชอบอยู่ในที่เงียบสงบ อบอุ่น ชอบนั่งใกล้เจ้าของ คลอเคลียเบาๆ เหมาะกับผู้เลี้ยงที่ใส่ใจในรายละเอียด',
    ' เคล็ดลับในการดูแล: แปรงขนทุกวันเพื่อป้องกันขนพันกัน ล้างหน้าเบาๆ โดยเฉพาะใต้ตา ดูแลด้วยความอ่อนโยนและสม่ำเสมอ',
    'https://example.com/images/persian.jpg'
),
-- 2. Siamese
(
    'Siamese',
    'Thailand',
    'ประวัติความเป็นมา
ต้นกำเนิดของ Siamese พบครั้งแรกในประเทศไทย มีชื่อเดิมว่า “Wa-Siam” หรือ “แมวสยาม” เป็นที่รู้จักในราชสำนักไทยและถูกนำไปยุโรปช่วงศตวรรษที่ 19 โดยนักเดินทางชาวยุโรป
พัฒนาการของสายพันธุ์
Siamese เป็นที่นิยมในอังกฤษและอเมริกา ถูกปรับปรุงลักษณะให้เรียวยาว ตาเฉียงสีฟ้า และนิสัยช่างพูดโดดเด่น
ลักษณะเด่นและนิสัย
รูปลักษณ์: ตัวเรียว ขนสั้น ใบหน้าลู่ ตาสีฟ้า ปลายหูและหางเข้มกว่าสีตัว
นิสัย: ขี้เล่น ช่างพูด ชอบเข้าสังคม รักเจ้าของ ชอบความสนใจ และฉลาด สามารถฝึกได้ง่าย',
    'เคล็ดลับในการดูแล: เล่นกับเจ้าของบ่อย ๆ ให้กิจกรรมและของเล่นกระตุ้นสมอง แปรงขนสัปดาห์ละครั้งก็เพียงพอ',
    'https://example.com/images/siamese.jpg'
),
-- 3. Ragdoll
(
    'Ragdoll',
    'USA',
    'ประวัติความเป็นมา
Ragdoll พัฒนาขึ้นในสหรัฐอเมริกาในปี 1960 โดย breeder ชื่อ Ann Baker ซึ่งได้ผสมแมวพันธุ์ Birman, Persian และ Angora จนได้แมวตัวใหญ่ ขนหนานุ่ม และนิสัยอ่อนโยน
พัฒนาการของสายพันธุ์
แมว Ragdoll มีชื่อเสียงเรื่องความใจเย็นและเชื่องมือ ทำให้เหมาะกับครอบครัว มีการปรับปรุงสายพันธุ์ให้คงความยาวขนและสีสวย
ลักษณะเด่นและนิสัย
รูปลักษณ์: ตัวใหญ่ ขนยาว หนานุ่ม ตาสีฟ้า หูและหางมีสีเข้ม
นิสัย: อ่อนโยน ขี้อ้อน ชอบอยู่บนตัก กอดเจ้าของ สุภาพและสงบ',
    'เคล็ดลับในการดูแล: แปรงขนสัปดาห์ละ 2–3 ครั้ง ตรวจฟันและหู ให้ความรักและการกอดอย่างสม่ำเสมอ',
    'https://example.com/images/ragdoll.jpg'
);