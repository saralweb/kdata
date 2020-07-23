CREATE OR REPLACE FUNCTION get_country_config (country text) returns jsonb AS $$
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

$$ LANGUAGE plv8;


CREATE OR REPLACE FUNCTION state_check (country text, state text, date text) returns boolean AS $$
  return plv8.find_function('get_country_config')(country).stateCheck(state, date)

$$ LANGUAGE plv8;

CREATE OR REPLACE FUNCTION country_agg (params jsonb) returns jsonb AS $$

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

$$ LANGUAGE plv8;



CREATE OR REPLACE FUNCTION country_state_agg (params jsonb) returns jsonb AS $$

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

$$ LANGUAGE plv8;



CREATE OR REPLACE FUNCTION country_state_county_agg (params jsonb) returns jsonb AS $$

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

$$ LANGUAGE plv8;



DROP TYPE cfr_record CASCADE;
CREATE TYPE cfr_record AS (
  
    date text, 
    cases int, 
    resolve_date text, 
    prior_deaths int, 
    deaths int, 
    prior_resolutions int, 
    resolutions int, 
    days_to_resolve int,
    i_cfr text
); 

CREATE OR REPLACE FUNCTION cfr_analysis (country text) returns setof cfr_record AS $$

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

$$ LANGUAGE plv8;

