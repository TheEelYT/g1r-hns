Changes in 0.7.7:

- Fixes the boot image byte-size crash after newer G1R installs compress `.rgba` and `.idx` mod assets.
- Decodes compressed installed assets through the engine codec, while preserving raw assets from older installs and compatibility with G1R 0.3.44.
- Supplies the caught Pokémon sprite and identity to G1R 0.3.53’s new registration-to-nickname handoff, preventing a second crash after catching.
- Adds image byte-size validation with the affected filename and a regression suite using the actual G1R 0.3.53 installer codec and real mod loader.

Existing HnS cart identity, isolated saves and seal are preserved. This is a compatibility update; previous terrain/UI fixes remain included. Automated checks cover both engine versions and both cache roots. Live Windows/GPU boot and gameplay still need player confirmation.
