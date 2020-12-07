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
where valid_location(a.location) is null ;

select ST_Y(ST_GeomFromText(valid_location(a.location)))as Y , ST_X(ST_GeomFromText(valid_location(a.location))) as X from address a
where valid_location(a.location) is not null ;

