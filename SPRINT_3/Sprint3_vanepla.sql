Use `transactions`;

--- --- --- --- --- SPRINT 3 --- --- --- --- ---
--- --- NIVEL 1 --- ---
--- Ejercicio 1 --- Tu tarea es diseñar y crear una tabla llamada "credit_card" que almacene detalles cruciales sobre las tarjetas de crédito. 
---                 La nueva tabla debe ser capaz de identificar de forma única cada tarjeta y establecer una relación adecuada con las otras dos tablas ("transaction" y "company"). 
---                 Después de crear la tabla será necesario que ingreses la información del documento denominado "datos_introducir_credit". 
---                 Recuerda mostrar el diagrama y realizar una breve descripción del mismo.

--- Se crea la tabla 'credit_card'
CREATE TABLE IF NOT EXISTS credit_card (
	id VARCHAR(15) NOT NULL,
	iban VARCHAR(50),
	pan VARCHAR(50),
	pin VARCHAR(4),
	cvv VARCHAR(3),
	expiring_date VARCHAR(15),
	PRIMARY KEY (id)
);

--- Se cargan lo valores de la tabla 'credit_card'. (se carga: 'datos_introducir_credit'.sql)
--- Se verifica y asigna que la tabla 'transaction' cuente con la FK que la relaciona con la tabla 'credit_card'.
ALTER TABLE transaction
ADD FOREIGN KEY (credit_card_id) REFERENCES credit_card (id);


--- EJERCICIO 2 --- El departamento de Recursos Humanos ha identificado un error en el número de cuenta asociado a su tarjeta de crédito con ID CcU-2938. 
---                 La información que debe mostrarse para este registro es: TR323456312213576817699999. Recuerda mostrar que el cambio se realizó.
--- Paso 1, se verifica que exista dicho registro:
SELECT id, iban
FROM credit_card
WHERE id = 'CcU-2938';

--- Paso 2, se realiza el cambio solicitado de iban:
UPDATE credit_card
SET iban = 'TR323456312213576817699999'
WHERE id = 'CcU-2938';

--- Paso 3, se verifica que cambio se realizo correctamente:
SELECT id, iban
FROM credit_card
WHERE id = 'CcU-2938';


--- EJERCICIO 3 --- En la tabla "transaction" ingresa un nuevo usuario con la siguiente información:
--- Id	108B1D1D-5B23-A76C-55EF-C568E49A99DD
--- credit_card_id	CcU-9999
--- company_id	b-9999
--- user_id	9999
--- lat	829.999
--- longitud	-117.999
--- amount	111.11
--- declined	0

--- Tabla 'credit_card'
--- Paso 1: se verifica que exista en tabla 'credit_card' el id  'CcU-9999'
SELECT *
FROM credit_card
WHERE id = 'CcU-9999';

--- Paso 2: Se crea el id 'CcU-9999' en la tabla 'credit_card' (porque no existe) y se verifica que el nuevo id esté en la tabla 'credit_card'.
INSERT INTO credit_card (id)
VALUES ('CcU-9999');

SELECT *
FROM credit_card
WHERE id = 'CcU-9999';
--- Tabla 'company'
--- Paso 1: se verifica que exista en tabla 'company' el id  'b-9999'
SELECT *
FROM company
WHERE id = 'b-9999';

--- Paso 2: Se crea el id 'b-9999' en la tabla 'company' (porque no existe) y se verifica que el nuevo id esté en la tabla 'company'.
INSERT INTO company (id)
VALUES ('b-9999');

SELECT *
FROM company
WHERE id = 'b-9999';
--- Tabla 'transaction'
--- Paso 1: Se verifica si existe en la tabla 'transaction' el id '108B1D1D-5B23-A76C-55EF-C568E49A99DD'
SELECT *
FROM transaction
WHERE id = '108B1D1D-5B23-A76C-55EF-C568E49A99DD';

--- Paso 2: Se ingresa el nuevo registro solicitado en tabla 'transaction' y se verifica que el nuevo registro esté en la tabla 'transaction'.
INSERT INTO transaction (id, credit_card_id, company_id, user_id, lat, longitude, amount, declined)
VALUES ('108B1D1D-5B23-A76C-55EF-C568E49A99DD', 'CcU-9999', 'b-9999', '9999', '829.999', '-117.999', '111.11', '0');

SELECT *
FROM transaction
WHERE id = '108B1D1D-5B23-A76C-55EF-C568E49A99DD';

--- EJERCICIO 4 --- Desde recursos humanos te solicitan eliminar la columna "pan" de la tabla credit_card. Recuerda mostrar el cambio realizado.
--- Paso 1: se verifica que en la tabla 'credit_card' exista la columna 'pan'.
DESCRIBE credit_card;


--- Paso 2: se elimina la columna 'pan' y se verifica que ya no aparezca en la tabla 'credit_card'.
ALTER TABLE credit_card
DROP pan;

DESCRIBE credit_card;



--- --- NIVEL 2 --- ---

--- EJERCICIO 1 --- Elimina de la tabla transacción el registro con ID 000447FE-B650-4DCF-85DE-C7ED0EE1CAAD de la base de datos.

--- Paso 1: se verifica que en la tabla 'transaction' exista el registro con ID 000447FE-B650-4DCF-85DE-C7ED0EE1CAAD.
SELECT *
FROM transaction
WHERE id = '000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

--- Paso 2: se elimina el registro con ID 000447FE-B650-4DCF-85DE-C7ED0EE1CAAD y se verifica que ya no aparezca en la tabla 'transaction'.
DELETE
FROM transaction
WHERE id = '000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

SELECT *
FROM transaction
WHERE id = '000447FE-B650-4DCF-85DE-C7ED0EE1CAAD';

--- EJERCICIO 2 --- La sección de marketing desea tener acceso a información específica para realizar análisis y estrategias efectivas. 
--- 				Se ha solicitado crear una vista que proporcione detalles clave sobre las compañías y sus transacciones. 
--- 				Será necesaria que crees una vista llamada VistaMarketing que contenga la siguiente información: Nombre de la compañía. Teléfono de contacto. País de residencia. Media de compra realizado por cada compañía. 
--- 				Presenta la vista creada, ordenando los datos de mayor a menor promedio de compra.

CREATE VIEW VistaMarketing (company_name, phone, country, average_purchases) AS
SELECT c.company_name, c.phone, c.country, ROUND(AVG(t.amount),2) AS average_purchases
FROM company c
JOIN transaction t ON c.id = t.company_id
WHERE t.declined = 0
GROUP BY c.company_name, c.phone, c.country
ORDER BY average_purchases DESC;

SELECT * FROM VistaMarketing;


--- EJERCICIO 3 --- Filtra la vista VistaMarketing para mostrar sólo las compañias que tienen su país de residencia en 'Germany'.
SELECT * FROM VistaMarketing
WHERE country = 'Germany';


--- --- NIVEL 3 --- ---

--- EJERCICIO 1 --- La próxima semana tendrás una nueva reunión con los gerentes de marketing.
---                 Un compañero de tu equipo realizó modificaciones en la base de datos, pero no recuerda cómo las realizó.
---                 Te pide que le ayudes a dejar los comandos ejecutados para obtener el siguiente diagrama:
---                 es necesario que describas el "paso a paso" de las tareas realizadas. Es importante realizar descripciones sencillas, simples y fáciles de comprender. 
---                 deberás trabajar con los archivos denominados "estructura_datos_user" y "datos_introducir_user".
---                 Recuerda seguir trabajando sobre el modelo y las tablas con las que ya has trabajado hasta ahora.

--- Paso 1: Se crea la tabla 'user'
CREATE TABLE IF NOT EXISTS user (
	id CHAR(10) PRIMARY KEY,
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
--- Paso 2: Se cargan lo valores de la tabla 'user'. (se carga: 'datos_introducir_user'.sql)
--- Paso 3: En tabla ‘user’, cambiar tipo de variable ‘id’ de CHAR a INT y nombre de variable ‘email’ por el ‘personal_email’.
--- se verifica tabla 'user', para ver la informacion actuales.
DESCRIBE user;

--- Se realiza el cambio del tipo de dato de ‘id’ de CHAR a INT y nombre de columna ‘email’ por el ‘personal_email’. Luego se visualiza nuevamente la tabla, para verificar cambios realizados.
ALTER TABLE user
MODIFY id INT;

ALTER TABLE user
RENAME COLUMN email TO personal_email;

DESCRIBE user;




--- Paso 4: En tabla ‘user’, agregar el user_id = '9999', que se habia ingresado en la tabla 'transaction' como parte de la información de una nueva transacción (ejercicio 3 - Nivel 1)

--- se verifica si existe o no en tabla 'user' el id '9999'
SELECT *
FROM user
WHERE id = '9999';

--- Se crea el id '9999' en la tabla 'user' (porque no existe) y se verifica que el nuevo id esté en la tabla 'user'.
INSERT INTO user (id)
VALUES ('9999');

SELECT *
FROM user
WHERE id = '9999';

--- Paso 5: actualizar tabla ‘transaction’ con FK ‘user_id’ para establecer la relación de 1 a N entre la tabla ‘data_user’ y la tabla ‘transaction’.
ALTER TABLE transaction
ADD FOREIGN KEY (user_id) REFERENCES user(id);

--- Paso 6: Se renombra tabla 'user' como 'data_user'.
RENAME TABLE user TO data_user;

--- Paso 7: en la tabla ‘company’ eliminar la columna ‘website’
--- Verificar las columnas de la tabla 'company'
DESCRIBE company;
--- se elimina la columna 'website' y se verifica nuevamente la tabla 'company'
ALTER TABLE company
DROP website;

DESCRIBE company;

--- Paso 8: en la tabla ‘credit_card’ agregar nueva variable ‘fecha_actual’ DATE
--- verificar si existe la columna 'fecha_Actual' DATE en la tabla 'credit_card'
DESCRIBE credit_card;
--- agregar la nueva columna 'fecha_actual' DATE y se verifica nuevamente la tabla 'credit_card'
ALTER TABLE credit_card
ADD fecha_actual DATE;

DESCRIBE credit_card;

--- Paso 9: en la tabla ‘credit_card’ cambiar los tipos de las variables: id VARCHAR(20), cvv INT y expiring_date VARCHAR(20)
--- verificar la tabla 'credit_card'
DESCRIBE credit_card;
--- realizar el cambio de tipo de dato en las variables solicitadas (id, cvv y expiring_date) y luego verificar los cambios en la tabla.
ALTER TABLE credit_card
	MODIFY id VARCHAR(20),
	MODIFY cvv INT,
	MODIFY expiring_date VARCHAR(20);

DESCRIBE credit_card;

--- Paso 10: en la tabla ‘transaction’ cambiar el tipo de dato de ‘credit_card_id’ VARCHAR(15) por VARCHAR(20).
--- verificar la tabla 'transaction'
DESCRIBE transaction;
--- realizar el cambio solicitado del tipo de dato de ‘credit_card_id’ y luego verificar tabla 'transaction'
ALTER TABLE transaction
MODIFY credit_card_id VARCHAR(20);

DESCRIBE transaction;

--- EJERCICIO 2 --- La empresa también le pide crear una vista llamada "InformeTecnico" que contenga la siguiente información:
---                 ID de la transacción, Nombre del usuario/a, Apellido del usuario/a, IBAN de la tarjeta de crédito usada, Nombre de la compañía de la transacción realizada.
---                 Asegúrese de incluir información relevante de las tablas que conocerá y utilice alias para cambiar de nombre columnas según sea necesario.
---                 Muestra los resultados de la vista, ordena los resultados de forma descendente en función de la variable ID de transacción.

CREATE VIEW InformeTecnico (id_transaccion, nombre_usuario, apellido_usuario, iban_tarj_cred, nombre_empresa, importe_transaccion, fecha_transaccion, hora_transaccion, 
lat_transaccion, longitud_transaccion, transaccion_declinada, fecha_exp_tarj_cred, pais_usuario, pais_empresa) AS
SELECT t.id, d.name, d.surname, e.iban, c.company_name, t.amount, DATE(t.timestamp), TIME(t.timestamp), t.lat, t.longitude, t.declined, e.expiring_date, d.country, c.country
FROM transaction t
JOIN company c ON c.id = t.company_id
JOIN data_user d ON d.id = t.user_id
JOIN credit_card e ON e.id = t.credit_card_id
ORDER BY t.id DESC;

SELECT * FROM InformeTecnico;
