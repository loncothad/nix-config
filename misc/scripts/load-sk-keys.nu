#!/usr/bin/env nu

# BOM-START
# {
#   "dependencies": [
#     "openssh",
#     "libfido2"
#   ]
# }
# BOM-END

# Download resident ssh-sk handles from a plugged FIDO token into ~/.ssh.
# Matches pubs in misc/ssh-keys/ (id_072, id_365) and ssh-adds them.

def repo-root [] {
    $env.FILE_PWD | path dirname | path dirname
}

def key-blob [pub: string] {
    $pub | split row -r '\s+' | get 1
}

def main [] {
    let ssh_dir = ($env.HOME | path join ".ssh")
    mkdir $ssh_dir

    let known = (
        glob ((repo-root) | path join "misc/ssh-keys/*.pub")
        | each {|p|
            {
                name: ($p | path parse | get stem)
                blob: (key-blob (open --raw $p | str trim))
            }
        }
    )
    if ($known | is-empty) {
        error make {msg: "no pubs in misc/ssh-keys/"}
    }

    let work = (mktemp -d)
    cd $work
    print "Touch the FEITIAN token and enter its PIN if asked..."
    try {
        ^ssh-keygen -K
    } catch {
        rm -rf $work
        error make {msg: "ssh-keygen -K failed. Keys must be resident (ssh-keygen -t ecdsa-sk -O resident). Is the token plugged in?"}
    }

    let downloaded = (glob "*.pub")
    if ($downloaded | is-empty) {
        rm -rf $work
        error make {msg: "token has no resident SSH keys. Recreate with: ssh-keygen -t ecdsa-sk -O resident -f ~/.ssh/id_072"}
    }

    mut installed = []
    for pub in $downloaded {
        let blob = (key-blob (open --raw $pub | str trim))
        let match = ($known | where blob == $blob)
        if ($match | is-empty) {
            print $"skip ($pub): pub does not match id_072/id_365"
            continue
        }
        let priv = ($pub | str replace -r '\.pub$' '')
        let dest = ($ssh_dir | path join $match.0.name)
        cp $priv $dest
        cp $pub $"($dest).pub"
        chmod 0600 $dest
        chmod 0644 $"($dest).pub"
        $installed = ($installed | append $dest)
        print $"installed ($dest)"
    }

    rm -rf $work

    if ($installed | is-empty) {
        error make {msg: "downloaded resident keys did not match misc/ssh-keys/*.pub"}
    }

    for dest in $installed {
        try { ^ssh-add $dest } catch {
            print $"ssh-add ($dest) failed (agent not running?); git will still use IdentityFile"
        }
    }
}
