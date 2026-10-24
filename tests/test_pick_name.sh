. "$(dirname "$0")/lib.sh"; S=skills/sdd-karazhan/scripts/pick-name.sh
assert_exit 0 bash $S --help
assert_exit 2 bash $S xyz
out=$(SDD_SEED=1 bash $S eng --em-uso /dev/null); assert_eq "Grom" "$out" "primeiro livre com seed, inicial maiúscula, sem prefixo"
printf '| Grom | Engineer |\n' > $TMP/equipe.md
out=$(SDD_SEED=1 bash $S eng --em-uso $TMP/equipe.md); assert_eq "Saurfang" "$out" "pula nome em uso"
# formato antigo (prefixo-nome) em equipe.md também conta como em uso
printf '| eng-grom | Engineer |\n' > $TMP/antigo.md
out=$(SDD_SEED=1 bash $S eng --em-uso $TMP/antigo.md); assert_eq "Saurfang" "$out" "formato antigo em uso"
# palavra inteira: Grommash não ocupa Grom
printf '| Grommash | Engineer |\n' > $TMP/parecido.md
out=$(SDD_SEED=1 bash $S eng --em-uso $TMP/parecido.md); assert_eq "Grom" "$out" "só palavra inteira"
printf '| Antonidas |\n| Jaina |\n| Aethas |\n| Khadgar |\n| Aegwynn |\n| Kelthuzad |\n' > $TMP/cheio.md
assert_exit 1 bash $S orch --em-uso $TMP/cheio.md
# várias fontes de nomes em uso, sem diferenciar maiúsculas; arquivo ausente não é erro
printf 'saurfang\n' > $TMP/sorteados.txt
out=$(SDD_SEED=1 bash $S eng --em-uso $TMP/equipe.md --em-uso $TMP/sorteados.txt --em-uso $TMP/nao-existe); assert_eq "Durotan" "$out" "várias fontes em uso"
# sem seed: sorteia um nome livre do pool
out=$(bash $S git --em-uso /dev/null); assert_contains "Gazlowe Gallywix Mekkatorque Thermaplugg Brann Sprocket" "$out" "sorteio dentro do pool"
# roster com maiúscula é normalizado (cópia da skill em $TMP, o roster real fica intacto)
cp -R skills/sdd-karazhan $TMP/sk; jq '.eng[0] = "Grom"' skills/sdd-karazhan/roster.json > $TMP/sk/roster.json
out=$(SDD_SEED=1 bash $TMP/sk/scripts/pick-name.sh eng --em-uso $TMP/equipe.md); assert_eq "Saurfang" "$out" "roster normalizado em minúsculas"
