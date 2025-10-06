--- Se crea la base de datos
CREATE DATABASE IF NOT EXISTS comercial;
USE comercial;

--- Se crea la tabla 'american_users'
CREATE TABLE IF NOT EXISTS american_users (
	id INT PRIMARY KEY,
	name VARCHAR(100),
	surname VARCHAR(100),
	phone VARCHAR(150),
	email VARCHAR(150),
	birth_date VARCHAR(100),
	country VARCHAR(150),
	city VARCHAR(150),
	postal_code VARCHAR(100),
	address VARCHAR(255)
);
--- Se crea la tabla 'european_users'
CREATE TABLE IF NOT EXISTS european_users (
	id INT PRIMARY KEY,
	name VARCHAR(100),
	surname VARCHAR(100),
	phone VARCHAR(150),
	email VARCHAR(150),
	birth_date VARCHAR(100),
	country VARCHAR(150),
	city VARCHAR(150),
	postal_code VARCHAR(100),
	address VARCHAR(255)
);
--- Se crea la tabla 'credit_cards'
CREATE TABLE IF NOT EXISTS credit_cards (
	id VARCHAR(15) PRIMARY KEY,
	user_id VARCHAR(15),
	iban VARCHAR(50),
	pan VARCHAR(50),
	pin VARCHAR(4),
	cvv VARCHAR(3),
	track1 VARCHAR(150),
	track2 VARCHAR(150),
	expiring_date VARCHAR(15)
);
--- Se crea la tabla 'companies'
CREATE TABLE IF NOT EXISTS companies (
	company_id VARCHAR(20) PRIMARY KEY,
	company_name VARCHAR(255),
	phone VARCHAR(15),
	email VARCHAR(100),
	country VARCHAR(100),
	website VARCHAR(255)
);
--- Se crea la tabla 'transactions'
CREATE TABLE IF NOT EXISTS transactions (
	id VARCHAR(255) PRIMARY KEY,
	card_id VARCHAR(15),
	business_id VARCHAR(20),
	timestamp TIMESTAMP,
	amount DECIMAL(10,2),
	declined TINYINT(1),
    product_ids VARCHAR(255),
    user_id INT,
    lat FLOAT,
    longitude FLOAT
);
--- Se carga los datos de la tabla 'american_users'
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\american_users.csv'
INTO TABLE american_users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

--- Ante un error 1290 de secure-file
--- SHOW VARIABLES LIKE "secure_file_priv"; --- encuentra el directorio en el que tienes permitido guardar.
--- SHOW VARIABLES LIKE "LOCAL_INFILE"; --- verifica si está ON o OFF.
--- SET GLOBAL LOCAL_INFILE = "ON"; --- Se cambia a ON y se verifica con la instrucción anterior.
--- Se vuelve a cargar los datos de la tabla, especificando la ruta y colocando dos barras.

--- Se carga los datos de la tabla 'european_users'
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\european_users.csv'
INTO TABLE european_users
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

--- Se carga los datos de la tabla 'credit_cards'
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\credit_cards.csv'
INTO TABLE credit_cards
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

--- Se carga los datos de la tabla 'companies'
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\companies.csv'
INTO TABLE companies
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

--- Se carga los datos de la tabla 'transactions'
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\transactions.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ';'
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

--- Se comparan los 'id' de las tablas ‘american_users’ y ‘european_users’
--- Encontrar IDs que existen en ambas tablas
SELECT au.id 
FROM american_users au
INNER JOIN european_users eu ON au.id = eu.id;

--- Se crea tabla unica 'users' que combina las tablas 'american_users' y 'european_users'
--- Se agrega una columna 'region' para identificar los registros de cada tabla. 
CREATE TABLE IF NOT EXISTS users (
	id INT PRIMARY KEY,
    name VARCHAR(100),
	surname VARCHAR(100),
	phone VARCHAR(150),
	email VARCHAR(150),
	birth_date VARCHAR(100),
	country VARCHAR(150),
	city VARCHAR(150),
	postal_code VARCHAR(100),
	address VARCHAR(255),
    region VARCHAR(150)
);
--- Se fusionan los datos de las tablas 'american_users' y 'european_users' en la nueva tabla 'users'
INSERT INTO users (id, name, surname, phone, email, birth_date, country, city, postal_code, address, region)
SELECT id, name, surname, phone, email, birth_date, country, city, postal_code, address, 'AMERICAN' as region
FROM american_users
UNION ALL
SELECT id, name, surname, phone, email, birth_date, country, city, postal_code, address, 'EUROPEAN' as region  
FROM european_users;

SELECT * 
FROM users;

--- Se eliminan las tablas 'american_users' y 'european_users' , porque ya no las necesitamos.
DROP TABLE IF EXISTS american_users;
DROP TABLE IF EXISTS european_users;

--- Se crea las FK para vincular las tablas en la base de datos.
ALTER TABLE transactions
ADD FOREIGN KEY (card_id) REFERENCES credit_cards (id),
ADD FOREIGN KEY (business_id) REFERENCES companies (company_id),
ADD FOREIGN KEY (user_id) REFERENCES users (id);

--- se crea diagrama de modelo (adjunto imagen en pdf)


--- --- NIVEL 1 --- ---

--- Ejercicio 1 --- se realiza una subconsulta que muestre a todos los usuarios con más de 80 transacciones utilizando al menos 2 tablas.
SELECT u.id, u.name, u.surname, total_transactions
FROM users u, (SELECT DISTINCT t.user_id, COUNT(t.id) AS total_transactions
	FROM transactions t
	GROUP BY t.user_id
	HAVING total_transactions > 80) ut
WHERE ut.user_id = u.id;


--- Ejercicio 2 --- Muestra la media de amount por IBAN de las tarjetas de crédito en la compañía Donec Ltd., utiliza por lo menos 2 tablas.
SELECT cc.iban, t.card_id, ROUND(AVG(t.amount),2) AS mean
FROM transactions t
JOIN credit_cards cc ON cc.id = t.card_id
JOIN companies c ON c.company_id = t.business_id AND c.company_name = 'Donec Ltd' 
GROUP BY t.card_id, t.business_id
ORDER BY mean DESC;





--- --- NIVEL 2 --- ---

--- Crea una nueva tabla que refleje el estado de las tarjetas de crédito basado en si las últimas tres transacciones fueron declinadas.
CREATE TABLE IF NOT EXISTS status_cc AS
SELECT card_id,
	CASE 
		WHEN SUM(declined) = 3 THEN 'inactive'
        ELSE 'active'
	END AS status
FROM (SELECT *
	FROM (SELECT *, 
		ROW_NUMBER() OVER (PARTITION BY card_id ORDER BY timestamp DESC) AS fila
		FROM transactions) stat_cc
	WHERE fila <= 3) last_reg
GROUP BY card_id;

SELECT *
FROM status_cc;


--- --- VERIFICACIONES PREVIAS --- ---
--- identifica tarjetas que coinciden en ambas tablas, (en este caso todas)
--- SELECT DISTINCT cc.id
--- FROM credit_cards cc
--- JOIN transactions t ON cc.id = t.card_id;

--- ordena transacciones por tarjeta y por fecha descendente
--- SELECT card_id, timestamp, declined
--- FROM transactions 
--- ORDER BY card_id, timestamp DESC;

--- CTE obtiene los 3 ultimos registros de cada tarjeta
--- WITH state_cc AS (
--- 	SELECT 
--- 		*,
---     ROW_NUMBER() OVER (PARTITION BY card_id ORDER BY timestamp DESC) AS fila
---     FROM transactions
--- )
--- SELECT *
--- FROM state_cc
--- WHERE fila <= 3;
--- --- FIN DE VERIFICACIONES PREVIAS --- ---


--- Se crea la PK de la tabla 'status_cc'.
ALTER TABLE status_cc
ADD PRIMARY KEY (card_id);

--- Se crea la FK de la tabla 'status_cc'.
ALTER TABLE status_cc
ADD FOREIGN KEY (card_id) REFERENCES credit_cards (id),
ADD UNIQUE (card_id);

--- se genera diagrama --- (adjunto imagen en pdf)


--- Ejercicio 1 --- ¿Cuántas tarjetas están activas?
SELECT COUNT(card_id) AS num_creditcards, status
FROM status_cc
WHERE status = 'active';

--- COMENTARIO --- Otra solucion --- donde se ve la cantidad de tarjetas activas y de inactivas
--- SELECT COUNT(card_id) AS num_creditcards, status
--- FROM status_cc
--- GROUP BY status;
---------------------------------





--- --- NIVEL 3 --- ---
--- Crea una tabla con la que podamos unir los datos del nuevo archivo products.csv con la base de datos creada, teniendo en cuenta que desde transaction tienes product_ids. Genera la siguiente consulta.
--- Se crea la tabla 'products'
CREATE TABLE IF NOT EXISTS products (
	id VARCHAR(250),
	product_name VARCHAR(250),
	price VARCHAR(150),
	colour VARCHAR(150),
	weight VARCHAR(150),
	warehouse_id VARCHAR(150)
);

--- Se carga los datos de la tabla 'products'
LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

--- Crea una nueva tabla que relacione la tabla products y la tabla transactions.

--- Solucion 1 (cuando es posible que se repitan productos en la misma transaccion)
--- 1ro se busca conocer el largo de cada registro y numero de comas (se aplica a todos los registros)
SELECT id, product_ids, length(product_ids) AS l1, length(REPLACE(product_ids,',','')) AS l2, length(product_ids) - length(REPLACE(product_ids,',','')) AS n 
FROM transactions 
ORDER BY length(product_ids) - length(REPLACE(product_ids,',','')) DESC;

--- 2do se crea la tabla
CREATE TABLE IF NOT EXISTS products_related AS
WITH prod_trans AS (
	SELECT *
	FROM (
		SELECT id, product_ids, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 1), ',', -1)) AS valor FROM transactions
		UNION 
		SELECT id, product_ids, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 2), ',', -1)) AS valor FROM transactions
		UNION 
		SELECT id, product_ids, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 3), ',', -1)) AS valor FROM transactions
		UNION 
		SELECT id, product_ids, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 4), ',', -1)) AS valor FROM transactions
		UNION 
		SELECT id, product_ids, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 5), ',', -1)) AS valor FROM transactions
	) a
	ORDER BY length(product_ids) - length(REPLACE(product_ids,',','')) DESC, id
)
SELECT pt.id AS id_transaction, p.id AS id_product
FROM prod_trans pt
JOIN products p ON FIND_IN_SET(p.id, pt.valor);

SELECT *
FROM products_related
ORDER BY id_transaction;


--- solucion 2 (cuando no se repiten productos en la misma transaccion)
--- CREATE TABLE IF NOT EXISTS products_related AS
--- SELECT t.id AS id_transaction, p.id AS id_product
--- FROM transactions t
--- JOIN products p ON FIND_IN_SET(p.id, replace(t.product_ids,' ',''))
--- order by t.id;



--- --- VERIFICACIONES y PRUEBAS PREVIAS --- ---
--- SELECT t.id AS id_transaction, p.id AS id_product, product_name
--- FROM transactions t
--- JOIN products p ON FIND_IN_SET(p.id, t.product_ids) > 0;

--- para conocer el largo de cada registro y numero de comas (se prueba con los 10 primeros registros)
--- SELECT id, product_ids, length(product_ids) AS l1, length(REPLACE(product_ids,',','')) AS l2, length(product_ids) - length(REPLACE(product_ids,',','')) AS n 
--- FROM transactions 
--- LIMIT 10;

--- para conocer la cantidad total de productos en todos los registros de transacciones --- (en este caso: 253391) ---
--- SELECT sum(1+ length(product_ids) - length(REPLACE(product_ids,',','')))
--- FROM (SELECT id, product_ids, length(product_ids) AS l1, length(REPLACE(product_ids,',','')) AS l2, length(product_ids) - length(REPLACE(product_ids,',','')) AS n 
--- 	FROM transactions) a;

--- consulta para poner los productos de la tabla transactions en una columna --- funciona ok ---
--- SELECT *
--- FROM
--- (
--- 	SELECT id, product_ids, SUBSTRING_INDEX(product_ids, ',', 1) AS sub, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 1), ',', -1)) AS valor FROM transactions
--- 	UNION 
--- 	SELECT id, product_ids, SUBSTRING_INDEX(product_ids, ',', 2) AS sub, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 2), ',', -1)) AS valor FROM transactions
--- 	UNION 
--- 	SELECT id, product_ids, SUBSTRING_INDEX(product_ids, ',', 3) AS sub, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 3), ',', -1)) AS valor FROM transactions
--- 	UNION 
--- 	SELECT id, product_ids, SUBSTRING_INDEX(product_ids, ',', 4) AS sub, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 4), ',', -1)) AS valor FROM transactions
--- 	UNION 
--- 	SELECT id, product_ids, SUBSTRING_INDEX(product_ids, ',', 5) AS sub, trim(SUBSTRING_INDEX(SUBSTRING_INDEX(product_ids, ',', 5), ',', -1)) AS valor FROM transactions
--- ) a
--- ORDER BYy length(product_ids) - length(REPLACE(product_ids,',','')) DESC, id, length(sub);

--- FIN DE VERIFICACIONES Y PRUEBAS ---


--- Se crea la PK en la tabla products
ALTER TABLE products
ADD PRIMARY KEY (id);

--- Se crea la PK y la FK para vincular la nueva tabla en la base de datos.
ALTER TABLE products_related
ADD PRIMARY KEY (id_transaction, id_product);

ALTER TABLE products_related
ADD FOREIGN KEY (id_transaction) REFERENCES transactions (id);

ALTER TABLE products_related
ADD FOREIGN KEY (id_product) REFERENCES products (id);

--- se genera diagrama --- (adjunto imagen en pdf)


--- Ejercicio 1 --- Necesitamos conocer el número de veces que se ha vendido cada producto.
SELECT pr.id_product, COUNT(pr.id_transaction) AS quantity_products
FROM products_related pr
JOIN transactions t ON pr.id_transaction = t.id AND t.declined = 0
GROUP BY id_product;
