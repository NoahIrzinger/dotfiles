# mobile-dark.tmux: compact, ASCII-only tmux status for small mobile SSH clients.
# Avoids Nerd Font icons, powerline separators, and long right-side modules.

set -g status 1
set -g status-position top
set -g status-interval 10
set -g status-style 'bg=#{E:@thm_crust},fg=#{E:@thm_fg}'
set -g status-left-length 24
set -g status-right-length 28
set -g window-status-separator ' '

set -g status-left '#[fg=#{E:@thm_green},bg=#{E:@thm_crust}]#S #[fg=#{E:@thm_overlay_1}]| '
set -g status-right '#[fg=#{E:@thm_overlay_1}]#(hostname -s 2>/dev/null) #[fg=#{E:@thm_peach}]%H:%M'

set -g window-status-format '#[fg=#{E:@thm_overlay_1},bg=#{E:@thm_crust}]#I:#W'
set -g window-status-current-format '#[fg=#{E:@thm_crust},bg=#{E:@thm_mauve}] #I:#W #[default]'
set -g window-status-activity-style 'fg=#{E:@thm_yellow},bg=#{E:@thm_crust}'
set -g window-status-bell-style 'fg=#{E:@thm_red},bg=#{E:@thm_crust}'
