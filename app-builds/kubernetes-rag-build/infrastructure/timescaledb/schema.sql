-- RAG Session Management Schema
-- Using TimescaleDB for time-series chat history

-- 1. Projects table to group sessions
CREATE TABLE IF NOT EXISTS projects (
    project_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID REFERENCES projects(project_id) ON DELETE CASCADE,
    name TEXT,
    metadata JSONB, -- For any extra info
    created_at TIMESTAMPTZ DEFAULT now(),
    last_active_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Messages table (Hypertable)
CREATE TABLE IF NOT EXISTS chat_messages (
    message_id UUID DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES sessions(session_id) ON DELETE CASCADE,
    role TEXT NOT NULL, -- 'user', 'assistant', 'system'
    content TEXT NOT NULL,
    tokens_used INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, created_at)
);

-- convert chat_messages to a hypertable
SELECT create_hypertable('chat_messages', 'created_at', if_not_exists => TRUE);

-- 4. Archiving and Heat Management
-- Retention policy: data stays in chat_messages (Hot) for 30 days
-- Then it can be moved to a 'compressed' or 'cold' state
SELECT add_retention_policy('chat_messages', INTERVAL '90 days', if_not_exists => TRUE);

-- 5. Vector search log
CREATE TABLE IF NOT EXISTS retrieval_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL, -- Refers to user message
    retrieved_chunks JSONB, -- List of paths and chunks
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_messages_session ON chat_messages(session_id, created_at DESC);
