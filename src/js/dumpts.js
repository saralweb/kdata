var path = require('path')
var db = require(path.join(__dirname, '../db'))
var fs = require('fs')

var countryListCds =  ['India']
var countryListCtind =  ['India']

var countryListJhu =  [
  'India', 
  'US', 
  'Italy', 
  'Iran', 
  'Spain', 
  'United Kingdom', 
  'France', 
  'Korea, South', 
  'China',
  'Indonesia',
  'Turkey',
  'Sweden',
  'New Zealand',
  'Australia',
  'Mexico',
  'Brazil',
  'Russia'
]

var statesListUS_JHU = ['Arizona', 'California', 'Connecticut', 'Florida', 'Georgia', 'Illinois', 'Indiana', 'Louisiana', 'Maryland', 'Massachusetts', 'Michigan', 'New Jersey', 'New York', 'Ohio', 'Pennsylvania', 'Texas']

const datasets = [
  { proc : 'country_agg', 
    args: {col: 'cases', op: 'sum', countries: countryListJhu,   source: 'jhu'}
  },
  { proc: 'country_agg', 
    args: {col: 'deaths', op: 'sum', countries: countryListJhu,   source: 'jhu'}
  },
  { proc: 'country_agg', 
    args: {col: 'recovered', op: 'sum', countries: countryListJhu,   source: 'jhu'}
  },
  { proc : 'country_agg', 
    args: {col: 'cases', op: 'dgr', countries: countryListJhu,   source: 'jhu'}
  },
  { proc: 'country_agg', 
    args: {col: 'deaths', op: 'dgr', countries: countryListJhu,   source: 'jhu'}
  },
  { proc : 'country_agg', 
    args: {col: 'cases', op: 'agr5', countries: countryListJhu,   source: 'jhu'}
  },
  { proc: 'country_agg', 
    args: {col: 'deaths', op: 'agr5', countries: countryListJhu,   source: 'jhu'}
  },
  { proc : 'country_agg',
    args: {col: 'cases', op: 'rate', countries: countryListJhu,   source: 'jhu'}
  },
  { proc: 'country_agg',
    args: {col: 'deaths', op: 'rate', countries: countryListJhu,   source: 'jhu'}
  },
  { proc: 'country_agg',
    args: {col: 'recovered', op: 'rate', countries: countryListJhu,   source: 'jhu'}
  },
  { proc: 'country_state_agg',
    args: { country: 'US', col: 'cases', op: 'rate',   states: statesListUS_JHU,  source: 'jhu'}
  },
  { proc: 'country_state_agg',
    args: { country: 'US', col: 'deaths', op: 'rate',    states: statesListUS_JHU, source: 'jhu'}
  },

  { proc: 'country_state_agg', 
    args: { country: 'US', col: 'cases', op: 'sum',  states: statesListUS_JHU, source: 'jhu'}
  },
  { proc: 'country_state_agg', 
    args: { country: 'US', col: 'cases', op: 'dgr',   states: statesListUS_JHU, source: 'jhu'}
  },
  { proc: 'country_state_agg', 
    args: { country: 'US', col: 'cases', op: 'agr5',   states: statesListUS_JHU,  source: 'jhu'}
  },

  { proc: 'country_state_agg', 
    args: { country: 'US', col: 'deaths', op: 'sum',   states: statesListUS_JHU,  source: 'jhu'}
  },
  { proc: 'country_state_agg', 
    args: { country: 'US', col: 'deaths', op: 'dgr',   states: statesListUS_JHU,  source: 'jhu'}
  },
  { proc: 'country_state_agg', 
    args: { country: 'US', col: 'deaths', op: 'agr5',    states: statesListUS_JHU, source: 'jhu'}
  },

  { proc: 'country_state_agg', 
    args: { country: 'India', col: 'cases', op: 'sum',  source: 'ctind'}
  },
  { proc: 'country_state_agg', 
    args: { country: 'India', col: 'deaths', op: 'sum',  source: 'ctind'}
  },
  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'Washington',  col: 'cases', op: 'sum',  source: 'jhu'}
  },
  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'Washington',  col: 'deaths', op: 'sum',  source: 'jhu'}
  },

  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'California', col: 'cases', op: 'sum',  source: 'jhu'}
  },
  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'California', col: 'deaths', op: 'sum',  source: 'jhu'}
  },

  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'New York', col: 'cases', op: 'sum',  source: 'jhu'}
  },
  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'New York', col: 'deaths', op: 'sum',  source: 'jhu'}
  },

  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'Illinois', col: 'cases', op: 'sum',  source: 'jhu'}
  },
  { proc: 'country_state_county_agg', 
    args: { country: 'US', state: 'Illinois', col: 'deaths', op: 'sum',  source: 'jhu'}
  }

] 

function quote(x) {
  return  '"' + x.replace(/"/g, '"""') + '"'
}

function array2csv_line (argArr) {
  var result = ''
  argArr.forEach (function(x, idx, arr) {
    //console.log ('datum: ' ,  x, typeof x)
    if (typeof x === 'string') {
      result += quote(x)
    }
    else if (typeof x === 'number') {
      result += quote(x.toString())
    } 

    else if ( x == null) { 
      result += quote('')
    } 
    else {
      console.log ('array2csv_line called with non string datum', x)
      process.exit(1)
    }

    if (idx < arr.length - 1) {
      result += ','
    }
    else {
      result += '\n'
    }
  })
  return result
}

async function getCsv (dsname, params) {
  var result, client, filename, file
  var op = params.op
  try {
    client = await db.getClient()
    result = await client.query('select ' + dsname + '($1)', [params] )

    //console.log ('result.rows: ' ,  result.rows)
    if (result.rows.length > 0) { 

      var ret = result.rows[0][dsname]
      var data = ret.data
      filename = path.join (__dirname, '../../generated/' + ret.name + '.csv')
      file = fs.openSync(filename, 'w')

      // first line - column headers
      var columns = Object.keys(data).sort()
      console.log ('csv headers: ' ,columns)
      fs.writeFileSync(file, array2csv_line(['date'].concat(columns)), {flag: 'a'})
       
      // data rows 
      
      var records = []
      columns.forEach (function(x, idx, arr) {
        var rows = data[x]
        // record all dates
        rows.forEach( function(x, idx) {
          if (records[x.date] == null) {
            records[x.date] = [x.date]
          }
        })
      })

      columns.forEach (function(x, idx, arr) {
        var rows = data[x]
        // record all values against dates
        rows.forEach( function(x, idx) {
          records[x.date].push (x[op])
        })

        // patch missing values
        Object.keys(records).forEach( function (date) {
          if (records[date].length < idx+2) {
            records[date].push('')
          }
        })
      })

      console.log ('records: ', records)
      Object.keys(records).sort().forEach( function(date) {
        fs.writeFileSync(file, array2csv_line(records[date]), {flag: 'a'})
      })
    }
  }
  catch (err) {
    throw (err)
  }
  finally {
    if (file != null) {
      fs.closeSync(file)
    }
    if (client != null) {
      client.release()
    }
  }
  return result
}


async function main() {
  for (var i=0; i < datasets.length; i++) {
    console.log ('processing dataset: ' ,  datasets[i].proc , '(\'' + JSON.stringify(datasets[i].args) + '\')')
    await getCsv(datasets[i].proc, datasets[i].args)
  }
  process.exit(0)
}

main()

