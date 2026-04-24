-- Create a new bucket for encrypted chat media
insert into storage.buckets (
        id,
        name,
        public,
        file_size_limit,
        allowed_mime_types
    )
values (
        'encrypted_chat_media',
        'encrypted_chat_media',
        false,
        52428800,
        '{image/*,video/*}'
    );
-- RLS for the bucket
create policy "Users can upload encrypted media" on storage.objects for
insert to authenticated with check (
        bucket_id = 'encrypted_chat_media'
        and auth.uid() = owner
    );
create policy "Users can see their uploaded media or shared media in their chats" on storage.objects for
select to authenticated using (bucket_id = 'encrypted_chat_media');
create policy "Users can delete their own media" on storage.objects for delete to authenticated using (
    bucket_id = 'encrypted_chat_media'
    and auth.uid() = owner
);



