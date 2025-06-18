const { series } = require('gulp');

// Example placeholder task
function buildTask(done) {
  console.log('Running Gulp build task...');
  // You can add real tasks here like compiling SCSS, copying files, etc.
  done();
}

exports.build = series(buildTask);
