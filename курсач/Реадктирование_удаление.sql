------------РЕДАКТИРОВАНИЕ АККАУНТА------------------
GRANT EXECUTE ON PROCEDURE edit_user_info(INT, VARCHAR, VARCHAR) TO users;
CREATE OR REPLACE PROCEDURE edit_user_info(
    user_id_param INT,
    new_username_param VARCHAR(255),
    new_password_hash_param VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    username_exists BOOLEAN;
    user_exists BOOLEAN;
BEGIN
    -- Проверка на пустые значения для new_username_param и new_password_hash_param
    IF new_username_param = '' THEN
        RAISE EXCEPTION 'Поле имени пользователя не может быть пустым.';
    END IF;

    IF new_password_hash_param = '' THEN
        RAISE EXCEPTION 'Поле пароля не может быть пустым.';
    END IF;

    -- Проверка существования пользователя с указанным ID
    SELECT EXISTS(
        SELECT 1
        FROM users
        WHERE user_id = user_id_param
    ) INTO user_exists;

    IF NOT user_exists THEN
        RAISE EXCEPTION 'Пользователь с ID % не существует.', user_id_param;
    END IF;

    -- Проверка наличия нового имени пользователя в базе данных, исключая текущего пользователя
    SELECT EXISTS(
        SELECT 1
        FROM users
        WHERE username = new_username_param
        AND user_id != user_id_param
    ) INTO username_exists;

    IF username_exists THEN
        RAISE EXCEPTION 'Пользователь с именем % уже существует. Выберите другое имя.', new_username_param;
    ELSE
        -- Обновление данных пользователя
        UPDATE users
        SET username = new_username_param,
            password_hash = new_password_hash_param
        WHERE user_id = user_id_param;

        RAISE NOTICE 'Информация пользователя с ID % успешно обновлена.', user_id_param;
    END IF;
END;
$$;

--call edit_user_info(5, 'admin', 'Adminadmin');


------------УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ-------------------
GRANT EXECUTE ON PROCEDURE delete_user(VARCHAR) TO users;
CREATE OR REPLACE PROCEDURE delete_user(
    username_param VARCHAR(255)
)
SECURITY DEFINER
AS $$
DECLARE
    user_id_param INT;
BEGIN
    -- Проверка существования пользователя
    IF NOT EXISTS(SELECT 1 FROM users WHERE username = username_param) THEN
        RAISE EXCEPTION 'Пользователь с именем % не существует.', username_param;
    END IF;

    -- Получение user_id из базы данных
    SELECT users.user_id INTO user_id_param
    FROM users
    WHERE username = username_param;

    -- Удаление пользователя и связанных с ним данных
    DELETE FROM users
    WHERE user_id = user_id_param;

    RAISE NOTICE 'Аккаунт пользователя % успешно удален.', username_param;
END;
$$ LANGUAGE plpgsql;

--CALL delete_user('');