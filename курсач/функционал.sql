select delete_playlist(5, 'qwerty')
--------------------GRANTEE-------------------------
grant connect on database "BD_kursach" to admin;
grant connect on database "BD_kursach" to users;
----------------------------------------------------
grant select on table artists to admin;
grant delete on table artists to admin;
----------------------------------------------------
grant select on table song_artists to admin;
grant delete on table song_artists to admin;
----------------------------------------------------
grant select on table artist_descriptions to admin;
grant delete on table artist_descriptions to admin;
----------------------------------------------------
grant select on table community_members to admin;
grant select on table genre_communities to admin;
----------------------------------------------------
--grant select on table likes to admin;
grant select on table playlist_songs to admin;
grant delete on table playlist_songs to admin;
grant select on table playlists to admin;
grant delete on table playlists to admin;
grant update on table playlists to admin;

grant select on table playlist_songs to users;
grant delete on table playlist_songs to users;
grant select on table playlists to users;
grant delete on table playlists to users;
grant update on table playlists to users;
----------------------------------------------------
grant select on table songs to admin;
----------------------------------------------------
grant select on table users to admin;


--------------ЗАПОЛНЕНИЕ 100 000 строк-------------------
DO $$
DECLARE
    i INT := 1;
    username_prefix VARCHAR := 'user';
BEGIN
    WHILE i <= 100000 LOOP
        INSERT INTO users_import (username, password_hash, role_name)
        VALUES (username_prefix || '_' || i, 'password_' || i, 'users');
        i := i + 1;
    END LOOP;
END $$;

select * from users_import
delete  from users_import

--explain analyze select * from users where username like '%7' order;
--create index user_ind on users (username)
--drop index user_ind

delete from users where username like '%user_%'

------------ПОЛУЧЕНИЕ ИМЕНИ И ПАРОЛЯ------------------
CREATE OR REPLACE FUNCTION GetUserCredentialsById(
    user_id_param INT,
    OUT username VARCHAR(255),
    OUT password_hash VARCHAR(255)
)
RETURNS RECORD
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    SELECT u.username, u.password_hash
    INTO username, password_hash
    FROM users u
    WHERE u.user_id = user_id_param;

    RETURN;
END;
$$;

SELECT * FROM GetUserCredentialsById(3);


------------ВЫВОД ИНФОРМАЦИИ ОБ ИСПОЛНИТЕЛЕ--------

CREATE OR REPLACE FUNCTION get_artist_info(p_artist_name VARCHAR(255))
RETURNS TABLE (
    artist_id INT,
    artist_name VARCHAR(255),
    photo BYTEA,
    birth_date DATE,
    artist_info TEXT,
    popular_album VARCHAR(255),
    listeners_count INT
)
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.artist_id,
        a.artist_name,
        a.photo,
        ad.birth_date,
        ad.artist_info,
        ad.popular_album,
        ad.listeners_count
    FROM
        artists a
        JOIN artist_descriptions ad ON a.artist_id = ad.artist_id
    WHERE
        a.artist_name = p_artist_name;
END;
$$ LANGUAGE plpgsql;
---------------------------------------------------

--------------ВЫВОД ВСЕХ ИСПОЛНИТЕЛЕЙ--------------
CREATE OR REPLACE FUNCTION select_artists()
  RETURNS TABLE (
    artist_id INT,
    artist_name VARCHAR(255),
    photo BYTEA
  )
  SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY SELECT artist_id, artist_name, photo FROM artists;
END;
$$ LANGUAGE plpgsql;
---------------------------------------------------


--------------------ПРОСМОТР СООБЩЕСТВ---------------------------------
CREATE OR REPLACE FUNCTION get_all_communities()
RETURNS TABLE (
    genre_name VARCHAR(255),
    community_name VARCHAR(255),
    community_description VARCHAR(255),
    image_community VARCHAR(255)
) SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY SELECT gc.genre_name, gc.community_name, gc.community_description, gc.image_community FROM genre_communities AS gc;
END;
$$ LANGUAGE plpgsql;



--------------ПЛЕЙЛИСТЫ ПОЛЬЗОВАТЕЛЕЙ--------------------------
CREATE OR REPLACE FUNCTION get_user_playlists(user_id_param INT) 
RETURNS TABLE (
    title VARCHAR(255),
    image_playlist VARCHAR(255)
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT p.title, p.image_playlist
    FROM playlists p
    WHERE p.user_id = user_id_param;
END;
$$ LANGUAGE plpgsql;

---------------------------------------------------


---------------------ДОБАВЛЕНИЕ В ПОНРАВИВШЕЕСЯ-----------------------------
CREATE OR REPLACE PROCEDURE add_song_to_favorites(
    user_id_param INT,
    song_id_param INT
)
SECURITY DEFINER
AS $$
DECLARE 
    v_playlist_id INT;
    v_user_role TEXT;
BEGIN
    -- Получаем роль пользователя
    SELECT u.role_name INTO v_user_role
    FROM users u
    WHERE u.user_id = user_id_param;

    IF v_user_role = 'admin' THEN
        RAISE NOTICE 'У администратора нет плейлиста "Понравившиеся"';
    ELSE
        -- Получаем ID плейлиста "Понравившиеся" для указанного пользователя
        SELECT p.playlist_id INTO v_playlist_id
        FROM playlists p
        WHERE p.user_id = user_id_param AND p.title = 'Понравившиеся'
        LIMIT 1;

        IF v_playlist_id IS NULL THEN
            RAISE NOTICE 'Произошла ошибка при обнаружении плейлиста';
        END IF;

        -- Проверяем, есть ли уже песня в плейлисте "Понравившиеся" для данного пользователя
        IF EXISTS (
            SELECT 1
            FROM playlist_songs ps
            WHERE ps.playlist_id = v_playlist_id AND ps.song_id = song_id_param
        ) THEN
            RAISE NOTICE 'Песня уже добавлена в плейлист "Понравившиеся"';
        ELSE
            -- Добавляем песню в плейлист "Понравившиеся"
            INSERT INTO playlist_songs (playlist_id, song_id)
            VALUES (v_playlist_id, song_id_param);
            RAISE NOTICE 'Песня добавлена';
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

--------------------ВЫВОД ПЕСЕН-------------------------------
CREATE OR REPLACE FUNCTION GetSongsWithArtists(lim INT, off INT)
RETURNS TABLE (song_id INT, title VARCHAR(255), artists TEXT, photo_path VARCHAR(255), audio_path VARCHAR(255), listens_count INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT subquery.song_id, subquery.title, subquery.artists, subquery.photo_path, subquery.audio_path, subquery.listens_count
    FROM (
        SELECT s.song_id, s.title, string_agg(a.artist_name, ' & ') AS artists, s.image::VARCHAR(255) AS photo_path, s.audio AS audio_path, s.listens_count,
               ROW_NUMBER() OVER (ORDER BY s.song_id) AS row_num
        FROM songs s
        JOIN song_artists sa ON s.song_id = sa.song_id
        JOIN artists a ON sa.artist_id = a.artist_id
        GROUP BY s.song_id, s.title, s.image, s.audio, s.listens_count
    ) AS subquery
    WHERE subquery.row_num > (off - 1) * lim
      AND subquery.row_num <= off * lim;
END;
$$;

select * from song_artists;

EXPLAIN ANALYZE
SELECT * FROM songS;
select * from song_artists;


---------------ОТОБРАЖЕНИЕ ПЕСЕН В ПЛЕЙЛИСТЕ ПОЛЬЗОВАТЕЛЯ--------------
CREATE OR REPLACE FUNCTION get_playlist_songs(
    user_id_param INT,
    playlist_title_param TEXT
)
RETURNS TABLE (
    song_id INT,
    title VARCHAR,
    artist_name VARCHAR,
    image VARCHAR,
    audio VARCHAR,
    listen_count INT
)
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT s.song_id, s.title, a.artist_name, s.image, s.audio, s.listens_count
    FROM playlists p
    JOIN playlist_songs ps ON p.playlist_id = ps.playlist_id
    JOIN songs s ON ps.song_id = s.song_id
    JOIN song_artists sa ON s.song_id = sa.song_id
    JOIN artists a ON sa.artist_id = a.artist_id
    WHERE p.user_id = user_id_param AND p.title = playlist_title_param;
END;
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------

-------------------УДАЛЕНИЕ ПЕСНИ ИЗ ПЛЕЙЛИСТА---------------------
CREATE OR REPLACE PROCEDURE RemoveSongFromPlaylist(
    p_user_id INT,
    p_playlist_title VARCHAR,
    p_song_id INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM playlist_songs
    WHERE playlist_id = (
        SELECT playlist_id
        FROM playlists
        WHERE user_id = p_user_id
        AND title = p_playlist_title
    )
    AND song_id = p_song_id;
    
    IF NOT FOUND THEN
        RAISE NOTICE 'Песня не найдена в указанном плейлисте';
    ELSE
        RAISE NOTICE 'Песня успешно удалена из плейлиста';
    END IF;
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Произошла ошибка при удалении песни из плейлиста';
END;
$$;


-----------------СОЗДАНИЕ ПЛЕЙЛИСТА----------------------------
CREATE OR REPLACE PROCEDURE create_playlist(
  p_user_id INT,
  p_title VARCHAR(255),
  p_description VARCHAR(255),
  p_image_playlist VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_title = '' THEN
    RAISE EXCEPTION 'Название плейлиста не может быть пустым.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM playlists
    WHERE user_id = p_user_id
    AND title = p_title
  ) THEN
     RAISE NOTICE 'У пользователя уже существует плейлист с таким именем.';
  ELSE
    BEGIN
      INSERT INTO playlists (user_id, title, descriprion, image_playlist)
      VALUES (p_user_id, p_title, p_description, p_image_playlist);
      RAISE INFO 'Плейлист успешно добавлен.';
    EXCEPTION
      WHEN OTHERS THEN
         RAISE NOTICE 'Ошибка при добавлении плейлиста:';
    END;
  END IF;
END;
$$;


--CALL create_playlist(9, 'БульварДепо', '', 'C:\3course\COURSE_PROJ\online_music\Photos\5.jpg');


-------------------------ПОЛУЧЕНИЕ ИНФОРМАЦИИ О ПЛЕЙЛИСТЕ------------------------
CREATE OR REPLACE FUNCTION get_playlist_info_by_name(p_playlist_name VARCHAR(255))
RETURNS TABLE (description VARCHAR(255), image_playlist VARCHAR(255)) AS $$
BEGIN
    RETURN QUERY SELECT playlists.descriprion, playlists.image_playlist
                 FROM playlists
                 WHERE playlists.title = p_playlist_name;
END;
$$ LANGUAGE plpgsql;

--SELECT * FROM get_playlist_info_by_name('0');

-------------------------УДАЛЕНИЕ ПЛЕЙЛИСТА------------------------
--GRANT EXECUTE ON FUNCTION delete_playlist(INT, VARCHAR) TO admin;
--GRANT EXECUTE ON FUNCTION delete_playlist(INT, VARCHAR) TO users;
CREATE OR REPLACE FUNCTION delete_playlist(
    p_user_id INT,
    p_title VARCHAR(255)
)
RETURNS VOID AS
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN
        RAISE NOTICE 'Пользователь с указанным ID не существует.';
    ELSE
        IF EXISTS (
            SELECT 1
            FROM playlists
            WHERE user_id = p_user_id
            AND title = p_title
        ) THEN
            DELETE FROM playlists
            WHERE user_id = p_user_id
            AND title = p_title;
            
            RAISE INFO 'Плейлист успешно удален.';
        ELSE
            RAISE NOTICE 'У пользователя нет плейлиста с указанным именем.';
        END IF;
    END IF;
--EXCEPTION
  --  WHEN OTHERS THEN
    --    RAISE NOTICE 'Ошибка при удалении плейлиста:';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--DO $$
--BEGIN
  --  PERFORM delete_playlist(9,'Понравившиеся');
--END $$;

-----------------ИЗМЕНЕНИЕ ПЛЕЙЛИСТА------------------------
CREATE OR REPLACE PROCEDURE edit_playlist(
    p_user_id INT,
    p_title VARCHAR(255),
    p_new_title VARCHAR(255),
    p_new_description VARCHAR(255),
    p_new_image_playlist VARCHAR(255)
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN
        RAISE NOTICE 'Пользователь с указанным ID не существует.';
    ELSE
        IF p_new_title = '' THEN
            RAISE NOTICE 'Название плейлиста не может быть пустым.';
        ELSE
            IF EXISTS (
                SELECT 1
                FROM playlists
                WHERE user_id = p_user_id
                AND title = p_title
            ) THEN
                IF p_title = 'Понравившиеся' THEN
                    RAISE NOTICE 'Нельзя изменять плейлист "Понравившиеся".';
                ELSE
                    IF EXISTS (
                        SELECT 1
                        FROM playlists
                        WHERE user_id = p_user_id
                        AND title = p_new_title
                        AND title <> p_title
                    ) THEN
                        RAISE NOTICE 'Плейлист с таким названием уже существует. Выберите другое название.';
                    ELSE
                        UPDATE playlists
                        SET title = p_new_title,
                            descriprion = p_new_description,
                            image_playlist = p_new_image_playlist
                        WHERE user_id = p_user_id
                        AND title = p_title;
                        
                        RAISE INFO 'Плейлист успешно отредактирован.';
                    END IF;
                END IF;
            ELSE
                RAISE NOTICE 'У пользователя нет плейлиста с указанным именем.';
            END IF;
        END IF;
    END IF;
END;
$$;

--call edit_playlist(5, 'qqqqqqqqqq', 'Понравившиеся','qwerty','C:\3course\COURSE_PROJ\online_music\Photos\5.jpg')

-----------------ДОБАВЛЕНИЕ ПЕСНИ В ПЛЕЙЛИСТ------------------------
CREATE OR REPLACE PROCEDURE add_song_to_playlist(
  p_user_id INT,
  p_playlist_title VARCHAR(255),
  p_song_id INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE 
  v_playlist_id INT;
  v_user_exists BOOLEAN;
  v_song_exists BOOLEAN;
BEGIN
  -- Check if the user with the provided user ID exists
  SELECT EXISTS (
    SELECT 1
    FROM users
    WHERE user_id = p_user_id
  ) INTO v_user_exists;

  -- Check if the song with the provided song ID exists in the song_artists table
SELECT EXISTS (
SELECT 1
    FROM song_artists
    WHERE song_id = p_song_id
  ) INTO v_song_exists;

  IF NOT v_user_exists THEN
    RAISE NOTICE 'Пользователь с указанным ID не существует.';
  ELSIF NOT v_song_exists THEN
    RAISE NOTICE 'Песня с указанным ID не существует или не имеет артистов.';
  ELSE
    -- Get the playlist ID for the specified playlist title and user
    SELECT playlist_id INTO v_playlist_id
    FROM playlists
    WHERE user_id = p_user_id
    AND title = p_playlist_title;
    
    -- Check if the playlist is found
    IF v_playlist_id IS NULL THEN
        RAISE NOTICE 'У пользователя не найден плейлист с указанным именем.';
    ELSE
      -- Check if the song already exists in the playlist
      IF EXISTS (
        SELECT 1
        FROM playlist_songs
        WHERE playlist_id = v_playlist_id
        AND song_id = p_song_id
      ) THEN
         RAISE NOTICE 'Песня уже существует в указанном плейлисте.';
      ELSE
        -- Add a record about the song to the playlist_songs table
        INSERT INTO playlist_songs (playlist_id, song_id)
        VALUES (v_playlist_id, p_song_id);
        RAISE INFO 'Песня успешно добавлена в плейлист.';
      END IF;
    END IF;
  END IF;
END;
$$;

--call add_song_to_playlist(100017,'For soul', 50)

-------------------------ВЫВОД ДЛЯ КОМБОБОКС ПЛЕЙЛИСТОВ------------------------
CREATE OR REPLACE FUNCTION get_user_playlists_without_like(user_id INT)
RETURNS TABLE (playlist_title VARCHAR) 
SECURITY DEFINER
AS
$$

BEGIN
    RETURN QUERY
    SELECT title
    FROM playlists
    WHERE playlists.user_id = get_user_playlists_without_like.user_id
    AND title <> 'Понравившиеся';
END;
$$
LANGUAGE plpgsql;

-----------------------------ПОИСК ПО НАЗВАНИЮ--------------------------
--GRANT EXECUTE ON FUNCTION SearchSongsByTitle(VARCHAR, INT, INT) TO admin;
--GRANT EXECUTE ON FUNCTION SearchSongsByTitle(VARCHAR, INT, INT) TO users;
CREATE OR REPLACE FUNCTION SearchSongsByTitle(search_term VARCHAR, limitPage INT, offsetPage INT)
RETURNS TABLE (song_id INT, title VARCHAR(255), artists TEXT, photo_path VARCHAR(255), audio_path VARCHAR(255), listens_count INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH ranked_songs AS (
        SELECT 
            s.song_id, 
            s.title, 
            string_agg(a.artist_name, ' & ') AS artists,
            s.image::VARCHAR(255) AS photo_path,
            s.audio AS audio_path,
            s.listens_count,
            ROW_NUMBER() OVER (ORDER BY s.listens_count DESC) AS row_num
        FROM songs s
        JOIN song_artists sa ON s.song_id = sa.song_id
        JOIN artists a ON sa.artist_id = a.artist_id
        WHERE s.title ILIKE '%' || search_term || '%'
        GROUP BY s.song_id, s.title, s.image, s.audio, s.listens_count
    )
    SELECT 
        rs.song_id,
        rs.title, 
        rs.artists,
        rs.photo_path, 
        rs.audio_path,
        rs.listens_count
    FROM ranked_songs rs
    WHERE rs.row_num > (offsetPage - 1) * limitPage
      AND rs.row_num <= offsetPage * limitPage;
END;
$$;


-----------------------------ПОИСК ПО АРТИСТУ--------------------------
--GRANT EXECUTE ON FUNCTION SearchSongsByArtist(VARCHAR, INT, INT) TO admin;
--GRANT EXECUTE ON FUNCTION SearchSongsByArtist(VARCHAR, INT, INT) TO users;
CREATE OR REPLACE FUNCTION SearchSongsByArtist(search_term VARCHAR, limitPage INT, offsetPage INT)
RETURNS TABLE (song_id INT, title VARCHAR(255), artists TEXT, photo_path VARCHAR(255), audio_path VARCHAR(255), listens_count INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH ranked_songs AS (
        SELECT 
            s.song_id, 
            s.title, 
            string_agg(a.artist_name, ' & ') AS artists,
            s.image::VARCHAR(255) AS photo_path,
            s.audio AS audio_path,
            s.listens_count,
            ROW_NUMBER() OVER (ORDER BY s.listens_count DESC) AS row_num
        FROM songs s
        JOIN song_artists sa ON s.song_id = sa.song_id
        JOIN artists a ON sa.artist_id = a.artist_id
        WHERE a.artist_name ILIKE '%' || search_term || '%'
        GROUP BY s.song_id, s.title, s.image, s.audio, s.listens_count
    )
    SELECT 
        rs.song_id,
        rs.title, 
        rs.artists,
        rs.photo_path, 
        rs.audio_path,
        rs.listens_count
    FROM ranked_songs rs
    WHERE rs.row_num > (offsetPage - 1) * limitPage
      AND rs.row_num <= offsetPage * limitPage;
END;
$$;


----------------СПИСОК НАЗВАНИЙ СООБЩЕСТВ------------------
CREATE OR REPLACE FUNCTION get_all_community_names()
RETURNS TABLE (community_name_param VARCHAR(255)) AS $$
BEGIN
    RETURN QUERY SELECT community_name FROM genre_communities;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--SELECT * FROM get_all_community_names();


----------------ВХОД В СООБЩЕСТВО------------------
CREATE OR REPLACE PROCEDURE join_community(
    user_id_param INT,
    community_name_param VARCHAR
)
SECURITY DEFINER
AS $$
DECLARE
    community_id_param INT;
BEGIN
    -- Проверка существования сообщества
    SELECT community_id INTO community_id_param
    FROM genre_communities
    WHERE community_name = community_name_param;

    IF community_id_param IS NULL THEN
        RAISE NOTICE 'Сообщество с указанным названием не существует';
        RETURN;
    END IF;

    -- Проверка существования пользователя
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = user_id_param
    ) THEN
        RAISE NOTICE 'Пользователь с указанным ID не существует';
        RETURN;
    END IF;

    -- Проверка, не является ли пользователь уже участником сообщества
    IF EXISTS (
        SELECT 1
        FROM community_members
        WHERE community_id = community_id_param
        AND user_id = user_id_param
    ) THEN
        RAISE NOTICE 'Вы уже вступили в данное сообщество!';
        RETURN;
    END IF;

    -- Добавление пользователя в сообщество
    INSERT INTO community_members (community_id, user_id)
    VALUES (community_id_param, user_id_param);

    RAISE NOTICE 'Теперь вы являетесь участником сообщества!';
END;
$$ LANGUAGE plpgsql;


-----------------------ВЫВОД ПОЛЬЗОВАТЕЛЕЙ В СООБЩЕТСВЕ---------------
CREATE OR REPLACE FUNCTION get_community_users(community_name_param VARCHAR(255))
RETURNS TABLE (username VARCHAR(255), image_community VARCHAR(255))
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT u.username, gc.image_community
    FROM users u
    INNER JOIN community_members cm ON u.user_id = cm.user_id
    INNER JOIN genre_communities gc ON cm.community_id = gc.community_id
    WHERE gc.community_name = community_name_param;
END;
$$
LANGUAGE plpgsql;

select * from songs;


--------------------------ВЫВОД ПЕСЕН ФИЛЬТРАЦИЯ-----------------------------
CREATE OR REPLACE FUNCTION get_songs_by_listens_count_range(
    min_count INT,
    max_count INT,
    offsetPage INT,
    limitPage INT
)	
RETURNS TABLE (serch
    song_id INT,
    title VARCHAR(255),
    audio VARCHAR(255),
    image VARCHAR(255),
    listens_count INT,
    artist_name VARCHAR(255)
)
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH ranked_songs AS (
        SELECT s.song_id, s.title, s.audio, s.image, s.listens_count, a.artist_name,
               ROW_NUMBER() OVER (ORDER BY s.listens_count DESC) AS row_num
        FROM songs s
        INNER JOIN song_artists sa ON s.song_id = sa.song_id
        INNER JOIN artists a ON sa.artist_id = a.artist_id
        WHERE s.listens_count >= min_count AND s.listens_count <= max_count
    )
    SELECT ranked_songs.song_id, ranked_songs.title, ranked_songs.audio, ranked_songs.image, ranked_songs.listens_count, ranked_songs.artist_name
    FROM ranked_songs
    WHERE ranked_songs.row_num > (offsetPage - 1) * limitPage
    AND ranked_songs.row_num <= offsetPage * limitPage;
END;
$$ LANGUAGE plpgsql;


----------------------ВЫХОД ИЗ СООБЩЕСТВА-------------------------------------
CREATE OR REPLACE PROCEDURE remove_user_from_community(
    p_communityName VARCHAR(255),
    p_userID INTEGER
)
SECURITY DEFINER
AS $$
DECLARE 
    community_id_p INT;
BEGIN
    SELECT community_id INTO community_id_p
    FROM genre_communities
    WHERE community_name = p_communityName;

    IF community_id_p IS NULL THEN
        RAISE NOTICE 'Сообщество не существует: %', p_communityName;
    END IF;

    DELETE FROM community_members
    WHERE community_id = community_id_p
    AND user_id = p_userID;

    IF NOT FOUND THEN
        RAISE NOTICE 'Пользователь не состоит в данном сообществе: community_name=%, user_id=%', p_communityName, p_userID;
    ELSE
        RAISE NOTICE 'Вы успешно вышли из сообщества сообщества:%' , p_communityName;
    END IF;
END;
$$
LANGUAGE plpgsql;


--------------------------СПИСОК СООБЩЕСТВ У ПОЛЬЗОВАТЕЛЯ-------------------
CREATE OR REPLACE FUNCTION GetCommunitiesByUser(userID INT)
RETURNS TABLE (community_name VARCHAR(255))
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT gc.community_name
    FROM genre_communities gc
    INNER JOIN community_members cm ON gc.community_id = cm.community_id
    WHERE cm.user_id = userID;
END;
$$
LANGUAGE plpgsql;


--------------------------ПРОВЕРКА ДОБАВЛЕНИЯ ПЛЕЙЛИСТА--------------------------
CREATE OR REPLACE FUNCTION check_playlist_insert()
    RETURNS TRIGGER AS $$
DECLARE
    user_exists INT;
BEGIN
    -- Проверка существования пользователя
    SELECT COUNT(*) INTO user_exists FROM users WHERE user_id = NEW.user_id;
    IF user_exists = 0 THEN
        RAISE EXCEPTION 'Ошибка при добавлении плейлиста: пользователь не существует';
    END IF;

    RETURN NEW;
END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER playlist_insert_trigger
    BEFORE INSERT ON playlists
    FOR EACH ROW
    EXECUTE FUNCTION check_playlist_insert();

INSERT INTO playlists (user_id, title, descriprion, image_playlist) VALUES (999, 'Плейлист без пользователя', 'Описание плейлиста', 'https://example.com/playlist.jpg');


--------------------------ИНФОРМАЦИЯ ОБ АРТИСТЕ--------------------------
CREATE OR REPLACE FUNCTION get_artist_description(p_artist_name VARCHAR)
RETURNS TABLE (
  artist_name VARCHAR,
  photo BYTEA,
  birth_date DATE,
  artist_info TEXT,
  popular_album VARCHAR,
  listeners_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.artist_name,
    a.photo,
    ad.birth_date,
    ad.artist_info,
    ad.popular_album,
    ad.listeners_count
  FROM artists a
  JOIN artist_descriptions ad ON a.artist_id = ad.artist_id
  WHERE a.artist_name = p_artist_name;
END;
$$;

select * from get_artist_description('Гиль Виталия')



--------------------------ДОБАВЛЕНИЕ ПРОСЛУШИВАНИЙ-------------------------
CREATE OR REPLACE PROCEDURE update_listen_count(song_id_param INT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE songs
    SET listens_count = listens_count + 1
    WHERE song_id = song_id_param;
END;
$$;



