"""Finder layout; coordinates are points on the background's 720 x 528 canvas."""
import os

format = "UDZO"
filesystem = "HFS+"
files = [os.path.join(defines["contents"], "SFlip.app"),
         os.path.join(defines["contents"], "安装说明.txt")]
symlinks = {"Applications": "/Applications"}
hide = ["安装说明.txt"]
background = defines["background"]
icon = defines["icon"]
window_rect = ((200, 200), (720, 528))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
arrange_by = None
icon_size = 96
text_size = 13
label_pos = "bottom"
icon_locations = {"SFlip.app": (188, 236), "Applications": (532, 236)}
