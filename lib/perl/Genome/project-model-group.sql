--uuid
select *
from model_group g
--join genome_project p on p.name = g.name
where g.uuid is null;

--user name
select * from model_group where user_name is null;

