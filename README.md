# node-disk-alert

A cron script that watches disk usage on node machines and sends a Telegram message before a disk
fills up. Chain data only grows, so this is worth having on every node.

For each configured path it stores the used bytes over time and computes

- the current usage in percent,
- the growth per day since the previous run, and
- the estimated number of days until the disk is full.

It alerts when usage goes above `THRESHOLD` percent or the estimate drops below `MIN_DAYS`. Messages
are sent on state changes only, with a recovery message when things are back to normal.

## Setup

```bash
cp disk-alert.conf.example disk-alert.conf   # fill in the bot token and chat id
chmod 600 disk-alert.conf
./disk-alert.sh                               # prints a report, sends alerts if needed
```

Hourly cron entry:

```
0 * * * * /opt/node-disk-alert/disk-alert.sh >> /var/log/node-disk-alert.log 2>&1
```

```
/                43% used  +0.1 GB/day  ~210 days left
```

The first run only stores a baseline and shows `n/a GB/day`. Growth appears from the second run.

The growth comes from `df`, so it includes everything on that filesystem, not only the chain data.
Needs `bash`, `df`, `awk` and `curl`.
