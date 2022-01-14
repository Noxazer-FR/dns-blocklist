#!/bin/bash
# inspirated from dnsblockbuster
# noxazer - 2022
[ -d /tmp/blockhosts ] && rm -rf /tmp/blockhosts
pushd /tmp
lists="https://s3.amazonaws.com/lists.disconnect.me/simple_ad.txt https://s3.amazonaws.com/lists.disconnect.me/simple_tracking.txt https://winhelp2002.mvps.org/hosts.txt https://adaway.org/hosts.txt http://sbc.io/hosts/alternates/fakenews-gambling/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts http://sysctl.org/cameleon/hosts http://pgl.yoyo.org/as/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt https://raw.githubusercontent.com/anudeepND/blacklist/master/facebook.txt https://ewpratten.retrylife.ca/youtube_ad_blocklist/domains.txt"

out="/tmp/blocklist"
i=0

redirect_type="127.0.0.1 0.0.0.0 NXDOMAIN IP"

echo "Fetching blocklists..."
mkdir $out
pushd $out
for url in $lists; do
        curl --silent $url >> $i
        echo "Cleaning host from $url"
         # Delete specific lines we don't want, try to fix typos and then cleanup.
        sed -i '/^#/d' "$i"
        sed -i '/^=/d' "$i"
        sed -i '/^:/d' "$i"
        sed -i '/^\./d' "$i"
        sed -i '/^127.0.0.1/d' "$i"
        sed -i '/^255.255.255.255/d' "$i"
        sed -i '/^ff0/d' "$i"
        sed -i '/^fe80/d' "$i"
        sed -i '/^0.0.0.0 0.0.0.0$/d' "$i"
        sed -i 's/0.0.0.0 0.0.0.0.//' "$i"
        sed -Ei 's/^(0.0.0.0 |0.0.0.0)//' "$i"
        # Delete all empty lines.
        sed -i '/^$/d' "$i"
         # Delete carriage-return.
        tr -d '\r' < $i > $i.tmp
        # Make proper host format.
        sed -i '/^0\.0\.0\.0/! s/^/0.0.0.0 /' "$i.tmp"
        # Some entries are duplicated because of comments after the domain like this:
        # 0.0.0.0 foo.bar
        # 0.0.0.0 foo.bar #foo's domain
        # This cleans all of that up.
        awk '/^0.0.0.0/ { print $2 }' "$i.tmp" > "$i"
        rm "$i.tmp"
        # The above occasionally leaves a line with a single hash, remove that.
        sed -i '/^#$/d' "$i"
        # Make all lower case.
        tr '[:upper:]' '[:lower:]' < "$i" > "$i.tmp"
        rm -f $i
        cat $i.tmp >> ../blacklist
        i=$((i+1))
done
rm -rf "/tmp/blocklist"
popd

echo "Processing blacklist..."
# Remove duplicate entries.
awk '!seen[$0]++' "blacklist" > "blacklist.tmp"

cat blacklist.tmp | uniq > blacklist
mv blacklist blacklist.tmp

# Whitelist.
if [ ! -f "~/dns-whitelist" ]; then
    printf "\nNo dns-whitelist found inside your home directory, running without.\n\n"
else
    sed '/^[[:space:]]*$/d' ~/dns-whitelist > whitelist.tmp2
    grep -f whitelist.tmp2 -v -- "blacklist.tmp" > "blacklist"
    mv blacklist blacklist.tmp
fi

mkdir -p ~/dns-blacklist

echo "Creating blacklist for dnsmasq..."
# Create dnsmasq hosts file
awk '{ print "0.0.0.0", $1 }' "blacklist.tmp" > dnsmasq-blacklist
echo "Creating blacklist for unbound..."
awk '/^0.0.0.0/ {
    print "local-zone: \""$2"\" always_null"
}' dnsmasq-blacklist > ~/dns-blacklist/unbound-blacklist.conf
echo "Creating blacklist for bind..."
awk '/^0.0.0.0/ {
    print "zone \""$2"\" { type master; notify no; file \"null.zone.file\"; };"
}' dnsmasq-blacklist > ~/dns-blacklist/bind-blacklist.zones

mv dnsmasq-blacklist ~/dns-blacklist/.

echo "Cleaning up..."
rm -f blacklist blacklist.tmp whitelist.tmp2

popd
