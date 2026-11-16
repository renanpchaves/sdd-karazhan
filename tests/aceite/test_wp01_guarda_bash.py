"""Oráculo de aceite da WP-01 (001-guarda-bash): hook PreToolUse para Bash.

Chama `bash skills/sdd-karazhan/hooks/bash-guard.sh` com o JSON do hook no stdin,
dentro de worktrees temporários com `.sdd-role` no formato do guard-install.sh.
Só stdlib e pytest.
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

RAIZ = Path(__file__).resolve().parents[2]
SK = RAIZ / "skills" / "sdd-karazhan"
HOOK = SK / "hooks" / "bash-guard.sh"
FORA_ABS = "/opt/sdd-karazhan-fora/x.txt"  # fora do worktree e fora de qualquer temp


def _worktree(base: Path, role: str = "bld", paths: str = "src/**") -> Path:
    wt = base / "wt"
    (wt / "src").mkdir(parents=True)
    (wt / "lib").mkdir()
    (wt / "tests" / "aceite").mkdir(parents=True)
    (wt / "src" / "a.py").write_text("a = 1\n")
    (wt / "lib" / "x.py").write_text("x = 1\n")
    subprocess.run(["git", "init", "-q"], cwd=wt, check=True)
    (wt / ".sdd-role").write_text(
        f"role={role}\nwp=WP-01\npaths={paths}\nroot={SK}\naceite=tests/aceite/**\n"
    )
    return wt


@pytest.fixture
def bld(tmp_path):
    return _worktree(tmp_path)


@pytest.fixture
def rev(tmp_path):
    return _worktree(tmp_path, role="rev", paths="")


def hook(cwd, command, tool="Bash"):
    entrada = json.dumps(
        {"tool_name": tool, "cwd": str(cwd), "tool_input": {"command": command}}
    )
    return subprocess.run(
        ["bash", str(HOOK)],
        input=entrada,
        capture_output=True,
        text=True,
        cwd=str(cwd),
        timeout=30,
    )


def bloqueia(cwd, command):
    r = hook(cwd, command)
    assert r.returncode == 2, f"esperava bloqueio (2) para {command!r}; rc={r.returncode} stderr={r.stderr!r}"
    assert r.stderr.strip(), f"bloqueio sem motivo em stderr: {command!r}"
    return r


def permite(cwd, command, tool="Bash"):
    r = hook(cwd, command, tool)
    assert r.returncode == 0, f"esperava permitir (0) para {command!r}; rc={r.returncode} stderr={r.stderr!r}"
    return r


def test_script_existe():
    assert HOOK.is_file(), f"falta {HOOK.relative_to(RAIZ)}"


@pytest.mark.parametrize(
    "cmd",
    [
        "sed -i '' 's/1/2/' lib/x.py",
        "sed -i 's/1/2/' lib/x.py",
        "sed -i.bak 's/1/2/' lib/x.py",
        "sed -i -e 's/1/2/' lib/x.py",
    ],
)
def test_bloqueia_sed_i_fora_dos_paths(bld, cmd):
    r = bloqueia(bld, cmd)
    assert "lib/x.py" in r.stderr


@pytest.mark.parametrize(
    "cmd",
    [
        "echo x > lib/x.py",
        "echo x >> lib/x.py",
        "ls &> lib/x.log",
        "ls 2> lib/err.log",
        "printf x>lib/x.py",
    ],
)
def test_bloqueia_redirecionamento_fora_dos_paths(bld, cmd):
    bloqueia(bld, cmd)


@pytest.mark.parametrize("cmd", ["echo x | tee lib/x.py", "echo x | tee -a lib/x.py"])
def test_bloqueia_tee_fora_dos_paths(bld, cmd):
    bloqueia(bld, cmd)


@pytest.mark.parametrize(
    "cmd",
    [
        "cp src/a.py lib/a.py",
        "mv src/a.py lib/a.py",
        "install -m 644 src/a.py lib/a.py",
    ],
)
def test_bloqueia_cp_mv_install_com_destino_fora(bld, cmd):
    bloqueia(bld, cmd)


@pytest.mark.parametrize(
    "cmd",
    [
        "rm lib/x.py",
        "rm -f lib/x.py",
        "touch lib/novo.py",
        "truncate -s 0 lib/x.py",
        "ln -s src/a.py lib/link.py",
        "dd if=/dev/zero of=lib/x.py count=1",
        "perl -pi -e 's/1/2/' lib/x.py",
        "perl -i -pe 's/1/2/' lib/x.py",
    ],
)
def test_bloqueia_demais_formas_de_escrita_fora(bld, cmd):
    bloqueia(bld, cmd)


@pytest.mark.parametrize(
    "cmd",
    [
        "true && echo x > lib/x.py",
        "ls; touch lib/novo.py",
        "cat src/a.py | tee lib/x.py",
        "bash -c 'echo x > lib/x.py'",
        "echo ok > src/a.py && sed -i '' 's/1/2/' lib/x.py",
    ],
)
def test_bloqueia_dentro_de_comando_composto(bld, cmd):
    bloqueia(bld, cmd)


@pytest.mark.parametrize(
    "cmd",
    [
        "echo x > tests/aceite/test_wp01_x.py",
        "sed -i '' 's/a/b/' tests/aceite/test_wp01_x.py",
        "cp src/a.py tests/aceite/test_wp01_x.py",
    ],
)
def test_bloqueia_tests_aceite_mesmo_com_paths_casando(tmp_path, cmd):
    wt = _worktree(tmp_path, paths="src/**,tests/**")
    bloqueia(wt, cmd)
    permite(wt, "echo x > tests/test_outro.py")  # tests/** fora do aceite segue livre


@pytest.mark.parametrize(
    "cmd",
    [
        "echo role=rev > .sdd-role",
        "sed -i '' 's/bld/rev/' .sdd-role",
        "echo 'paths=**' >> ./.sdd-role",
    ],
)
def test_bloqueia_sdd_role(tmp_path, cmd):
    wt = _worktree(tmp_path, paths="**")
    bloqueia(wt, cmd)


@pytest.mark.parametrize(
    "cmd",
    [
        f"echo x > {FORA_ABS}",
        f"cp src/a.py {FORA_ABS}",
        "echo x > ../fora.txt",
        "touch ../fora.txt",
    ],
)
def test_bloqueia_fora_do_worktree(tmp_path, cmd):
    wt = _worktree(tmp_path, paths="**")
    bloqueia(wt, cmd)


@pytest.mark.parametrize(
    "cmd",
    [
        "echo x > src/a.py",
        "touch src/novo.py",
        "sed -i '' 's/1/2/' src/a.py",
        "cp lib/x.py src/x.py",
    ],
)
def test_bloqueia_reviewer_escrevendo(rev, cmd):
    r = bloqueia(rev, cmd)
    assert "Reviewer" in r.stderr


def test_reviewer_le_e_descarta_em_dev_null(rev):
    permite(rev, "git status")
    permite(rev, "grep -r a src > /dev/null 2>&1")


@pytest.mark.parametrize(
    "cmd",
    [
        "echo x > src/a.py",
        "echo x >> src/novo.py",
        "sed -i '' 's/1/2/' src/a.py",
        "sed -i 's/1/2/' src/a.py",
        "echo x | tee src/a.py",
        "cp lib/x.py src/x.py",
        "mv src/a.py src/b.py",
        "touch src/novo.py",
        "rm src/a.py",
    ],
)
def test_permite_escrita_dentro_dos_paths(bld, cmd):
    permite(bld, cmd)


def test_permite_caminho_absoluto_dentro_dos_paths(bld):
    permite(bld, f"echo x > {bld}/src/a.py")


def test_permite_cwd_em_subdiretorio(bld):
    permite(bld / "src", "echo x > a.py")
    bloqueia(bld / "src", f"echo x > {bld}/lib/x.py")


@pytest.mark.parametrize(
    "cmd",
    [
        "grep a src/a.py > /dev/null",
        "ls 2>/dev/null",
        "echo erro > /dev/stderr",
        "echo x > /tmp/sdd-guarda.txt",
        "echo x > /private/tmp/sdd-guarda.txt",
        "cp lib/x.py /tmp/x.py",
    ],
)
def test_permite_dev_null_e_tmp(bld, cmd):
    permite(bld, cmd)


def test_permite_tmpdir(bld):
    tmpdir = os.environ.get("TMPDIR") or tempfile.gettempdir()
    permite(bld, f"echo x > {tmpdir.rstrip('/')}/sdd-guarda.txt")


@pytest.mark.parametrize(
    "cmd",
    [
        "git status",
        "git log --oneline -5",
        "ls -la",
        "cat lib/x.py",
        "bash tests/run.sh",
        "bash tests/run.sh 2>&1 | tail -5",
        "echo erro >&2",
        "grep -rn x lib | head",
        "python3 script.py",
    ],
)
def test_permite_comandos_de_leitura(bld, cmd):
    permite(bld, cmd)


def test_alvo_com_variavel_nao_expandida_nao_e_falso_positivo(bld):
    permite(bld, 'echo x > "$OUT"')


def test_sem_sdd_role_nao_faz_nada(tmp_path):
    livre = tmp_path / "livre"
    livre.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=livre, check=True)
    permite(livre, f"echo x > {FORA_ABS}")
    permite(livre, "sed -i '' 's/a/b/' qualquer.py")


def test_ignora_ferramenta_que_nao_e_bash(bld):
    permite(bld, "echo x > lib/x.py", tool="Read")


def test_hooks_json_registra_bash_para_bash_guard():
    cfg = json.loads((RAIZ / "hooks" / "hooks.json").read_text())
    entradas = cfg["hooks"]["PreToolUse"]
    bash = [e for e in entradas if "Bash" in e["matcher"].split("|")]
    assert bash, "nenhuma entrada PreToolUse com matcher Bash"
    cmds = [h["command"] for e in bash for h in e["hooks"]]
    assert any("bash-guard.sh" in c and c.startswith("bash ") for c in cmds), cmds
    edit = [e for e in entradas if e["matcher"] == "Edit|Write|MultiEdit|NotebookEdit"]
    assert edit and "path-guard.sh" in edit[0]["hooks"][0]["command"], "path-guard perdeu o registro"


def test_suite_do_plugin_tem_test_bash_guard():
    assert (RAIZ / "tests" / "test_bash_guard.sh").is_file()


def test_versao_013_e_changelog():
    plugin = json.loads((RAIZ / ".claude-plugin" / "plugin.json").read_text())
    market = json.loads((RAIZ / ".claude-plugin" / "marketplace.json").read_text())
    assert plugin["version"] == "0.1.3"
    assert market["plugins"][0]["version"] == "0.1.3"
    assert "## 0.1.3" in (RAIZ / "CHANGELOG.md").read_text()


def test_guardrails_documenta_bash_guard_e_limite():
    g = (SK / "references" / "guardrails.md").read_text()
    assert "bash-guard.sh" in g
    assert "Não cobre Bash" not in g
    assert "python" in g.lower(), "limite (escrita por dentro de programa) não documentado"


def test_suite_do_plugin_passa():
    r = subprocess.run(
        ["bash", "tests/run.sh"], cwd=RAIZ, capture_output=True, text=True, timeout=600
    )
    assert r.returncode == 0, r.stdout[-2000:] + r.stderr[-2000:]
