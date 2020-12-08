#4. Для страны, в которой живет наибольшее число покупателей, сформировать полигон, 
#   являющийся минимальным ограничивающим прямоугольником координат места жительства покупателей из этой страны.

use sakila;


 # возвращает индекс  страны  с наибольшим числом покупателей 
 drop function if exists country_with_max_customer;

delimiter $$
create function country_with_max_customer()
returns int
DETERMINISTIC 
begin 
	declare ret int default 0;
    select country.country_id into ret from customer cr 
	inner join address a on cr.address_id=a.address_id
	inner join city on city.city_id=a.address_id
	inner join country on country.country_id=city.country_id
	group by country.country_id
	order by count(country.country_id) DESC
	limit 1 ;
    return ret;
end$$
delimiter ;

# Процедура формирует полигон, 
# являющийся минимальным ограничивающим прямоугольником координат места жительства покупателей из этой страны.

drop procedure if exists region;

delimiter //
CREATE PROCEDURE region( OUT _region GEOMETRY)
BEGIN
  DECLARE done INT DEFAULT TRUE;
  DECLARE _point POINT;
  DECLARE tmp GEOMETRY;
  
  DECLARE cur CURSOR FOR (SELECT a.location  FROM address a
							 INNER JOIN city ci ON ci.city_id=a.city_id
							 INNER JOIN country c ON c.country_id=ci.country_id
							 WHERE c.country_id=country_with_max_customer() and valid_location(a.location) is not null);
                             
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = FALSE;
  OPEN cur;
  
  SELECT a.location INTO tmp FROM address a
					     INNER JOIN city ci ON ci.city_id=a.city_id
                         INNER JOIN country c ON c.country_id=ci.country_id
						 WHERE c.country_id=country_with_max_customer() and valid_location(a.location) is not null
                         LIMIT 1;
                         
  WHILE done DO
    FETCH cur INTO _point;
    IF valid_location(_point) is not null THEN
      SET tmp=ST_Union(tmp,_point);
    END IF;
  END WHILE;
  CLOSE cur;
  SET _region=ST_Envelope(tmp);
END//
delimiter ;

CALL region( @region);
select ST_AsText(@region);


