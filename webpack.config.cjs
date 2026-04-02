const path = require("path");

module.exports = {
  mode: "production",
  entry: "./src/index.js",
  optimization: { minimize: false },
  target: "webworker",
  output: {
    filename: "index.js",
    path: path.resolve(__dirname, "build"),
    libraryTarget: "this",
  },
  externals: [
    ({ request }, callback) => {
      if (/^fastly:.*$/.test(request)) {
        return callback(null, "commonjs " + request);
      }
      callback();
    },
  ],
};
