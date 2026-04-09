Use `transactions`;

--- NIVEL 1 ---

--- EJERCICIO 2 --- Utilizando JOIN realizarás las siguientes consultas
--- EJERCICIO 2.1 --- Listado de los países que están generando ventas ---
SELECT DISTINCT c.country
FROM company c
INNER JOIN transaction t ON  c.id = t.company_id
WHERE t.declined = 0
ORDER BY c.country;

--- EJERCICIO 2.2 --- Desde cuántos países se generan las ventas ---
SELECT COUNT(DISTINCT c.country) AS cantidad_paises
FROM company c
INNER JOIN transaction t ON  c.id = t.company_id
WHERE t.declined = 0;

--- EJERCICIO 2.3 --- Identifica a la compañía con la mayor media de ventas
SELECT c.company_name, ROUND(AVG(t.amount),2) AS promedio_ventas
FROM company c
INNER JOIN transaction t ON  c.id = t.company_id
WHERE t.declined = 0
GROUP BY c.company_name
ORDER BY promedio_ventas DESC
LIMIT 1;


--- EJERCICIO 3 --- Utilizando sólo subconsultas (sin utilizar JOIN)
--- EJERCICIO 3.1 --- Muestra todas las transacciones realizadas por empresas de Alemania
SELECT *
FROM transaction t
WHERE EXISTS (SELECT c.id, c.country
    FROM company c
    WHERE c.id = t.company_id
    AND c.country = 'Germany')
AND t.declined = 0;

--- Otra solucion pero sin subconsulta ---
--- SELECT t.id AS codigo_transaccion, t.amount AS importe
--- FROM company c, transaction t
--- WHERE c.id = t.company_id 
--- AND c.country = 'Germany'
--- AND t.declined = 0;

--- EJERCICIO 3.2 --- Lista las empresas que han realizado transacciones por un amount superior a la media de todas las transacciones
SELECT DISTINCT(c.company_name)
FROM company c
WHERE EXISTS (SELECT t.id, t.company_id, t.amount
	FROM transaction t
	WHERE c.id = t.company_id
    AND t.declined = 0
    AND t.amount > (SELECT ROUND(AVG(t.amount),2) AS promedio_total
		FROM transaction t
		WHERE t.declined = 0)) 
ORDER BY c.company_name;

--- VERIFICACIONES PREVIAS ---
--- Transacciones superiores al promedio total de transacciones ---
--- SELECT id, company_id, amount
--- FROM transaction
--- WHERE amount > (SELECT ROUND(AVG(amount),2) AS promedio_total
--- 	FROM transaction
--- 	WHERE declined = 0)
--- AND declined = 0;
--- Promedio de total de transacciones ---
--- SELECT ROUND(AVG(amount),2) AS promedio_total
--- FROM transaction
--- WHERE declined = 0;

--- EJERCICIO 3.3 --- Eliminarán del sistema las empresas que carecen de transacciones registradas, entrega el listado de estas empresas
SELECT c.company_name
FROM company c
WHERE NOT EXISTS (SELECT DISTINCT(t.company_id)
	FROM transaction t);


--- NIVEL 2 ---

--- EJERCICIO 1 --- Identifica los cinco dias que se generó la mayor cantidad de ingresos en la empresa por ventas. 
--- 				Muestra la fecha de cada transacción junto con el total de las ventas.
SELECT DATE(t.timestamp) AS fecha, SUM(t.amount) AS ingreso
FROM transaction t
WHERE t.declined = 0
GROUP BY DATE(t.timestamp)
ORDER BY ingreso DESC
LIMIT 5;

--- EJERCICIO 2 --- ¿Cuál es la media de ventas por país? Presenta los resultados ordenados de mayor a menor media.
SELECT c.country, ROUND(AVG(t.amount),2) AS promedio_ventas
FROM company c
INNER JOIN transaction t ON  c.id = t.company_id
WHERE t.declined = 0
GROUP BY c.country
ORDER BY promedio_ventas DESC;

--- EJERCICIO 3 --- En tu empresa, se plantea un nuevo proyecto para lanzar algunas campanyas publicitarias para hacer competencia a la compañía “Non Institute”. 
---                 Para ello, te piden la lista de todas las transacciones realizadas por empresas que están ubicadas en el mismo país que esta compañía.
--- 3.a) Muestra el listado aplicando JOIN y subconsultas.
SELECT t.id AS codigo_transaccion, t.amount AS importe, c.company_name
FROM transaction t
INNER JOIN company c ON  c.id = t.company_id
WHERE t.declined = 0
AND c.country = (SELECT c.country
    FROM company c
    WHERE c.company_name = 'Non Institute');

--- 3.b) Muestra el listado aplicando solo subconsultas.
SELECT t.id AS codigo_transaccion, t.amount AS importe, t.company_id
FROM transaction t
WHERE EXISTS (SELECT c.id, c.country
	FROM company c
    WHERE c.id = t.company_id
    AND c.country = (SELECT c.country
		FROM company c
		WHERE c.company_name = 'Non Institute'))
AND t.declined = 0;

--- otra solucion sin subconculta --
--- SELECT t.id AS codigo_transaccion, t.amount AS importe, c.company_name
--- FROM transaction t, company c 
--- WHERE c.id = t.company_id
--- AND t.declined = 0
--- AND c.country = (SELECT country
---     FROM company
---     WHERE company_name = 'Non Institute');


--- NIVEL 3 ---
--- EJERCICIO 1 --- Presenta el nombre, teléfono, país, fecha y amount, de aquellas empresas que realizaron
---                 transacciones con un valor comprendido entre 350 y 400 euros y 
---                 en alguna de estas fechas: 29 de abril de 2015, 20 de julio de 2018 y 13 de marzo de 2024. 
---                 Ordena los resultados de mayor a menor cantidad.
SELECT c.company_name, c.phone, c.country, DATE(t.timestamp) AS fecha, t.amount
FROM transaction t
JOIN company c ON  c.id = t.company_id
WHERE t.amount BETWEEN 350 AND 400
AND t.declined = 0
AND DATE(t.timestamp) IN('2015-04-29', '2018-07-20', '2024-03-13')
ORDER BY t.amount DESC;


--- VERIFICACIONES PREVIAS ---
--- SELECT c.company_name, c.phone, c.country, t.amount
--- FROM company c
--- INNER JOIN transaction t ON  c.id = t.company_id 
--- WHERE t.amount BETWEEN 350 AND 400
--- AND t.declined = 0
--- ORDER BY t.amount DESC;

--- SELECT DATE(t.timestamp) AS fecha, t.amount, t.company_id
--- FROM transaction t
--- WHERE t.declined = 0
--- AND DATE(t.timestamp) IN('2015-04-29', '2018-07-20', '2024-03-13');


--- EJERCICIO 2 --- Necesitamos optimizar la asignación de los recursos y dependerá de la capacidad operativa que se requiera, 
---                 por lo que te piden la información sobre la cantidad de transacciones que realizan las empresas, 
---                 pero el departamento de recursos humanos es exigente y quiere un listado de las empresas en las que especifiques
---                 si tienen más de 400 transacciones o menos.
SELECT c.company_name, COUNT(t.id) AS cantidad_transacciones,
	CASE
		WHEN COUNT(t.id) < 400 THEN 'Menos de 400 tr'
        WHEN COUNT(t.id) = 400 THEN 'Tiene 400 tr'
        ELSE 'Mas de 400 tr'
	END AS comentario
FROM transaction t
JOIN company c ON  c.id = t.company_id
WHERE t.declined = 0
GROUP BY c.company_name
ORDER BY cantidad_transacciones;
