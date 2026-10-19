-- Server entry point. Starts saving, cosmetics and the shop, then the round loop.
local CosmeticEffects = require(script.Parent.CosmeticEffects)
local DataManager = require(script.Parent.DataManager)
local GameManager = require(script.Parent.GameManager)
local ShopManager = require(script.Parent.ShopManager)

DataManager.Init()
CosmeticEffects.Init()
ShopManager.Init()
GameManager.Start()
