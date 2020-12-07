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