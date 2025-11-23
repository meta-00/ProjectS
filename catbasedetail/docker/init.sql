
-- สร้างตาราง  cat_breeds — ข้อมูลสายพันธุ์แมว
CREATE TABLE cat_breeds (
    id SERIAL PRIMARY KEY,                          
    name VARCHAR(255) NOT NULL,                     
    origin VARCHAR(255),                             
    description TEXT,                               
    care_instructions TEXT,                         
    image_url TEXT,                                 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้าง function สำหรับอัพเดท updated_at โดยอัตโนมัติ

CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE 'plpgsql';

-- สร้าง trigger เพื่อเรียกใช้ function update_modified_column
CREATE TRIGGER update_breeds_modtime
BEFORE UPDATE ON cat_breeds
FOR EACH ROW
EXECUTE FUNCTION update_modified_column();

  -- Index สำหรับค้นหาชื่อสายพันธุ์เร็วขึ้น
CREATE INDEX idx_cat_breeds_name ON cat_breeds(name);

  --สร้าง ตาราง discussions — คอมเมนต์ของผู้ใช้

CREATE TABLE discussions (
    id SERIAL PRIMARY KEY,
    breed_id INTEGER NOT NULL REFERENCES cat_breeds(id) ON DELETE CASCADE,
    user_name VARCHAR(255) NOT NULL,                 -- ชื่อผู้พิมพ์ (ใช้แทน users table ก่อน)
    message TEXT NOT NULL,                           -- เนื้อหาคอมเมนต์
    parent_id INTEGER REFERENCES discussions(id) ON DELETE CASCADE, -- สำหรับ reply
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

 --ตาราง discussion_reactions — Like / Dislike

CREATE TABLE discussion_reactions (
    id SERIAL PRIMARY KEY,
    discussion_id INTEGER NOT NULL REFERENCES discussions(id) ON DELETE CASCADE,
    user_name VARCHAR(255) NOT NULL,                 -- ใครกด like/dislike
    reaction_type VARCHAR(20) NOT NULL CHECK (reaction_type IN ('like', 'dislike')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
-- ป้องกันกดซ้ำคนเดิม
CREATE UNIQUE INDEX unique_reaction_per_user
ON discussion_reactions(discussion_id, user_name);

--สร้าง ENUM สำหรับ rating_type
CREATE TYPE rating_type_enum AS ENUM (
    'friendly',        -- ความเป็นมิตร
    'easy_to_care',    -- ความง่ายในการเลี้ยง
    'grooming_need',   -- การดูแลขน
    'energy_level'    -- ขี้เล่น
);

--สร้างตาราง breed_ratings ใหม่ โดยใช้ ENUM
CREATE TABLE breed_ratings (
    id SERIAL PRIMARY KEY,
    breed_id INTEGER NOT NULL REFERENCES cat_breeds(id) ON DELETE CASCADE,
    rating_type rating_type_enum NOT NULL,               -- บังคับให้เป็น ENUM ที่กำหนด
    rating_value INTEGER NOT NULL CHECK (rating_value BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);


-- Index ให้ค้นคะแนนของสายพันธุ์ได้เร็วขึ้น
CREATE INDEX idx_breed_ratings_breed ON breed_ratings(breed_id);


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