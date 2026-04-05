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
    college_code VARCHAR(50) NOT NULL,
    college_name VARCHAR(255) NOT NULL,
    branch VARCHAR(255) NOT NULL,
    oc_max DOUBLE PRECISION,
    oc_min DOUBLE PRECISION,
    bcm_max DOUBLE PRECISION,
    bcm_min DOUBLE PRECISION,
    bc_max DOUBLE PRECISION,
    bc_min DOUBLE PRECISION,
    mbc_max DOUBLE PRECISION,
    mbc_min DOUBLE PRECISION,
    sc_max DOUBLE PRECISION,
    sc_min DOUBLE PRECISION,
    sca_max DOUBLE PRECISION,
    sca_min DOUBLE PRECISION,
    st_max DOUBLE PRECISION,
    st_min DOUBLE PRECISION,
    PRIMARY KEY (college_code, branch)
);

-- CREATE INDEXES for performance
CREATE INDEX IF NOT EXISTS idx_college_id_courses ON courses(college_id);

CREATE INDEX IF NOT EXISTS idx_cutoff_college_code ON cutoff_history(college_code);
CREATE INDEX IF NOT EXISTS idx_cutoff_branch ON cutoff_history(branch);
