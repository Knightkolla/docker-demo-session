import express from "express";

const app = express();
const port = Number(process.env.PORT) || 3000;

app.get("/", (_req, res) => {
  res.send("Hello from the workshop app!");
});

app.get("/health", (_req, res) => {
  res.sendStatus(200);
});

app.listen(port, () => console.log(`listening on :${port}`));
