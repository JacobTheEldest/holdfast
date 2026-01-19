# Holdfast

Holdfast is a personal Linux distribution based on [Universal Blue](https://universal-blue.org/) and [Bluefin](https://projectbluefin.io). It’s designed to provide a stable, dependable foundation to serve as a home base for development, experimentation, and daily use.

## Included from Bluefin

### Build System

- Automated builds via GitHub Actions on every commit
- Awesome self hosted Renovate setup that keeps all your images and actions up to date.
- Automatic cleanup of old images (90+ days) to keep it tidy
- Pull request workflow - test changes before merging to master
  - PRs build and validate before merge
  - `master` branch builds `:stable` images
- Validates your files on pull requests so you never break a build:
  - Brewfile, Justfile, ShellCheck, Renovate config, and it'll even check to make sure the flatpak you add exists on FlatHub
- Production Grade Features
  - Container signing and SBOM Generation
  - See checklist below to enable these as they take some manual configuration

### Homebrew Integration

- Pre-configured Brewfiles for easy package installation and customization
- Includes curated collections: development tools, fonts, CLI utilities. Go nuts.
- Users install packages at runtime with `brew bundle`, aliased to premade `ujust commands`
- See [custom/brew/README.md](custom/brew/README.md) for details

### Flatpak Support

- Ship your favorite flatpaks
- Automatically installed on first boot after user setup
- See [custom/flatpaks/README.md](custom/flatpaks/README.md) for details

### ujust Commands

- User-friendly command shortcuts via `ujust`
- Pre-configured examples for app installation and system maintenance for you to customize
- See [custom/ujust/README.md](custom/ujust/README.md) for details

### Build Scripts

- Modular numbered scripts (10-, 20-, 30-) run in order
- Example scripts included for third-party repositories and desktop replacement
- Helper functions for safe COPR usage
- See [build/README.md](build/README.md) for details

## Quick Start

### Verify Workflow Configuration

Your repository includes the following automated workflows:

- **Build Workflow** (`.github/workflows/build.yml`) - Builds and publishes the OS image
  - Creates tagged images: `stable`, `stable.YYYYMMDD`, `YYYYMMDD`
  - Publishes to: `ghcr.io/jacobtheeldest/holdfast:stable`

- **Validation Workflows** - Run on pull requests to validate:
  - Brewfiles (`.github/workflows/validate-brewfiles.yml`)
  - Flatpaks (`.github/workflows/validate-flatpaks.yml`)
  - Justfiles (`.github/workflows/validate-justfiles.yml`)
  - Shell scripts (`.github/workflows/validate-shellcheck.yml`)
  - Renovate config (`.github/workflows/validate-renovate.yml`)

- **Cleanup Workflow** (`.github/workflows/clean.yml`)
  - Runs: Weekly on Sundays at midnight UTC
  - Automatically removes images older than 90 days

- **Renovate Workflow** (`.github/workflows/renovate.yml`)
  - Keeps your dependencies up to date automatically

### Building

A build will start automatically on push to the `master` branch or when a pull request is opened. You can also trigger a build manually:

1. Go to Actions tab
2. Click on "Build container image" workflow
3. Click "Run workflow" button
4. Select branch and click "Run workflow"

**Note:** Image signing is disabled by default. Your images will build successfully without any signing keys. Once you're ready for production, see the "Complete GitHub Setup for Production" section below.

### 4. Customize Your Image

Choose your base image in `Containerfile` (line 23):

```dockerfile
FROM ghcr.io/ublue-os/bluefin:stable
```

Add your packages in `build/10-build.sh`:

```bash
dnf5 install -y package-name
```

Customize your apps:

- Add Brewfiles in `custom/brew/` ([guide](custom/brew/README.md))
- Add Flatpaks in `custom/flatpaks/` ([guide](custom/flatpaks/README.md))
- Add ujust commands in `custom/ujust/` ([guide](custom/ujust/README.md))

### 5. Development Workflow

All changes should be made via pull requests:

1. Open a pull request on GitHub with the change you want.
1. The PR will automatically trigger:
   - Build validation
   - Brewfile, Flatpak, Justfile, and shellcheck validation
   - Test image build
1. Once checks pass, merge the PR
1. Merging triggers publishes a `:stable` image

### 6. Deploy

Switch to the Holdfast image:

```bash
sudo bootc switch ghcr.io/jacobtheeldest/holdfast:stable
sudo systemctl reboot
```

## Complete GitHub Setup for Production

After enabling GitHub Actions and getting your first successful build, complete these steps to prepare your operating system for production use.

**5. Enable signing in the workflow:**

The build workflow has signing disabled by default. To enable it:

   a. Edit `.github/workflows/build.yml` in your repository

   b. Find the "OPTIONAL: Image Signing with Cosign" section (around line 210)

   c. Uncomment the signing steps by removing the `#` from the beginning of each line

   d. Commit and push the changes:

**6. Verify signing is working:**

After the next successful build, verify your images are signed:

```bash
cosign verify --key cosign.pub ghcr.io/jacobtheeldest/holdfast:stable
```

### Step 2: Enable SBOM Generation (Optional but Recommended)

Software Bill of Materials (SBOM) provides transparency about what's in your image for supply chain security.

**Requirements:** Image signing must be enabled first (Step 1 above).

**To enable SBOM generation:**

1. Edit `.github/workflows/build.yml`

2. Find the "SBOM (OPTIONAL)" section (around line 128)

3. Uncomment the following steps:
   - "Setup Syft"
   - "Generate SBOM"

4. Find the "OPTIONAL: SBOM Attestation" section (around line 232)

5. Uncomment the "Add SBOM Attestation" step

6. Commit and push:

   ```bash
   git add .github/workflows/build.yml
   git commit -m "Enable SBOM generation and attestation"
   git push
   ```

### Step 3: GitHub Actions Permissions

Ensure your repository has the correct permissions for Actions to work:

1. Go to **Settings** → **Actions** → **General**
   - Direct link: `https://github.com/JacobTheEldest/holdfast/settings/actions`

2. Under **"Workflow permissions"**, ensure either:
   - **"Read and write permissions"** is selected (recommended for this template)
   - Or **"Read repository contents and packages permissions"** with specific permissions granted

3. Check **"Allow GitHub Actions to create and approve pull requests"** if you want Renovate to work automatically

### Step 4: Enable GitHub Container Registry (GHCR)

Your images will be published to GitHub Container Registry. By default, packages are private.

**To make your images public:**

1. After your first successful build, go to your profile packages:
   - Visit: `https://github.com/users/JacobTheEldest/packages/container/holdfast`

2. Click on the package name (holdfast)

3. Click **"Package settings"** (on the right side)

4. Under **"Danger Zone"**, click **"Change visibility"**

5. Select **"Public"** and confirm

**To verify package settings:**

- Ensure the package is linked to your repository
- Add a description if desired
- Verify tags are being created properly

### Step 5: Set Up Renovate (Automated Dependency Updates)

Renovate is already configured in your repository (`renovate.json5`) and will automatically:

- Update OCI container image tags to SHA digests
- Update GitHub Actions versions
- Create pull requests for dependency updates

**The Renovate workflow should already be running.** Verify by checking:

1. Go to **Actions** tab → **Renovate** workflow
2. It should run every day at 10:00 AM UTC (configured in `.github/workflows/renovate.yml`)
3. Check for pull requests from Renovate updating dependencies

No additional setup is required unless you want to customize the Renovate configuration.

### Step 6: Repository Settings Checklist

Ensure these repository settings are configured correctly:

- [ ] **General Settings** (`Settings` → `General`)
  - [ ] Repository name is `holdfast`
  - [ ] Description is set appropriately
  - [ ] Enable Issues if you want to track bugs/features
  
- [ ] **GitHub Actions** (`Settings` → `Actions` → `General`)
  - [ ] Workflows are enabled
  - [ ] Workflow permissions are set correctly
  
- [ ] **Secrets and Variables** (`Settings` → `Secrets and variables` → `Actions`)
  - [ ] `SIGNING_SECRET` is added (after completing Step 1)
  
- [ ] **Pages** (Optional, for documentation)
  - [ ] Can be enabled to host documentation
  
- [ ] **Branch Protection** (Recommended for production)
  - [ ] Protect `master` branch
  - [ ] Require pull request reviews
  - [ ] Require status checks to pass before merging

## Production Checklist

- [ ] **Enable Image Signing** (Recommended)
  - Provides cryptographic verification of your images
  - Prevents tampering and ensures authenticity
  - Status: **Disabled by default** to allow immediate testing

- [ ] **Enable SBOM Attestation** (Recommended)
  - Generates Software Bill of Materials for supply chain security
  - Provides transparency about what's in your image
  - Requires image signing to be enabled first
  - Status: **Disabled by default** (requires signing first)

- [ ] **Enable Image Rechunking** (Recommended)
  - Optimizes bootc image layers for better update performance
  - Reduces update sizes by 5-10x
  - Improves download resumability with evenly sized layers
  - To enable:
    1. Edit `.github/workflows/build.yml`
    2. Find the "Build Image" step
    3. Add a rechunk step after the build (see example below)
  - Status: **Not enabled by default** (optional optimization)

#### Adding Image Rechunking

After building your bootc image, add a rechunk step before pushing to the registry. Here's an example based on the workflow used by [zirconium-dev/zirconium](https://github.com/zirconium-dev/zirconium):

```yaml
- name: Build image
  id: build
  run: sudo podman build -t "${IMAGE_NAME}:${DEFAULT_TAG}" -f ./Containerfile .

- name: Rechunk Image
  run: |
    sudo podman run --rm --privileged \
      -v /var/lib/containers:/var/lib/containers \
      --entrypoint /usr/libexec/bootc-base-imagectl \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      rechunk --max-layers 96 \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}"

- name: Push to Registry
  run: sudo podman push "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" "${IMAGE_REGISTRY}/${IMAGE_NAME}:${DEFAULT_TAG}"
```

Alternative approach using a temporary tag for clarity:

```yaml
- name: Rechunk Image
  run: |
    sudo podman run --rm --privileged \
      -v /var/lib/containers:/var/lib/containers \
      --entrypoint /usr/libexec/bootc-base-imagectl \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      rechunk --max-layers 67 \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}" \
      "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked"
    
    # Tag the rechunked image with the original tag
    sudo podman tag "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked" "localhost/${IMAGE_NAME}:${DEFAULT_TAG}"
    sudo podman rmi "localhost/${IMAGE_NAME}:${DEFAULT_TAG}-rechunked"
```

**Parameters:**

- `--max-layers`: Maximum number of layers for the rechunked image (typically 67 for optimal balance)
- The first image reference is the source (input)
- The second image reference is the destination (output)
  - When using the same reference for both, the image is rechunked in-place
  - You can also use different tags (e.g., `-rechunked` suffix) and then retag if preferred

**References:**

- [CoreOS rpm-ostree build-chunked-oci documentation](https://coreos.github.io/rpm-ostree/build-chunked-oci/)
- [bootc documentation](https://containers.github.io/bootc/)

### After Enabling Production Features

Your workflow will:

- Sign all images with your key
- Generate and attach SBOMs
- Provide full supply chain transparency

Users can verify your images with:

```bash
cosign verify --key cosign.pub ghcr.io/jacobtheeldest/holdfast:stable
```

## Detailed Guides

- [Homebrew/Brewfiles](custom/brew/README.md) - Runtime package management
- [Flatpak Preinstall](custom/flatpaks/README.md) - GUI application setup
- [ujust Commands](custom/ujust/README.md) - User convenience commands
- [Build Scripts](build/README.md) - Build-time customization

## Architecture

This template follows the **multi-stage build architecture** from @projectbluefin/distroless, as documented in the [Bluefin Contributing Guide](https://docs.projectbluefin.io/contributing/).

### Multi-Stage Build Pattern

**Stage 1: Context (ctx)** - Combines resources from multiple sources:

- Local build scripts (`/build`)
- Local custom files (`/custom`)
- **@projectbluefin/common** - Desktop configuration shared with Aurora
- **@projectbluefin/branding** - Branding assets
- **@ublue-os/artwork** - Artwork shared with Aurora and Bazzite
- **@ublue-os/brew** - Homebrew integration

**Stage 2: Base Image** - Default options:

- `ghcr.io/ublue-os/silverblue-main:latest` (Fedora-based, default)
- `quay.io/centos-bootc/centos-bootc:stream10` (CentOS-based alternative)

### Benefits of This Architecture

- **Modularity**: Compose your image from reusable OCI containers
- **Maintainability**: Update shared components independently
- **Reproducibility**: Renovate automatically updates OCI tags to SHA digests
- **Consistency**: Share components across Bluefin, Aurora, and custom images

### OCI Container Resources

The template imports files from these OCI containers at build time:

```dockerfile
COPY --from=ghcr.io/ublue-os/base-main:latest /system_files /oci/base
COPY --from=ghcr.io/projectbluefin/common:latest /system_files /oci/common
COPY --from=ghcr.io/ublue-os/brew:latest /system_files /oci/brew
```

Your build scripts can access these files at:

- `/ctx/oci/base/` - Base system configuration
- `/ctx/oci/common/` - Shared desktop configuration
- `/ctx/oci/branding/` - Branding assets
- `/ctx/oci/artwork/` - Artwork files
- `/ctx/oci/brew/` - Homebrew integration files

**Note**: Renovate automatically updates `:latest` tags to SHA digests for reproducible builds.

## Local Testing

Test your changes before pushing:

```bash
just build              # Build container image
just build-qcow2        # Build VM disk image
just run-vm-qcow2       # Test in browser-based VM
```

## Community

- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc Discussion](https://github.com/bootc-dev/bootc/discussions)

## Learn More

- [Universal Blue Documentation](https://universal-blue.org/)
- [bootc Documentation](https://containers.github.io/bootc/)
- [Video Tutorial by TesterTech](https://www.youtube.com/watch?v=IxBl11Zmq5wE)

## Security

- Optional SBOM generation (Software Bill of Materials) for supply chain transparency
- Optional image signing with cosign for cryptographic verification
- Automated security updates via Renovate
- Build provenance tracking
