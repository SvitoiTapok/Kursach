CREATE TABLE APP_USER
(
    ID                BIGINT PRIMARY KEY,
    LOGIN             VARCHAR(255) NOT NULL,
    PASSWORD          VARCHAR(255) NOT NULL,
    REGISTRATION_DATE TIMESTAMP,
    UNIQUE (LOGIN)
);
CREATE TABLE ROOM
(
    ID            BIGINT PRIMARY KEY,
    CREATION_DATE TIMESTAMP    NOT NULL,
    NAME          VARCHAR(255) NOT NULL,
    DESCRIPTION   VARCHAR(3000),
    LINK          VARCHAR(255),
    CREATOR       BIGINT,
    FOREIGN KEY (CREATOR) REFERENCES APP_USER (ID) ON DELETE CASCADE
);

CREATE TABLE VIDEO
(
    id           BIGINT PRIMARY KEY,
    name         VARCHAR(255),
    duration     BIGINT,
    quality      VARCHAR(10),
    hlp_playlist INTEGER,
    creator      BIGINT,
    upload_time  TIMESTAMP DEFAULT NOW(),
    s3_key_temp  VARCHAR(500), -- Путь к исходнику в S3 (temp)
    s3_key_hls   VARCHAR(500), -- Путь к HLS в S3 (videos/)
    expires_at   TIMESTAMP DEFAULT NOW()+INTERVAL '24 hours',
    FOREIGN KEY (CREATOR) REFERENCES APP_USER (ID) ON DELETE CASCADE
);

CREATE TABLE PARTICIPANT
(
    ID             BIGINT PRIMARY KEY,
    NICKNAME       VARCHAR(255),
    MESSAGE_RIGHTS BOOLEAN,
    PLAYER_RIGHTS  BOOLEAN,
    ROOM           BIGINT,
    FOREIGN KEY (ROOM) REFERENCES ROOM (ID) ON DELETE CASCADE
);


CREATE TABLE WATCH_UPDATES
(
    update_time      TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    user_id          BIGINT                    NOT NULL,
    position_seconds INTEGER                   NOT NULL
--     FOREIGN KEY (user_id) REFERENCES PARTICIPANT (ID) ON DELETE CASCADE
);

SELECT create_hypertable('WATCH_UPDATES', 'update_time',
                         chunk_time_interval => INTERVAL '1 hour');



CREATE
MATERIALIZED VIEW user_positions
WITH (timescaledb.continuous) AS
SELECT time_bucket('3 seconds', update_time) as time_bucket, -- маленький интервал для актуальности
       user_id, LAST (position_seconds, update_time) as last_position, MAX (update_time) as last_update_time
FROM WATCH_UPDATES
WHERE update_time > NOW() - INTERVAL '10 minutes' -- только свежие данные
GROUP BY
    time_bucket('3 seconds', update_time),
    user_id;

-- Автообновление каждую минуту
SELECT add_continuous_aggregate_policy('user_positions',
                                       start_offset => INTERVAL '10 minutes', -- окно 2 минуты (достаточно для видео)
                                       end_offset => INTERVAL '2 seconds',
                                       schedule_interval => INTERVAL '3 seconds');

--для сравнения
CREATE TABLE WATCH_UPDATES_NORMAL (
                                      update_time TIMESTAMPTZ DEFAULT NOW() NOT NULL,
                                      user_id BIGINT NOT NULL,
                                      position_seconds INTEGER NOT NULL
--                                       created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_normal_update_time ON watch_updates (update_time DESC);
CREATE INDEX idx_normal_user ON watch_updates (user_id DESC);

CREATE TABLE WATCH_UPDATES_NORMAL_NO_INDEX (
                                      update_time TIMESTAMPTZ DEFAULT NOW() NOT NULL,
                                      user_id BIGINT NOT NULL,
                                      position_seconds INTEGER NOT NULL,
--                                       created_at TIMESTAMPTZ DEFAULT NOW()
);

SELECT DISTINCT ON (user_id)
    user_id,
    position_seconds,
    update_time
FROM WATCH_UPDATES_NORMAL

ORDER BY user_id, update_time DESC;

SELECT
    user_id,
    last_position,
    max(last_update_time)
FROM user_positions
group by user_id, last_position
ORDER BY user_id   -- самый свежий бакет


