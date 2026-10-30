# Workflow del fork

Fork personal de [helix-editor/helix](https://github.com/helix-editor/helix) en
`SpicyDogWings/helix`. Este repo se usa para dos cosas a la vez: **aportar**
(PRs a upstream) y **uso personal** (parches propios). La separación es por
ramas, no por repos.

## Las 3 ramas

| Rama | Rol | ¿Se commitea? | ¿Se pushea? |
|---|---|---|---|
| `master` | Espejo exacto de `upstream/master` | **Nunca** | **Nunca** (se sincroniza con `gh repo sync`) |
| `personal` | Tu trabajo diario: parches, config, experimentos | Sí | Sí (`origin/personal`) |
| `feat/<tema>` | Una rama por PR, nacida de `upstream/master` | Sí | Sí (`origin/feat/<tema>`) |

`feat/<tema>` no existe de antemano: se crea cuando hay algo que mandar, para
no dejar ramas vacías. Mientras no haya PR, trabajás en `personal`.

## Remotos

```
origin    https://github.com/SpicyDogWings/helix.git   (tu fork)
upstream  https://github.com/helix-editor/helix.git    (helix oficial, push deshabilitado)
```

`master` sigue a `upstream/master`. `push.default=current` y
`remote.pushDefault=origin` están configurados en el repo. El push por HTTPS usa
`gh` como credential helper (`gh auth setup-git`).

## Reglas (aplicadas por hooks, no por memoria)

Los hooks activos viven en `.git/hooks/` (así funcionan en **todas** las ramas,
incluso con `master` chequeado). La copia versionada está en `.githooks/`:

```sh
# después de clonar de cero:
cp .githooks/pre-commit .githooks/pre-push .git/hooks/ && chmod +x .git/hooks/pre-*
```

- `pre-commit` **bloquea commits en `master`**. Bypass consciente: `--no-verify`.
- `pre-push` **bloquea pushear `master`** a cualquier remoto.

Nota: no usar `core.hooksPath=.githooks` — en `master` ese directorio no existe
y git saltea los hooks en silencio (pasó en la prueba inicial).

Motivo: si `master` lleva commits propios, `git reset --hard upstream/master`
los pierde y los PRs arrastran ruido. Los parches viven en `personal`.

## Sincronizar con upstream

```sh
# master local = upstream
git switch master
git fetch upstream
git reset --hard upstream/master

# reflejarlo en el fork (fast-forward, no usa push local)
gh repo sync SpicyDogWings/helix -b master

# traer lo nuevo a tu rama de trabajo
git switch personal
git merge upstream/master        # merge, para no reescribir lo ya compilado
```

## Trabajo diario

```sh
git switch personal
# ... editar ...
cargo run --release              # probar el editor
git commit -am "lo que sea"
git push                         # push.default=current → origin/personal
```

## Abrir un PR a upstream

```sh
git fetch upstream
git switch -c feat/mi-tema upstream/master   # nace limpia, sin tus parches
# ... editar, commitear ...
cargo test --workspace
git push -u origin feat/mi-tema
gh pr create --repo helix-editor/helix --base master --head SpicyDogWings:feat/mi-tema

# si upstream avanzó:
git fetch upstream && git rebase upstream/master
git push --force-with-lease      # solo en ramas propias, nunca en master
```

Si el PR se estanca (upstream tiene ~637 PRs abiertos y ningún release desde
jul-2025), guardá el trabajo como serie de parches:

```sh
git format-patch upstream/master..feat/mi-tema -o /tmp/parches/
```

## Compilar y probar

```sh
cargo run --release                  # build de desarrollo (runtime del repo)
cargo test --workspace               # tests
cargo xtask docgen                   # regenerar docs autogeneradas si tocaste comandos/lenguajes
hx -g fetch && hx -g build           # grammars
rustup component add rust-analyzer   # si usás el toolchain del repo (MSRV)
```

## Licencia

Helix es **MPL-2.0** (copyleft por archivo). Uso personal no impone nada; si
distribuís binarios modificados, publicás los archivos modificados bajo MPL-2.0.
No hay derechos sobre la marca "Helix": el fork no debe presentarse como oficial.
