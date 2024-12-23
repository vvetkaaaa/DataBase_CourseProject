------------ДОБАВЛЕНИЕ ИСПОЛНИТЕЛЯ-------------------
--grant execute on procedure insert_artist to admin;
CREATE OR REPLACE PROCEDURE insert_artist(
    p_artist_name VARCHAR(255),
    p_photo BYTEA,
    p_birth_date DATE,
    p_artist_info TEXT,
    p_popular_album VARCHAR(255),
    p_listeners_count INT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_artist_id INT;
BEGIN
    -- Проверка наличия пустых полей
    IF p_artist_name = '' THEN
        RAISE EXCEPTION 'Имя артиста не может быть пустым.';
    END IF;

    IF p_photo IS NULL THEN
        RAISE EXCEPTION 'Фото артиста не может быть пустым.';
    END IF;

    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'Дата рождения артиста не может быть пустой.';
    END IF;

    IF p_artist_info = '' THEN
        RAISE EXCEPTION 'Информация об артисте не может быть пустой.';
    END IF;

    IF p_popular_album = '' THEN
        RAISE EXCEPTION 'Название популярного альбома не может быть пустым.';
    END IF;

    IF p_listeners_count IS NULL THEN
        RAISE EXCEPTION 'Количество слушателей не может быть пустым.';
    END IF;

    -- Проверка наличия артиста с таким же именем
    IF EXISTS (SELECT 1 FROM artists WHERE artist_name = p_artist_name) THEN
         RAISE NOTICE 'Артист с именем % уже существует', p_artist_name;
    ELSE
        -- Вставка данных в таблицу artists
        INSERT INTO artists (artist_name, photo)
        VALUES (p_artist_name, p_photo)
        RETURNING artist_id INTO v_artist_id;
        
        -- Вставка данных в таблицу artist_descriptions
        INSERT INTO artist_descriptions (artist_id, birth_date, artist_info, popular_album, listeners_count)
        VALUES (v_artist_id, p_birth_date, p_artist_info, p_popular_album, p_listeners_count);
        
        RAISE NOTICE 'Исполнитель успешно добавлен!';
    END IF;
END;
$$;

CALL insert_artist(
    'John Doe', 
    'C:\3course\COURSE_PROJ\online_music\Photos\1.jpg', -- Вместо NULL можно передать данные в формате BYTEA, если есть изображение
    '1980-01-01', 
    'John Doe is a popular artist known for his unique style.', 
    'Greatest Hits', 
    500000
);



------------УДАЛЕНИЕ ИСПОЛНИТЕЛЯ-------------------
--grant execute on procedure delete_artist_by_name to admin;
CREATE OR REPLACE PROCEDURE delete_artist_by_name(
    p_artist_name VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Проверка наличия артиста с указанным именем
    IF NOT EXISTS (SELECT 1 FROM artists WHERE artist_name = p_artist_name) THEN
         RAISE NOTICE 'Артист с именем % не существует', p_artist_name;
    END IF;

    -- Удаление данных из таблицы artist_descriptions по artist_id
    DELETE FROM artist_descriptions
    WHERE artist_id IN (
        SELECT artist_id FROM artists
        WHERE artist_name = p_artist_name
    );

    -- Удаление данных из таблицы artists по artist_name
    DELETE FROM artists
    WHERE artist_name = p_artist_name;
    RAISE NOTICE 'Исполнитель с именем:% , успешно удалён!',p_artist_name ;
END;
$$;

--CALL delete_artist_by_name('qwerty1');
--------------------------------------------------

-----------ДОБАВЛЕНИЕ ПЕСЕН И СВЯЗИ-------------
--grant execute on procedure add_song_and_link_artists to admin;
CREATE OR REPLACE PROCEDURE add_song_and_link_artists(
    title_param VARCHAR,
    audio_param VARCHAR,
    image_param VARCHAR,
    artist_names_param VARCHAR[]
)
SECURITY DEFINER
AS $$
DECLARE
    artist_id_param INTEGER[];
    song_exists BOOLEAN;
    song_id_param INTEGER;
    artist_not_found BOOLEAN := FALSE;
BEGIN
    -- Проверка на пустую строку для title_param, audio_param и image_param
    IF title_param = '' OR audio_param = '' OR image_param = '' THEN
        RAISE NOTICE 'Поля названия, аудио и фото не могут быть пустыми';
        RETURN;
    END IF;

    BEGIN
        -- Проверка существования исполнителей
        SELECT array_agg(artist_id) INTO artist_id_param
        FROM artists
        WHERE artist_name = ANY (artist_names_param);

        IF artist_id_param IS NULL THEN
            RAISE NOTICE 'Один или несколько исполнителей не существуют';
            artist_not_found := TRUE;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE NOTICE 'Один или несколько исполнителей не существуют';
            artist_not_found := TRUE;
    END;

    IF NOT artist_not_found THEN
        -- Проверка наличия песни у указанных исполнителей
        SELECT EXISTS (
            SELECT 1
            FROM songs s
            INNER JOIN song_artists sa ON s.song_id = sa.song_id
            WHERE s.title = title_param AND sa.artist_id = ANY (artist_id_param)
        ) INTO song_exists;

        IF song_exists THEN
            RAISE NOTICE 'Песня уже существует у указанных исполнителей';
        ELSE
            BEGIN
                -- Вставка записи в таблицу songs
                INSERT INTO songs (title, audio, image)
                VALUES (title_param, audio_param, image_param)
                RETURNING song_id INTO song_id_param;

                -- Вставка записей в таблицу song_artists
                INSERT INTO song_artists (song_id, artist_id)
                SELECT song_id_param, unnest(artist_id_param) AS artist_id;
                
                RAISE NOTICE 'Песня успешно добавлена!';
            EXCEPTION
                WHEN unique_violation THEN
                    RAISE NOTICE 'Такая песня уже существует';
            END;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;



------------------------------ИЗМЕНЕНИЕ ПЕСНИ-------------------------
CREATE OR REPLACE PROCEDURE public.updatesongandartistsbyid(
    IN songid INTEGER,
    IN newaudio CHARACTER VARYING,
    IN newimage CHARACTER VARYING,
    IN artistnames TEXT[]
)
LANGUAGE 'plpgsql'
SECURITY DEFINER
AS $$
DECLARE
    artistName TEXT;
    artistId INT;
BEGIN
    -- Проверка на пустую строку для newAudio, newImage
    IF newAudio = '' OR newImage = '' THEN
        RAISE NOTICE 'Поля аудио и фото не могут быть пустыми';
        RETURN;
    END IF;

    -- Обновляем информацию о песне
    UPDATE songs
    SET audio = newAudio, image = newImage
    WHERE song_id = songId;
    
    -- Удаляем текущих исполнителей песни
    DELETE FROM song_artists WHERE song_id = songId;

    -- Добавляем новых исполнителей песни
    FOREACH artistName IN ARRAY artistNames
    LOOP
        -- Проверяем, существует ли исполнитель в таблице "Исполнители"
        EXECUTE format('SELECT artist_id FROM artists WHERE artist_name = %L', artistName) INTO artistId;

        -- Проверка на пустую строку для имени исполнителя
        IF artistName = '' THEN
            RAISE NOTICE 'Имя исполнителя не может быть пустым.';
			return;
        ELSIF artistId IS NULL THEN
            RAISE NOTICE 'Исполнителя с именем %s не существует.', artistName;
			return;
        ELSE
            -- Добавляем связь песни и исполнителя
            BEGIN
                INSERT INTO song_artists (song_id, artist_id) VALUES (songId, artistId);
                EXCEPTION WHEN unique_violation THEN
                -- Выводим сообщение, если связь уже существует
                RAISE NOTICE 'Связь между песней и исполнителем уже существует.';
				return;
            END;
        END IF;
    END LOOP;
    
    -- Выводим сообщение об успешном обновлении песни
    RAISE NOTICE 'Песня успешно обновлена.';
END;
$$;

ALTER PROCEDURE public.updatesongandartistsbyid(INTEGER, CHARACTER VARYING, CHARACTER VARYING, TEXT[])
OWNER TO postgres;

GRANT EXECUTE ON PROCEDURE public.updatesongandartistsbyid(INTEGER, CHARACTER VARYING, CHARACTER VARYING, TEXT[]) TO PUBLIC;
GRANT EXECUTE ON PROCEDURE public.updatesongandartistsbyid(INTEGER, CHARACTER VARYING, CHARACTER VARYING, TEXT[]) TO admin;

------------------УДАЛЕНИЕ ПЕСНИ У ИСПОЛНИТЕЛЯ---------
--grant execute on procedure delete_song_and_unlink_artists to admin;
CREATE OR REPLACE PROCEDURE delete_song_and_unlink_artists(
    title_param VARCHAR,
    artist_names_param VARCHAR[]
)
SECURITY DEFINER
AS $$
DECLARE
    artist_id_param INTEGER[];
    song_id_param INTEGER;
    artist_exists BOOLEAN;
    song_exists BOOLEAN;
BEGIN
    -- Проверка наличия песни с указанным названием
    SELECT song_id INTO song_id_param
    FROM songs
    WHERE title = title_param;

    IF song_id_param IS NULL THEN
         RAISE NOTICE 'Песня с указанным названием не существует';
         RETURN;
    END IF;

    BEGIN
        -- Проверка существования всех исполнителей
        SELECT array_agg(artist_id) INTO artist_id_param
        FROM artists
        WHERE artist_name = ANY (artist_names_param::varchar[]);

        IF artist_id_param IS NULL OR array_length(artist_id_param, 1) <> array_length(artist_names_param, 1) THEN
              RAISE NOTICE 'Один или несколько исполнителей не существуют';
              RETURN;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE NOTICE 'Один или несколько исполнителей не существуют';
            RETURN;
    END;

    -- Проверка наличия всех исполнителей у песни
    SELECT EXISTS (
        SELECT 1
        FROM unnest(artist_id_param) a
        WHERE a NOT IN (
            SELECT sa.artist_id
            FROM song_artists sa
            WHERE sa.song_id = song_id_param
        )
    ) INTO artist_exists;

    IF artist_exists THEN
          RAISE NOTICE 'Песня не найдена у указанных исполнителей';
    ELSE
        BEGIN
            -- Удаление записей из таблицы song_artists только для указанных исполнителей
            DELETE FROM song_artists
            WHERE song_id = song_id_param AND artist_id = ANY (artist_id_param);

            -- Проверка оставшихся связей песни с другими исполнителями
            SELECT EXISTS (
                SELECT 1
                FROM song_artists
                WHERE song_id = song_id_param
            ) INTO song_exists;

            -- Если у песни нет больше связей с исполнителями, удалить ее из таблицы songs
            IF NOT song_exists THEN
                DELETE FROM songs WHERE song_id = song_id_param;
                RAISE NOTICE 'Песня успешно удалена и отсоединена от исполнителей';
            END IF;
        END;
    END IF;
END;
$$ LANGUAGE plpgsql;

--CALL delete_artist_by_name('SummertymeSudness',  ["Lana"]);

----------------СОЗДАНИЕ СООБЩЕСТВА------------------
--grant execute on procedure create_genre_community to admin;
CREATE OR REPLACE PROCEDURE create_genre_community(
    community_name_param VARCHAR(255),
    genre_name_param VARCHAR(255),
    community_description_param VARCHAR(255),
    image_community_param VARCHAR(255)
) AS $$
BEGIN
    IF community_name_param = '' THEN
        RAISE NOTICE 'Название сообщества не может быть пустым. Укажите корректное название.';
    ELSIF EXISTS (
        SELECT 1
        FROM genre_communities
        WHERE community_name = community_name_param
    ) THEN
        RAISE NOTICE 'Сообщество с таким названием уже существует. Выберите другое название.';
    ELSE
        INSERT INTO genre_communities (community_name, genre_name, community_description, image_community)
        VALUES (community_name_param, genre_name_param, community_description_param, image_community_param);
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


----------------------ОБНАВЛЕНИЕ ПЕСНИ-------------------
--grant execute on procedure UpdateSongAndArtistsById to admin;
CREATE OR REPLACE PROCEDURE UpdateSongAndArtistsById(
    songId INT,
    newAudio VARCHAR(255),
    newImage VARCHAR(255),
    artistNames TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    artistName TEXT;
    artistIdParam INT;
    artistNotFound BOOLEAN := FALSE;
BEGIN
    -- Удаляем старые связи исполнителей для этой песни
    DELETE FROM song_artists WHERE song_id = songId;

    -- Добавляем новые связи с артистами
    FOREACH artistName IN ARRAY artistNames
    LOOP
        SELECT artist_id INTO artistIdParam
        FROM artists
        WHERE artist_name = artistName;

        IF NOT FOUND THEN
            RAISE NOTICE 'Исполнитель с именем % не найден.', artistName;
            artistNotFound := TRUE;
        ELSE
            -- Добавляем связь песни и исполнителя
            BEGIN
                INSERT INTO song_artists (song_id, artist_id) 
                VALUES (songId, artistIdParam);
            EXCEPTION 
                WHEN unique_violation THEN
                    -- Если связь уже существует
                    RAISE NOTICE 'Связь между песней и исполнителем уже существует.';
            END;
        END IF;
    END LOOP;

    IF artistNotFound THEN
        RETURN; -- Если хотя бы один из артистов не найден, завершаем выполнение процедуры
    END IF;

    -- Обновляем информацию о песне
    UPDATE songs
    SET audio = newAudio, image = newImage
    WHERE song_id = songId;

    -- Выводим сообщение об успешном обновлении песни
    RAISE NOTICE 'Песня успешно обновлена.';
END;
$$;

-- Обновляем информацию о песне
   


select * from songs
select * from artists

----------------------Удалить сообщество у участников---------------------- 
--grant execute on procedure delete_community to admin;
CREATE OR REPLACE PROCEDURE delete_community(IN community_name_param VARCHAR(255))
LANGUAGE plpgsql 
SECURITY DEFINER
AS $$
DECLARE 
    community_id_value INT;
BEGIN
    -- Получаем идентификатор сообщества по его названию
    SELECT community_id INTO community_id_value
    FROM genre_communities
    WHERE community_name = community_name_param;
    
    IF community_id_value IS NOT NULL THEN
        -- Удаляем участников сообщества
        DELETE FROM community_members
        WHERE community_id = community_id_value;
        
        -- Удаляем само сообщество
        DELETE FROM genre_communities
        WHERE community_id = community_id_value;
        
        -- Выводим сообщение об успешном удалении
        RAISE NOTICE 'Сообщество "%", его участники и сообщество успешно удалены.', community_name_param;
    ELSE
        -- Выводим сообщение о том, что сообщество не найдено
        RAISE NOTICE 'Сообщество "%s" не найдено.', community_name_param;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- Выводим сообщение об ошибке
        RAISE NOTICE 'Произошла ошибка при удалении сообщества "%". Сообщение об ошибке: %', community_name_param, SQLERRM;
END;
$$;

--CALL delete_community('qwertyqwert');