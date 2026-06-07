# lcars.tmux: LCARS panel header, active only under the lcars theme. `theme` copies
# this to ~/.config/tmux/theme-style.conf, sourced by tmux.conf via a deferred
# run-shell after tpm (catppuccin, re-sourced by tpm, sets status-format[0] from its
# own async job; sourcing last wins). empty for other themes -> default 1-row bar.
#
# shape: a continuous amber left bar + a solid amber top arm (rounded cap) make the
# elbow; content nests inside. rows (status-position top): [0]=arm, [1]=session +
# window pills, [2]=module pills (index 0 is the top line, 2 nearest the panes).
# pills are stadium caps in black text on solid colors. modules call scripts via
# #(), each with an explicit PATH since tmux runs #() with an empty PATH (no
# /usr/sbin -> no iostat, no /sbin -> no route).

set -g status 3
set -g status-position top
set -g status-interval 5
set -g status-style 'bg=#{E:@thm_crust},fg=#{E:@thm_fg}'
set -g status-left ''
set -g status-right ''
set -g window-status-separator ''

set -g 'status-format[0]' '#[fg=#{E:@thm_crust},bg=#{E:@thm_peach}]                                                          #[fg=#{E:@thm_peach},bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}]'
set -g 'status-format[1]' '#[fg=#{E:@thm_crust},bg=#{E:@thm_peach}]    #[bg=#{E:@thm_crust}] #[fg=#{E:@thm_peach},bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust},bg=#{E:@thm_peach}] #S #[fg=#{E:@thm_peach},bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}]  #[list=on align=left]#{W:#[fg=#{E:@thm_mauve}]#[bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust}]#[bg=#{E:@thm_mauve}] #I #W #[fg=#{E:@thm_mauve}]#[bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}] ,#[fg=#{E:@thm_peach}]#[bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust}]#[bg=#{E:@thm_peach}] #I #W #[fg=#{E:@thm_peach}]#[bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}] }'
set -g 'status-format[2]' '#[fg=#{E:@thm_crust},bg=#{E:@thm_peach}]    #[bg=#{E:@thm_crust}] #[align=right]#[fg=#{E:@thm_blue},bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust},bg=#{E:@thm_blue}] 󰫾 #(PATH=/usr/sbin:/sbin:/usr/bin:/bin:/opt/homebrew/bin $HOME/.local/share/tmux/plugins/kube-tmux/kube.tmux 250 #{E:@thm_crust} #{E:@thm_crust}) #[fg=#{E:@thm_blue},bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}] #[fg=#{E:@thm_sapphire},bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust},bg=#{E:@thm_sapphire}] CPU #(PATH=/usr/sbin:/sbin:/usr/bin:/bin:/opt/homebrew/bin $HOME/.local/share/tmux/plugins/tmux-cpu/scripts/cpu_percentage.sh) #[fg=#{E:@thm_sapphire},bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}] #[fg=#{E:@thm_mauve},bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust},bg=#{E:@thm_mauve}] RAM #(PATH=/usr/sbin:/sbin:/usr/bin:/bin:/opt/homebrew/bin $HOME/.local/share/tmux/plugins/tmux-cpu/scripts/ram_percentage.sh) #[fg=#{E:@thm_mauve},bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}] #[fg=#{E:@thm_pink},bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust},bg=#{E:@thm_pink}] 󰩠 #(PATH=/usr/sbin:/sbin:/usr/bin:/bin:/opt/homebrew/bin $HOME/.local/share/tmux/plugins/tmux-primary-ip/scripts/primary_ip.sh) #[fg=#{E:@thm_pink},bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}] #[fg=#{E:@thm_peach},bg=#{E:@thm_crust}]#[fg=#{E:@thm_crust},bg=#{E:@thm_peach}] 󰥔 %Y-%m-%d %H:%M #[fg=#{E:@thm_peach},bg=#{E:@thm_crust}]#[bg=#{E:@thm_crust}]'
