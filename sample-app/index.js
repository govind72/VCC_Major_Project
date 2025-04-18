const express = require('express');
const os = require('os');
const app = express();
const PORT = process.env.PORT || 8000;

app.get('/', (req, res) => {
  res.send(`Hello from pod on node ${process.env.NODE_NAME || os.hostname()}`);
});

app.listen(PORT, () => {
  console.log(`Sample app listening on port ${PORT}`);
});
