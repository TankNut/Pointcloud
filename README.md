# Pointcloud
A work in progress minimap addon based around the idea of using a point cloud to store map info

## Console variables
- `pointcloud_enabled` - Addon-wide toggle of functionality
- `pointcloud_resolution` - How many units one point represents

- `pointcloud_minimap_enabled` - Whether to draw the minimap or not
- `pointcloud_minimap_width` - How wide the minimap should be in pixels
- `pointcloud_minimap_tall` - How tall the minimap should be in pixels
- `pointcloud_minimap_zoom` - Self-explanatory

- `pointcloud_projection_key` - What key to use to toggle the map projection (Defaults to J)
- `pointcloud_projection_scale` - How large the projection should be in respect to the actual map
- `pointcloud_projection_height` - At what height relative to the player's feet the projection should put the origin
- `pointcloud_projection_mode` - What rendering mode should be used to draw projections (1: Cubes, 2: Points)