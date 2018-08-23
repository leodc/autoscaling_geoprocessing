// api.js

// BASE SETUP
// =============================================================================

// call the packages we need
var express    = require('express');        // call express
var app        = express();                 // define our app using express
var bodyParser = require('body-parser');
var {Pool, Client}    = require("pg");

// configure app to use bodyParser()
// this will let us get the data from a POST
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

var port = process.env.PORT || 8080;        // set our port

// ROUTES FOR OUR API
// =============================================================================
var router = express.Router();              // get an instance of the express Router

// postgresql connection
// var client = new Client();
var pool = new Pool();
/*  VARIABLES

PGHOST=34.219.110.93 PGPORT=30001 PGDATABASE=test_db node api.js

PGHOST=ELB-coordinators-923901666.us-west-2.elb.amazonaws.com PGPORT=80 PGDATABASE=test_db nohup node api.js &

PGHOST=elb-coordinators-f59f9466ecc3fcd7.elb.us-west-2.amazonaws.com PGPORT=80 PGDATABASE=test_db node api.js


PGHOST=elb-coordinators-535768356.us-west-2.elb.amazonaws.com PGPORT=80 PGDATABASE=test_db forever start api.js

PGPASSWORD

*/

router.get('/', function(req, res) {
  var x = -13319525.55 + (Math.random() * 50);
  var y = 3948525.84 + (Math.random() * 50);

  var query = 'select *,st_distance(the_geom, ST_GeomFromText(\'POINT(' + x + ' ' + y + ')\',3857)) as distance from osm_points order by distance limit 20';
  pool.query(query, (err, postgresResponse) => {
    if(!err){
      res.json({ result: postgresResponse.rows });
    }else{
      console.log("Error running query", query, err);
    }
  });
});

// more routes for our API will happen here

// REGISTER OUR ROUTES -------------------------------
// all of our routes will be prefixed with /api
app.use('/api', router);

// START THE SERVER
// =============================================================================
app.listen(port);
console.log('Magic happens on port ' + port);
