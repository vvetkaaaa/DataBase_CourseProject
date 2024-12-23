------------------------ИЗ ПРИЛОЖЕНИЯ В JSON--------------------------
CREATE OR REPLACE PROCEDURE export_users_to_json(p_file_path text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    EXECUTE format('COPY (
        SELECT json_agg(row_to_json(t))
        FROM (
            SELECT u.*
            FROM users_import u
        ) t
    ) TO %L', p_file_path);
END;
$$;

CALL export_users_to_json('C:\3course\COURSE_PROJ\online_music\importUsers.json');


------------------------ИЗ JSON В ПРИЛОЖУХУ-----------------------------------
CREATE OR REPLACE PROCEDURE import_users_from_json_file(
    json_file_path TEXT
)
AS $$
DECLARE
    json_data JSON;
    user_data JSON;
    username_param VARCHAR;
    password_hash_param VARCHAR;
    role_name_param VARCHAR;
    playlist_photo_url_param VARCHAR;
BEGIN
    -- Read JSON file
    json_data := jsonb(PG_READ_FILE(json_file_path));

    -- Check if JSON file reading is successful
    IF json_data IS NULL THEN
        RAISE EXCEPTION 'Failed to read the JSON file';
    END IF;

    -- Loop through users in the JSON
    FOR user_data IN SELECT * FROM json_array_elements(json_data)
    LOOP
        -- Extract values from JSON
        username_param := user_data->>'username';
        password_hash_param := user_data->>'password_hash';
        role_name_param := user_data->>'role_name';
        
        -- Insert user data into the 'users_import' table
        INSERT INTO users_import(username, password_hash, role_name)
        VALUES (username_param, password_hash_param, role_name_param);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the procedure to import data from the JSON file to the 'users_import' table
CALL import_users_from_json_file('C:\\3course\\COURSE_PROJ\\online_music\\importUsers.json');
select * from users_import;