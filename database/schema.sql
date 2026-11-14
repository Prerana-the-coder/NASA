-- ==========================================
-- NASA PLANETARY EXPLORATION DATABASE
-- PostgreSQL + PostGIS
-- ==========================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. PLANETS
CREATE TABLE planets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(50) UNIQUE NOT NULL,
    planet_type VARCHAR(30) NOT NULL,
    radius_km NUMERIC(12,3),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. REGIONS
CREATE TABLE regions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    planet_id UUID NOT NULL REFERENCES planets(id),
    name VARCHAR(200) NOT NULL,
    region_type VARCHAR(100),
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    elevation_m NUMERIC(12,3),
    earth_geometry GEOMETRY(MultiPolygon, 4326),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),

    UNIQUE(planet_id, name)
);

CREATE INDEX idx_regions_planet
ON regions(planet_id);

CREATE INDEX idx_regions_earth_geometry
ON regions USING GIST(earth_geometry);

-- 3. DATA SOURCES
CREATE TABLE data_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    organization VARCHAR(100),
    base_url TEXT,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. DATASETS
CREATE TABLE datasets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID REFERENCES data_sources(id),
    name VARCHAR(200) NOT NULL,
    external_dataset_id TEXT,
    data_type VARCHAR(100),
    resolution_m NUMERIC(12,3),
    format VARCHAR(50),
    description TEXT,
    license TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_datasets_source
ON datasets(source_id);

CREATE INDEX idx_datasets_metadata
ON datasets USING GIN(metadata);

-- 5. DATASET ASSETS
CREATE TABLE dataset_assets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dataset_id UUID NOT NULL REFERENCES datasets(id),
    external_product_id TEXT,
    asset_name TEXT,
    storage_uri TEXT NOT NULL,
    file_format VARCHAR(50),
    file_size_bytes BIGINT,
    checksum TEXT,
    status VARCHAR(30) DEFAULT 'registered',
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_assets_dataset
ON dataset_assets(dataset_id);

-- 6. MISSIONS
CREATE TABLE missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) UNIQUE NOT NULL,
    agency VARCHAR(100),
    target_planet_id UUID REFERENCES planets(id),
    launch_date DATE,
    end_date DATE,
    mission_url TEXT,
    description TEXT
);

-- 7. INSTRUMENTS
CREATE TABLE instruments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mission_id UUID REFERENCES missions(id),
    name VARCHAR(200) NOT NULL,
    instrument_type VARCHAR(100),
    description TEXT
);

-- 8. OBSERVATIONS
CREATE TABLE observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id UUID REFERENCES regions(id),
    dataset_id UUID REFERENCES datasets(id),
    mission_id UUID REFERENCES missions(id),
    instrument_id UUID REFERENCES instruments(id),
    observed_at TIMESTAMPTZ,
    observation_type VARCHAR(100),
    value JSONB DEFAULT '{}',
    provenance JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_observations_region
ON observations(region_id);

CREATE INDEX idx_observations_dataset
ON observations(dataset_id);

CREATE INDEX idx_observations_date
ON observations(observed_at);

-- 9. TERRAIN MEASUREMENTS
CREATE TABLE terrain_measurements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id UUID NOT NULL REFERENCES regions(id),
    dataset_asset_id UUID REFERENCES dataset_assets(id),
    measured_at TIMESTAMPTZ,
    elevation_mean_m NUMERIC(12,4),
    elevation_min_m NUMERIC(12,4),
    elevation_max_m NUMERIC(12,4),
    slope_mean_deg NUMERIC(10,4),
    roughness_mean_m NUMERIC(12,4),
    valid_pixel_count BIGINT,
    resolution_m NUMERIC(12,3),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_terrain_region
ON terrain_measurements(region_id);

-- 10. FINGERPRINT PROFILES
CREATE TABLE fingerprint_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id UUID NOT NULL REFERENCES regions(id),
    version VARCHAR(30) NOT NULL,
    algorithm VARCHAR(100),
    status VARCHAR(30) DEFAULT 'generated',
    feature_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(region_id, version)
);

-- 11. FINGERPRINT FEATURES
CREATE TABLE fingerprint_features (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fingerprint_id UUID NOT NULL
        REFERENCES fingerprint_profiles(id) ON DELETE CASCADE,
    feature_name VARCHAR(100) NOT NULL,
    feature_value NUMERIC(20,8),
    unit VARCHAR(50),
    normalized_value NUMERIC(20,8),
    confidence NUMERIC(5,4),
    source_asset_id UUID REFERENCES dataset_assets(id),
    metadata JSONB DEFAULT '{}',

    UNIQUE(fingerprint_id, feature_name)
);

CREATE INDEX idx_features_fingerprint
ON fingerprint_features(fingerprint_id);

-- 12. EARTH ANALOGS
CREATE TABLE earth_analogs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    region_id UUID UNIQUE NOT NULL REFERENCES regions(id),
    analog_category VARCHAR(100),
    research_relevance TEXT,
    verified BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 13. ANALOG MATCHES
CREATE TABLE analog_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    planetary_fingerprint_id UUID NOT NULL
        REFERENCES fingerprint_profiles(id),
    earth_analog_id UUID NOT NULL
        REFERENCES earth_analogs(id),
    similarity_score NUMERIC(7,6),
    algorithm VARCHAR(100),
    feature_comparison JSONB DEFAULT '{}',
    explanation TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CHECK (
        similarity_score IS NULL OR
        similarity_score BETWEEN 0 AND 1
    ),

    UNIQUE(planetary_fingerprint_id, earth_analog_id, algorithm)
);

CREATE INDEX idx_analog_score
ON analog_matches(similarity_score DESC);

-- 14. KNOWLEDGE ENTITIES
CREATE TABLE knowledge_entities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type VARCHAR(100) NOT NULL,
    entity_name VARCHAR(200) NOT NULL,
    region_id UUID REFERENCES regions(id),
    mission_id UUID REFERENCES missions(id),
    description TEXT,
    metadata JSONB DEFAULT '{}'
);

-- 15. KNOWLEDGE RELATIONSHIPS
CREATE TABLE knowledge_relationships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_entity_id UUID NOT NULL
        REFERENCES knowledge_entities(id),
    target_entity_id UUID NOT NULL
        REFERENCES knowledge_entities(id),
    relationship_type VARCHAR(100) NOT NULL,
    confidence NUMERIC(5,4),
    evidence JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),

    CHECK (source_entity_id <> target_entity_id),
    UNIQUE(
        source_entity_id,
        target_entity_id,
        relationship_type
    )
);

CREATE INDEX idx_graph_source
ON knowledge_relationships(source_entity_id);

CREATE INDEX idx_graph_target
ON knowledge_relationships(target_entity_id);

-- ==========================================
-- SCHEMA COMPLETE
-- ==========================================
