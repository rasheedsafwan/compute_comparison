const express = require('express');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  ScanCommand,
  PutCommand,
  DeleteCommand,
} = require('@aws-sdk/lib-dynamodb');

const app = express();
app.use(express.json());

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE_NAME = process.env.TABLE_NAME;

// Health check 
app.get('/health', (req, res) => res.status(200).send('ok'));

app.get('/coffee', async (req, res) => {
  try {
    const result = await client.send(new ScanCommand({ TableName: TABLE_NAME }));
    res.status(200).json(result.Items);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to read inventory' });
  }
});

app.post('/coffee', async (req, res) => {
  try {
    await client.send(new PutCommand({ TableName: TABLE_NAME, Item: req.body }));
    res.status(201).json(req.body);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to create item' });
  }
});

app.put('/coffee', async (req, res) => {
  try {
    await client.send(new PutCommand({ TableName: TABLE_NAME, Item: req.body }));
    res.status(200).json(req.body);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to update item' });
  }
});

app.delete('/coffee', async (req, res) => {
  try {
    const { coffeeId } = req.query;
    await client.send(new DeleteCommand({ TableName: TABLE_NAME, Key: { coffeeId } }));
    res.status(204).send();
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to delete item' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`coffee-api listening on ${PORT}`));