-- Create a non-overloaded chat RPC to avoid GRST203 ambiguity.
DO $$
DECLARE fn RECORD;
BEGIN FOR fn IN
SELECT p.oid::regprocedure AS signature
FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'send_chat_message_v2' LOOP EXECUTE format('DROP FUNCTION IF EXISTS %s;', fn.signature);
END LOOP;
END;
$$;
CREATE OR REPLACE FUNCTION public.send_chat_message_v2(
    p_chat_id TEXT,
    p_sender_id UUID,
    p_content TEXT,
    p_is_sensitive BOOLEAN,
    p_is_offline_relay BOOLEAN,
    p_is_spam BOOLEAN,
    p_plaintext_preview TEXT,
    p_message_type TEXT DEFAULT 'text',
    p_metadata JSONB DEFAULT '{}'::JSONB,
    p_expires_at TIMESTAMPTZ DEFAULT NULL
  ) RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE has_content BOOLEAN;
has_content_encrypted BOOLEAN;
has_message_type BOOLEAN;
has_metadata BOOLEAN;
has_expires_at BOOLEAN;
content_column TEXT;
insert_columns TEXT;
insert_values TEXT;
BEGIN
SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'messages'
      AND column_name = 'content'
  ) INTO has_content;
SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'messages'
      AND column_name = 'content_encrypted'
  ) INTO has_content_encrypted;
IF has_content THEN content_column := 'content';
ELSIF has_content_encrypted THEN content_column := 'content_encrypted';
ELSE RAISE EXCEPTION 'messages table must contain either content or content_encrypted column';
END IF;
SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'messages'
      AND column_name = 'message_type'
  ) INTO has_message_type;
SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'messages'
      AND column_name = 'metadata'
  ) INTO has_metadata;
SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'messages'
      AND column_name = 'expires_at'
  ) INTO has_expires_at;
insert_columns := format(
  'chat_id, sender_id, %I, is_sensitive, is_offline_relay, is_spam',
  content_column
);
insert_values := '$1, $2, $3, $4, $5, $6';
IF has_message_type THEN insert_columns := insert_columns || ', message_type';
insert_values := insert_values || ', COALESCE(NULLIF($7, ''''), ''text'')';
END IF;
IF has_metadata THEN insert_columns := insert_columns || ', metadata';
insert_values := insert_values || ', COALESCE($8, ''{}''::JSONB)';
END IF;
IF has_expires_at THEN insert_columns := insert_columns || ', expires_at';
insert_values := insert_values || ', $9';
END IF;
EXECUTE format(
  'INSERT INTO public.messages (%s) VALUES (%s)',
  insert_columns,
  insert_values
) USING p_chat_id,
p_sender_id,
p_content,
p_is_sensitive,
p_is_offline_relay,
p_is_spam,
p_message_type,
p_metadata,
p_expires_at;
UPDATE public.chats
SET last_message = p_plaintext_preview,
  last_sender = p_sender_id,
  last_at = NOW(),
  is_sensitive = p_is_sensitive,
  is_spam = p_is_spam
WHERE id = p_chat_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.send_chat_message_v2(
    TEXT,
    UUID,
    TEXT,
    BOOLEAN,
    BOOLEAN,
    BOOLEAN,
    TEXT,
    TEXT,
    JSONB,
    TIMESTAMPTZ
  ) TO authenticated,
  service_role,
  anon;
NOTIFY pgrst,
'reload schema';



