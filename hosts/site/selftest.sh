#!/bin/sh
# Run only inside the "selftest" stage of Dockerfile.server (BusyBox sh, nc and grep; nginx already started on port 80).
# check <address> <status> [line]: the answer to GET <address> must have that status and, when a line is given, that exact line
# (a header such as "Location: /articles/" or a line of the body).
set -eu

check() {
    answer=$(printf 'GET %s HTTP/1.0\r\nHost: localhost\r\n\r\n' "$1" | nc -w 2 127.0.0.1 80 | tr -d '\r')
    if ! echo "$answer" | head -n 1 | grep -q "^HTTP/1.1 $2 "; then
        echo "SELFTEST FAILED: $1 did not answer $2"
        echo "$answer"
        exit 1
    fi
    if [ "$#" -ge 3 ] && ! echo "$answer" | grep -qxF "$3"; then
        echo "SELFTEST FAILED: $1 did not answer with the line: $3"
        echo "$answer"
        exit 1
    fi
    echo "ok $1 $2"
}

check /tag/ilm 301 'Location: /articles/?tag=ilm'
check /category/ethics 301 'Location: /articles/?category=ethics'
check /2020/05/12/real-slug 301 'Location: /articles/real-slug/'
check /2020/05/real-slug/ 301 'Location: /articles/real-slug/'
check /feed 302 'Location: /articles/'
check /feed/atom 302 'Location: /articles/'
check /author/someone 301 'Location: /articles/'
check /page/2 301 'Location: /articles/'
check /home 301 'Location: /'
check /articles/importance-reality-awaiting-intezaar-imam-mahdi 301 'Location: /articles/importance-virtue-awaiting-intezaar-imam-mahdi/'
check /articles/importance-reality-awaiting-intezaar-imam-mahdi/ 301 'Location: /articles/importance-virtue-awaiting-intezaar-imam-mahdi/'
check /real-slug 301 'Location: /articles/real-slug/'
check /real-slug/ 301 'Location: /articles/real-slug/'
check /.well-known/apple-app-site-association 200 'Content-Type: application/json'

# What exists keeps working; what does not exist is still the site's own 404 page.
check /about/ 200 'stand-in about page'
check /about 301 'Location: /about/'
check /site.css 200 'stand-in stylesheet'
check /articles/real-slug/ 200 'stand-in article'
check /no-such-address 404 'stand-in not-found page'
check /articles/x/ 404 'stand-in not-found page'
check /a/b/c 404 'stand-in not-found page'
