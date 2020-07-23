drop table jhu.timeseries cascade;


create table jhu.timeseries (


  date timestamp,
  fips text,
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
  combined_key text,
  ir float,
  cfr float
);
