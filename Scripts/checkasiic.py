filename = "/Users/i521907/firewall.conf"

with open(filename) as f:
    content = f.readlines()

for entry in content:
    try:
        entry.decode('ascii')
    except UnicodeDecodeError:
        print "it was not a ascii-encoded unicode string"
    else:
        print "It may have been an ascii-encoded unicode string"

f.close()
