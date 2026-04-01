-- 1. Create Colleges Table
CREATE TABLE IF NOT EXISTS colleges (
    college_id BIGSERIAL PRIMARY KEY,
    college_name VARCHAR(255) NOT NULL,
    college_type VARCHAR(100),
    district VARCHAR(100),
    city VARCHAR(100)
);

-- 2. Create Courses Table
CREATE TABLE IF NOT EXISTS courses (
    course_id BIGSERIAL PRIMARY KEY,
    college_id BIGINT NOT NULL,
    course_name VARCHAR(255) NOT NULL,
    CONSTRAINT fk_college_course FOREIGN KEY(college_id) REFERENCES colleges(college_id) ON DELETE CASCADE
);

-- 3. Create Cutoff History Table
CREATE TABLE IF NOT EXISTS cutoff_history (
    cutoff_id BIGSERIAL PRIMARY KEY,
    year INTEGER NOT NULL,
    college_id BIGINT NOT NULL,
    course_id BIGINT NOT NULL,
    category VARCHAR(50),
    opening_cutoff DOUBLE PRECISION,
    closing_cutoff DOUBLE PRECISION,
    CONSTRAINT fk_college_cutoff FOREIGN KEY(college_id) REFERENCES colleges(college_id) ON DELETE CASCADE,
    CONSTRAINT fk_course_cutoff FOREIGN KEY(course_id) REFERENCES courses(course_id) ON DELETE CASCADE
);

-- CREATE INDEXES for performance
CREATE INDEX IF NOT EXISTS idx_college_id_courses ON courses(college_id);
CREATE INDEX IF NOT EXISTS idx_college_id_cutoff ON cutoff_history(college_id);
CREATE INDEX IF NOT EXISTS idx_course_id_cutoff ON cutoff_history(course_id);
