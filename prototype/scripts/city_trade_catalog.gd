extends RefCounted
## Original game-balance catalog. Prices are not historical Roman price claims.

const STABLE_ID := "equarius"
const HORSE_IDS := ["horse_fara", "horse_silex", "horse_iuba"]
const TACK_IDS := ["halter_leather", "saddlecloth_wool"]
const STABLE_ITEMS := HORSE_IDS + TACK_IDS

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
	"officer_cloak":{"name":"Verdienstmantel","price":90,"sell_price":30,"stock":0,"health":0,"stamina":0.0,"slot":"body","attack":0,"defense":3,"command":2},
	# Every animal is an individual stock unit. Its catalogue id survives resale
	# and, scoped to a world, cannot identify a second animal in that world.
	"horse_fara":{"name":"Fara · ruhige Packstute","price":18,"sell_price":8,"stock":1,"health":0,"stamina":0.0,"slot":"mount","attack":0,"defense":0,"command":0,
		"era":"equipment.italia.horse_trade", "access":"adult", "horse":{"name":"Fara","quality":1,"pace":43,"endurance":67,"handling":87}},
	"horse_silex":{"name":"Silex · trittsicheres Reisepferd","price":36,"sell_price":17,"stock":1,"health":0,"stamina":0.0,"slot":"mount","attack":0,"defense":0,"command":0,
		"era":"equipment.italia.horse_trade", "access":"delivery", "horse":{"name":"Silex","quality":2,"pace":64,"endurance":81,"handling":76}},
	"horse_iuba":{"name":"Iuba · schnelles Kurierpferd","price":58,"sell_price":27,"stock":1,"health":0,"stamina":0.0,"slot":"mount","attack":0,"defense":0,"command":0,
		"era":"equipment.italia.horse_trade", "access":"escort", "horse":{"name":"Iuba","quality":3,"pace":85,"endurance":88,"handling":58}},
	"halter_leather":{"name":"Lederhalfter","price":5,"sell_price":2,"stock":4,"health":0,"stamina":0.0,"slot":"tack","attack":0,"defense":0,"command":0,
		"era":"equipment.italia.leather_tack", "access":"adult", "tack":{"quality":1,"weight_kg":0.45}},
	"saddlecloth_wool":{"name":"Wollene Reitdecke mit Gurt","price":12,"sell_price":5,"stock":2,"health":0,"stamina":0.0,"slot":"tack","attack":0,"defense":0,"command":0,
		"era":"equipment.italia.leather_tack", "access":"delivery", "tack":{"quality":2,"weight_kg":1.2}}
}
const SHOPS := {
	"bakery":{"name":"Bäckerei","kind":"bakery","position":[-10.0,-8.0],"items":["bread"]},
	"foodstall":{"name":"Lebensmittelstand","kind":"foodstall","position":[-4.0,-8.0],"items":["olives","cheese","dried_figs"]},
	"thermopolium":{"name":"Garküche und Trinkwasser","kind":"thermopolium","position":[4.0,-8.0],"items":["stew","water"]},
	"pottery":{"name":"Töpferei","kind":"pottery","position":[10.0,-8.0],"items":["clay_cup","oil_lamp"]},
	"clothier":{"name":"Tuch- und Lederwaren","kind":"clothier","position":[-10.0,4.0],"items":["linen_tunic","wool_cloak","leather_belt"]},
	"armorer":{"name":"Waffen- und Ausrüstungsschmiede","kind":"armorer","position":[10.0,4.0],"items":["gladius","scutum","fine_gladius","bronze_brooch","officer_cloak"]},
	# The optional shop has no test-district fallback. The city has to register a
	# verified physical access point before any offer or transaction is enabled.
	"equarius":{"name":"Pferdehändler","kind":"stable","items":STABLE_ITEMS}
}
const SERVICE_KIT := {"gladius":1,"scutum":1,"linen_tunic":1,"leather_belt":1}
const REWARDS := {
	"watch_duty":{"name":"Verlässlich bei der Wachhilfe","money":3,"items":{"bronze_brooch":1},"xp":{"combat":0,"defense":2,"command":2}},
	"village_defense":{"name":"Bewährte Dorfverteidigung","money":8,"items":{"fine_gladius":1},"xp":{"combat":10,"defense":8,"command":4}},
	"frontier_delivery":{"name":"Bestätigte Versorgungslieferung","money":6,"items":{"leather_belt":1},"xp":{"combat":0,"defense":2,"command":8}},
	"valley_victory":{"name":"Gesicherte Talstraße","money":15,"items":{"officer_cloak":1},"xp":{"combat":8,"defense":8,"command":12}}
}

