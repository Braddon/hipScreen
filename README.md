# hipScreen (hs)

**GNU screen for cool kids with bad memories**

## Why?

Screen is powerful but clunky, and remembering session names does not make me fun at parties.  And that's why i made `hipScreen`.   You too can change your life with this one command line tool.  

Thankfully `hipScreen` makes it dead simple:

- **Named sessions you'll actually remember** - "Big Jim's little bug" beats "23847.pts-2.hostname"
- **See everything at a glance** - what's running, when you last touched it, when you created it
- **Quick attach/detach** - perfect for remote work sessions

**Real-world scenario:** I run Claude Code on remote servers, because that's how i roll.  I even use termius on my phone so i can monitor them - yes life is really that amazing.  When i need a latte but I don't want to lose my place, it really bugs me to reconnect to the screens sessions on remote.  That's why i created hipScreen - and now I'm sharing it so you can go grab a latte too!

 Installation

```bash
# Download
curl -O https://raw.githubusercontent.com/Braddon/hipscreen/main/hs
# Or just copy the script

# Make executable and install
chmod +x hs
sudo mv hs /usr/local/bin/

# Done!
hs
```

## Usage

```bash
$ hs
There are 3 screen(s) currently running:

#    Name                      Last Active          Created              Connections
─────────────────────────────────────────────────────────────────────────────────────
1.   adding reflow^           2025-10-30 14:23:15  2025-10-30 09:15:42  1
2.   database backup          2025-10-30 14:20:01  2025-10-29 22:10:33  0
3.   server logs              2025-10-30 12:45:22  2025-10-30 08:00:11  2

^ [you are already in 'adding reflow']

Select session number, 'n' for new, 'k' to kill:
```

Type a number to attach, `n` to create a new named session, or `k` to kill an old one.

## Contributing

Found a bug? Want to make it more hip???  PRs welcome! 
