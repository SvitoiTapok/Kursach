WITH user_data AS (
    SELECT
        gs as id,
        'user' || gs || '@stream.com' as login,
        '$2a$10$' || substr(md5(random()::text), 1, 50) as password,
        NOW() - (random() * INTERVAL '365 days') as reg_date
    FROM generate_series(1, 50000) gs
)
INSERT INTO APP_USER (ID, LOGIN, PASSWORD, REGISTRATION_DATE)
SELECT * FROM user_data;

-- 3. Генерация комнат (10,000) ~25 MB
WITH room_data AS (
    SELECT
        gs as id,
        NOW() - (random() * INTERVAL '180 days') as creation_date,
        'Комната ' || gs || ' ' ||
        (ARRAY['Кино', 'Сериалы', 'Музыка', 'Игры', 'Спорт', 'Наука'])[1 + floor(random() * 6)] as name,
    'Описание комнаты ' || gs || '. ' ||
    repeat('Здесь можно смотреть видео вместе с друзьями. ', 30) as description,
    'https://streamapp.com/room/' || (100000 + gs) as link,
    1 + floor(random() * 50000)::bigint as creator
FROM generate_series(1, 10000) gs
    )
INSERT INTO ROOM (ID, CREATION_DATE, NAME, DESCRIPTION, LINK, CREATOR)
SELECT * FROM room_data;

-- 4. Генерация видео (100,000) ~150 MB
WITH video_data AS (
    SELECT
        gs as id,
        (ARRAY['Научная фантастика', 'Документальный', 'Комедия', 'Драма', 'Боевик', 'Аниме'])[1 + floor(random() * 6)] ||
    ' видео ' || gs as name,
    300 + floor(random() * 10800)::bigint as duration, -- 5 мин - 3 часа
   (ARRAY['360p', '480p', '720p', '1080p', '4K'])[1 + floor(random() * 5)] as quality,
    floor(random() * 5) as hlp_playlist,
    1 + floor(random() * 50000)::bigint as creator,
    NOW() - (random() * INTERVAL '90 days') as upload_time,
    'temp/raw_videos/vid_' || gs || '_' || substr(md5(random()::text), 1, 16) || '.mp4' as s3_key_temp,
    'videos/encoded/hls/vid_' || gs || '/playlist.m3u8' as s3_key_hls,
    CASE
    WHEN random() < 0.3 THEN NOW() - INTERVAL '1 day'
    WHEN random() < 0.7 THEN NOW() + INTERVAL '12 hours'
    ELSE NOW() + INTERVAL '3 days'
END as expires_at
    FROM generate_series(1, 100000) gs
)
INSERT INTO VIDEO (id, name, duration, quality, hlp_playlist, creator, upload_time, s3_key_temp, s3_key_hls, expires_at)
SELECT * FROM video_data;

-- 5. Генерация участников (400,000) ~45 MB
WITH participant_data AS (
    SELECT
        gs as id,
        CASE
            WHEN random() < 0.3 THEN 'Гость_' || floor(random() * 10000)::text
            WHEN random() < 0.6 THEN 'Зритель_' || substr(md5(random()::text), 1, 6)
            ELSE 'Аноним_' || gs
            END as nickname,
        random() > 0.3 as message_rights,  -- 70% имеют право писать
        random() > 0.2 as player_rights,   -- 80% имеют право управлять плеером
        1 + floor(random() * 10000)::bigint as room
    FROM generate_series(1, 400000) gs
)
INSERT INTO PARTICIPANT (ID, NICKNAME, MESSAGE_RIGHTS, PLAYER_RIGHTS, ROOM)
SELECT * FROM participant_data;
INSERT INTO WATCH_UPDATES (update_time, user_id, position_seconds)
SELECT
    NOW() - (random() * 2592000) * INTERVAL '1 second',
    (random() * 4999 + 1)::INT,
    (random() * 7200)::INT
FROM generate_series(1, 1000000);