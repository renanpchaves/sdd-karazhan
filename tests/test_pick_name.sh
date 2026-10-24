. "$(dirname "$0")/lib.sh"; S=skills/sdd-karazhan/scripts/pick-name.sh
assert_exit 0 bash $S --help
assert_exit 2 bash $S xyz
out=$(SDD_SEED=1 bash $S eng --em-uso /dev/null); assert_eq "eng-grom" "$out" "primeiro livre com seed"
printf '| eng-grom | Engineer |\n' > $TMP/equipe.md
out=$(SDD_SEED=1 bash $S eng --em-uso $TMP/equipe.md); assert_eq "eng-saurfang" "$out" "pula nome em uso"
printf '| orch-antonidas |\n| orch-jaina |\n| orch-aethas |\n| orch-khadgar |\n| orch-aegwynn |\n| orch-kelthuzad |\n' > $TMP/cheio.md
assert_exit 1 bash $S orch --em-uso $TMP/cheio.md
# várias fontes de nomes em uso; arquivo ausente não é erro
printf 'eng-saurfang\n' > $TMP/sorteados.txt
out=$(SDD_SEED=1 bash $S eng --em-uso $TMP/equipe.md --em-uso $TMP/sorteados.txt --em-uso $TMP/nao-existe); assert_eq "eng-durotan" "$out" "várias fontes em uso"
# sem seed: sorteia um nome livre do pool
out=$(bash $S git --em-uso /dev/null); assert_contains "gazlowe gallywix mekkatorque thermaplugg brann sprocket" "${out#git-}" "sorteio dentro do pool"
