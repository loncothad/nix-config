# # Base command wrapper for execution utilities.
# export def main [...args: string] {
#     if ($args | is-empty) {
#         print "Usage: run privileged <command> [...args]"
#     } else {
#         let cmd = $args.0
#         let rest = $args | skip 1
#         ^$cmd ...$rest
#     }
# }

# # Run a command with elevated privileges using systemd-run.
# export def "main privileged" [
#     ...command_and_args: string,     # The command to execute followed by its arguments.
#     --preserve-env (-E),             # Skip environment scrubbing and inherit the current user's full environment.
#     --set-env (-e): record = {},     # Pass explicit environment variables (e.g., --set-env { NIXOS_INSTALL_BOOTLOADER: "1" })
#     --keep-working-dir: bool = true, # Maintain the current working directory inside the privileged process.
#     --unit (-u): string,             # Use a custom systemd unit name instead of an automatically generated one.
#     --user: string = "root",         # The target user context under which the command should execute.
#     --group: string = "root",        # The target group context under which the command should execute.
#     --collect,                       # Unload the transient unit after it completes, even if it failed.
#     --no-ask-password                # Do not query the user for authentication via TTY agent.
# ] {
#     if ($command_and_args | is-empty) {
#         error make {
#             msg: "No command provided to run with privileges."
#             label: {
#                 text: "Specify an external executable or script."
#                 span: (metadata $command_and_args).span
#             }
#         }
#     }

#     let external_cmd = $command_and_args.0
#     let external_args = $command_and_args | skip 1

#     # Base flags matching standard service-type tracking and user privileges
#     mut run_flags = [
#         "--quiet",
#         $"--property=User=($user)",
#         $"--property=Group=($group)",
#         "--property=SameProcessGroup=true"
#     ]

#     # --- Verification & Logic fixes based on Documentation ---

#     # 1. TTY / Pipe Handling: Determine if we are interactive or inside a shell pipe
#     # As noted in the docs: when combined, systemd-run picks the most appropriate mechanism.
#     # To support interactive text editors flawlessly, we append both flags.
#     $run_flags = ($run_flags | append ["--pty", "--pipe"])

#     # 2. Add structural modifiers
#     if $keep_working_dir { $run_flags = ($run_flags | append "--same-dir") }
#     if $collect { $run_flags = ($run_flags | append "--collect") }
#     if $no-ask-password { $run_flags = ($run_flags | append "--no-ask-password") }
#     if ($unit | is-not-empty) { $run_flags = ($run_flags | append [$"--unit=($unit)"]) }

#     # 3. Assemble target execution environment profiles safely (NixOS-resilient)
#     let target_env = if $preserve_env {
#         $env 
#     } else {
#         # Retain critical terminal parameters so editors don't lose capability markers
#         let safelist = ["TERM", "DISPLAY", "XAUTHORITY", "LANG", "LC_ALL", "TZ", "LOCALE_ARCHIVE"]
#         mut isolated = ($env | columns 
#             | filter { |key| $key in $safelist }
#             | reduce -f {} { |key, acc| $acc | insert $key ($env | get $key) }
#         )

#         # Inject real execution environments dynamically evaluated from current shell state
#         let host_path = ($env | get -i PATH | default "/run/current-system/sw/bin:/usr/bin:/bin")
#         let host_shell = ($env | get -i SHELL | default "/bin/sh")
#         let target_home = if $user == "root" { "/root" } else { $"/home/($user)" }

#         $isolated = ($isolated 
#             | insert HOME $target_home
#             | insert USER $user
#             | insert LOGNAME $user
#             | insert SHELL $host_shell
#             | insert PATH $host_path
#         )
        
#         # Merge explicitly requested individual commands flags (--set-env)
#         $isolated | merge $set-env
#     }

#     # Format environment map definitions to individual command arguments (--setenv=K=V)
#     let env_flags = ($target_env | columns | each { |key| $"--setenv=($key)=($target_env | get $key)" })

#     # 4. Compile final arguments sequence
#     let final_args = ([] 
#         | append $run_flags 
#         | append $env_flags 
#         | append [$external_cmd] 
#         | append $external_args
#     )

#     with-env $target_env {
#         ^systemd-run ...$final_args
#     }
# }