-- Создание таблицы "Исполнители"
CREATE TABLE artists (
artist_id SERIAL PRIMARY KEY,
artist_name VARCHAR(255) NOT NULL UNIQUE,
photo BYTEA NOT NULL
);
select * from playlist_songs;
select * from songs

-- Создание таблицы "Песни"
CREATE TABLE songs (
    song_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    audio VARCHAR(255) NOT NULL,
    image VARCHAR(255) NOT NULL,
    listens_count INT DEFAULT 0
);


drop INDEX idx_song_artists_song_id  
drop INDEX idx_song_artists_artist_id 
CREATE INDEX idx_song_artists_song_id ON song_artists (song_id);
CREATE INDEX idx_song_artists_artist_id ON song_artists (artist_id);

-- Создание таблицы "Связь песен и исполнителей"
CREATE TABLE song_artists (
song_artist_id SERIAL PRIMARY KEY,
song_id INT NOT NULL,
artist_id INT NOT NULL,
FOREIGN KEY (song_id) REFERENCES songs(song_id) ON DELETE CASCADE,
FOREIGN KEY (artist_id) REFERENCES artists(artist_id) ON DELETE CASCADE
);

select * from users;
-- Создание таблицы "Пользователи"
CREATE TABLE users (
user_id SERIAL PRIMARY KEY,
username VARCHAR(255) NOT NULL UNIQUE,
password_hash VARCHAR(255) NOT NULL,
role_name VARCHAR(255) NOT NULL
);

-- Создание таблицы "Пользователи_IMPORT"
CREATE TABLE users_import (
user_id SERIAL PRIMARY KEY,
username VARCHAR(255) NOT NULL UNIQUE,
password_hash VARCHAR(255) NOT NULL,
role_name VARCHAR(255) NOT NULL
);

-- Создание таблицы "Лайки"
CREATE TABLE likes (
like_id SERIAL PRIMARY KEY,
user_id INT NOT NULL,
song_id INT NOT NULL,
FOREIGN KEY (user_id) REFERENCES users(user_id),
FOREIGN KEY (song_id) REFERENCES songs(song_id) ON DELETE CASCADE
);

-- Создание таблицы "Плейлисты"
CREATE TABLE playlists (
playlist_id SERIAL PRIMARY KEY,
user_id INT NOT NULL,
title VARCHAR(255) NOT NULL,
descriprion VARCHAR(255),
image_playlist VARCHAR(255),
FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Создание таблицы "Состав плейлиста"
CREATE TABLE playlist_songs (
playlist_song_id SERIAL PRIMARY KEY,
playlist_id INT NOT NULL,
song_id INT NOT NULL,
FOREIGN KEY (playlist_id) REFERENCES playlists(playlist_id) ON DELETE CASCADE,
FOREIGN KEY (song_id) REFERENCES songs(song_id) ON DELETE CASCADE
);

-- Создание таблицы "Сообщества по жанрам"
CREATE TABLE genre_communities (
community_id SERIAL PRIMARY KEY,
genre_name VARCHAR(255) NOT NULL,
community_name VARCHAR(255) NOT NULL,
community_description VARCHAR(255) NOT NULL,
image_community VARCHAR(255) NOT NULL
);

-- Создание таблицы "Участники сообществ"
CREATE TABLE community_members (
community_member_id SERIAL PRIMARY KEY,
community_id INT NOT NULL,
user_id INT NOT NULL,
FOREIGN KEY (community_id) REFERENCES genre_communities(community_id) ON DELETE CASCADE,
FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE artist_descriptions (
  description_id SERIAL PRIMARY KEY,
  artist_id INT NOT NULL,
  birth_date DATE NOT NULL,
  artist_info TEXT,
  popular_album VARCHAR(255),
  listeners_count INT,
  FOREIGN KEY (artist_id) REFERENCES artists(artist_id) ON DELETE CASCADE
);

-- Удаление таблицы "Сообщества по жанрам"
DROP TABLE IF EXISTS genre_communities CASCADE;

-- Удаление таблицы "Участники сообществ"
DROP TABLE IF EXISTS community_members CASCADE;

-- Удаление таблицы "Лайки"
DROP TABLE IF EXISTS likes CASCADE;

-- Удаление таблицы "Состав плейлиста"
DROP TABLE IF EXISTS playlist_songs CASCADE;

-- Удаление таблицы "Плейлисты"
DROP TABLE IF EXISTS playlists CASCADE;

-- Удаление таблицы "Связь песен и исполнителей"
DROP TABLE IF EXISTS song_artists CASCADE;

-- Удаление таблицы "Песни"
DROP TABLE IF EXISTS songs CASCADE;

-- Удаление таблицы "Исполнители"
DROP TABLE IF EXISTS artists CASCADE;

-- Удаление таблицы "Описания исполнителей"
DROP TABLE IF EXISTS artist_descriptions;
DROP TABLE IF EXISTS users;