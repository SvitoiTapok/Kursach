CREATE TABLE "APP_USER"
(
    ID                BIGINT PRIMARY KEY,
    LOGIN             VARCHAR(255) NOT NULL,
    PASSWORD          VARCHAR(255) NOT NULL,
    REGISTRATION_DATE TIMESTAMP,
    UNIQUE (LOGIN)
);
CREATE TABLE "ROOM"
(
    ID            BIGINT PRIMARY KEY,
    CREATION_DATE TIMESTAMP    NOT NULL,
    NAME          VARCHAR(255) NOT NULL,
    DESCRIPTION   VARCHAR(3000),
    LINK          VARCHAR(255),
    CREATOR       BIGINT,
    FOREIGN KEY (CREATOR) REFERENCES "APP_USER" (ID) ON DELETE CASCADE
);
CREATE TABLE "VIDEO"
(
    id           BIGINT PRIMARY KEY,
    name         VARCHAR(255),
    duration     BIGINT,
    quality      VARCHAR(10),
    hlp_playlist INTEGER,
    creator      BIGINT,
    upload_time  TIMESTAMP,
    s3_key_temp  VARCHAR(500),       -- Путь к исходнику в S3 (temp)
    s3_key_hls   VARCHAR(500),       -- Путь к HLS в S3 (videos/)
    expires_at   TIMESTAMP
);


-- Гипертаблица для всех обновлений
CREATE TABLE watch_updates (
                               update_time TIMESTAMPTZ DEFAULT NOW() NOT NULL,
                               user_id BIGINT NOT NULL,
                               video_id BIGINT NOT NULL,
                               position_seconds INTEGER NOT NULL
);

SELECT create_hypertable('watch_updates', 'update_time',
                         chunk_time_interval => INTERVAL '1 hour');

CREATE MATERIALIZED VIEW watch_current_state
            WITH (timescaledb.continuous) AS
SELECT
    time_bucket('30 seconds', update_time) as bucket,  -- время
    user_id,
    video_id,
    LAST(position_seconds, update_time) as last_position,
    MAX(update_time) as last_update_time
FROM watch_updates
WHERE update_time > NOW() - INTERVAL '10 minutes'
GROUP BY
    time_bucket('30 seconds', update_time),  -- ДОБАВЬТЕ ЭТО!
    user_id,
    video_id;

-- Автообновление каждую минуту
SELECT add_continuous_aggregate_policy('watch_current_state',
                                       start_offset => INTERVAL '2 minutes',      -- окно 2 минуты (достаточно для видео)
                                       end_offset => INTERVAL '2 seconds',        -- задержка ВСЕГО 2 СЕКУНДЫ!
                                       schedule_interval => INTERVAL '3 seconds');


