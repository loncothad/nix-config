#!/usr/bin/env nu

# BOM-START
# {
#   "dependencies": [
#     "nodejs"
#   ]
# }
# BOM-END

const REGISTRY = "https://registry.npmjs.org"

def repo-root [] {
    $env.FILE_PWD | path dirname | path dirname
}

def sources-path [] {
    (repo-root) | path join "pkgs/pi-extensions/sources.json"
}

def tarball-url [name: string, version: string] {
    let base = ($name | split row "/" | last)
    $"($REGISTRY)/($name)/-/($base)-($version).tgz"
}

def nix-hash-file [path: path] {
    ^nix hash file $path | str trim
}

def nix-hash-path [path: path] {
    ^nix hash path $path | str trim
}

def npm-meta [name: string] {
    let encoded = ($name | str replace --all "/" "%2f")
    http get $"($REGISTRY)/($encoded)"
}

def prefetch [name: string, version: string, pkg: record] {
    let url = (tarball-url $name $version)
    let tmp = (mktemp -d)
    let tgz = ($tmp | path join "pkg.tgz")
    ^curl --fail --silent --show-error --location --output $tgz $url

    mut entry = {
        npm: $name
        version: $version
        hash: (nix-hash-file $tgz)
    }

    let has_deps = ($pkg.dependencies? | default {} | is-not-empty)
    if $has_deps {
        let unpacked = ($tmp | path join "unpacked")
        mkdir $unpacked
        ^tar -xzf $tgz -C $unpacked
        let root = ($unpacked | path join "package")
        do {
            cd $root
            ^npm install --omit=dev --ignore-scripts --no-audit --no-fund
        }
        $entry = ($entry | insert npmDepsHash (nix-hash-path $root))
    }

    rm -rf $tmp
    $entry
}

def "main list" [] {
    let src = (open (sources-path))
    let names = ($src | columns)
    for name in $names {
        let meta = ($src | get $name)
        let deps = if "npmDepsHash" in ($meta | columns) { " +deps" } else { "" }
        print $"($name)  ($meta.npm)@($meta.version)($deps)"
    }
}

def main [...names: string] {
    let sources_file = (sources-path)
    let current = (open $sources_file)
    let all_names = ($current | columns)

    if not ($names | is-empty) {
        let missing = ($names | where {|n| $n not-in $all_names })
        if not ($missing | is-empty) {
            error make { msg: $"unknown extension(s): ($missing | str join ', ')" }
        }
    }

    let targets = if ($names | is-empty) { $all_names } else { $names }

    mut updated = {}
    for attr in $targets {
        let src = ($current | get $attr)
        let npm_name = $src.npm
        let meta = (npm-meta $npm_name)
        let latest = ($meta | get dist-tags | get latest)
        let pkg = ($meta.versions | get $latest)
        let old = ($src.version? | default "")
        if $old == $latest {
            print $"($attr): ($latest)"
        } else {
            print $"($attr): ($old) -> ($latest)"
        }
        $updated = ($updated | insert $attr (prefetch $npm_name $latest $pkg))
    }

    mut out = {}
    for name in $all_names {
        let val = if $name in ($updated | columns) {
            $updated | get $name
        } else {
            $current | get $name
        }
        $out = ($out | insert $name $val)
    }

    $out | to json --indent 2 | save --force $sources_file
    print "wrote pkgs/pi-extensions/sources.json"
}
