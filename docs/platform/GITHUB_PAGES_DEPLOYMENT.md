# GitHub Pages Deployment

## What is prepared

The project contains `.github/workflows/deploy-pages.yml`. After the owner enables GitHub Pages for GitHub Actions and pushes this workflow to `main`, GitHub builds the Godot 4.7.2 Web Single-Threaded release and publishes only the generated static Web files. The owner's PC does not need to remain running, and future pushes to `main` rebuild automatically.

The workflow does not commit generated files. It uses official GitHub Pages actions pinned to specific commits and official Godot release assets pinned by SHA-256. The build job can read repository content and Pages metadata; the separate deploy job receives only `pages: write` and `id-token: write`.

## One-time owner activation

1. Review and commit the Task 31O project changes, then push them to `main` using the owner's normal Git workflow.
2. Open the GitHub repository, then **Settings > Pages**.
3. Under **Build and deployment**, set **Source** to **GitHub Actions**. Do not change repository visibility as part of this task.
4. Open **Actions** and select **Deploy Godot Web to GitHub Pages**. The push to `main` should start it automatically; **Run workflow** is also available for a manual retry.
5. Wait for both the `build` and `deploy` jobs to pass. The deployment summary shows the actual published URL.

GitHub returned no public repository metadata during Task 31O's unauthenticated check, so repository visibility and Pages-plan eligibility must be confirmed by the owner in Settings. The expected project-site format, not a verified live URL, is:

`https://insanevampyr.github.io/i-tank-prime-arena/`

Do not treat that address as live until the `deploy` job succeeds and the game is opened there.

## Browser acceptance check

1. Open the deployment URL in desktop Edge or Chrome and confirm the Arena scene loads.
2. Start the default Guard duel and Wave 1 once each.
3. Confirm keyboard/mouse controls, audio policy after a user gesture, and WebAssembly startup show no console errors.
4. Open the same HTTPS URL in Chrome on Android, rotate to landscape, and verify touch joystick, RUN, ATTACK, target selection, resize, focus-loss release, and RESET.

A desktop responsive viewport is not a physical Android test. Record physical-device results separately.

## Publishing future updates

Every owner push to `main` runs the workflow again. A successful deploy replaces the prior Pages artifact at the same stable URL. Failed builds do not publish a partial export.

## Disable or roll back deployment

- To stop automatic publication while retaining the current site, disable the workflow from **Actions > Deploy Godot Web to GitHub Pages > ... > Disable workflow**.
- To remove public Pages hosting, use **Settings > Pages** and unpublish/disable the site.
- To restore an older game version, the owner should use the normal safe Git history workflow and dispatch the workflow from an approved revision. Do not force-push or commit generated Web files.
