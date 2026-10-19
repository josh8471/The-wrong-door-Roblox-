--!strict
-- Everything sold in the cosmetic shop. Prices are in coins earned by playing;
-- cosmetics are purely visual and never affect gameplay.

export type Slot = "Trail" | "Title" | "Victory"

export type Cosmetic = {
	Id: string,
	Name: string,
	Slot: Slot,
	Price: number,
	Colors: { Color3 }, -- trail gradient, title color, or particle colors
	Text: string?, -- titles: the words shown over your head
	Particle: string?, -- victory effects: "Sparkles" or "Smoke"
}

local Cosmetics = {}

Cosmetics.Slots = { "Trail", "Title", "Victory" } :: { Slot }

Cosmetics.List = {
	{
		Id = "SparkleTrail",
		Name = "Sparkle Trail",
		Slot = "Trail",
		Price = 100,
		Colors = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255) },
	},
	{
		Id = "SlimeTrail",
		Name = "Toxic Slime Trail",
		Slot = "Trail",
		Price = 150,
		Colors = { Color3.fromRGB(150, 255, 60), Color3.fromRGB(30, 120, 40) },
	},
	{
		Id = "YarnTrail",
		Name = "Grandma's Yarn",
		Slot = "Trail",
		Price = 200,
		Colors = { Color3.fromRGB(255, 140, 190), Color3.fromRGB(170, 120, 200) },
	},
	{
		Id = "RainbowTrail",
		Name = "Rainbow Trail",
		Slot = "Trail",
		Price = 300,
		Colors = {
			Color3.fromRGB(255, 70, 70),
			Color3.fromRGB(255, 160, 40),
			Color3.fromRGB(255, 230, 60),
			Color3.fromRGB(80, 220, 90),
			Color3.fromRGB(70, 150, 255),
			Color3.fromRGB(170, 90, 255),
		},
	},
	{
		Id = "TitleDoorExpert",
		Name = "Door Expert",
		Slot = "Title",
		Price = 80,
		Text = "Door Expert",
		Colors = { Color3.fromRGB(120, 220, 255) },
	},
	{
		Id = "TitleChickenWhisperer",
		Name = "Chicken Whisperer",
		Slot = "Title",
		Price = 150,
		Text = "Chicken Whisperer",
		Colors = { Color3.fromRGB(255, 205, 50) },
	},
	{
		Id = "TitleCertifiedCursed",
		Name = "Certified Cursed",
		Slot = "Title",
		Price = 300,
		Text = "Certified Cursed",
		Colors = { Color3.fromRGB(255, 70, 90) },
	},
	{
		Id = "ConfettiPop",
		Name = "Confetti Pop",
		Slot = "Victory",
		Price = 120,
		Particle = "Sparkles",
		Colors = {
			Color3.fromRGB(255, 120, 200),
			Color3.fromRGB(255, 230, 60),
			Color3.fromRGB(90, 220, 255),
			Color3.fromRGB(120, 255, 140),
		},
	},
	{
		Id = "FeatherPoof",
		Name = "Feather Poof",
		Slot = "Victory",
		Price = 200,
		Particle = "Smoke",
		Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 240, 210) },
	},
} :: { Cosmetic }

Cosmetics.ById = {} :: { [string]: Cosmetic }
for _, item in Cosmetics.List do
	Cosmetics.ById[item.Id] = item
end

-- A color gradient from a list of colors, spaced evenly.
function Cosmetics.ColorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

return Cosmetics
