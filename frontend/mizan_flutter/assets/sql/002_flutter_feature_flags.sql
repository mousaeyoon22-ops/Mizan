-- Mizan Flutter Client — Cached Operational Feature Preferences (Offline-Safe)
CREATE TABLE IF NOT EXISTS local_feature_preferences (
    org_id              TEXT NOT NULL,
    feature_key         TEXT NOT NULL,
    category            TEXT NOT NULL,
    release_phase       INTEGER NOT NULL,
    is_immutable_core   INTEGER NOT NULL DEFAULT 0 CHECK (is_immutable_core IN (0, 1)),
    platform_enabled    INTEGER NOT NULL DEFAULT 0 CHECK (platform_enabled IN (0, 1)),
    org_configurable    INTEGER NOT NULL DEFAULT 1 CHECK (org_configurable IN (0, 1)),
    effective_enabled   INTEGER NOT NULL DEFAULT 0 CHECK (effective_enabled IN (0, 1)),
    requires_feature    TEXT,
    synced_at           TEXT NOT NULL,
    PRIMARY KEY (org_id, feature_key)
);
