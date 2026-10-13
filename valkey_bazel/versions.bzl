"""Known Valkey source releases.

Only releases that ship a CMake build (8.1.0 onwards) are listed. Each one needs
`patches/<series>.patch`, shared by every release in that series and generated
by `scripts/make_patch.py`.
"""

ValkeyVersion = provider(
    doc = "Upstream source location for one Valkey release.",
    fields = {
        "series": "Major.minor release series, e.g. \"9.1\". Picks the patch.",
        "sha256": "sha256 of the tarball.",
        "url": "Tarball URL.",
    },
)

def _valkey(version, sha256):
    return ValkeyVersion(
        series = version.rsplit(".", 1)[0],
        sha256 = sha256,
        url = "https://github.com/valkey-io/valkey/archive/refs/tags/{}.tar.gz".format(version),
    )

VERSIONS = {
    "8.1.0": _valkey("8.1.0", "559274e81049326251fa5b1e1c64d46d3d4d605a691481e0819133ca1f1db44f"),
    "8.1.1": _valkey("8.1.1", "3355fbd5458d853ab201d2c046ffca9f078000587ccbe9a6c585110f146ad2c5"),
    "8.1.2": _valkey("8.1.2", "747b272191c15c7387f4ad3b3e7eda16deb1cffc6425e0571547f54e4d2e3646"),
    "8.1.3": _valkey("8.1.3", "8f862b3b0a72fd40587793964539589f6f83d01361ca1598b370cfaa301e0ec0"),
    "8.1.4": _valkey("8.1.4", "32350b017fee5e1a85f7e2d8580d581a0825ceae5cb3395075012c0970694dee"),
    "8.1.5": _valkey("8.1.5", "2d47a6afaec7a5383813579c2367193053ec885bc135e810284fe94ccdd324d2"),
    "8.1.6": _valkey("8.1.6", "8898dea8a51d25334db1835aeb55d475027f39d672213941308b9d3d470f832c"),
    "8.1.7": _valkey("8.1.7", "15c984f3fa7ee5b45a79cf9641e4871bf999acb65654940304e1c0807f58f7bc"),
    "8.1.8": _valkey("8.1.8", "0edc455ba7524f0cfa4f73fdc70b91dec6941e893a09bcbdd012470d08043cec"),
    "8.1.9": _valkey("8.1.9", "f7e927534aaeb3a5f4410375c3e6f2f0c1b9257db8bc573e68f9e2dbb11344f4"),
    "8.1.10": _valkey("8.1.10", "c74e50cd83f6d398a3dc570e04ac2fe538249585d021f76ee2449bbf9ebd04ed"),
    "9.0.0": _valkey("9.0.0", "088f47e167eb640ea31af48c81c5d62ee56321f25a4b05d4e54a0ef34232724b"),
    "9.0.1": _valkey("9.0.1", "9cfbc5f32a2a6058ee0f8c532b9c4d24167cc49d719f091dd75f1bb8353a1fc5"),
    "9.0.2": _valkey("9.0.2", "0ebaa583659ab784ce19170627032cfab7793a5570b7262775f9dbf77c103ec7"),
    "9.0.3": _valkey("9.0.3", "e220f4b0143292ee6ea6d705aa40d45a0c8a77759b3e94c201cb5c25dbdca42f"),
    "9.0.4": _valkey("9.0.4", "8d65e12cc9edb14d117b56fd33300e7b8cde2c087356de3f055d44689667670b"),
    "9.0.5": _valkey("9.0.5", "42aa4fdf8b6212071b101f32c9bc23b99e40e8494eebe0c9e4bbc50d04153741"),
    "9.0.6": _valkey("9.0.6", "38f1e83faf382637d6e49503903187acb3ceed624e96d7b1d32b8d3d52768414"),
    "9.1.0": _valkey("9.1.0", "7789fe1df257774457bafb4c1d56c9f7020c3879a7f5b4234af9030b2bd82dfd"),
    "9.1.1": _valkey("9.1.1", "7d7232acd1b8a49b4e05d07a00b3ca8c801ae06ab633ca6a3423bc5f385ab7ee"),
    "9.1.2": _valkey("9.1.2", "19c23908e7d57e8d91ef85b41f5646307582f10f4f0fb999bbf89ed24ec9c983"),
}
