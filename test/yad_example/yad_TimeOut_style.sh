#!/bin/sh

# 更换yad的超时样式

# Add a following lines to your .gtkrc-2.0
style "timeout-indicator"
{
    GtkProgressBar::min-horizontal-bar-height = 5
    GtkProgressBar::min-vertical-bar-width = 5
}
widget "*yad-timeout-indicator" style "timeout-indicator"
This style may be added to any script by a simple trick
cat > /tmp/gtkrc.yad <<EOF
style "timeout-indicator"
{
    GtkProgressBar::min-horizontal-bar-height = 5
    GtkProgressBar::min-vertical-bar-width = 5
}
widget "*yad-timeout-indicator" style "timeout-indicator"
EOF

if [ -n "$GTK_RC_FILES" ]; then
    export GTK_RC_FILES="$GTK_RC_FILES:/tmp/gtkrc.yad"
else
    export GTK_RC_FILES="/tmp/gtkrc.yad"
fi