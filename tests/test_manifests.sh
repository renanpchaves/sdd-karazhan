. "$(dirname "$0")/lib.sh"
assert_exit 0 jq -e '.name == "sdd-karazhan"' .claude-plugin/plugin.json
assert_exit 0 jq -e '.plugins[0].name == "sdd-karazhan"' .claude-plugin/marketplace.json
assert_exit 0 jq -e '.orch | length == 6' skills/sdd-karazhan/roster.json
assert_exit 0 jq -e 'keys | length == 6' skills/sdd-karazhan/roster.json
assert_exit 0 jq -e '[.[][]] as $n | ($n | unique | length) == ($n | length)' skills/sdd-karazhan/roster.json   # nome em um pool só
assert_exit 0 jq -e '[.[][]] | all(test("^[a-z]+$"))' skills/sdd-karazhan/roster.json
assert_exit 0 jq -e '.mapa_max_dias == 30' skills/sdd-karazhan/config.json
