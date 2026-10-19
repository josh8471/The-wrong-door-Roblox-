-- Client entry point. Builds the HUD, voting cards, shop, results card and
-- spectate bar, and draws room effects.
local ChaserRenderer = require(script.Parent.ChaserRenderer)
local ProjectileRenderer = require(script.Parent.ProjectileRenderer)
local ResultsUI = require(script.Parent.ResultsUI)
local ScreenEffects = require(script.Parent.ScreenEffects)
local ShopUI = require(script.Parent.ShopUI)
local SpectateController = require(script.Parent.SpectateController)
local UIController = require(script.Parent.UIController)
local VotingUI = require(script.Parent.VotingUI)

UIController.Start()
VotingUI.Start()
SpectateController.Start()
ScreenEffects.Start()
ChaserRenderer.Start()
ProjectileRenderer.Start()
task.spawn(ShopUI.Start)
task.spawn(ResultsUI.Start)
