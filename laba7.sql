#1 Написать функцию проверки валидности данных: значения долготы должны находиться в диапазоне (-180, 180], 
#   значения широты должны находиться в диапазоне [-90, 90]. Координаты (0, 0) также считать невалидными
#   В следующих запросах учитывать только адреса с валидной геометрией.
use sakila;

drop function if exists valid_location;

delimiter $$
create function valid_location(location POINT)
returns varchar(50)
DETERMINISTIC 
begin 
	declare loc varchar(50) default null;
    if ST_X(location) between -180 and 180 and ST_Y(location) between -90 and 90 and  ST_Y(location)!=0  and ST_X(location)!=0 then 
		SELECT  ST_AsText(location) into loc;
		return loc;
   end if; 
   return loc;
end$$
delimiter ;


select ST_AsText(a.location) from address a
where valid_location(a.location) is not null ;

select ST_AsText(a.location) from address a
where valid_location(a.location) is not null ;

select ST_Y(ST_GeomFromText(valid_location(a.location)))as Y , ST_X(ST_GeomFromText(valid_location(a.location))) as X from address a
where valid_location(a.location) is not null ;


#2. Найти всех покупателей, проживающих внутри заданного полигона 
#(например, "POLYGON ((-60 -40,-57.9 -37.3,-57.9 -34.3,-59.1 -34.3,-60 -40))").
use sakila;

drop procedure if exists area ;

delimiter $$
create procedure area(pol POLYGON)
begin
	select c.first_name, c.last_name , ST_AsText(a.location) as coordinates  from address a
    inner join customer c on c.address_id=a.address_id
    where ST_Contains(pol,a.location)=1 and valid_location(a.location)is not null;
end$$
delimiter ;

call area( ST_PolygonFromText('POLYGON ((-10 -10,-10 10,10 10,10 -10,-10 -10))'));

call area( ST_PolygonFromText('POLYGON ((-60 -40,-57.9 -37.3,-57.9 -34.3,-59.1 -34.3,-60 -40))')  );



#3. Для первого покупателя из указанной страны определить количество покупателей, 
#   проживающих на заданном расстоянии (в градусах), используя функцию ST_Buffer.	
 	
use sakila;

drop procedure if exists neighbors ;

delimiter $$
create procedure neighbors(in arg_country int , in rad int)
begin
	select count(*)  from address a
	where (st_contains(ST_Buffer((select a.location from customer cr
	inner join address a on cr.address_id=a.address_id
	inner join city on city.city_id=a.address_id
	inner join country on country.country_id=city.country_id
	where country.country_id=arg_country and valid_location(a.location) is not null
	limit 1) , rad) , a.location))=1;
end$$
delimiter ;

call neighbors(80,15);


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


#5. Определить пространственные соотношения полигонов, полученных в заданиях №3 и №4.
use sakila;

drop function if exists area_relation;

delimiter //
CREATE FUNCTION area_relation(from_3 GEOMETRY, from_4 GEOMETRY )
RETURNS VARCHAR(200) DETERMINISTIC
BEGIN
    DECLARE res VARCHAR(200);
    IF ST_Contains(from_3, from_4)THEN 
		SET res='region 3 contain region 4, ';
    END IF;
    IF ST_Contains(from_4, from_3)THEN
		SET res='region 4 contain region 3, ';
    END IF;
    IF NOT ST_Contains(from_4, from_3) AND NOT ST_Contains(from_3, from_4)THEN 
		SET res='regions don\'t include in each other, ';
    END IF;
    IF ST_Crosses(from_4, from_3) THEN
		SET res=concat(res,'region 4 crosses region 3, ');
    ELSEIF ST_Crosses(from_3, from_4) THEN 
		SET res=concat(res,'region 3 crosses region 4, ');
    ELSE 
		SET res=concat(res,'not crosses, ');
    END IF;
    IF ST_Touches(from_4, from_3) THEN 
		SET res=concat(res,'not touches, ');
    ELSE
		SET res=concat(res,'touches, ');
    END IF;
    IF ST_Disjoint(from_4, from_3)THEN
		SET res=concat(res,'disjoint!');
    ELSE
		SET res=concat(res,'not disjoint!');
    END IF;
    RETURN res;
END//
delimiter ;


use sakila;

select ST_Buffer((select a.location from customer cr
	inner join address a on cr.address_id=a.address_id
	inner join city on city.city_id=a.address_id
	inner join country on country.country_id=city.country_id
	where country.country_id=19 and valid_location(a.location) is not null
	limit 1) , 120 ) into @region_from_3;
    
    select ST_AsText(@region_from_3);
    
    CALL region(@region_from_4);

    select ST_AsText(@region_from_4);
    
    
    
SELECT area_relation(@region_from_3, @region_from_4);

#-------------------------------------JSON---------------------------------------------------------------------


#6. Создать новую таблицу или изменить существующую, добавив поле типа JSON и заполнить его данными. 
#Минимум одно из значений записи должно представлять из себя вложенную структуру, одно – массив.
# Каждая запись должна содержать не менее 5 ключей.
use football_league;

CREATE TABLE dogs 
(
  id_dog INT NOT NULL AUTO_INCREMENT,
  person_information JSON,
  common_information JSON,
CONSTRAINT id_dog PRIMARY KEY (id_dog)
);


INSERT INTO dogs  VALUES
(
    null,
    JSON_OBJECT("nickname" ,"black", "color" , JSON_ARRAY("black") , "Age" , 1 ),
	'{"breed":"great dane", "parents": {"mather": "great dane", "father": "great dane"} , "price":22250 , "available":true}'
);
INSERT INTO dogs  VALUES
(
    null,
    JSON_OBJECT("nickname" ,"baron", "color" , JSON_ARRAY("brown", "grey") , "Age" , 2 ),
	'{"breed":"Welsh terrier", "parents": {"mather": "Welsh terrier", "father": "Welsh terrier"} , "price":1150 , "available":false}'
);
INSERT INTO dogs  VALUES
(
    null,
    JSON_OBJECT("nickname" ,"chacha", "color" , JSON_ARRAY("brown","black") , "Age" ,1 ),
	'{"breed":"German Shepherd", "parents": {"mather": "German Shepherd", "father": "German Shepherd"} , "price":7000 , "available":true}'
);
INSERT INTO dogs  VALUES
(
    null,
    JSON_OBJECT("nickname" ,"Myxtar", "color" , JSON_ARRAY("black" , "brown", "grey") , "Age" , 2 ),
	'{"breed":"cur", "parents": {"mather": "cur", "father": "cur"} , "price":150 , "available":true}'
);


#7. Выполнить запрос, возвращающий содержимое данной таблицы, соответствующее некоторому условию, проверяющему значение атрибута вложенной 
#структуры.

SELECT * FROM dogs WHERE person_information->"$.color[0]"="brown" or person_information->"$.color[1]"="brown" or person_information->"$.color[2]"="brown";
SELECT * FROM dogs WHERE common_information->"$.parents.mather" = common_information->"$.parents.father";



#8. Выполнить запрос, добавляющие новую пару «ключ-значение» к заданной строке таблицы, причем «значение» является массивом.
SET SQL_SAFE_UPDATES = 0;

UPDATE dogs 
SET person_information= JSON_INSERT(person_information,'$.Awards' , JSON_ARRAY('A1','F2','AEA')) 
WHERE person_information->"$.nickname" = 'chacha';




#9. Выполнить запрос, изменяющий значение некоторого существующего ключа в заданной строке таблицы.

SET SQL_SAFE_UPDATES = 0;

UPDATE dogs
SET person_information = JSON_REPLACE(person_information, '$.nickname',"new_name") 
WHERE id_dog = 1;



#10. Выполнить запрос, осуществляющий удаление созданной пары «ключ-значение».
SET SQL_SAFE_UPDATES = 0;

UPDATE dogs
SET person_information=JSON_REMOVE(person_information, "$.Age")
WHERE id_dog=1;


