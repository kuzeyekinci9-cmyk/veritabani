CREATE TABLE users(
	user_id SERIAL PRIMARY KEY,
	full_name VARCHAR(100) NOT NULL
);


CREATE TABLE categories (
	category_id SERIAL PRIMARY KEY,
	name VARCHAR(50) NOT NULL
);

CREATE TABLE tools (
    tool_id SERIAL PRIMARY KEY,
    owner_id INTEGER REFERENCES users(user_id),       -- Links to User
    category_id INTEGER REFERENCES categories(category_id), -- Links to Category
    name VARCHAR(100) NOT NULL,
    daily_price DECIMAL(10, 2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);


INSERT INTO users (full_name) VALUES
('Sarah Martinez'),
('James Chen'),
('Emma Thompson'),
('Michael Rodriguez'),
('Olivia Johnson'),
('David Kim'),
('Sofia Anderson'),
('Lucas Brown'),
('Isabella Garcia'),
('Noah Williams');


INSERT INTO categories (name) VALUES
('Power Tools'),
('Hand Tools'),
('Gardening'),
('Ladders & Scaffolding'),
('Cleaning Equipment'),
('Painting Supplies'),
('Plumbing Tools'),
('Automotive'),
('Camping Gear'),
('Party Equipment');


INSERT INTO tools (owner_id, category_id, name, daily_price, is_active) VALUES
(1, 1, 'DeWalt Cordless Drill 20V', 15.00, TRUE),
(2, 3, 'Electric Hedge Trimmer', 12.50, TRUE),
(3, 4, 'Extension Ladder 24ft', 25.00, TRUE),
(4, 5, 'Carpet Steam Cleaner', 30.00, TRUE),
(5, 1, 'Circular Saw Professional Grade', 18.00, TRUE),
(6, 8, 'OBD2 Diagnostic Scanner', 20.00, TRUE),
(7, 9, '4-Person Camping Tent', 22.00, TRUE),
(8, 6, 'Paint Sprayer Electric', 28.00, FALSE),
(9, 2, 'Socket Wrench Set Complete', 10.00, TRUE),
(10, 10, 'Folding Tables (Set of 4)', 35.00, TRUE);

