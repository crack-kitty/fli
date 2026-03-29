# FlightCheck n8n Workflow Templates

Two n8n workflows that automatically search Google Flights for cheap fares, store prices in Postgres, and send Discord alerts when deals are found.

## What It Does

**Daily Collector** runs on a schedule (default: 6 AM EST). It:
1. Reads a watchlist of destination airports from Google Sheets
2. Searches flights from your origin airport to each destination at 4, 8, and 12 weeks out
3. Filters for your preferred airline (default: United Airlines)
4. Writes the best price per route to Postgres
5. Logs results to Google Sheets (Price History tab)
6. Triggers the Alert Engine

**Alert Engine** compares today's prices against historical data and sends Discord alerts for:
- New all-time low prices
- Prices 20%+ below the 30-day average

## Dependencies

### fli (Google Flights MCP server)
- Repository: https://github.com/crack-kitty/fli
- Runs as a Docker container exposing an MCP endpoint on port 8000
- The Daily Collector calls it via HTTP (MCP protocol over SSE)

### Postgres
- Any Postgres instance accessible from n8n
- Used to store flight price history

### Google Sheets
- Used for the destination watchlist and logging

### Discord (optional)
- Webhook for price drop alerts

## Placeholders to Configure

After importing each workflow into n8n, find and replace these placeholders:

| Placeholder | Where | What to set |
|---|---|---|
| `YOUR_GOOGLE_SHEETS_CREDENTIAL` | Read Watchlist, Write Price History, Write Daily Summary | Your n8n Google Sheets OAuth2 credential name |
| `YOUR_GOOGLE_SHEETS_CREDENTIAL_ID` | Same nodes | Your n8n credential ID (visible in the URL when editing the credential) |
| `YOUR_GOOGLE_SHEET_ID` | Same nodes | The Google Sheet ID from your sheet's URL |
| `YOUR_POSTGRES_CREDENTIAL` | Write to DB, Query Summary, Get Today Results (Collector); Get Today Prices, Get Historical Stats (Alert Engine) | Your n8n Postgres credential name |
| `YOUR_POSTGRES_CREDENTIAL_ID` | Same nodes | Your n8n Postgres credential ID |
| `YOUR_FLIGHTCHECK_HOST:8000` | Search Flights node (Collector) | The hostname of your fli container (e.g., `flightcheck:8000` if on the same Docker network) |
| `YOUR_ALERT_ENGINE_WORKFLOW_ID` | Trigger Alert Engine node (Collector) | The n8n workflow ID of your imported Alert Engine workflow |
| `YOUR_DISCORD_WEBHOOK_URL` | Send Discord node (Alert Engine) | Your Discord channel webhook URL |

## Required Google Sheet Structure

Create a Google Sheet with 3 tabs:

### Tab 1: "Watchlist"

| Column | Type | Description |
|---|---|---|
| `iata_code` | Text | 3-letter airport code (e.g., `ATL`) |
| `destination_name` | Text | Human-readable name (e.g., `Atlanta`) |
| `enabled` | Boolean | `TRUE` to include in searches |

### Tab 2: "Price History"

| Column | Type | Description |
|---|---|---|
| `run_date` | Date | Date the search ran |
| `destination_iata` | Text | Airport code |
| `destination_name` | Text | Destination name |
| `price` | Number | Best price found |
| `airline` | Text | Airline name |
| `stops` | Number | Number of stops |
| `layover_airport` | Text | Layover airport code (blank if direct) |
| `departure_date` | Date | Flight departure date |

### Tab 3: "Daily Summary"

| Column | Type | Description |
|---|---|---|
| `run_date` | Date | Date the search ran |
| `routes_checked` | Number | How many routes had results |
| `routes_alerted` | Number | How many triggered alerts |
| `lowest_price_found` | Number | Cheapest price of the day |
| `lowest_price_route` | Text | Airport code of cheapest route |
| `notes` | Text | Optional notes |

## Required Postgres Schema

```sql
CREATE TABLE IF NOT EXISTS flight_prices (
  id SERIAL PRIMARY KEY,
  run_date DATE NOT NULL,
  destination_iata VARCHAR(3) NOT NULL,
  destination_name VARCHAR(100),
  price INTEGER,
  airline VARCHAR(50),
  stops INTEGER,
  layover_airport VARCHAR(3),
  departure_date DATE,
  flight_duration INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_destination_iata
  ON flight_prices(destination_iata);
CREATE INDEX IF NOT EXISTS idx_run_date
  ON flight_prices(run_date);
```

## Customization

### Change origin airport
In the Daily Collector's "Search Flights" Code node, change `origin: 'ALB'` to your airport code.

### Change preferred airline
In the "Parse and Filter" Code node, modify the `includes('united')` filter.

### Change search windows
In "Generate Search Pairs", modify the `weeksOut` array (default: `[4, 8, 12]`).

### Change batch concurrency
In "Loop Searches", adjust the `batchSize` parameter (default: 3). Higher = faster but more CPU load.

### Change alert thresholds
In the Alert Engine's "Evaluate Alert" node, modify `avg30d * 0.8` (20% drop threshold).

## Importing into n8n

1. In the n8n editor, click the three-dot menu and select "Import from File"
2. Import `flightcheck-daily-collector-template.json` first
3. Import `flightcheck-alert-engine-template.json` second
4. Update all placeholder values in both workflows
5. Set up the required n8n credentials (Google Sheets OAuth2, Postgres)
6. Copy the Alert Engine's workflow ID into the Daily Collector's "Trigger Alert Engine" node
7. Test with a small watchlist (2-3 destinations) before enabling the full list
