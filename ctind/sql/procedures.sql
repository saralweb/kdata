CREATE OR REPLACE FUNCTION jhu.load_next_day () returns jsonb AS $$

  var path_prefix = '/home/kavi/cdata'
  var base_date = '2020-01-22'

  var column_sets = {
    A : 'state,country,update_date,cases,deaths,recovered' ,
    B : 'state,country,update_date,cases,deaths,recovered,lat,long' , 
    C : 'fips,county,state,country,update_date,lat,long,cases,deaths,recovered,active,combined_key',
    D : 'state,country,update_date,lat,long,cases,deaths,recovered,active,county,fips,combined_key,incident_rate,tested,hospitalized,uid,iso3'
  }

  var columns = [
  
    [Date.parse('2020-01-22'), Date.parse('2020-02-29'), column_sets.A],
    [Date.parse('2020-03-01'), Date.parse('2020-03-21'), column_sets.B],
    [Date.parse('2020-03-22'), Date.parse('9999-01-01'), column_sets.C],
/*    [Date.parse('2020-04-12'), Date.parse('9999-01-01'), column_sets.D],
*/

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

$$ LANGUAGE plv8;

