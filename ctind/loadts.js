var path = require('path')
var db = require(path.join(__dirname, '../js/db'))
var fs = require('fs')


var client;
var records = {}

async function init() {
  client = await db.getClient()
}

async function processRecord( rec ) {
  
  var col = {
    'Deceased' : 'deaths',
    'Recovered' : 'recovered',
    'Confirmed' : 'cases'
  }[rec.status]

  if (records[rec.date] == null) {
    records[rec.date] = {}
  }

  Object.keys(rec).forEach( function(k) {
    if (k != 'date' && k != 'status') {
      if (records[rec.date][k] == null) {
        records[rec.date][k] = {}
      }
      records[rec.date][k][col] = rec[k]
    }
  })
}

async function insertRecords (rec) {

  var cmd = 'insert into ctind.timeseries (date, update_date, country, state, cases, deaths, recovered) values ($1, $2, $3, $4, $5, $6, $7)'
  for (var i = 0; i< Object.keys(records).length; i++) {
    var date = Object.keys(records)[i]
    for ( var j = 0; j < Object.keys(records[date]).length; j++ ) {
      var state = Object.keys(records[date])[j]
      console.log ('inserting: ', date, date, 'India', state, records[date][state]['cases'], records[date][state]['deaths'], records[date][state]['recovered'])
      await client.query(cmd, [date, date, 'India', state, records[date][state]['cases'], records[date][state]['deaths'], records[date][state]['recovered']])
    }
  }
}

async function main() {

  await init()

  var textData = fs.readFileSync('data/states_daily.json')
  var jsonData = JSON.parse(textData)
  for (var i = 0; i < jsonData.states_daily.length; i++) {
    await processRecord (jsonData.states_daily[i])
  }
  console.log ('records: ', records)
  await insertRecords();

  process.exit(0)
}
main()

