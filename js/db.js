const { Client } = require('pg')
const path = require('path')

const poolSize = 50
const { Pool } = require('pg')

const pool = new Pool({
  //host: 'localhost',
  user: 'postgres',
  database: 'corona',
  max: poolSize + 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
})


async function getClient() { 
  const client = await pool.connect()
  return client
}


exports = module.exports = {
  getClient
}
