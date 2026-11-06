-- ==============================================================================
-- MailMind Supabase Database Schema
-- Shared tables: emails, chunks (pgvector 768 dims), chats, pdfs
-- ==============================================================================

-- 1. Enable the pgvector extension for embedding search
CREATE EXTENSION IF NOT EXISTS vector;

-- 2. Emails table
-- Caches Gmail messages fetched via Gmail API
CREATE TABLE IF NOT EXISTS public.emails (
    id TEXT PRIMARY KEY,                       -- Gmail message ID
    thread_id TEXT NOT NULL,                   -- Gmail thread ID
    user_email TEXT NOT NULL,                  -- User's email address
    sender TEXT NOT NULL,                      -- From header
    recipient TEXT,                            -- To header
    subject TEXT,                              -- Email subject
    snippet TEXT,                              -- Short preview snippet
    body_plain TEXT,                           -- Clean plain text body
    body_html TEXT,                            -- Raw HTML body (optional)
    internal_date TIMESTAMPTZ NOT NULL,        -- Internal timestamp from Gmail
    is_read BOOLEAN DEFAULT FALSE,             -- Read status
    labels TEXT[] DEFAULT '{}',                -- Gmail label IDs (INBOX, UNREAD, etc.)
    summary TEXT,                              -- Generated on-device AI summary
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_emails_user_date ON public.emails (user_email, internal_date DESC);
CREATE INDEX IF NOT EXISTS idx_emails_thread ON public.emails (thread_id);

-- 3. PDFs table
-- Stores metadata of attached PDFs processed on the device
CREATE TABLE IF NOT EXISTS public.pdfs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_size BIGINT,
    file_path TEXT,
    total_pages INT DEFAULT 1,
    extracted_text TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pdfs_user ON public.pdfs (user_email, created_at DESC);

-- 4. Chunks table (pgvector 768 dimensions for nomic-embed-text)
-- Stores chunked text and vector embeddings from emails and PDFs for RAG
CREATE TABLE IF NOT EXISTS public.chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    source_type TEXT NOT NULL CHECK (source_type IN ('email', 'pdf')),
    source_id TEXT NOT NULL,                   -- references emails.id or pdfs.id
    chunk_index INT NOT NULL,
    content TEXT NOT NULL,                     -- chunk text
    metadata JSONB DEFAULT '{}'::jsonb,        -- extra metadata (subject, sender, page number, etc.)
    embedding VECTOR(768),                     -- 768-dim vector from nomic-embed-text
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chunks_source ON public.chunks (source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_chunks_user ON public.chunks (user_email);

-- HNSW index for fast cosine distance vector similarity search
CREATE INDEX IF NOT EXISTS idx_chunks_embedding 
ON public.chunks 
USING hnsw (embedding vector_cosine_ops);

-- 5. Chats table
-- Stores chat sessions and Q&A history
CREATE TABLE IF NOT EXISTS public.chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_email TEXT NOT NULL,
    title TEXT DEFAULT 'New Conversation',
    messages JSONB DEFAULT '[]'::jsonb,        -- array of {role, content, timestamp, sources}
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chats_user ON public.chats (user_email, updated_at DESC);

-- 6. RPC Function for RAG Vector Search
-- Finds top matching chunks within cosine distance threshold
CREATE OR REPLACE FUNCTION match_chunks(
    query_embedding VECTOR(768),
    match_threshold FLOAT DEFAULT 0.3,
    match_count INT DEFAULT 5,
    filter_user_email TEXT DEFAULT NULL,
    filter_source_type TEXT DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    source_type TEXT,
    source_id TEXT,
    chunk_index INT,
    content TEXT,
    metadata JSONB,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.id,
        c.source_type,
        c.source_id,
        c.chunk_index,
        c.content,
        c.metadata,
        1 - (c.embedding <=> query_embedding) AS similarity
    FROM public.chunks c
    WHERE 
        (filter_user_email IS NULL OR c.user_email = filter_user_email)
        AND (filter_source_type IS NULL OR c.source_type = filter_source_type)
        AND (1 - (c.embedding <=> query_embedding)) > match_threshold
    ORDER BY c.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- 7. Enable Row Level Security (RLS)
ALTER TABLE public.emails ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pdfs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chats ENABLE ROW LEVEL SECURITY;

-- Allow anon & authenticated access with user_email matching or allow service access
-- (Adjust to match your auth mode: either Supabase Auth UID or user_email)
CREATE POLICY "Allow users to manage own emails" ON public.emails
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow users to manage own pdfs" ON public.pdfs
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow users to manage own chunks" ON public.chunks
    FOR ALL USING (true) WITH CHECK (true);

CREATE POLICY "Allow users to manage own chats" ON public.chats
    FOR ALL USING (true) WITH CHECK (true);

