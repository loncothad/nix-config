def create_left_prompt [] {
    let path_segment = ($env.PWD | path basename)
    let dir = if $env.PWD == $env.HOME { 
        "~" 
    } else if $path_segment == "" { 
        "/" 
    } else { 
        $path_segment 
    }

    mut git_info = ""
    if (which git | is-not-empty) {
        let branch = (do -i { ^git symbolic-ref --short HEAD } | complete | get stdout | str trim)
        if ($branch | is-not-empty) {
            let dirty = (do -i { ^git status --porcelain } | complete | get stdout | is-not-empty)
            let status_char = if $dirty { "*" } else { "" }
            $git_info = $"(ansi green_bold)($branch)($status_char)(ansi reset)"
        }
    }

    mut jj_info = ""
    if (which jj | is-not-empty) {
        let jj_check = (do -i { ^jj log -r @ -T 'change_id.short()' } | complete)
        if $jj_check.status == 0 {
            let change_id = ($jj_check.stdout | str trim)
            if ($change_id | is-not-empty) {
                $jj_info = $"(ansi magenta_bold)jj:($change_id)(ansi reset)"
            }
        }
    }

    let separator = $"(ansi blue_bold)❯(ansi reset) "
    
    let parts = [$dir, $git_info, $jj_info] | where { |it| ($it | str trim) != "" }
    
    ($parts | str join " ") + "\n" + $separator
}

def create_right_prompt [] {
    let exit_code = $env.LAST_EXIT_CODE
    
    let exit_msg = if $exit_code == 0 {
        ""
    } else {
        $"(ansi red)($exit_code) "
    }
    
    $"(ansi white)($exit_msg)(ansi reset)"
}

$env.PROMPT_COMMAND = { create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = { create_right_prompt }