----------------------РЕГИСТРАЦИЯ---------------------
CREATE OR REPLACE PROCEDURE add_user(
    username_param VARCHAR(255),
    password_hash_param VARCHAR(255),
    role_name_param VARCHAR(255),
    playlist_photo_url_param VARCHAR(255),
    OUT user_id_param INT,
    OUT user_exists BOOLEAN
)
SECURITY DEFINER
AS $$
DECLARE
    user_id_output INTEGER;
    playlist_id_output INTEGER;
BEGIN
    -- Проверка на пустые значения для входных параметров
    IF username_param = '' THEN
        RAISE EXCEPTION 'Имя пользователя не может быть пустым.';
    END IF;

    IF password_hash_param = '' THEN
        RAISE EXCEPTION 'Хэш пароля не может быть пустым.';
    END IF;

    IF role_name_param = '' THEN
        RAISE EXCEPTION 'Роль пользователя не может быть пустой.';
    END IF;

    IF playlist_photo_url_param = '' THEN
        RAISE EXCEPTION 'URL фотографии плейлиста не может быть пустым.';
    END IF;

    -- Проверка наличия пользователя с таким именем
    BEGIN
        SELECT user_id INTO STRICT user_id_output
        FROM users
        WHERE username = username_param;
        
        -- Если пользователь найден, устанавливаем флаг user_exists в true
        user_exists := TRUE;
        RAISE NOTICE 'Пользователь с именем % уже существует.', username_param;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Если пользователь не найден, продолжаем выполнение
            user_exists := FALSE;
    END;

    -- Если пользователь существует, выходим из процедуры
    IF user_exists THEN
        RETURN;
    END IF;

    -- Создаем нового пользователя
    INSERT INTO users (username, password_hash, role_name)
    VALUES (username_param, password_hash_param, role_name_param)
    RETURNING user_id INTO STRICT user_id_output;
    
    -- Проверяем роль пользователя перед созданием плейлиста
    IF role_name_param = 'users' THEN
        -- Создаем плейлист "Понравившиеся" для нового пользователя
        INSERT INTO playlists (user_id, title, descriprion, image_playlist)
        VALUES (user_id_output, 'Понравившиеся', '', playlist_photo_url_param)
        RETURNING playlist_id INTO STRICT playlist_id_output;
    END IF;

    -- Возвращаем ID пользователя и флаг user_exists
    user_id_param := user_id_output;
    user_exists := FALSE;
    RAISE NOTICE 'Вы успешно зарегистрировались под именем: %', username_param;
END;
$$ LANGUAGE plpgsql;

--------------------АВТОРИЗАЦИЯ----------------------
CREATE OR REPLACE PROCEDURE login(
    username_param VARCHAR(255),
    password_hash_param VARCHAR(255),
    OUT is_valid_user BOOLEAN,
    OUT user_role VARCHAR(255),
    OUT user_id INT
)
SECURITY DEFINER
AS $$
BEGIN
    -- Проверка на пустые значения для входных параметров
    IF username_param = '' THEN
        RAISE EXCEPTION 'Имя пользователя не может быть пустым.';
    END IF;

    IF password_hash_param = '' THEN
        RAISE EXCEPTION 'Пароль не может быть пустым.';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM users
        WHERE username = username_param
    ) INTO is_valid_user;
    
    IF is_valid_user THEN
        SELECT role_name INTO user_role FROM users WHERE username = username_param AND password_hash = password_hash_param;
        
        IF user_role IS NULL THEN
            RAISE NOTICE 'Неверный пароль для пользователя: %', username_param;
            RETURN;
        ELSE
            SELECT u.user_id INTO user_id FROM users u WHERE u.username = username_param;
        END IF;
    ELSE
        RAISE NOTICE 'Пользователь не существует: %', username_param;
        RETURN;
    END IF;
    
    RAISE NOTICE 'Вы успешно вошли в аккаунт: %', username_param;
END;
$$ LANGUAGE plpgsql;
