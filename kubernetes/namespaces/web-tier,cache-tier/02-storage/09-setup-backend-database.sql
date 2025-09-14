-- Backend 애플리케이션용 데이터베이스 및 사용자 생성
CREATE DATABASE kosa_db;
CREATE USER kosa_user WITH ENCRYPTED PASSWORD 'secure_password_2024';
GRANT ALL PRIVILEGES ON DATABASE kosa_db TO kosa_user;

-- kosa_db에 연결한 후 실행할 권한 설정
\c kosa_db;
GRANT ALL ON SCHEMA public TO kosa_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO kosa_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO kosa_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO kosa_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO kosa_user;