#!/usr/bin/env nu

# BOM-START
# {
#   "dependencies": [
#     "gnutar", "gzip", "bzip2", "xz", "zstd", "lz4", 
#     "zip", "unzip", "_7zz", "libarchive"
#   ]
# }
# BOM-END

# Creates an archive from the provided inputs.
def "main archive" [
    output: path
    ...inputs: path
] {
    if ($inputs | is-empty) {
        error make { msg: "No input files provided for archiving." }
    }

    let ext = ($output | str downcase)

    if ($ext =~ '\.(tar\.gz|tgz)$') {
        ^tar -czf $output ...$inputs
    } else if ($ext =~ '\.(tar\.bz2|tbz|tbz2)$') {
        ^tar -cjf $output ...$inputs
    } else if ($ext =~ '\.(tar\.xz|txz)$') {
        ^tar -cJf $output ...$inputs
    } else if ($ext =~ '\.(tar\.zst|tzst)$') {
        ^tar --zstd -cf $output ...$inputs
    } else if ($ext =~ '\.tar\.lz4$') {
        ^tar -I lz4 -cf $output ...$inputs
    } else if ($ext =~ '\.tar\.lzma$') {
        ^tar --lzma -cf $output ...$inputs
    } else if ($ext =~ '\.tar$') {
        ^tar -cf $output ...$inputs
    } else if ($ext =~ '\.(zip|jar|apk)$') {
        ^zip -r $output ...$inputs
    } else if ($ext =~ '\.7z$') {
        ^7zz a $output ...$inputs
    } else if ($ext =~ '\.gz$') {
        ^gzip -k -c ($inputs | first) | save -f $output
    } else if ($ext =~ '\.bz2$') {
        ^bzip2 -k -c ($inputs | first) | save -f $output
    } else if ($ext =~ '\.xz$') {
        ^xz -k -c ($inputs | first) | save -f $output
    } else if ($ext =~ '\.zst$') {
        ^zstd -k -c ($inputs | first) | save -f $output
    } else if ($ext =~ '\.lz4$') {
        ^lz4 -c ($inputs | first) | save -f $output
    } else {
        print -e $"Warning: Unknown/unsupported creation extension for ($output). Defaulting to 7zz."
        ^7zz a $output ...$inputs
    }
}

# Extracts an archive to the specified destination.
def "main unarchive" [
    input: path
    --dest (-d): path = "."
] {
    if not ($dest | path exists) {
        mkdir $dest
    }

    let ext = ($input | str downcase)
    let stem = ($input | path parse | get stem)
    let single_out_path = ([$dest, $stem] | path join)

    if ($ext =~ '\.(tar\.gz|tgz|tar\.bz2|tbz|tbz2|tar\.xz|txz|tar\.zst|tzst|tar\.lz4|tar\.lzma|tar)$') {
        ^tar -xf $input -C $dest
    } else if ($ext =~ '\.(zip|jar|apk)$') {
        ^unzip $input -d $dest
    } else if ($ext =~ '\.rar$') {
        ^7zz x $input $"-o($dest)"
    } else if ($ext =~ '\.gz$') {
        ^gzip -d -k -c $input | save -f $single_out_path
    } else if ($ext =~ '\.bz2$') {
        ^bzip2 -d -k -c $input | save -f $single_out_path
    } else if ($ext =~ '\.xz$') {
        ^xz -d -k -c $input | save -f $single_out_path
    } else if ($ext =~ '\.zst$') {
        ^zstd -d -k -c $input | save -f $single_out_path
    } else if ($ext =~ '\.lz4$') {
        ^lz4 -d -c $input | save -f $single_out_path
    } else if ($ext =~ '\.(cpio|iso|rpm|deb|cab|wim|chm)$') {
        let abs_input = ([$env.PWD, $input] | path join)
        cd $dest
        ^bsdtar -xf $abs_input
    } else {
        print -e $"Warning: Unknown extension for ($input). Attempting 7zz extraction."
        ^7zz x $input $"-o($dest)"
    }
}