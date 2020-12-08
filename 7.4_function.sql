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
 


