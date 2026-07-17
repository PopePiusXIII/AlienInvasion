--!strict

export type API = {
	selectRandom: <T>(items: { T }) -> T?,
	selectRandom3: <T>(items: { T }) -> { T },
}

return {}
