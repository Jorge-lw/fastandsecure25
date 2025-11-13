-- Base de datos con datos de prueba y configuraciones inseguras

CREATE DATABASE IF NOT EXISTS vulnerable_db;
USE vulnerable_db;

-- Vulnerabilidad: Tabla con información sensible sin encriptar
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50),
    password VARCHAR(50),  -- Sin hash
    email VARCHAR(100),
    credit_card VARCHAR(20),
    ssn VARCHAR(20)
);

-- Vulnerabilidad: Insertar datos de prueba con credenciales débiles
INSERT INTO users (username, password, email, credit_card, ssn) VALUES
('admin', 'admin123', 'admin@example.com', '4532-1234-5678-9010', '123-45-6789'),
('user1', 'password123', 'user1@example.com', '4111-1111-1111-1111', '987-65-4321'),
('test', 'test', 'test@example.com', '5555-5555-5555-5555', '111-22-3333');

-- Vulnerabilidad: Usuario con privilegios excesivos
CREATE USER 'test'@'%' IDENTIFIED BY 'test123';
GRANT ALL PRIVILEGES ON *.* TO 'test'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;

