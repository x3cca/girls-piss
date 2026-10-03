# Refactor salvage review

Compared the working checkout with `origin/main` (`e8569ec`) in the detached
worktree `/tmp/girl-pisser-remote` on 2026-10-03. The local committed baseline
is `0409c1c`; remote is not a superset of it.

## Keep

- `gameplay_base.tscn`: removing the real level's inheritance from the smoke-test
  fixture is useful. Level 1 and future separate scenes can share the systems.
- `LevelDefinition` and the app's scene catalog: stable IDs, scenes, and ordering
  are enough for adding another level without rewriting Level 1.
- Subtree-scoped negative-zone discovery: one level should not find another
  level's hazards through global groups.
- Menu and credits scenes, route locking, and input-source handoff.
- The ribbon builder and surface-state helper: their extracted behavior matches
  the original code; stream/depth tests pass.
- Local music commit `7014437` (Crossfade gameplay music transitions), including
  both replacement Ogg files. A blanket remote reset would lose these changes.
  Spray looping, pitch, fades, and the shared Master bus also remain intact.

## Repairs made

- Title leads directly into Level 1. The placeholder Play/Credits menu was
  removed from startup at the user's request. Its scenes remain available for
  the future proper menu. Esc/controller B currently opens that menu.
- Restored the original completion card script and scene's credit artwork from
  remote, including seven credit chunks and the staggered reveal/retry timing.
- Kept completion in the level instead of sending replay completion directly to
  the generic results screen, which would interrupt the authored presentation.
- Moved initial music startup and the controls prompt out of retry/reset, so
  in-place retry preserves the original behavior rather than restarting the
  music and repeating the prompt.
- Updated navigation tests and documentation to describe the actual routes.

## Limits of reuse

The shared base still has bathroom-specific depth, lighting, surface discovery,
and completion art. It is a reusable scene foundation, not yet an environment-
independent gameplay framework. A future level should override those scene
resources and content rules as needed. Generalizing all of them today would
increase the risk of changing Level 1.

The generic results screen and ordered next-level helpers remain unused. Enable
progression only once a second scene exists and the intended completion handoff
is defined. The next level was deferred at the user's request.

## Validation

- Before repair: 171/171 local tests; some asserted that the menu was bypassed.
- Remote baseline: 167/167 tests.
- After repair: 173/173 local tests, including menu/credits/return navigation,
  original completion-card retention and retry, and failure/retry routing.
- Native rendered comparison of Level 1 against remote; bathroom composition
  and controls placement match. Targets randomize between attempts.
- Local music-file hashes match the pre-repair files; music controller behavior
  was preserved. No game code or assets in the remote worktree were edited.

A snapshot of pre-repair modified/untracked files is at
`/tmp/girl-pisser-before-salvage.tar.gz`. Changes remain uncommitted.

## Follow-up audio repair

A persistent `GameAudio` autoload creates the music controller and all effect
players from the outset. Scenes hold references to these globally owned players.
No playback nodes are reparented. Scene exit releases idle players, lets active
one-shots finish, and stops looping gameplay effects such as spray.
Retry resets the retained music; raid effects can finish even across retry.
This replaces retaining a hidden failed level solely for its audio.

The startup preload registry now includes all 16 runtime streams, including
the spray loop. The Web export also includes the missing mouse controls icon
and action labels. CI checks the manager, preload registry, key audio clips,
and mouse prompt are present in the Web bundle.

Validation: 175/175 tests pass, including preserved music position after scene
freeing, one-shot completion/cleanup, looping-effect cleanup, and raid sounds
continuing through retry. Release Web export succeeds and stays under the
12 MB bundle limit.

Looping music and spray use streamed playback from preloaded resources in the
HTML export; short effects use the warmed sample path. This preserves native
loop handling instead of depending on browser sample registration metadata.
