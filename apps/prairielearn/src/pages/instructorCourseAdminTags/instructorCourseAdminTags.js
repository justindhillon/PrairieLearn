//@ts-check
var ERR = require('async-stacktrace');
var express = require('express');
var router = express.Router();

var sqldb = require('@prairielearn/postgres');

var sql = sqldb.loadSqlEquiv(__filename);

router.get('/', function (req, res, next) {
  var params = {
    course_id: res.locals.course.id,
  };
  sqldb.query(sql.select_tags, params, function (err, result) {
    if (ERR(err, next)) return;
    res.locals.tags = result.rows;
    res.render(__filename.replace(/\.js$/, '.ejs'), res.locals);
  });
});

module.exports = router;
