-- Mizan Flutter Client — Migration 007: Offline Workspace Experience Modes & Custom Layouts
CREATE TABLE IF NOT EXISTS local_workspace_preferences (
    user_id                 TEXT NOT NULL,
    org_id                  TEXT NOT NULL,
    experience_mode         TEXT NOT NULL DEFAULT 'STANDARD' CHECK (experience_mode IN (
                                'EASY', 'STANDARD', 'PROFESSIONAL', 'EXECUTIVE', 'EXPRESS_FIELD'
                            )),
    terminology_style       TEXT NOT NULL DEFAULT 'BALANCED' CHECK (terminology_style IN (
                                'SIMPLE_TRADE', 'BALANCED', 'STRICT_ACCOUNTING'
                            )),
    ui_density              TEXT NOT NULL DEFAULT 'COMFORTABLE' CHECK (ui_density IN (
                                'SPACIOUS', 'COMFORTABLE', 'COMPACT'
                            )),
    hide_empty_print_rows   INTEGER NOT NULL DEFAULT 1 CHECK (hide_empty_print_rows IN (0, 1)),
    custom_widgets_json     TEXT NOT NULL DEFAULT '{}',
    custom_columns_json     TEXT NOT NULL DEFAULT '{}',
    updated_at              TEXT NOT NULL,
    PRIMARY KEY (user_id, org_id)
);

CREATE TABLE IF NOT EXISTS local_org_role_mode_policies (
    org_id                  TEXT NOT NULL,
    role                    TEXT NOT NULL,
    default_mode            TEXT NOT NULL,
    allow_user_override     INTEGER NOT NULL DEFAULT 1 CHECK (allow_user_override IN (0, 1)),
    allowed_modes_json      TEXT NOT NULL DEFAULT '["EASY","STANDARD"]',
    synced_at               TEXT NOT NULL,
    PRIMARY KEY (org_id, role)
);
