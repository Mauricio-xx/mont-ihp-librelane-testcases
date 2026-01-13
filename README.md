# IHP LibreLane Testcases

RTL-to-GDS testcases for validating [LibreLane](https://github.com/efabless/librelane) with the IHP SG13G2 PDK.

This repository is designed for CI/CD testing of [IHP-EDA-Tools](https://github.com/mauricio-xx/ihp-eda-tools) container builds.

## Designs

| Design | Description | Complexity | Status |
|--------|-------------|------------|--------|
| inverter | Simple inverter gate | Minimal | Ready |
| user_proj_timer | Timer peripheral | Medium | Ready |
| y_huff | Huffman encoder | Medium | Ready |
| BM64 | BM64 design | Medium | Ready |
| usb | USB 2.0 core | Medium | Needs PDK update |
| APU | Audio Processing Unit | Medium | Needs PDK update |
| usb_cdc_core | USB CDC core | Medium | Needs PDK update |
| picorv32a | RISC-V CPU core | Large | Needs PDK update |

**Note**: "Needs PDK update" designs require LibreLane 2.x compatible PDK configuration with `FP_PDN_*` variables.

## Usage

### GitHub Actions (CI/CD)

1. Go to **Actions** → **LibreLane Tests**
2. Click **Run workflow**
3. Enter:
   - **Container image**: `ghcr.io/mauricio-xx/ihp-eda-tools:latest` (or specific tag)
   - **Designs**: `inverter user_proj_timer` (space-separated, or `all`)
   - **Use nix-eda**: `true` for reproducible builds

### Inside IHP-EDA-Tools Container

```bash
# Clone testcases
git clone https://github.com/mauricio-xx/ihp-librelane-testcases /tmp/testcases
cd /tmp/testcases

# Run specific design
./run_tests.sh inverter

# Run all IHP-ready designs
./run_tests.sh

# Run all designs (including those needing PDK updates)
./run_tests.sh all
```

### From Host (Docker)

```bash
# Clone this repo
git clone https://github.com/mauricio-xx/ihp-librelane-testcases
cd ihp-librelane-testcases

# Run tests in container
docker run --rm \
  -v $(pwd):/foss/designs/testcases:rw \
  ghcr.io/mauricio-xx/ihp-eda-tools:latest \
  --skip bash -c 'cd /foss/designs/testcases && ./run_tests.sh inverter'
```

### Local Development (with Nix)

```bash
# Enter nix-eda environment
nix develop

# Run tests (requires PDK_ROOT to be set)
PDK_ROOT=/path/to/pdks ./run_tests.sh inverter
```

## Requirements

- **IHP-EDA-Tools container** with `librelane-nix` support (recommended)
- OR local **nix** installation with flake support
- IHP SG13G2 PDK installed at `$PDK_ROOT/ihp-sg13g2`

## Reproducible Builds

This repository includes `flake.nix` and `flake.lock` for reproducible tool versions via [nix-eda](https://github.com/chipsalliance/nix-eda):

- LibreLane 3.0.0.dev43
- OpenROAD 2025-06-12
- Yosys 0.54
- Magic 8.3.528
- And other pinned EDA tools

Using `librelane-nix` (default) ensures consistent results regardless of container or host tool versions.

## Directory Structure

```
ihp-librelane-testcases/
├── .github/workflows/       # CI/CD workflows
├── designs/                 # RTL-to-GDS testcases
│   ├── inverter/
│   │   ├── config.json      # LibreLane configuration
│   │   └── src/             # Verilog source
│   ├── usb/
│   └── ...
├── flake.nix                # nix-eda environment
├── flake.lock               # Pinned dependencies
├── run_tests.sh             # Test runner script
└── README.md
```

## Test Results

Results are saved to `runs/<random_id>/<design>/`:
- `librelane.log` - Full build log
- `runs/` - LibreLane run artifacts including GDS

## Contributing

1. Fork this repository
2. Add new design under `designs/<name>/`
3. Include `config.json` and source files
4. Submit pull request

## License

Apache-2.0

## Related Projects

- [IHP-EDA-Tools](https://github.com/mauricio-xx/ihp-eda-tools) - Docker container for IHP IC design
- [IHP-Open-PDK](https://github.com/IHP-GmbH/IHP-Open-PDK) - IHP SG13G2 130nm BiCMOS PDK
- [LibreLane](https://github.com/efabless/librelane) - RTL-to-GDS flow
- [nix-eda](https://github.com/chipsalliance/nix-eda) - Reproducible EDA tool builds
