drop table ctind.timeseries cascade;


create table ctind.timeseries (


  county text,
  state text,
  country text,
  update_date timestamp,
  lat float,
  long float,
  cases float,
  deaths float,
  recovered float,
  active float,
  date timestamp
);
