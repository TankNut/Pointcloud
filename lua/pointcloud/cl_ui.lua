hook.Add("AddToolMenuCategories", "pointcloud", function()
	spawnmenu.AddToolCategory("Options", "Pointcloud", "Pointcloud")
end)

hook.Add("PopulateToolMenu", "pointcloud", function()
	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_changelog", "Changelog (Last updated: 26 Apr 2021)", "", "", function(pnl)
		pnl:ClearControls()

		pnl:Help([[26 Apr 2021:

			- Improved the way data is stored and saved, reducing file sizes. This unfortunately means that any existing save files no longer work and will have to be remade
			- Greatly improved automapping behavior, it should no longer get 'stuck' as easily
			- Added an optional line of sight system to the minimap
			- Added pixelated filter options to both the minimap and line of sight system
			- Added a hologram display option to projections]])

		pnl:Help([[16 Aug 2020:

			- Added a new performance system based on frame budgets (Some convars might be reset, renamed or removed because of this)
			- Added a new radar sweep sample mode
			- The minimap now hides with the rest of your HUD when using the camera tool]])

		pnl:Help([[13 Aug 2020 (Hotfix):

			- Fixed an error when turning off the addon as it's loading a file]])

		pnl:Help([[13 Aug 2020:

			- Automap now follows the sample rate option instead of doing 10 times as much work
			- Automap samples can now 'bounce' off of the sky, allowing it to better deal with open areas]])

		pnl:Help([[10 Aug 2020:

			- Added an experimental automap sample mode]])

		pnl:Help([[08 Aug 2020:

			- Fixed some error spam (Surprised nobody reported this)
			- Improved the way the addon behaves when enabling/disabling, it now clears all data and starts loading fresh when re-enabled]])

		pnl:Help([[06 Aug 2020 (Hotfix #2):

			- Fixed the pointcloud folder not being created]])

		pnl:Help([[06 Aug 2020 (Hotfix):

			- Fixed the clear current map button not working
			- Added a button to manually toggle projections from the options menu]])

		pnl:Help([[06 Aug 2020:

			- Reorganized almost everything interally
			- Added this changelog
			- Loading is now done asynchronously to support larger files without crashing the game
			- Added a new option: Load budget
			- Fixed minimaps cutting off near the max map size]])

		pnl:Help([[03 Aug 2020:

			Initial release]])
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_general", "General settings", "", "", function(pnl)
		pnl:ClearControls()

		pnl:CheckBox("Enable", "pointcloud_enabled")
		pnl:Help([[Changing the resolution might help alleviate performance issues caused by the size of the map and the amount of data being stored but will decrease clarity and accuracy.

			This option can cause your game to slow down considerably as things are saved and loaded. Don't worry, this is normal.]])
		pnl:AddControl("ComboBox", {
			Label = "Resolution",
			MenuButton = 0,
			CVars = {"pointcloud_resolution"},
			Options = {
				["1. High (32 units/point)"] = {pointcloud_resolution = 32},
				["2. Medium (64 units/point)"] = {pointcloud_resolution = 64},
				["3. Low (128 units/point)"] = {pointcloud_resolution = 128}
			}
		})
		pnl:Help([[The sample mode is purely down to user preference and has no impact on performance whatsoever.]])
		pnl:AddControl("ComboBox", {
			Label = "Sample Mode",
			MenuButton = 0,
			CVars = {"pointcloud_samplemode"},
			Options = {
				["0. Disabled"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NONE},
				["1. Random noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_NOISE},
				["2. Front-facing noise"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_FRONTFACING},
				["3. AutoMap"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_AUTOMAP},
				["4. Radar sweep"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_SWEEPING},
				["5. BSP Leafs (Experimental)"] = {pointcloud_samplemode = POINTCLOUD_SAMPLE_BSP}
			}
		})

		pnl:CheckBox("Show Debug Info (requires minimap)", "pointcloud_debug")

		pnl:Help("If you for any reason want to delete all maps or a specific subset, you can find the directory containing the map files in garrysmod/data/pointcloud")
		pnl:Button("Clear Current Map (current resolution)").DoClick = function()
			pointcloud:Clear()

			file.Delete(pointcloud.Persistence:GetFileName())
		end
		pnl:Button("Clear Current Map (all resolutions)").DoClick = function()
			pointcloud:Clear()

			for _, v in pairs(file.Find("pointcloud/" .. game.GetMap() .. "-*.dat", "DATA")) do
				file.Delete("pointcloud/" .. v)
			end
		end
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_performance", "Performance", "", "", function(pnl)
		pnl:ClearControls()

		pnl:Help([[Options in this menu determine how many miliseconds certain features of the mod can take up per frame.

			Increasing budgets will lower your FPS but increase the speed of certain actions.]])

		pnl:NumSlider("Load Budget", "pointcloud_budget_load", 20, 200, 0)
		pnl:NumSlider("Sampler Budget", "pointcloud_budget_sampler", 5, 40, 0)
		pnl:NumSlider("Projection Budget", "pointcloud_budget_projection", 1, 40, 0)
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_minimap", "Minimap", "", "", function(pnl)
		pnl:ClearControls()

		pnl:CheckBox("Enable Minimap", "pointcloud_minimap_enabled")
		pnl:CheckBox("Enable Line of Sight", "pointcloud_minimap_mask")

		pnl:NumSlider("Horizontal Alignment", "pointcloud_minimap_align_x", 0, 1, 2)
		pnl:NumSlider("Vertical Alignment", "pointcloud_minimap_align_y", 0, 1, 2)

		pnl:NumSlider("Width", "pointcloud_minimap_width", 1, ScrW(), 0)
		pnl:NumSlider("Height", "pointcloud_minimap_height", 1, ScrH(), 0)
		pnl:NumSlider("Zoom", "pointcloud_minimap_zoom", POINTCLOUD_MINZOOM, POINTCLOUD_MAXZOOM, 1)
		pnl:Help([[Changing the layer depth will adjust how many layers the minimap can draw below you at any time, which may affect performance on maps with a lot of verticality.

			Setting this to -1 will make it render every layer instead.]])
		pnl:NumSlider("Layer Depth", "pointcloud_minimap_layerdepth", -1, 100, 0)
		pnl:NumSlider("Minimap Alpha", "pointcloud_minimap_alpha", 1, 255, 0)

		pnl:AddControl("Color", {
			Label = "Background Color",
			Red = "pointcloud_minimap_color_r",
			Green = "pointcloud_minimap_color_g",
			Blue = "pointcloud_minimap_color_b",
			Alpha = "pointcloud_minimap_color_a"
		})

		pnl:CheckBox("Pixelated Minimap", "pointcloud_minimap_pixelated")
		pnl:CheckBox("Draw Player Position", "pointcloud_minimap_drawplayer")

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Zoom Out", Command = "pointcloud_minimap_zoomout", Label2 = "Zoom In", Command2 = "pointcloud_minimap_zoomin"})
		pnl:NumSlider("Zoom Step Size", "pointcloud_minimap_zoomstep", 0.1, 1, 1)
	end)

	spawnmenu.AddToolMenuOption("Options", "Pointcloud", "pointcloud_projection", "Projection", "", "", function(pnl)
		pnl:ClearControls()

		pnl:NumSlider("Scale", "pointcloud_projection_scale", 0.001, 0.1, 3)

		pnl:AddControl("ComboBox", {
			Label = "Render Mode",
			MenuButton = 0,
			CVars = {"pointcloud_projection_mode"},
			Options = {
				["1. Cubes"] = {pointcloud_projection_mode = POINTCLOUD_MODE_CUBE},
				["2. Points"] = {pointcloud_projection_mode = POINTCLOUD_MODE_POINTS},
				["3. Hologram"] = {pointcloud_projection_mode = POINTCLOUD_MODE_HOLOGRAM}
			}
		})

		pnl:AddControl("Color", {
			Label = "Hologram Color",
			Red = "pointcloud_projection_color_r",
			Green = "pointcloud_projection_color_g",
			Blue = "pointcloud_projection_color_b"
		})

		pnl:Help("There's currently an issue where other addons can break the control method used in singleplayer, use this button to toggle projections if that's the case for you")
		pnl:Button("Manual Toggle").DoClick = function()
			pointcloud.Projection:Toggle()
		end

		pnl:Help("")
		pnl:ControlHelp("Controls")
		pnl:AddControl("Numpad", {Label = "Toggle Projection", Command = "pointcloud_projection_key", ButtonSize = 22})
	end)
end)
