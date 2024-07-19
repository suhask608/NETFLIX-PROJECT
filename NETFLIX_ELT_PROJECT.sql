use master;

select * from netflix_raw --title:??? ??? but it should be in korean language(korean characters) to get the same value we use nvarchar data type instead on varchar.
where show_id='s5023'
order by title;

/*-- creating a table by changing the datatype from varchar to nvarchar, converting max to some range of value. */
create table [dbo].[netflix_raw]
(
[show_id] [varchar](20) primary key,
[type] [varchar](20) null,
[title] [nvarchar](300) null,
[director] [varchar](300) null,
[cast] [varchar](1000) null,
[country] [varchar](200) null,
[date_added] [varchar](20) null,
[release_year] [int] null,
[rating] [varchar](10) null,
[duration] [varchar](10) null,
[listed_in] [varchar](200) null,
[description] [varchar](500) null
);
drop table netflix_raw;

--Cleaning the data:
--1)Checking for duplicates: It doesn't contains duplicates so making this column has "primary key".
select [show_id], count(*) as cnt
from netflix_raw
group by [show_id]
having count(*)>1;

--Checking duplicates for type,title columns: we found 5 pairs of duplicates.
select * from netflix_raw
where concat(title, type) IN 
(
select concat(title, type)
from netflix_raw
group by title, type
having count(*)>1
)
order by title;

/*
select title, type, count(*) as cnt
from netflix_raw
group by title, type
having count(*)>1 
*/
-- Handling duplicates lets check the count of rows: earlier total rows=8807
with cte as
(
select *,
row_number() over(partition by title, type order by show_id) as rn
from netflix_raw
)
select * from cte
where rn=1;
-- A: 8802 rows after neglecting duplicates. 

--Splitting the director, country, cast which are in (,) comma separated & adding it into a new table.
select show_id, trim(value) as Director
into netflix_directors
from netflix_raw
cross apply string_split(director,',')

select * from netflix_directors; -- total rows: 6978

--Creating the same as above for country, cast, listed_in (which is genre)
select show_id, trim(value) as country --trim is using to trim the extra white spaces
into netflix_country -- Sorted values added into new table.
from netflix_raw
cross apply string_split(country,',')

select * from netflix_country; -- total rows: 10019

select show_id, trim(value) as cast --trim is using to trim the extra white spaces
into netflix_cast -- Sorted values added into new table.
from netflix_raw
cross apply string_split(cast,',')

select * from netflix_cast -- total rows: 64126

select show_id, trim(value) as genre --trim is using to trim the extra white spaces
into netflix_genre -- Sorted values added into new table.
from netflix_raw
cross apply string_split(listed_in,',')

select * from netflix_genre -- total rows: 19323 

--populating null values in country & director columns using it's separe respective tables.
select n.show_id, m.country, n.country 
from netflix_raw n inner join
(
select d.director, c.country from netflix_directors d --6650 rows
inner join netflix_country c
on d.show_id=c.show_id
group by d.director, c.country
) m
on n.director=m.director 
where n.country is null; -- overall query result: 194 rows

--checking null values on duration.
select * from netflix_raw where duration is null; --here in duration it is mentioned as null & in rating it is mentioned the values of duration like eg: 74, 84 min etc.

------------Data Cleaning----------------
--To fix that by making to fill rating values into duration were ever it is null.
--Converting datatype of date_added column from varchar to date
with cte as
(
select *,
row_number() over(partition by type, title order by show_id) as rn
from netflix_raw
)
select show_id, type, title, cast(date_added as date) as date_added, release_year, rating,
case when duration is null then rating else duration end as duration, description
into netflix_cleaned
from cte
where rn=1;

--extracting cleaned netfix data 
select * from netflix_cleaned; --8802 rows

--Netflix Data Analysis:
--1. for each director count the no of movies and tv shows created by them in separate columns for directors who created tv shows & movies both.
select d.director, --83 rows
count(distinct case when c.type='Movie' then 1 else 0 end) as Movie_cnt,
count(distinct case when c.type='TV Show' then 1 else 0 end) as TVShow_cnt
from netflix_directors d
inner join netflix_cleaned c
on d.show_id=c.show_id
group by d.director
having count(distinct c.type)>1;

--2.Which country has highest number of comedy movies.
select TOP 1 co.country, count(distinct g.show_id) as movie_cnt 
from netflix_country co inner join netflix_genre g
on co.show_id=g.show_id
inner join netflix_cleaned cl
on co.show_id=cl.show_id
where g.genre='Comedies'
group by co.country
order by movie_cnt desc

--3.On each year (as per date added to netflix), which director has maximum  number of movies released.
with cte as
(
select year(date_added) as Year, d.director, 
count(distinct c.show_id) as movie_cnt
from netflix_directors d
inner join netflix_cleaned c
on d.show_id=c.show_id
group by year(date_added), d.director
)
,cte2 as
(
select *,
row_number() over(partition by Year order by movie_cnt desc, director) as rk
from cte
)
select * from cte2
where rk=1;

--4. What is the average duration of movies in each genre.
select  g.genre, avg(cast(replace(duration,' min','') as int)) as avg_duration 
from netflix_cleaned c inner join netflix_genre g
on c.show_id = g.show_id
where type='Movie'
group by g.genre
order by avg_duration desc;

--5. Find the list of directors who have create horror and comedy movies both.
select d.director, 
count(distinct case when g.genre='Comedies' then cl.show_id end) as  comedy_movies, 
count(distinct case when g.genre='Horror Movies' then cl.show_id end) as Horror_movies
from netflix_directors d inner join netflix_cleaned cl
on d.show_id=cl.show_id
inner join netflix_genre g
on cl.show_id=g.show_id
where cl.type='Movie' and g.genre IN ('Comedies','Horror Movies')
group by d.director
having count(distinct g.genre)=2;

