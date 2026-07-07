# export def main [...args: string] {
#     # If the user is running 'nix shell' or 'nix-shell', we intercept
#     if ($args | length) > 1 and $args.0 == "shell" {
#         let shell_args = $args | skip 1
        
#         # Modern 'nix shell' uses --command to specify the shell executable
#         ^nix shell ...$shell_args --command nu
#     } else {
#         # Pass through all other nix commands unmodified
#         ^nix ...$args
#     }
# }

# export def "main shell-configured" [...args: string] {
#     let nu_config = (nu-check --config-path)
#     ^nix shell ...$args --command nu --config $nu_config
# }