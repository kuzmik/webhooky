# Webhooky

I couldn't get the webhook.site docker image to actually start up, so... here is a local webhook capture and inspection tool. Send HTTP requests to a unique URL and see them appear in real-time.

This 100% AI generated, this is used on my laptop for testing other software; do not run this anywhere you care about, for the love of god. I am not proud of this, but it solves a problem I personally had.

## Setup

```bash
bin/setup
bin/rails db:migrate
```

## Run

```bash
bin/rails server
```

Visit http://localhost:3000 and click "Create New URL".

## Test

```bash
bin/rails test
```
