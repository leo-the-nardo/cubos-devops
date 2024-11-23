// backend/index.js
import Module from 'node:module'
import http from 'http';
import fs from 'fs';
import winston from 'winston';
const logger = winston.createLogger();
const require = Module.createRequire(import.meta.url);
const PG = require('pg')

const serverPort = Number(process.env.PORT) || 443;
const client = new PG.Client({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASS,
  port: process.env.DB_PORT,
  ssl: {
      ca: fs.readFileSync(process.env.PGSSLROOTCERT).toString(),
      cert: fs.readFileSync(process.env.PGSSLCERT).toString(),
      key: fs.readFileSync(process.env.PGSSLKEY).toString(),
      rejectUnauthorized: true,
    },
  });
  
let successfulConnection = false;

// Connect to the database when the server starts
client.connect()
  .then(() => { 
    successfulConnection = true;
    logger.info('Database connected successfully');
  })
  .catch(err => console.error('Database connection error -', err.stack));

const server = http.createServer(async (req, res) => {
  logger.info(`Request: ${req.url}`);

  if (req.url === "/api" || req.url === "/api/") {
    res.setHeader("Content-Type", "application/json");
    res.writeHead(200);

    let result;

    try {
      result = (await client.query("SELECT * FROM users")).rows[0];
    } catch (error) {
      logger.error(error);
      res.writeHead(500);
      return res.end(JSON.stringify({ error: 'Internal Server Error' }));
    }

    const data = {
      database: successfulConnection,
      userAdmin: result?.role === "admin"
    }

    res.end(JSON.stringify(data));
  } else {
    res.writeHead(404);
    res.end("Not Found");
  }

}).listen(serverPort, () => {
  logger.info(`Server is listening on port ${serverPort}`);
});
