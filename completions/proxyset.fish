# Fish completion for proxyset

set -l commands wizard set unset status test diagnose discover audit install uninstall update gen-man list snapshot profile pac run
set -l modules apt dnf yum pacman zypper apk xbps brew snap flatpak nix swupd emerge git npm yarn pip cargo go gem composer gradle nuget maven docker podman containerd buildah kubernetes helm aws gcloud az terraform conda brave chromium edge firefox wget curl aria2 ytdlp

complete -c proxyset -f # Disable file completion by default

# Main commands
complete -c proxyset -n "not __fish_seen_subcommand_from $commands $modules" -a "$commands" -d "Command"
complete -c proxyset -n "not __fish_seen_subcommand_from $commands $modules" -a "$modules" -d "Module target"

# Subcommands for modules
for mod in $modules
    complete -c proxyset -n "__fish_seen_subcommand_from $mod" -a "set unset status"
end

# Specific command completions
complete -c proxyset -n "__fish_seen_subcommand_from snapshot" -a "save restore list show diff delete"
complete -c proxyset -n "__fish_seen_subcommand_from profile" -a "save load list"
complete -c proxyset -n "__fish_seen_subcommand_from pac" -a "set unset status"

# Run command needs file completion for command
complete -c proxyset -n "__fish_seen_subcommand_from run" -F
