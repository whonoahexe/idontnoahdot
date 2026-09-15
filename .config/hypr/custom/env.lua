-- systemd's user-session PATH never included ~/.local/bin, so anything Hyprland
-- spawns (e.g. kitty running fish, which doesn't source .bashrc) couldn't see
-- binaries installed there, like claude.
local home_dir = os.getenv("HOME")
hl.env("PATH", home_dir .. "/.local/bin:" .. (os.getenv("PATH") or ""))

-- Carried over from the pre-rice hyprland.conf: force the NVIDIA dGPU (card1, 01:00.0)
-- as primary over the AMD iGPU (card2, 06:00.0) — aquamarine otherwise auto-picks
-- whichever GPU drives the physical panel (the iGPU here).
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card2")

-- NVIDIA rendering — required for correct behavior on the nvidia-open-dkms driver
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
