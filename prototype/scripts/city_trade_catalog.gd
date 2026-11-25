extends RefCounted
## Original game-balance catalog. Prices are not historical Roman price claims.

const ITEMS := {
	"bread":{"name":"Brot","price":2,"sell_price":1,"stock":40,"health":5,"stamina":12.0,"slot":"","attack":0,"defense":0,"command":0},
	"olives":{"name":"Oliven","price":2,"sell_price":1,"stock":24,"health":3,"stamina":6.0,"slot":"","attack":0,"defense":0,"command":0},
	"cheese":{"name":"Käse","price":4,"sell_price":2,"stock":18,"health":6,"stamina":10.0,"slot":"","attack":0,"defense":0,"command":0},
	"dried_figs":{"name":"Getrocknete Feigen","price":3,"sell_price":1,"stock":24,"health":4,"stamina":8.0,"slot":"","attack":0,"defense":0,"command":0},
	"stew":{"name":"Warmer Eintopf","price":5,"sell_price":2,"stock":18,"health":12,"stamina":20.0,"slot":"","attack":0,"defense":0,"command":0},
	"water":{"name":"Trinkwasser","price":1,"sell_price":0,"stock":60,"health":0,"stamina":22.0,"slot":"","attack":0,"defense":0,"command":0},
	"clay_cup":{"name":"Tonbecher","price":3,"sell_price":1,"stock":12,"health":0,"stamina":0.0,"slot":"","attack":0,"defense":0,"command":0},
	"oil_lamp":{"name":"Öllampe","price":6,"sell_price":2,"stock":8,"health":0,"stamina":0.0,"slot":"","attack":0,"defense":0,"command":0},
	"linen_tunic":{"name":"Leinentunika","price":12,"sell_price":4,"stock":8,"health":0,"stamina":0.0,"slot":"body","attack":0,"defense":1,"command":0},
	"wool_cloak":{"name":"Wollmantel","price":18,"sell_price":6,"stock":6,"health":0,"stamina":0.0,"slot":"body","attack":0,"defense":2,"command":0},
	"leather_belt":{"name":"Ledergürtel","price":10,"sell_price":3,"stock":8,"health":0,"stamina":0.0,"slot":"belt","attack":0,"defense":0,"command":1},
	"gladius":{"name":"Gladius","price":24,"sell_price":8,"stock":4,"health":0,"stamina":0.0,"slot":"weapon","attack":1,"defense":0,"command":0},
	"scutum":{"name":"Scutum","price":20,"sell_price":7,"stock":4,"health":0,"stamina":0.0,"slot":"shield","attack":0,"defense":2,"command":0},
	"fine_gladius":{"name":"Ausgezeichneter Gladius","price":70,"sell_price":24,"stock":0,"health":0,"stamina":0.0,"slot":"weapon","attack":3,"defense":0,"command":0},
	"bronze_brooch":{"name":"Bronzefibel","price":25,"sell_price":9,"stock":0,"health":0,"stamina":0.0,"slot":"belt","attack":0,"defense":0,"command":1},
	"officer_cloak":{"name":"Verdienstmantel","price":90,"sell_price":30,"stock":0,"health":0,"stamina":0.0,"slot":"body","attack":0,"defense":3,"command":2}
}
const SHOPS := {
	"bakery":{"name":"Bäckerei","kind":"bakery","position":[-10.0,-8.0],"items":["bread"]},
	"foodstall":{"name":"Lebensmittelstand","kind":"foodstall","position":[-4.0,-8.0],"items":["olives","cheese","dried_figs"]},
	"thermopolium":{"name":"Garküche und Trinkwasser","kind":"thermopolium","position":[4.0,-8.0],"items":["stew","water"]},
	"pottery":{"name":"Töpferei","kind":"pottery","position":[10.0,-8.0],"items":["clay_cup","oil_lamp"]},
	"clothier":{"name":"Tuch- und Lederwaren","kind":"clothier","position":[-10.0,4.0],"items":["linen_tunic","wool_cloak","leather_belt"]},
	"armorer":{"name":"Waffen- und Ausrüstungsschmiede","kind":"armorer","position":[10.0,4.0],"items":["gladius","scutum","fine_gladius","bronze_brooch","officer_cloak"]}
}
const SERVICE_KIT := {"gladius":1,"scutum":1,"linen_tunic":1,"leather_belt":1}
const REWARDS := {
	"watch_duty":{"name":"Verlässlich bei der Wachhilfe","money":3,"items":{"bronze_brooch":1},"xp":{"combat":0,"defense":2,"command":2}},
	"village_defense":{"name":"Bewährte Dorfverteidigung","money":8,"items":{"fine_gladius":1},"xp":{"combat":10,"defense":8,"command":4}},
	"frontier_delivery":{"name":"Bestätigte Versorgungslieferung","money":6,"items":{"leather_belt":1},"xp":{"combat":0,"defense":2,"command":8}},
	"valley_victory":{"name":"Gesicherte Talstraße","money":15,"items":{"officer_cloak":1},"xp":{"combat":8,"defense":8,"command":12}}
}

