-- Custom window rule overrides (loaded after hyprland/rules.lua)

-- Disable tearing for Steam games: VRR (misc.vrr = 2) already gives low
-- latency in fullscreen, and `immediate` on top of it shows a tear line.
hl.window_rule({match = {class = "^(steam_app).*" }, immediate = false})
