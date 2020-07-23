--
-- PostgreSQL database dump
--

-- Dumped from database version 11.2
-- Dumped by pg_dump version 11.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: cds; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA cds;


ALTER SCHEMA cds OWNER TO postgres;

--
-- Name: ctind; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ctind;


ALTER SCHEMA ctind OWNER TO postgres;

--
-- Name: jhu; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA jhu;


ALTER SCHEMA jhu OWNER TO postgres;

--
-- Name: plv8; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plv8 WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plv8; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plv8 IS 'PL/JavaScript (v8) trusted procedural language';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: cfr_record; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.cfr_record AS (
	date text,
	cases integer,
	resolve_date text,
	prior_deaths integer,
	deaths integer,
	prior_resolutions integer,
	resolutions integer,
	days_to_resolve integer,
	i_cfr text
);


ALTER TYPE public.cfr_record OWNER TO postgres;

--
-- Name: load_next_day(); Type: FUNCTION; Schema: jhu; Owner: postgres
--

CREATE FUNCTION jhu.load_next_day() RETURNS jsonb
    LANGUAGE plv8
    AS $_$

  var path_prefix = '/home/kavi/cdata'
  var base_date = '2020-01-22'

  var column_sets = {
    A : 'state,country,update_date,cases,deaths,recovered' ,
    B : 'state,country,update_date,cases,deaths,recovered,lat,long' , 
    C : 'fips,county,state,country,update_date,lat,long,cases,deaths,recovered,active,combined_key',
    D : 'fips,county,state,country,update_date,lat,long,cases,deaths,recovered,active,combined_key, ir, cfr',
  }

  var columns = [
  
    [Date.parse('2020-01-22'), Date.parse('2020-02-29'), column_sets.A],
    [Date.parse('2020-03-01'), Date.parse('2020-03-21'), column_sets.B],
    [Date.parse('2020-03-22'), Date.parse('2020-05-28'), column_sets.C],
    [Date.parse('2020-05-29'), Date.parse('9999-01-01'), column_sets.D]

  ]

  var result = {}

  var next_date = base_date
  var cmd = 'select to_char((coalesce ( max(distinct(date)), ($1::timestamp - \'1 day\'::interval)) + \'1 day\'::interval )::date, \'MM-DD-YYYY\') as date from jhu.timeseries'
  plv8.elog (NOTICE, cmd)
  var next_date_rec = plv8.execute (cmd, [base_date])
  if (next_date_rec.length > 0){
    next_date = next_date_rec[0].date
    result.next_date  = next_date 
  }
  
  var filename = path_prefix + '/jhu/data/' + next_date + '.csv'
  var copy_cmd
  columns.forEach( function(colspec) {
    var dtokens = next_date.split('-')
    var dt = Date.parse([dtokens[2], dtokens[0], dtokens[1]].join('-'))
    plv8.elog (NOTICE, 'begin, dt, end : ', colspec[0], dt, colspec[1])
    if (dt >= colspec[0] && dt <= colspec[1]) {
      plv8.elog(NOTICE, 'next_date, columns: ', next_date, colspec[2])
      copy_cmd = 'copy jhu.timeseries ( ' + colspec[2]  + '  ) from \'' + filename + '\'  csv header;'
    }
  })
  
  if (copy_cmd != null) {
    plv8.elog(NOTICE, copy_cmd)
    var ret = plv8.execute (copy_cmd);
    var uret = plv8.execute ('update jhu.timeseries set date = $1 where date is null', [next_date])
    result.inserts = ret
    result.updates = uret
    result.message = 'OK'
  }
  else {
    result.message = 'ERROR colspec not found for next_date' 
  }

  return result; 

$_$;


ALTER FUNCTION jhu.load_next_day() OWNER TO postgres;

--
-- Name: cfr_analysis(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.cfr_analysis(country text) RETURNS SETOF public.cfr_record
    LANGUAGE plv8
    AS $_$

  var result = 'Covid19 cfr analysis for: ' + country + '\n'

  var cmd = [
  'with base_cte as (' ,
    ' select distinct on (update_date, date::date, country, state, county) date::date as date, country, state, county, cases, deaths, recovered, active from jhu.timeseries where date > now() - \'90 days\'::interval order by update_date desc, date::date, country, state, county' ,
  ' ),' ,
  ' sum_cte as (' ,
    ' select date::text, sum(cases) as cases, sum(deaths) as deaths, sum (deaths + recovered) as resolutions  from base_cte where  country = $1 and state_check(country, state, date::date::text) group by date' ,
  ' ),' ,
  ' lag_cte as (' ,
    ' select A.date, min(A.cases) as cases, min(B.date) as resolve_date, max(A.deaths) as prior_deaths, min(B.deaths) as deaths, max(A.resolutions) as prior_resolutions,  min(B.resolutions) as resolutions, min(B.date::date - A.date::date) as days_to_resolve from sum_cte as A, sum_cte as B where B.date >= A.date and B.resolutions >= A.cases group by A.date' ,
  ' )' ,
  ' select * , case when resolutions - prior_resolutions > 0 ' ,
    ' then' ,
      ' to_char(( (deaths - prior_deaths)/(resolutions - prior_resolutions) )*100, \'FM99.99%\')' ,
    ' else' ,
      ' \'-\'' ,
    ' end as i_cfr' ,
  ' from  lag_cte order by date;'
  ].join (' ')

  plv8.elog(NOTICE, country, cmd)
  var ret = plv8.execute (cmd, [country])
  plv8.elog(NOTICE, JSON.stringify(ret[0]))
  return ret

$_$;


ALTER FUNCTION public.cfr_analysis(country text) OWNER TO postgres;

--
-- Name: country_agg(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.country_agg(params jsonb) RETURNS jsonb
    LANGUAGE plv8
    AS $_$

  var clist = params.countries
  var col = params.col // cases, deaths, recovered
  var op = params.op // sum, dgr, agr5

  var source = params.source

  var result = {col : col, data : {}}
  result.name = ['country_agg', col, op].join('.')  
  cnames = []
  clist.forEach( function (x) {
    cnames.push.apply(cnames, plv8.find_function('get_country_config')(x).name)
  })
  result.title = 'Covid19 country data for: ' + cnames.join(', ')

  var baseCmd = ()=> 'select distinct on (update_date, date::date, country, state, county) date::date as date, country, state, county, cases, deaths, recovered, active from ' + source + '.timeseries order by update_date desc, date::date, country, state, county'
  var sumCmd =(country, col)=> 'select date::text, sum(' + col + ') as sum  from base_cte where  country = any($1) and state_check($1[1], state, date::date::text)  group by date order by date asc'

  var laggedCmd = (country, col)=>'select date::text,  lag (sum(' + col + '),1) over ()  as lagged_val, sum(' + col + ') as current_val  from base_cte where  country = any($1) and state_check($1[1], state, date::date::text)  group by date order by date asc'
  var dgrCmd = ()=>'select date, case when lagged_val > 0 then ((current_val - lagged_val)/lagged_val)*100 else 0 end as dgr from lagged_cte'
  var agr5Cmd = ()=>'select  date, ( dgr + lag(dgr,1) over () + lag(dgr,2) over() + lag(dgr,3) over() + lag(dgr,4) over() ) / 5 as agr5 from dgr_cte'

  var cmdTable = {
    sum : {},
    dgr : {},
    agr5 : {}
  }
  cmdTable.sum['cases'] = (country)=>'with base_cte as (' + baseCmd() + ') ' + sumCmd(country, 'cases')
  cmdTable.sum['deaths'] = (country)=>'with base_cte as (' + baseCmd() + ') ' + sumCmd(country, 'deaths')
  cmdTable.sum['recovered'] = (country)=>'with base_cte as (' + baseCmd() + ') ' + sumCmd(country, 'recovered')
  cmdTable.dgr['cases'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'cases') + '), dgr_cte as ( ' + dgrCmd() + ' ) select date, to_char(dgr, \'99D99 %\') as dgr from dgr_cte'
  cmdTable.dgr['deaths'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'deaths') + ') , dgr_cte as ( ' + dgrCmd() + ' ) select date, to_char(dgr, \'99D99 %\') as dgr from dgr_cte'
  cmdTable.agr5['cases'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'cases') + '), dgr_cte as ( ' + dgrCmd() + '), agr5_cte as ( ' + agr5Cmd() + ' ) select date, to_char(agr5, \'99D99 %\') as agr5 from agr5_cte'
  cmdTable.agr5['deaths'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'deaths') + '), dgr_cte as ( ' + dgrCmd() + '),  agr5_cte as ( ' + agr5Cmd() + ' ) select date, to_char(agr5, \'99D99 %\') as agr5 from agr5_cte'



  if (clist instanceof Array) {
    clist.forEach ( function (country, idx) {
      var crec = plv8.find_function('get_country_config')(country)
      cmd = cmdTable[op][col](crec)
      plv8.elog(NOTICE, crec.name, cmd)
      result.data[crec.name[0]] = plv8.execute (cmd, [crec.name])
    })
  }
  return result; 

$_$;


ALTER FUNCTION public.country_agg(params jsonb) OWNER TO postgres;

--
-- Name: country_state_agg(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.country_state_agg(params jsonb) RETURNS jsonb
    LANGUAGE plv8
    AS $_$

  var country = params.country
  var states = params.states
  var col = params.col // cases, deaths, recovered
  var op = params.op // sum, dgr, agr5
  var source = params.source

  var result = {col : col, data : {}}
  result.name = ['country_state_agg', country, col, op].join('.')
  result.title = 'Covid19 statewise data for: ' + country

  var statesListClause = ''
  if (params.states != null) {
    statesListClause = ' and state = any(\'{' + params.states.join(', ') + '}\') '
  }

  var statesCmd, statesArgs, cmd

  if (source == 'jhu') { 
    statesCmd = 'select distinct state from ' + source + '.timeseries where country = $1 and state != $1 and state is not null ' + statesListClause + ' and date > $2::date'
    statesArgs = [country, '2020-03-10']
  }
  else {
    statesCmd = 'select distinct state from ' + source + '.timeseries where country = $1 and state is not null ' + statesListClause + ' and date > $2::date'
    statesArgs = [country, '2020-01-20']
  }


/* begin */

  var baseCmd = ()=> 'select distinct on (update_date, date::date, country, state, county) date::date as date, country, state, county, cases, deaths, recovered, active from ' + source + '.timeseries order by update_date desc, date::date, country, state, county'
  var sumCmd = (country, col) => 'select date::text, sum(' + col + ') as  sum  from base_cte where  country = $1 and state = $2  group by date order by date asc'
  var laggedCmd = (country, col)=>'select date::text,  lag (sum(' + col + '),1) over ()  as lagged_val, sum(' + col + ') as current_val  from base_cte where  country = $1 and state = $2  group by date order by date asc'
  var dgrCmd = ()=>'select date, case when lagged_val > 0 then ((current_val - lagged_val)/lagged_val)*100 else 0 end as dgr from lagged_cte'
  var agr5Cmd = ()=>'select  date, ( dgr + lag(dgr,1) over () + lag(dgr,2) over() + lag(dgr,3) over() + lag(dgr,4) over() ) / 5 as agr5 from dgr_cte'

  var cmdTable = {
    sum : {},
    dgr : {},
    agr5 : {}
  }
  cmdTable.sum['cases'] = (country)=>'with base_cte as (' + baseCmd() + ') ' + sumCmd(country, 'cases')
  cmdTable.sum['deaths'] = (country)=>'with base_cte as (' + baseCmd() + ') ' + sumCmd(country, 'deaths')
  cmdTable.sum['recovered'] = (country)=>'with base_cte as (' + baseCmd() + ') ' + sumCmd(country, 'recovered')
  cmdTable.dgr['cases'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'cases') + '), dgr_cte as ( ' + dgrCmd() + ' ) select date, to_char(dgr, \'99D99 %\') as dgr from dgr_cte'
  cmdTable.dgr['deaths'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'deaths') + ') , dgr_cte as ( ' + dgrCmd() + ' ) select date, to_char(dgr, \'99D99 %\') as dgr from dgr_cte'
  cmdTable.agr5['cases'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'cases') + '), dgr_cte as ( ' + dgrCmd() + '), agr5_cte as ( ' + agr5Cmd() + ' ) select date, to_char(agr5, \'99D99 %\') as agr5 from agr5_cte'
  cmdTable.agr5['deaths'] = (country)=>'with base_cte as (' + baseCmd() + '), lagged_cte as ( ' + laggedCmd(country, 'deaths') + '), dgr_cte as ( ' + dgrCmd() + '),  agr5_cte as ( ' + agr5Cmd() + ' ) select date, to_char(agr5, \'99D99 %\') as agr5 from agr5_cte'


/* end */


/*
  cmd = 'with x as ( select distinct on (update_date, date::date, country, state, county) date::date as date, country, state, county, cases, deaths, recovered, active from ' + source + '.timeseries order by update_date desc, date::date, country, state, county ) select date::text, sum(' + col + ') as  sum  from x where  country = $1 and state = $2  group by date order by date asc'
*/

  if (country != null) {
    var states = plv8.execute (statesCmd, statesArgs)
    if (states.length > 0) { 
      states.forEach( function(stateRec) {
/*
        result.data[stateRec.state] = plv8.execute(cmd, [country, stateRec.state])
*/
        cmd = cmdTable[op][col](country)
        plv8.elog(NOTICE, country, cmd)
        result.data[stateRec.state] = plv8.execute (cmd, [country, stateRec.state])

      })
    }
  }
  return result; 

$_$;


ALTER FUNCTION public.country_state_agg(params jsonb) OWNER TO postgres;

--
-- Name: country_state_county_agg(jsonb); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.country_state_county_agg(params jsonb) RETURNS jsonb
    LANGUAGE plv8
    AS $_$

  var country = params.country
  var state = params.state
  var col = params.col // cases, deaths, recovered
  var op = params.op // sum, dgr, agr5
  var source = params.source
  var counties = params.counties;

  var result = {col : col, data : {}}
  result.name = ['country_state_county_agg', country, state, col, op].join('.')
  result.title = 'Covid19 state/county wise data for: ' + country +  '/' + state

  var keyCmd, keyArgs, cmd, cmdArgs

  if (source == 'jhu') { 
    keyCmd = 'select state, county from ' + source + '.timeseries where country = $1 and state = $2 and county is not null and country is not null and date > $3::date group by state, county'
    keyArgs = [country, state, '2020-03-10']
  }
  else {
    keyCmd = 'select state, county from ' + source + '.timeseries where country = $1 and state = $2 and county is not null and country is not null and date > $3::date group by state, county'
    keyArgs = [country, state, '2020-01-20']
  }

  cmd = 'with x as ( select distinct on (update_date, date::date, country, state, county) date::date as date, country, state, county, cases, deaths, recovered, active from ' + source + '.timeseries order by update_date desc, date::date, country, state, county ) select date::text, sum(' + col + ') as  sum  from x where  country = $1 and state = $2  and county = $3 group by date order by date asc'

  if (country != null) {
    plv8.elog (NOTICE, 'keyCmd: ', keyCmd, keyArgs)
    var keys = plv8.execute (keyCmd, keyArgs)

    plv8.elog ( NOTICE, 'scagg with ', keys.length, ' keys ', keys )
    if (keys.length > 0) { 
      keys.forEach( function(keyRec) {        
        plv8.elog ( NOTICE, 'scagg with key: ' , keyRec )
        result.data[keyRec.state + '/' + keyRec.county] = plv8.execute(cmd, [country, keyRec.state, keyRec.county])
      })
    }
  }
  return result; 

$_$;


ALTER FUNCTION public.country_state_county_agg(params jsonb) OWNER TO postgres;

--
-- Name: get_country_config(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_country_config(country text) RETURNS jsonb
    LANGUAGE plv8
    AS $$
  var countryListJhu =  {
    India : {
      name : ['India'], 
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-06-09') ? state == null : state != null
    },
    US: {
      name : ['US'], 
      stateCheck :(state, date) =>  state != null
    },
    Germany : {
      name : ['Germany'], 
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-05-14') ? state == null : state != null
    },

    Italy : {
      name : ['Italy'], 
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-05-14') ? state == null : state != null
    },
    Iran : {
      name : ['Iran'], 
      stateCheck : (state, date) => state == null
    },
    Spain : {
      name : ['Spain'], 
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-05-14') ? state == null : state != null
    },
    'United Kingdom' : {
      name : ['United Kingdom', 'UK'], 
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-06-10') ? state == null : state != null
    },
    France : {
      name : ['France'], 
      stateCheck : (state, date) => state == null
    },
    'Korea, South' : {
      name : ['Korea, South'], 
      stateCheck : (state, date) => state == null
    },
    China : {
      name : ['China'],
      stateCheck : (state, date) =>   state != null
    },
    Indonesia: {
      name : ['Indonesia'],
      stateCheck : (state, date) => state == null
    },
    Turkey: {
      name : ['Turkey'],
      stateCheck : (state, date) => state == null
    },
    Sweden: {
      name : ['Sweden'],
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-06-05') ? state == null : state != null
    },
    'New Zealand': {
      name : ['New Zealand'],
      stateCheck : (state, date) => state == null
    },
    Australia: {
      name : ['Australia'],
      stateCheck : (state, date) =>   state != null
    },
    Mexico: {
      name : ['Mexico'],
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-05-20') ? state == null : state != null
    },
    Russia: {
      name : ['Russia'],
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-05-31') ? state == null : state != null
    },
    Brazil: {
      name : ['Brazil'],
      stateCheck : (state, date) => Date.parse(date) < Date.parse('2020-05-20') ? state == null : state != null
    }


  }

  var result = countryListJhu[country]

  if (result == null) {
    throw ('could not find stateclause for country : ' + country);
  }

  return result

$$;


ALTER FUNCTION public.get_country_config(country text) OWNER TO postgres;

--
-- Name: row2csv(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.row2csv(robj json) RETURNS text
    LANGUAGE plv8
    AS $$

  var result = ''
  Object.keys(robj).forEach( function(x, idx, arr) { 
    result += x
    if (idx < arr.length -1 ) {
      result += ', '
    }
  })
  return result

$$;


ALTER FUNCTION public.row2csv(robj json) OWNER TO postgres;

--
-- Name: row2csvheader(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.row2csvheader(robj json) RETURNS text
    LANGUAGE plv8
    AS $$

  var result = ''
  Object.keys(robj).forEach( function(x, idx, arr) { 
    result += x
    if (idx < arr.length -1 ) {
      result += ', '
    }
  })
  return result

$$;


ALTER FUNCTION public.row2csvheader(robj json) OWNER TO postgres;

--
-- Name: row2csvline(json); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.row2csvline(robj json) RETURNS text
    LANGUAGE plv8
    AS $$

  var result = ''
  Object.keys(robj).forEach( function(x, idx, arr) { 
    result += robj[x]
    if (idx < arr.length -1 ) {
      result += ', '
    }
  })
  return result

$$;


ALTER FUNCTION public.row2csvline(robj json) OWNER TO postgres;

--
-- Name: state_agg_clause(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.state_agg_clause(country text) RETURNS text
    LANGUAGE plv8
    AS $$
  var countryListJhu =  [
    { name : ['India'], 
      stateClause : 'state is null'
    },
    { name : ['US'], 
      stateClause : 'state is not null'
    },
    { name : ['Italy'], 
      stateClause : 'state is null'
    },
    { name : ['Iran'], 
      stateClause : 'state is null'
    },
    { name : ['Spain'], 
      stateClause : 'state is null'
    },
    { name : ['United Kingdom', 'UK'], 
      stateClause : 'state is null'
    },
    { name : ['France'], 
      stateClause : 'state is null'
    },
    { name : ['Korea, South'], 
      stateClause : 'state is null'
    },
    { name : ['China'],
      stateClause : 'state is not null'
    },
    { name : ['Indonesia'],
      stateClause : 'state is null'
    },
    { name : ['Turkey'],
      stateClause : 'state is null'
    },
    { name : ['Sweden'],
      stateClause : 'state is null'
    },
    { name : ['New Zealand'],
      stateClause : 'state is null'
    },
    { name : ['Australia'],
      stateClause : 'state is not null'
    },
    { name : ['Mexico'],
      stateClause : 'state is null'
    }
  ]

  var result = ''
  countryListJhu.forEach( function(c) {
    if (c.name.indexOf(country) >= 0) {
      result = c.stateClause
    }
  })

  if (result == null) {
    throw ('could not find stateclause for country : ' + country);
  }

  return result

$$;


ALTER FUNCTION public.state_agg_clause(country text) OWNER TO postgres;

--
-- Name: state_check(text, text, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.state_check(country text, state text, date text) RETURNS boolean
    LANGUAGE plv8
    AS $$
  return plv8.find_function('get_country_config')(country).stateCheck(state, date)

$$;


ALTER FUNCTION public.state_check(country text, state text, date text) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: timeseries; Type: TABLE; Schema: cds; Owner: postgres
--

CREATE TABLE cds.timeseries (
    name text,
    level text,
    city text,
    county text,
    state text,
    country text,
    population double precision,
    lat double precision,
    long double precision,
    url text,
    aggregate text,
    tz text,
    cases double precision,
    deaths double precision,
    recovered double precision,
    active double precision,
    tested double precision,
    hospitalized double precision,
    discharged double precision,
    icu double precision,
    growthfactor double precision,
    update_date timestamp without time zone,
    date timestamp without time zone
);


ALTER TABLE cds.timeseries OWNER TO postgres;

--
-- Name: timeseries; Type: TABLE; Schema: ctind; Owner: postgres
--

CREATE TABLE ctind.timeseries (
    county text,
    state text,
    country text,
    update_date timestamp without time zone,
    lat double precision,
    long double precision,
    cases double precision,
    deaths double precision,
    recovered double precision,
    active double precision,
    date timestamp without time zone
);


ALTER TABLE ctind.timeseries OWNER TO postgres;

--
-- Name: timeseries; Type: TABLE; Schema: jhu; Owner: postgres
--

CREATE TABLE jhu.timeseries (
    fips text,
    county text,
    state text,
    country text,
    date timestamp without time zone,
    lat double precision,
    long double precision,
    cases double precision,
    deaths double precision,
    recovered double precision,
    active double precision,
    combined_key text,
    incident_rate double precision,
    tested double precision,
    hospitalized double precision,
    uid text,
    iso3 text,
    update_date timestamp without time zone,
    ir double precision,
    cfr double precision
);


ALTER TABLE jhu.timeseries OWNER TO postgres;

--
-- Name: jhu_timeseries_date_idx; Type: INDEX; Schema: jhu; Owner: postgres
--

CREATE INDEX jhu_timeseries_date_idx ON jhu.timeseries USING btree (date);


--
-- PostgreSQL database dump complete
--

